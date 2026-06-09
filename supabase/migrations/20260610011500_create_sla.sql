CREATE TABLE sla_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  priority_level TEXT CHECK (priority_level IN ('low','medium','high','critical')),
  max_response_time_minutes INTEGER NOT NULL,
  max_resolution_time_minutes INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE sla_breaches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_order_id UUID REFERENCES work_orders(id) ON DELETE CASCADE,
  policy_id UUID REFERENCES sla_policies(id),
  breach_type TEXT CHECK (breach_type IN ('response','resolution')),
  breached_at TIMESTAMPTZ DEFAULT now(),
  is_acknowledged BOOLEAN DEFAULT false,
  acknowledged_by UUID REFERENCES profiles(id),
  acknowledged_at TIMESTAMPTZ
);

-- RLS
ALTER TABLE sla_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE sla_breaches ENABLE ROW LEVEL SECURITY;

-- Admins can do everything
CREATE POLICY "Admins can manage SLA policies" ON sla_policies
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Admins can manage SLA breaches" ON sla_breaches
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

-- Technicians and Customers can read SLA policies
CREATE POLICY "Anyone can read SLA policies" ON sla_policies
  FOR SELECT
  USING (true);

-- Technicians can view breaches for their work orders
CREATE POLICY "Technicians can read their SLA breaches" ON sla_breaches
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM work_orders 
      WHERE work_orders.id = sla_breaches.work_order_id 
      AND work_orders.assigned_to = auth.uid()
    )
  );

-- Insert default SLA policies
INSERT INTO sla_policies (name, priority_level, max_response_time_minutes, max_resolution_time_minutes) VALUES
  ('Kritik Arıza SLA', 'critical', 60, 240),      -- 1 hour response, 4 hours resolution
  ('Yüksek Öncelikli SLA', 'high', 120, 480),     -- 2 hours response, 8 hours resolution
  ('Normal Arıza SLA', 'medium', 240, 1440),      -- 4 hours response, 24 hours resolution
  ('Düşük Öncelikli SLA', 'low', 1440, 2880);     -- 24 hours response, 48 hours resolution
