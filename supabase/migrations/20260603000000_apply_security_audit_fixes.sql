-- Security & Architecture Audit Fixes

-- 1. Helper Functions
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role::text FROM public.profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.current_user_elevator_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT elevator_id FROM public.profiles WHERE id = auth.uid()
$$;

-- 2. fault_reports RLS Fix (prevent cross-tenant reporting)
DROP POLICY IF EXISTS "Faults: Authenticated users can report" ON public.fault_reports;
DROP POLICY IF EXISTS "Authenticated users can insert fault reports" ON public.fault_reports;

DROP POLICY IF EXISTS "Faults: admins full access" ON public.fault_reports;
CREATE POLICY "Faults: admins full access"
ON public.fault_reports FOR ALL TO authenticated
USING (public.current_user_role() = 'admin')
WITH CHECK (public.current_user_role() = 'admin');

DROP POLICY IF EXISTS "Faults: technicians can insert and read" ON public.fault_reports;
CREATE POLICY "Faults: technicians can insert and read"
ON public.fault_reports FOR INSERT TO authenticated
WITH CHECK (public.current_user_role() = 'technician');

DROP POLICY IF EXISTS "Faults: customers insert own elevator" ON public.fault_reports;
CREATE POLICY "Faults: customers insert own elevator"
ON public.fault_reports FOR INSERT TO authenticated
WITH CHECK (
  public.current_user_role() = 'customer'
  AND public.current_user_elevator_id() = fault_reports.elevator_id
);

DROP POLICY IF EXISTS "Faults: customers read own elevator" ON public.fault_reports;
CREATE POLICY "Faults: customers read own elevator"
ON public.fault_reports FOR SELECT TO authenticated
USING (
  (public.current_user_role() = 'customer' AND public.current_user_elevator_id() = fault_reports.elevator_id)
  OR public.current_user_role() IN ('admin', 'technician')
);

DROP POLICY IF EXISTS "Faults: technicians/admins update" ON public.fault_reports;
CREATE POLICY "Faults: technicians/admins update"
ON public.fault_reports FOR UPDATE TO authenticated
USING (public.current_user_role() IN ('admin', 'technician'))
WITH CHECK (public.current_user_role() IN ('admin', 'technician'));

-- 3. maintenance-reports Bucket Fix (make private and scoped)
UPDATE storage.buckets SET public = false WHERE id = 'maintenance-reports';

DROP POLICY IF EXISTS "Allow public to read maintenance reports" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated to update maintenance reports" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to upload maintenance reports" ON storage.objects;

DROP POLICY IF EXISTS "Reports: technicians/admins upload" ON storage.objects;
CREATE POLICY "Reports: technicians/admins upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'maintenance-reports'
  AND (storage.foldername(name))[1] = 'reports'
  AND public.current_user_role() IN ('admin', 'technician')
);

DROP POLICY IF EXISTS "Reports: scoped read" ON storage.objects;
CREATE POLICY "Reports: scoped read"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'maintenance-reports'
  AND (
    public.current_user_role() IN ('admin', 'technician')
    OR (
      public.current_user_role() = 'customer'
      AND public.current_user_elevator_id()::text = (storage.foldername(name))[2]
    )
  )
);

DROP POLICY IF EXISTS "Reports: owner roles update" ON storage.objects;
CREATE POLICY "Reports: owner roles update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'maintenance-reports'
  AND public.current_user_role() IN ('admin', 'technician')
)
WITH CHECK (
  bucket_id = 'maintenance-reports'
  AND public.current_user_role() IN ('admin', 'technician')
);

-- 4. notify_fault_report Webhook Fix (pinned search_path)
CREATE OR REPLACE FUNCTION public.notify_fault_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  v_url text;
  v_payload jsonb;
  v_headers jsonb;
BEGIN
  v_payload := json_build_object(
    'type', 'INSERT',
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW),
    'old_record', null
  )::jsonb;

  v_url := 'https://fuwmrhahwvsouhcxycyr.supabase.co/functions/v1/send-notification';
  v_headers := '{"Content-Type": "application/json"}'::jsonb;

  PERFORM net.http_post(
    url := v_url,
    headers := v_headers,
    body := v_payload
  );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_fault_report() FROM PUBLIC;

-- 5. elevators RLS Fix (apply tenant-scoped policies)
ALTER TABLE public.elevators ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Elevators: Admins full access" ON public.elevators;
DROP POLICY IF EXISTS "Elevators: Technicians can view all" ON public.elevators;
DROP POLICY IF EXISTS "Elevators: Customers view own" ON public.elevators;
DROP POLICY IF EXISTS "Elevators are viewable by authenticated users" ON public.elevators;

DROP POLICY IF EXISTS "Elevators: Admins full access" ON public.elevators;
CREATE POLICY "Elevators: Admins full access"
ON public.elevators FOR ALL TO authenticated
USING (public.current_user_role() = 'admin')
WITH CHECK (public.current_user_role() = 'admin');

DROP POLICY IF EXISTS "Elevators: Technicians can view all" ON public.elevators;
CREATE POLICY "Elevators: Technicians can view all"
ON public.elevators FOR SELECT TO authenticated
USING (public.current_user_role() = 'technician');

DROP POLICY IF EXISTS "Elevators: Customers view own" ON public.elevators;
CREATE POLICY "Elevators: Customers view own"
ON public.elevators FOR SELECT TO authenticated
USING (
  public.current_user_role() = 'customer'
  AND public.current_user_elevator_id() = elevators.id
);

-- 6. profiles RLS Fix (prevent self-escalation of role)
DROP POLICY IF EXISTS "Profiles: Users view/update own" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

DROP POLICY IF EXISTS "Profiles: Read all" ON public.profiles;
CREATE POLICY "Profiles: Read all"
  ON public.profiles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Profiles: Users update benign fields" ON public.profiles;
CREATE POLICY "Profiles: Users update benign fields"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND role::text = public.current_user_role()
    AND elevator_id IS NOT DISTINCT FROM public.current_user_elevator_id()
  );

DROP POLICY IF EXISTS "Profiles: Admins full update" ON public.profiles;
CREATE POLICY "Profiles: Admins full update"
  ON public.profiles FOR UPDATE
  USING (public.current_user_role() = 'admin')
  WITH CHECK (public.current_user_role() = 'admin');

-- 7. conflict_reports RLS Fix (add missing role check)
DROP POLICY IF EXISTS "Technicians can insert their own conflict reports" ON public.conflict_reports;
DROP POLICY IF EXISTS "Technicians can view their own conflict reports" ON public.conflict_reports;

CREATE POLICY "Technicians can insert their own conflict reports"
    ON public.conflict_reports FOR INSERT
    WITH CHECK (
      auth.uid() = technician_id 
      AND public.current_user_role() = 'technician'
    );

CREATE POLICY "Technicians can view their own conflict reports"
    ON public.conflict_reports FOR SELECT
    USING (
      auth.uid() = technician_id
      AND public.current_user_role() = 'technician'
    );
