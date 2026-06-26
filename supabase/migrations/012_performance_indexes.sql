-- 010_performance_indexes.sql
-- Required for leaderboard fallback query on read replica
CREATE INDEX IF NOT EXISTS idx_users_total_earned
  ON public.users(total_earned DESC)
  WHERE total_earned > 0;

-- Helps game_sessions daily cap fallback query
CREATE INDEX IF NOT EXISTS idx_game_sessions_user_date
  ON public.game_sessions(user_id, created_at DESC)
  WHERE validated = true;
