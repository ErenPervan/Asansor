-- Create a bucket for storing fault images
insert into storage.buckets (id, name, public) 
values ('fault-images', 'fault-images', true)
on conflict (id) do nothing;

-- Ensure the column exists on fault_reports table (in case it wasn't there)
alter table public.fault_reports 
add column if not exists photo_url text;

-- RLS Policies for storage
-- Allow public viewing of fault images
create policy "Public Access to Fault Images"
  on storage.objects for select
  using ( bucket_id = 'fault-images' );

-- Allow authenticated users (technicians) to upload images
create policy "Authenticated Users can Upload Images"
  on storage.objects for insert
  to authenticated
  with check ( bucket_id = 'fault-images' );

-- Optional: Allow technicians to delete/update their own uploaded images
create policy "Authenticated Users can Update Images"
  on storage.objects for update
  to authenticated
  using ( bucket_id = 'fault-images' );
