-- ============================================
-- RBX Rewards - Adjust Reward Caps (500 Daily Model)
-- ============================================
-- Daily claim now accepts a variable amount (clamped 1-30)
-- Game daily cap reduced from 5000 to 50

-- Update claim_daily_reward to accept variable amount
CREATE OR REPLACE FUNCTION public.claim_daily_reward(
  p_user_id UUID,
  p_amount INTEGER DEFAULT 15
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
  v_result JSONB;
BEGIN
  -- Clamp reward between 1 and 30 (max premium double of 15 base)
  v_daily_reward := LEAST(30, GREATEST(1, p_amount));

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

  -- Calculate consecutive days
  v_consecutive_days := v_user.consecutive_days;
  IF v_user.last_active_date IS NOT NULL THEN
    v_diff_days := floor(extract(epoch from (v_now - v_user.last_active_date)) / 86400)::integer;
    IF v_diff_days = 1 THEN
      v_consecutive_days := v_consecutive_days + 1;
    ELSIF v_diff_days > 1 THEN
      v_consecutive_days := 1;
    END IF;
  ELSE
    v_consecutive_days := 1;
  END IF;

  -- Update user
  UPDATE public.users
  SET
    balance = balance + v_daily_reward,
    total_earned = total_earned + v_daily_reward,
    level = ((v_user.total_earned + v_daily_reward) / 5000) + 1,
    consecutive_days = v_consecutive_days,
    last_active_date = v_now,
    daily_reward_claimed_at = v_now,
    updated_at = v_now
  WHERE id = p_user_id;

  v_result := jsonb_build_object(
    'success', true,
    'amount', v_daily_reward,
    'balance', v_user.balance + v_daily_reward,
    'consecutive_days', v_consecutive_days
  );

  RETURN v_result;
END;
$$;

-- Update process_game_session default daily cap from 5000 to 50
CREATE OR REPLACE FUNCTION public.process_game_session(
  p_session_id UUID,
  p_user_id UUID,
  p_game_name TEXT,
  p_score INTEGER,
  p_duration_seconds INTEGER,
  p_tx_id TEXT,
  p_daily_cap INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted BOOLEAN := false;
  v_daily_total INTEGER;
  v_allowed INTEGER;
  v_new_balance INTEGER;
BEGIN
  -- Compute today's validated game total
  SELECT COALESCE(SUM(score), 0) INTO v_daily_total
  FROM public.game_sessions
  WHERE user_id = p_user_id
    AND validated = true
    AND created_at >= DATE_TRUNC('day', NOW());

  IF v_daily_total + p_score > p_daily_cap THEN
    v_allowed := GREATEST(0, p_daily_cap - v_daily_total);
    RETURN jsonb_build_object('success', false, 'error', 'Daily game cap reached. Max allowed: ' || v_allowed);
  END IF;

  -- Atomic duplicate check: insert session, silently skip if duplicate
  INSERT INTO public.game_sessions (id, user_id, game_name, score, duration_seconds, validated, tx_id)
  VALUES (p_session_id, p_user_id, p_game_name, p_score, p_duration_seconds, true, p_tx_id)
  ON CONFLICT (id) DO NOTHING
  RETURNING true INTO v_inserted;

  IF NOT v_inserted THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duplicate session');
  END IF;

  -- Credit coins atomically
  v_new_balance := public.credit_user_coins(p_user_id, p_score, 'game', p_tx_id);

  -- Update stats (best effort; failure doesn't rollback credit)
  BEGIN
    PERFORM public.upsert_game_stats(p_user_id, p_game_name, p_score);
    PERFORM public.increment_games(p_user_id);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'credited', p_score,
    'balance', v_new_balance,
    'dailyTotal', v_daily_total + p_score
  );
END;
$$;
