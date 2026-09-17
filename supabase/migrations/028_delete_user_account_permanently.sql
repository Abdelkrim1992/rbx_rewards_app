-- ============================================================================
-- Migration 028: Permanent User Account Deletion (Apple Guideline 5.1.1(v))
-- ============================================================================

-- 1. Enable RLS and add DELETE policies so authenticated users can delete their own rows directly
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can delete own data" ON public.users;
CREATE POLICY "Users can delete own data" ON public.users
    FOR DELETE USING (auth.uid() = id);

-- 2. Dependent table DELETE policies
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'transactions') THEN
    ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Users can delete own transactions" ON public.transactions;
    CREATE POLICY "Users can delete own transactions" ON public.transactions
        FOR DELETE USING (auth.uid() = user_id);
  END IF;

  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'game_sessions') THEN
    ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Users can delete own game sessions" ON public.game_sessions;
    CREATE POLICY "Users can delete own game sessions" ON public.game_sessions
        FOR DELETE USING (auth.uid() = user_id);
  END IF;

  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'game_stats') THEN
    ALTER TABLE public.game_stats ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Users can delete own game stats" ON public.game_stats;
    CREATE POLICY "Users can delete own game stats" ON public.game_stats
        FOR DELETE USING (auth.uid() = user_id);
  END IF;

  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'redeemed_rewards') THEN
    ALTER TABLE public.redeemed_rewards ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Users can delete own redeemed rewards" ON public.redeemed_rewards;
    CREATE POLICY "Users can delete own redeemed rewards" ON public.redeemed_rewards
        FOR DELETE USING (auth.uid() = user_id);
  END IF;

  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'referrals') THEN
    ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Users can delete own referrals" ON public.referrals;
    CREATE POLICY "Users can delete own referrals" ON public.referrals
        FOR DELETE USING (auth.uid() = referrer_id OR auth.uid() = referee_id);
  END IF;

  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_ad_stats') THEN
    ALTER TABLE public.user_ad_stats ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Users can delete own ad stats" ON public.user_ad_stats;
    CREATE POLICY "Users can delete own ad stats" ON public.user_ad_stats
        FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

-- 3. Atomic RPC to completely and permanently eradicate the user account from
--    both public tables AND auth.users without requiring manual developer confirmation.
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Cascade cleanup of dependent tables
  DELETE FROM public.transactions WHERE user_id = v_user_id;
  DELETE FROM public.game_sessions WHERE user_id = v_user_id;
  DELETE FROM public.game_stats WHERE user_id = v_user_id;
  DELETE FROM public.redeemed_rewards WHERE user_id = v_user_id;

  BEGIN
    DELETE FROM public.referrals WHERE referrer_id = v_user_id OR referee_id = v_user_id;
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;

  BEGIN
    DELETE FROM public.user_ad_stats WHERE user_id = v_user_id;
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;

  -- 2. Delete user profile row from public.users
  DELETE FROM public.users WHERE id = v_user_id;

  -- 3. Permanently delete auth user from auth.users
  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN true;
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
