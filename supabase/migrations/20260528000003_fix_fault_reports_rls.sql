-- Migration: Restrict fault_reports INSERT to authenticated users only.
-- Prevents anonymous/unauthenticated spam that would trigger FCM notification floods.

-- Step 1: Drop the public INSERT policy
DROP POLICY IF EXISTS "Faults: Anyone can report" ON public.fault_reports;

-- Step 2: Recreate it restricted to authenticated users only
CREATE POLICY "Faults: Authenticated users can report"
  ON public.fault_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Note: "Authenticated users can insert fault reports" policy (already authenticated) 
-- is redundant. Review if both should exist.
