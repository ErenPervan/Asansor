-- 1. Add version column to elevators
ALTER TABLE public.elevators
ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;

-- 2. Create trigger to auto-increment elevator version
CREATE OR REPLACE FUNCTION increment_elevator_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.version = OLD.version + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_increment_elevator_version ON public.elevators;

CREATE TRIGGER trg_increment_elevator_version
BEFORE UPDATE ON public.elevators
FOR EACH ROW
EXECUTE FUNCTION increment_elevator_version();

-- 3. Create conflict_reports table
CREATE TABLE IF NOT EXISTS public.conflict_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    elevator_id UUID NOT NULL REFERENCES public.elevators(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    local_payload JSONB NOT NULL,
    remote_payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Set up RLS for conflict_reports
ALTER TABLE public.conflict_reports ENABLE ROW LEVEL SECURITY;

-- Admins can view all reports
CREATE POLICY "Admins can view all conflict reports"
    ON public.conflict_reports FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

-- Technicians can insert their own reports
CREATE POLICY "Technicians can insert their own conflict reports"
    ON public.conflict_reports FOR INSERT
    WITH CHECK (auth.uid() = technician_id);

-- Technicians can view their own reports
CREATE POLICY "Technicians can view their own conflict reports"
    ON public.conflict_reports FOR SELECT
    USING (auth.uid() = technician_id);

-- Admins can update conflict reports
CREATE POLICY "Admins can update conflict reports"
    ON public.conflict_reports FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );
