-- ============================================
-- Migration 033: Add Email Column to Users and Update Auth Trigger
-- ============================================

-- 1. Add email column to public.users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS email TEXT;

-- 2. Create index on email for fast lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- 3. Backfill existing emails from auth.users into public.users
UPDATE public.users pu
SET email = au.email
FROM auth.users au
WHERE pu.id = au.id AND pu.email IS NULL AND au.email IS NOT NULL;

-- 4. Update the handle_new_user() trigger function to populate email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (
    id,
    email,
    balance,
    total_earned,
    total_spent,
    games_played,
    offers_completed,
    consecutive_days,
    spin_free_spins,
    level,
    display_name,
    profile_photo_url,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    0,
    0,
    0,
    0,
    0,
    0,
    3,
    1,
    COALESCE(
      NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
      NULLIF(NEW.raw_user_meta_data->>'name', ''),
      NULLIF(NEW.raw_user_meta_data->>'display_name', ''),
      NULLIF(split_part(NEW.email, '@', 1), ''),
      'Player_' || SUBSTRING(NEW.id::text, 1, 6)
    ),
    NEW.raw_user_meta_data->>'profile_photo_url',
    COALESCE(NEW.created_at, NOW()),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = COALESCE(EXCLUDED.email, public.users.email),
    display_name = CASE 
      WHEN public.users.display_name IS NULL OR public.users.display_name LIKE 'Player_%'
      THEN COALESCE(EXCLUDED.display_name, public.users.display_name)
      ELSE public.users.display_name
    END,
    updated_at = NOW();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user failed: %', SQLERRM;
  RETURN NEW;
END;
$$;
