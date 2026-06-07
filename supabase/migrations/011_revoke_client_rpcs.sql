-- 011_revoke_client_rpcs.sql
-- Revoke execution rights on client-callable functions to enforce routing through Edge Functions only
REVOKE EXECUTE ON FUNCTION public.use_spin(UUID)                    FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_spin_state(UUID)              FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_user_stat(UUID, TEXT)   FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_leaderboard(TEXT, INTEGER)    FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_weekly_leaderboard(INTEGER)   FROM authenticated;
