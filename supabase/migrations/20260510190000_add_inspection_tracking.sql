-- =============================================================================
-- Migration: Add Inspection Tracking Fields & History Table
-- Date: 2026-05-10
-- =============================================================================

-- 1. Create enum for inspection status if it doesn't exist
DO $$ BEGIN
    CREATE TYPE inspection_status AS ENUM ('red', 'yellow', 'blue', 'green', 'none');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Add columns to elevators table
ALTER TABLE public.elevators
  ADD COLUMN IF NOT EXISTS last_inspection_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS next_inspection_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS inspection_status inspection_status DEFAULT 'none';

COMMENT ON COLUMN public.elevators.last_inspection_date IS 'The date when the last A-Type legal inspection occurred.';
COMMENT ON COLUMN public.elevators.next_inspection_date IS 'The date when the next A-Type legal inspection is due (usually 1 year after the last).';
COMMENT ON COLUMN public.elevators.inspection_status IS 'The current legal certification tag (red, yellow, blue, green).';

-- 3. Create inspection_history table
CREATE TABLE IF NOT EXISTS public.inspection_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elevator_id UUID NOT NULL REFERENCES public.elevators(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES auth.users(id),
    inspection_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    status inspection_status NOT NULL,
    inspector_name TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Set up RLS for inspection_history
ALTER TABLE public.inspection_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Technicians can read all inspection history"
ON public.inspection_history FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Technicians can insert inspection history"
ON public.inspection_history FOR INSERT
TO authenticated
WITH CHECK (true);

-- 5. Set up realtime for inspection_history
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'inspection_history'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE inspection_history;
    END IF;
END $$;
