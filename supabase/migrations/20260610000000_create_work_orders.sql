CREATE TABLE work_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  elevator_id UUID REFERENCES elevators(id),
  created_by UUID REFERENCES profiles(id),
  assigned_to UUID REFERENCES profiles(id),
  title TEXT NOT NULL,
  description TEXT,
  priority TEXT CHECK (priority IN ('low','medium','high','critical')) DEFAULT 'medium',
  status TEXT CHECK (status IN (
    'open','in_progress','pending_approval','resolved','closed','cancelled'
  )) DEFAULT 'open',
  source TEXT CHECK (source IN ('manual','fault_report','schedule','sla_trigger')) DEFAULT 'manual',
  source_id UUID,
  due_date TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ,
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  idempotency_key TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE work_order_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_id UUID REFERENCES work_orders(id) ON DELETE CASCADE,
  changed_by UUID REFERENCES profiles(id),
  old_status TEXT,
  new_status TEXT,
  note TEXT,
  changed_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE work_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_order_history ENABLE ROW LEVEL SECURITY;

-- Admins can do everything
CREATE POLICY "Admins can manage all work orders" ON work_orders
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Admins can manage all work order history" ON work_order_history
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

-- Technicians can see and update work orders assigned to them
CREATE POLICY "Technicians can see assigned work orders" ON work_orders
  FOR SELECT
  USING (
    assigned_to = auth.uid()
    AND EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'technician')
  );

CREATE POLICY "Technicians can update assigned work orders" ON work_orders
  FOR UPDATE
  USING (
    assigned_to = auth.uid()
    AND EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'technician')
  );

-- Technicians can create work orders (e.g. from faults)
CREATE POLICY "Technicians can insert work orders" ON work_orders
  FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'technician')
  );

-- Technicians can see and insert their own history
CREATE POLICY "Technicians can see their work order history" ON work_order_history
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM work_orders 
      WHERE work_orders.id = work_order_history.work_order_id 
      AND work_orders.assigned_to = auth.uid()
    )
  );

CREATE POLICY "Technicians can insert work order history" ON work_order_history
  FOR INSERT
  WITH CHECK (
    changed_by = auth.uid()
  );

-- Customers can view work orders related to their elevators
CREATE POLICY "Customers can see work orders for their elevators" ON work_orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'customer'
      AND profiles.elevator_id = work_orders.elevator_id
    )
  );
