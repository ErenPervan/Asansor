CREATE TABLE service_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  elevator_id UUID REFERENCES elevators(id) ON DELETE SET NULL,
  subject TEXT NOT NULL,
  status TEXT CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')) DEFAULT 'open',
  priority TEXT CHECK (priority IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID REFERENCES service_tickets(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE service_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_messages ENABLE ROW LEVEL SECURITY;

-- Admins can do everything
CREATE POLICY "Admins can manage tickets" ON service_tickets FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Admins can manage messages" ON ticket_messages FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

-- Customers can read and create their own tickets
CREATE POLICY "Customers can manage their tickets" ON service_tickets FOR ALL
  USING (customer_id = auth.uid());

CREATE POLICY "Customers can manage their messages" ON ticket_messages FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM service_tickets 
      WHERE service_tickets.id = ticket_messages.ticket_id 
      AND service_tickets.customer_id = auth.uid()
    )
  );

-- Technicians can read all tickets and messages (or optionally only assigned, but let's say all for now)
CREATE POLICY "Technicians can read tickets" ON service_tickets FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'technician'));

CREATE POLICY "Technicians can read messages" ON ticket_messages FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'technician'));
