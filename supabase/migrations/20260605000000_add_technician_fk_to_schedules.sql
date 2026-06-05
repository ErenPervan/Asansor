-- Add foreign key constraint between maintenance_schedules.technician_id and profiles.id
ALTER TABLE public.maintenance_schedules
  ADD CONSTRAINT fk_maintenance_schedules_technician
  FOREIGN KEY (technician_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
