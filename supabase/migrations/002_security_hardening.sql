-- ============================================
-- RBX Rewards - Security Hardening Migration
-- ============================================

-- Fix existing policy creation to avoid 42710 errors
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Users can read own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can read own game sessions" ON public.game_sessions;
DROP POLICY IF EXISTS "Users can read own game stats" ON public.game_stats;
DROP POLICY IF EXISTS "Users can read leaderboard" ON public.game_stats;

-- Recreate policies
CREATE POLICY "Users can read own data" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own data" ON public.users
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can read own transactions" ON public.transactions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can read own game sessions" ON public.game_sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can read own game stats" ON public.game_stats
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can read leaderboard" ON public.game_stats
  FOR SELECT USING (true);

-- ============================================
-- SPIN STATE (Server-side)
-- ============================================
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS spin_free_spins INTEGER NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS spin_cooldown_end TIMESTAMPTZ;

-- ============================================
-- USE SPIN FUNCTION (Atomic server-side spin tracking)
-- ============================================
CREATE OR REPLACE FUNCTION public.use_spin(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_now TIMESTAMPTZ := NOW();
  v_cooldown_hours INTEGER := 24;
  v_result JSONB;
BEGIN
  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- If cooldown expired, reset free spins
  IF v_user.spin_cooldown_end IS NOT NULL AND v_now >= v_user.spin_cooldown_end THEN
    UPDATE public.users
    SET spin_free_spins = 3, spin_cooldown_end = NULL, updated_at = v_now
    WHERE id = p_user_id;
    v_user.spin_free_spins := 3;
    v_user.spin_cooldown_end := NULL;
  END IF;

  -- Check if on cooldown with no spins left
  IF v_user.spin_free_spins <= 0 THEN
    IF v_user.spin_cooldown_end IS NOT NULL THEN
      v_result := jsonb_build_object(
        'success', false,
        'error', 'cooldown',
        'next_in', extract(epoch from (v_user.spin_cooldown_end - v_now)) * 1000
      );
    ELSE
      -- Should not happen, but recover
      UPDATE public.users SET spin_free_spins = 3, spin_cooldown_end = NULL WHERE id = p_user_id;
      v_user.spin_free_spins := 3;
    END IF;
  END IF;

  -- Use one spin
  IF v_user.spin_free_spins > 0 THEN
    DECLARE
      v_new_spins INTEGER := v_user.spin_free_spins - 1;
      v_new_cooldown TIMESTAMPTZ := NULL;
    BEGIN
      IF v_new_spins = 0 THEN
        v_new_cooldown := v_now + (v_cooldown_hours || ' hours')::interval;
      END IF;

      UPDATE public.users
      SET spin_free_spins = v_new_spins, spin_cooldown_end = v_new_cooldown, updated_at = v_now
      WHERE id = p_user_id;

      v_result := jsonb_build_object(
        'success', true,
        'spins_remaining', v_new_spins,
        'cooldown_end', CASE WHEN v_new_cooldown IS NOT NULL THEN extract(epoch from (v_new_cooldown - v_now)) * 1000 ELSE 0 END
      );
    END;
  END IF;

  RETURN v_result;
END;
$$;

-- ============================================
-- GET SPIN STATE FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION public.get_spin_state(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_now TIMESTAMPTZ := NOW();
  v_result JSONB;
BEGIN
  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Auto-reset cooldown if expired
  IF v_user.spin_cooldown_end IS NOT NULL AND v_now >= v_user.spin_cooldown_end THEN
    UPDATE public.users
    SET spin_free_spins = 3, spin_cooldown_end = NULL, updated_at = v_now
    WHERE id = p_user_id;
    v_user.spin_free_spins := 3;
    v_user.spin_cooldown_end := NULL;
  END IF;

  v_result := jsonb_build_object(
    'spins_remaining', v_user.spin_free_spins,
    'cooldown_end', CASE WHEN v_user.spin_cooldown_end IS NOT NULL
      THEN extract(epoch from (v_user.spin_cooldown_end - v_now)) * 1000
      ELSE 0 END
  );

  RETURN v_result;
END;
$$;

-- ============================================
-- REVOKE DIRECT RPC ACCESS FROM CLIENTS
-- Only Edge Functions (service_role) can call sensitive functions
-- ============================================
REVOKE EXECUTE ON FUNCTION public.credit_user_coins(UUID, INTEGER, TEXT, TEXT) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.spend_user_coins(UUID, INTEGER, TEXT) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(UUID) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_games(UUID) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_offers(UUID) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.upsert_game_stats(UUID, TEXT, INTEGER) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_daily_game_total(UUID, TIMESTAMPTZ) FROM anon, authenticated;

-- Spin state functions remain accessible to authenticated users via Edge Functions
REVOKE EXECUTE ON FUNCTION public.use_spin(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_spin_state(UUID) FROM anon;
