-- ============================================
-- Add display_name to users table
-- ============================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS display_name TEXT DEFAULT 'Player';

-- Backfill existing rows
UPDATE public.users SET display_name = 'Player' WHERE display_name IS NULL;

-- Update handle_new_user trigger to set a default display_name
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.users (id, balance, total_earned, total_spent, display_name)
  VALUES (NEW.id, 0, 0, 0, COALESCE(NEW.raw_user_meta_data->>'display_name', 'Player'))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Update leaderboard to read display_name from public.users when available
CREATE OR REPLACE FUNCTION public.get_leaderboard(
  p_game_name TEXT,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  rank BIGINT,
  user_id UUID,
  display_name TEXT,
  high_score INTEGER,
  total_plays INTEGER,
  last_played_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY gs.high_score DESC) as rank,
    gs.user_id,
    COALESCE(u.display_name, 'Anonymous') as display_name,
    gs.high_score,
    gs.total_plays,
    gs.last_played_at
  FROM public.game_stats gs
  LEFT JOIN public.users u ON u.id = gs.user_id
  WHERE gs.game_name = p_game_name
  ORDER BY gs.high_score DESC
  LIMIT p_limit;
END;
$$;
