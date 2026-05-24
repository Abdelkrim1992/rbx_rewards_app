-- ============================================
-- RBX Rewards - Leaderboard from users table
-- ============================================

-- Switch get_weekly_leaderboard to read total_earned from the users table
-- instead of summing transactions for the current week.
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
BEGIN
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY u.total_earned DESC) as rank,
    u.id as user_id,
    COALESCE(u.display_name, 'Anonymous') as display_name,
    u.total_earned::bigint as coins
  FROM public.users u
  WHERE u.total_earned > 0
  ORDER BY u.total_earned DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_weekly_leaderboard(INTEGER) TO authenticated;
