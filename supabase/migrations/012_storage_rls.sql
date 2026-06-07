-- 012_storage_rls.sql
-- Authenticated users can upload only into their own folder in the profiles bucket
CREATE POLICY "upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profiles' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "public read avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'profiles');
