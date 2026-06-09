-- Create the storage bucket for maintenance reports if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('maintenance-reports', 'maintenance-reports', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS for the objects table if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to upload files to the maintenance-reports bucket
CREATE POLICY "Allow authenticated users to upload maintenance reports"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'maintenance-reports');

-- Allow public to read maintenance reports (since public=true on bucket)
CREATE POLICY "Allow public to read maintenance reports"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'maintenance-reports');

-- Allow users to update their own uploads or allow authenticated to update
CREATE POLICY "Allow authenticated to update maintenance reports"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'maintenance-reports');
