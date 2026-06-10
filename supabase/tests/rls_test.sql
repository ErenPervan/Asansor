BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

-- Define plan size (number of tests)
SELECT plan(15);

-- Setup Mock Data & Users
-- Assume supabase's public schema
-- We need to mock user contexts for different roles

-- helper to set role context
CREATE OR REPLACE FUNCTION set_role_context(user_id uuid, role text) RETURNS void AS $$
BEGIN
  -- simulate auth.uid() and role claim
  PERFORM set_config('request.jwt.claims', format('{"sub": "%s", "role": "%s", "user_role": "%s"}', user_id, 'authenticated', role), true);
  SET LOCAL ROLE authenticated;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION reset_role_context() RETURNS void AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', '', true);
  RESET ROLE;
END;
$$ LANGUAGE plpgsql;

-- MOCK IDS
DO $$
DECLARE
  tech1_id uuid := '11111111-1111-1111-1111-111111111111';
  tech2_id uuid := '22222222-2222-2222-2222-222222222222';
  admin_id uuid := '33333333-3333-3333-3333-333333333333';
  customer_id uuid := '44444444-4444-4444-4444-444444444444';
  elevator1_id uuid := 'aaaa0000-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  elevator2_id uuid := 'bbbb0000-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  fault1_id uuid := 'cccc0000-cccc-cccc-cccc-cccccccccccc';
BEGIN
  -- Insert dummy users to auth.users (to satisfy foreign keys)
  INSERT INTO auth.users (id, email) VALUES 
    (tech1_id, 'tech1@test.com'),
    (tech2_id, 'tech2@test.com'),
    (admin_id, 'admin@test.com'),
    (customer_id, 'cust@test.com');

  -- Insert dummy profiles
  INSERT INTO public.profiles (id, full_name, role) VALUES 
    (tech1_id, 'Tech 1', 'technician'),
    (tech2_id, 'Tech 2', 'technician'),
    (admin_id, 'Admin', 'admin'),
    (customer_id, 'Customer', 'customer');

  -- Insert dummy elevators
  INSERT INTO public.elevators (id, qr_code_hash, label, current_status) VALUES
    (elevator1_id, 'hash1', 'Elevator 1', 'active'),
    (elevator2_id, 'hash2', 'Elevator 2', 'active');
    
  -- Insert dummy elevator customer mapping
  -- Assuming there is a relation or we just query by logic. 
  -- Our RLS says customers can only see maintenance_logs for elevators they own, or their profile
  -- Wait, if there's an `elevator_customers` table? No, we just insert and test if the policy allows.

  -- Insert a fault report created by tech1
  INSERT INTO public.fault_reports (id, elevator_id, reported_by, description, is_resolved) VALUES
    (fault1_id, elevator1_id, tech1_id, 'Initial fault', false);
END $$;


-- ==========================================
-- TEST: anon -> elevators (SELECT should be denied by RLS, or allowed if public? Plan says 'reddedilmeli')
-- ==========================================
SET LOCAL ROLE anon;
SELECT results_eq(
  'SELECT count(*) FROM public.elevators',
  ARRAY[0::bigint],
  'Anon user should see 0 elevators due to RLS'
);
RESET ROLE;

-- ==========================================
-- TEST: technician -> fault_reports (INSERT allowed for self)
-- ==========================================
SELECT set_role_context('11111111-1111-1111-1111-111111111111', 'technician');
SELECT lives_ok(
  $$ INSERT INTO public.fault_reports (elevator_id, reported_by, description) VALUES ('aaaa0000-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test fault') $$,
  'Technician should be able to insert fault report for themselves'
);
SELECT reset_role_context();

-- ==========================================
-- TEST: technician -> fault_reports (UPDATE another technician's record denied)
-- ==========================================
SELECT set_role_context('22222222-2222-2222-2222-222222222222', 'technician');
-- update should fail or affect 0 rows. Using RLS, it silently affects 0 rows.
-- Wait, we can test it by seeing if the row was updated.
UPDATE public.fault_reports SET description = 'Hacked' WHERE id = 'cccc0000-cccc-cccc-cccc-cccccccccccc';
SELECT results_eq(
  $$ SELECT description FROM public.fault_reports WHERE id = 'cccc0000-cccc-cccc-cccc-cccccccccccc' $$,
  ARRAY['Initial fault'],
  'Technician should not be able to update another technician''s fault report'
);
SELECT reset_role_context();

-- ==========================================
-- TEST: technician -> maintenance_logs (INSERT allowed for self)
-- ==========================================
SELECT set_role_context('11111111-1111-1111-1111-111111111111', 'technician');
SELECT lives_ok(
  $$ INSERT INTO public.maintenance_logs (elevator_id, technician_id, notes, is_approved) VALUES ('aaaa0000-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test maintenance', false) $$,
  'Technician should be able to insert maintenance log for themselves'
);
SELECT reset_role_context();

-- ==========================================
-- TEST: admin -> conflict_reports (SELECT allowed)
-- ==========================================
-- Insert a dummy conflict as admin or bypass
INSERT INTO public.conflict_reports (table_name, record_id, conflict_data) VALUES ('test', 'id1', '{}');

SELECT set_role_context('33333333-3333-3333-3333-333333333333', 'admin');
SELECT results_eq(
  'SELECT count(*) FROM public.conflict_reports',
  ARRAY[1::bigint],
  'Admin should be able to select from conflict_reports'
);
SELECT reset_role_context();

-- ==========================================
-- TEST: customer -> maintenance_logs (SELECT denied for other elevators)
-- ==========================================
SELECT set_role_context('44444444-4444-4444-4444-444444444444', 'customer');
-- Should see 0 since it doesn't own elevator1
SELECT results_eq(
  'SELECT count(*) FROM public.maintenance_logs',
  ARRAY[0::bigint],
  'Customer should see 0 maintenance logs for elevators they do not own'
);
SELECT reset_role_context();


-- FINISH
SELECT * FROM finish();
ROLLBACK;
