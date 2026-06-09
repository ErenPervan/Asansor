CREATE TABLE parts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  part_number TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  min_stock_level INTEGER NOT NULL DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE inventory_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  part_id UUID REFERENCES parts(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 0,
  location TEXT,
  last_restock_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(part_id, location)
);

CREATE TABLE part_usages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_id UUID REFERENCES work_orders(id) ON DELETE CASCADE,
  part_id UUID REFERENCES parts(id),
  quantity_used INTEGER NOT NULL CHECK (quantity_used > 0),
  used_by UUID REFERENCES profiles(id),
  used_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE parts ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE part_usages ENABLE ROW LEVEL SECURITY;

-- Admins can manage all
CREATE POLICY "Admins can manage parts" ON parts FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Admins can manage inventory" ON inventory_items FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Admins can manage usages" ON part_usages FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

-- Technicians can read parts and inventory
CREATE POLICY "Technicians can read parts" ON parts FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'technician'));

CREATE POLICY "Technicians can read inventory" ON inventory_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'technician'));

-- Technicians can insert part usages for their own work orders
CREATE POLICY "Technicians can read part usages" ON part_usages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM work_orders 
      WHERE work_orders.id = part_usages.work_order_id 
      AND work_orders.assigned_to = auth.uid()
    )
  );

CREATE POLICY "Technicians can insert part usages" ON part_usages FOR INSERT
  WITH CHECK (used_by = auth.uid());

-- Function to deduct stock automatically when a part is used
CREATE OR REPLACE FUNCTION deduct_inventory_stock()
RETURNS TRIGGER AS $$
BEGIN
  -- Deduct from the main inventory location (or the first available location)
  UPDATE inventory_items
  SET quantity = quantity - NEW.quantity_used,
      updated_at = now()
  WHERE part_id = NEW.part_id
    AND quantity >= NEW.quantity_used
    AND id = (
      SELECT id FROM inventory_items 
      WHERE part_id = NEW.part_id AND quantity >= NEW.quantity_used 
      ORDER BY quantity DESC LIMIT 1
    );

  -- If no stock found or insufficient, it might still insert the usage 
  -- but we could optionally raise an exception here.
  -- IF NOT FOUND THEN
  --   RAISE EXCEPTION 'Insufficient stock for part %', NEW.part_id;
  -- END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_deduct_inventory
AFTER INSERT ON part_usages
FOR EACH ROW
EXECUTE FUNCTION deduct_inventory_stock();
