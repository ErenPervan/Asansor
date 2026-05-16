-- Add new columns for Maintenance Completion Flow
ALTER TABLE public.maintenance_logs
ADD COLUMN IF NOT EXISTS checklist JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS photos TEXT[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS signature_url TEXT;

-- Create storage bucket for maintenance records
INSERT INTO storage.buckets (id, name, public)
VALUES ('maintenance-records', 'maintenance-records', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policies for the bucket
-- Allow public read access to maintenance records
CREATE POLICY "Public Access for maintenance records" 
ON storage.objects FOR SELECT
USING ( bucket_id = 'maintenance-records' );

-- Allow authenticated users (technicians) to upload files
CREATE POLICY "Authenticated users can upload maintenance records" 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK ( bucket_id = 'maintenance-records' );

-- Allow authenticated users to update their own files (if needed)
CREATE POLICY "Authenticated users can update maintenance records" 
ON storage.objects FOR UPDATE 
TO authenticated 
USING ( bucket_id = 'maintenance-records' );

-- Allow authenticated users to delete files
CREATE POLICY "Authenticated users can delete maintenance records" 
ON storage.objects FOR DELETE 
TO authenticated 
USING ( bucket_id = 'maintenance-records' );
