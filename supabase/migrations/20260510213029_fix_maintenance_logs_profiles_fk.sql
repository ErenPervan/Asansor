-- Fix the foreign key relationship between maintenance_logs and profiles
-- This allows PostgREST to join the tables via .select('*, profiles(*)')

DO $$ 
BEGIN
    -- Check if the constraint already exists
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'maintenance_logs_technician_id_fkey_profiles' 
        AND table_name = 'maintenance_logs'
    ) THEN
        -- Add the foreign key constraint
        ALTER TABLE public.maintenance_logs
        ADD CONSTRAINT maintenance_logs_technician_id_fkey_profiles
        FOREIGN KEY (technician_id) REFERENCES public.profiles(id)
        ON DELETE SET NULL;
    END IF;
END $$;
