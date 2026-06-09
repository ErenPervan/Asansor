DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_maintenance_schedules_technician'
    ) THEN
        ALTER TABLE public.maintenance_schedules
        ADD CONSTRAINT fk_maintenance_schedules_technician
        FOREIGN KEY (technician_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;
END $$;
