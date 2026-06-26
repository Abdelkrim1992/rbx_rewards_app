-- ============================================
-- Fix Auth Trigger to be completely robust
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
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
    profile_photo_url
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
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'Player'),
    NEW.raw_user_meta_data->>'profile_photo_url'
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Catch any errors so the Auth signup does not fail
  -- The app has a client-side fail-safe that will insert the user row if this fails
  RAISE WARNING 'handle_new_user failed: %', SQLERRM;
  RETURN NEW;
END;
$$;
