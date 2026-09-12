-- ============================================
-- Migration 025: Drop Display Name Unique Constraint & Auto-Heal Missing Users
-- ============================================

-- 1. Drop the unique index/constraint on display_name that was preventing multiple users from having default names
DROP INDEX IF EXISTS public.idx_users_display_name_unique;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS idx_users_display_name_unique;

-- 2. Create a standard non-unique index for fast display_name queries and leaderboard lookups
CREATE INDEX IF NOT EXISTS idx_users_display_name ON public.users(display_name);

-- 3. Auto-heal: Backfill all existing auth.users who are missing a record in public.users
INSERT INTO public.users (
  id,
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
SELECT 
  au.id,
  0,
  0,
  0,
  0,
  0,
  0,
  3,
  1,
  COALESCE(
    NULLIF(au.raw_user_meta_data->>'display_name', ''),
    'Player_' || SUBSTRING(au.id::text, 1, 6)
  ),
  au.raw_user_meta_data->>'profile_photo_url',
  COALESCE(au.created_at, NOW()),
  NOW()
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- 4. Update the handle_new_user trigger to safely handle display names and never fail
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (
    id,
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
    0,
    0,
    0,
    0,
    0,
    0,
    3,
    1,
    COALESCE(
      NULLIF(NEW.raw_user_meta_data->>'display_name', ''),
      'Player_' || SUBSTRING(NEW.id::text, 1, 6)
    ),
    NEW.raw_user_meta_data->>'profile_photo_url',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user failed: %', SQLERRM;
  RETURN NEW;
END;
$$;
