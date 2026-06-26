-- ============================================
-- RBX Rewards - Weekly Leaderboard + User Stats Increment
-- ============================================

-- Weekly leaderboard (resets Monday 00:00 UTC)
-- Ranks users by total positive transaction amount in the current week
CREATE OR REPLACE FUNCTION public.get_weekly_leaderboard(p_limit INTEGER DEFAULT 50)
RETURNS TABLE (
  rank BIGINT,
  user_id UUID,
  display_name TEXT,
  coins BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_week_start TIMESTAMPTZ;
BEGIN
  v_week_start := date_trunc('week', NOW() AT TIME ZONE 'UTC');

  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(t.amount), 0) DESC) as rank,
    u.id as user_id,
    COALESCE(u.display_name, 'Anonymous') as display_name,
    COALESCE(SUM(t.amount), 0)::bigint as coins
  FROM public.users u
  LEFT JOIN public.transactions t
    ON t.user_id = u.id
    AND t.processed_at >= v_week_start
    AND t.amount > 0
  GROUP BY u.id, u.display_name
  HAVING COALESCE(SUM(t.amount), 0) > 0
  ORDER BY coins DESC
  LIMIT p_limit;
END;
$$;

-- Generic user stat incrementer (works online; offline queue handled client-side)
CREATE OR REPLACE FUNCTION public.increment_user_stat(
  p_user_id UUID,
  p_stat TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_stat = 'offers_completed' THEN
    UPDATE public.users
    SET offers_completed = offers_completed + 1, updated_at = NOW()
    WHERE id = p_user_id;
  ELSIF p_stat = 'games_played' THEN
    UPDATE public.users
    SET games_played = games_played + 1, updated_at = NOW()
    WHERE id = p_user_id;
  END IF;
END;
$$;

-- Grant execute to authenticated users (Flutter calls these via RPC)
GRANT EXECUTE ON FUNCTION public.get_weekly_leaderboard(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_user_stat(UUID, TEXT) TO authenticated;
