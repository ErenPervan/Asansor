CREATE TABLE pm_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  interval_months INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE pm_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  elevator_id UUID REFERENCES elevators(id) ON DELETE CASCADE,
  template_id UUID REFERENCES pm_templates(id),
  next_maintenance_date DATE NOT NULL,
  last_maintenance_date DATE,
  assigned_to UUID REFERENCES profiles(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE pm_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_schedules ENABLE ROW LEVEL SECURITY;

-- Admins can do everything
CREATE POLICY "Admins can manage pm_templates" ON pm_templates
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Admins can manage pm_schedules" ON pm_schedules
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

-- Technicians and Customers can read templates
CREATE POLICY "Anyone can read pm_templates" ON pm_templates
  FOR SELECT
  USING (true);

-- Technicians can see schedules assigned to them
CREATE POLICY "Technicians can read assigned pm_schedules" ON pm_schedules
  FOR SELECT
  USING (
    assigned_to = auth.uid()
  );

-- Default Templates
INSERT INTO pm_templates (name, description, interval_months) VALUES
  ('Aylık Standart Bakım', 'Asansörün genel kontrolü ve yağlaması', 1),
  ('Üç Aylık Detaylı Bakım', 'Halat, motor ve fren detaylı kontrolü', 3),
  ('Yıllık Ağır Bakım', 'Kapsamlı revizyon ve parça testi', 12);
