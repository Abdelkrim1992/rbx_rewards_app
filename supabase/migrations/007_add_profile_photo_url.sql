-- ============================================
-- Add profile_photo_url to users table
-- ============================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;

-- Update handle_new_user trigger to include profile_photo_url
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
    display_name,
    profile_photo_url
  )
  VALUES (
    NEW.id,
    0,
    0,
    0,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'Player'),
    NEW.raw_user_meta_data->>'profile_photo_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
