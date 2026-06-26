-- Allow users to insert their own row in the public.users table 
-- (mainly used as a fail-safe in the app if the auth trigger fails or is delayed)
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;

CREATE POLICY "Users can insert own data" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);
