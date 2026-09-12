-- ============================================
-- Migration 024: Streak Saver & Daily Reward Scale Up
-- ============================================

-- 1. Drop existing overloaded claim_daily_reward functions
DROP FUNCTION IF EXISTS public.claim_daily_reward(UUID);
DROP FUNCTION IF EXISTS public.claim_daily_reward(UUID, INTEGER);

-- 2. Redefine claim_daily_reward to support Streak Saver (p_save_streak) and Day 7 rewards up to 200 coins
CREATE OR REPLACE FUNCTION public.claim_daily_reward(
  p_user_id UUID,
  p_amount INTEGER DEFAULT 15,
  p_save_streak BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_now TIMESTAMPTZ := NOW();
  v_last_claimed TIMESTAMPTZ;
  v_cooldown_ms BIGINT := 24 * 60 * 60 * 1000;
  v_daily_reward INTEGER;
  v_consecutive_days INTEGER;
  v_diff_days INTEGER;
  v_new_balance INTEGER;
  v_tx_id TEXT;
  v_result JSONB;
BEGIN
  -- Clamp reward between 1 and 200 (supports 15-100 base, and up to 200 with ad multiplier)
  v_daily_reward := LEAST(200, GREATEST(1, p_amount));

  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  v_last_claimed := v_user.daily_reward_claimed_at;

  -- Check cooldown
  IF v_last_claimed IS NOT NULL THEN
    IF extract(epoch from (v_now - v_last_claimed)) * 1000 < v_cooldown_ms THEN
      v_result := jsonb_build_object(
        'success', false,
        'error', 'cooldown',
        'next_in', v_cooldown_ms - (extract(epoch from (v_now - v_last_claimed)) * 1000)::bigint
      );
      RETURN v_result;
    END IF;
  END IF;

  -- Calculate consecutive days with streak saver support
  v_consecutive_days := COALESCE(v_user.consecutive_days, 0);
  IF p_save_streak THEN
    -- Streak saved by user watching rewarded ad or activating streak saver
    v_consecutive_days := v_consecutive_days + 1;
  ELSIF v_user.last_active_date IS NOT NULL THEN
    v_diff_days := floor(extract(epoch from (v_now - v_user.last_active_date)) / 86400)::integer;
    IF v_diff_days = 1 THEN
      v_consecutive_days := v_consecutive_days + 1;
    ELSIF v_diff_days > 1 THEN
      v_consecutive_days := 1;
    END IF;
  ELSE
    v_consecutive_days := 1;
  END IF;

  -- Generate deterministic tx_id for daily login
  v_tx_id := 'daily_' || p_user_id || '_' || to_char(v_now, 'YYYY_MM_DD');

  -- Credit coins via credit_user_coins function (enforces caps and logs transaction)
  v_new_balance := public.credit_user_coins(p_user_id, v_daily_reward, 'daily_reward', v_tx_id);

  -- Update cooldown and activity metadata
  UPDATE public.users
  SET
    consecutive_days = v_consecutive_days,
    last_active_date = v_now,
    daily_reward_claimed_at = v_now,
    updated_at = v_now
  WHERE id = p_user_id;

  v_result := jsonb_build_object(
    'success', true,
    'amount', v_daily_reward,
    'balance', v_new_balance,
    'consecutive_days', v_consecutive_days
  );

  RETURN v_result;
END;
$$;

-- 3. Security: Revoke client direct access (only Edge Functions / Service Role can call this)
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(UUID, INTEGER, BOOLEAN) FROM anon, authenticated;
