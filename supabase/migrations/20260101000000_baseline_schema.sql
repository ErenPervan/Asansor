-- Baseline schema to allow local 'supabase start' to succeed
-- These tables were created manually in the Supabase Dashboard.
-- Using IF NOT EXISTS ensures this is skipped on production.

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY,
  full_name text,
  role text,
  fcm_token text,
  elevator_id uuid
);

CREATE TABLE IF NOT EXISTS public.elevators (
  id uuid PRIMARY KEY,
  qr_code_hash text,
  label text,
  current_status text
);

CREATE TABLE IF NOT EXISTS public.fault_reports (
  id uuid PRIMARY KEY,
  elevator_id uuid REFERENCES public.elevators(id),
  reported_by uuid REFERENCES public.profiles(id),
  description text,
  fault_type text,
  is_resolved boolean DEFAULT false,
  reported_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.maintenance_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  technician_id uuid REFERENCES public.profiles(id),
  scheduled_date date,
  status text DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS public.maintenance_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  elevator_id uuid REFERENCES public.elevators(id),
  technician_id uuid REFERENCES public.profiles(id),
  schedule_id uuid REFERENCES public.maintenance_schedules(id),
  notes text,
  is_approved boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.elevator_customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  elevator_id uuid REFERENCES public.elevators(id),
  customer_id uuid REFERENCES public.profiles(id)
);

CREATE TABLE IF NOT EXISTS public.checklist_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  maintenance_id uuid REFERENCES public.maintenance_logs(id),
  task text,
  is_completed boolean DEFAULT false
);
