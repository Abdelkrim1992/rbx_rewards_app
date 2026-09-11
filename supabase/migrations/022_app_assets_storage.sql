-- 022_app_assets_storage.sql
-- Create public storage bucket for app assets (CDN cached) and set public read RLS policy

-- 1. Create the 'app-assets' bucket if it doesn't already exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'app-assets',
  'app-assets',
  true,
  10485760, -- 10MB limit per asset
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'];

-- 2. Allow public global read (SELECT) for all users worldwide via Cloudflare CDN
DROP POLICY IF EXISTS "public read app-assets" ON storage.objects;
CREATE POLICY "public read app-assets" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'app-assets');

-- 3. Allow authenticated admins / service_role to upload and update assets
DROP POLICY IF EXISTS "admin upload app-assets" ON storage.objects;
CREATE POLICY "admin upload app-assets" ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'app-assets');

DROP POLICY IF EXISTS "admin update app-assets" ON storage.objects;
CREATE POLICY "admin update app-assets" ON storage.objects
  FOR UPDATE
  USING (bucket_id = 'app-assets');
