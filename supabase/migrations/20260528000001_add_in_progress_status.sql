-- Migration: Add 'in_progress' to maintenance_schedules status constraint
-- This fixes the mismatch between the DB check constraint and the Flutter frontend
-- which sends 'in_progress' when a technician starts a task.

ALTER TABLE public.maintenance_schedules 
DROP CONSTRAINT IF EXISTS maintenance_schedules_status_check;

ALTER TABLE public.maintenance_schedules 
ADD CONSTRAINT maintenance_schedules_status_check 
CHECK (status = ANY (ARRAY[
  'pending'::text, 
  'in_progress'::text, 
  'completed'::text, 
  'cancelled'::text
]));
