-- 014_feature_level_caps.sql
-- Enforce feature-level caps and sub-game limits.
-- Align all features and games under the shared 1,000 features daily cap.

-- 1. Redefine credit_user_coins with feature-specific limits
CREATE OR REPLACE FUNCTION public.credit_user_coins(
  p_user_id UUID,
  p_amount INTEGER,
  p_source TEXT,
  p_tx_id TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance INTEGER;
  v_today_earned INTEGER;
  v_feature_today_earned INTEGER;
  v_feature_limit INTEGER;
  v_allowed_amount INTEGER;
BEGIN
  -- Check deduplication
  IF EXISTS (
    SELECT 1 FROM public.transactions WHERE tx_id = p_tx_id
  ) THEN
    RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
  END IF;

  -- Enforce cap based on source
  IF p_source = 'survey' THEN
    -- Calculate total earned from surveys today (UTC day)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_today_earned
    FROM public.transactions
    WHERE user_id = p_user_id
      AND amount > 0
      AND source = 'survey'
      AND processed_at >= DATE_TRUNC('day', NOW());
      
    IF v_today_earned >= 1000 THEN
      RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
    END IF;
    
    v_allowed_amount := LEAST(p_amount, 1000 - v_today_earned);
  ELSIF p_source != 'redeem' AND p_source != 'refund' THEN
    -- Calculate total earned from other features today (UTC day)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_today_earned
    FROM public.transactions
    WHERE user_id = p_user_id
      AND amount > 0
      AND source != 'survey'
      AND source != 'redeem'
      AND source != 'refund'
      AND processed_at >= DATE_TRUNC('day', NOW());
      
    IF v_today_earned >= 1000 THEN
      RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
    END IF;

    -- Determine feature specific limit
    IF p_source = 'daily_reward' THEN
      v_feature_limit := 30;
    ELSIF p_source = 'chest' THEN
      v_feature_limit := 120;
    ELSIF p_source = 'spin' THEN
      v_feature_limit := 150;
    ELSIF p_source = 'scratch' THEN
      v_feature_limit := 100;
    ELSIF p_source = 'quiz' THEN
      v_feature_limit := 120;
    ELSIF p_source = 'game' THEN
      v_feature_limit := 1000; -- Games capped individually in process_game_session and globally by global cap
    ELSE
      v_feature_limit := 0; -- Unknown source gets 0 limit
    END IF;

    -- Calculate total earned from this specific feature source today (UTC day)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_feature_today_earned
    FROM public.transactions
    WHERE user_id = p_user_id
      AND amount > 0
      AND source = p_source
      AND processed_at >= DATE_TRUNC('day', NOW());

    IF v_feature_today_earned >= v_feature_limit THEN
      RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
    END IF;
    
    v_allowed_amount := LEAST(p_amount, 1000 - v_today_earned, v_feature_limit - v_feature_today_earned);
  ELSE
    -- For redeem or refund, no cap applies
    v_allowed_amount := p_amount;
  END IF;

  IF v_allowed_amount <= 0 THEN
    RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
  END IF;

  -- Insert transaction
  INSERT INTO public.transactions (user_id, amount, source, tx_id)
  VALUES (p_user_id, v_allowed_amount, p_source, p_tx_id);

  -- Update user balance, total earned, and level
  UPDATE public.users
  SET
    balance = balance + v_allowed_amount,
    total_earned = total_earned + v_allowed_amount,
    level = ((total_earned + v_allowed_amount) / 5000) + 1,
    updated_at = NOW()
  WHERE id = p_user_id
  RETURNING balance INTO v_current_balance;

  RETURN v_current_balance;
END;
$$;

-- 2. Redefine claim_daily_reward to call credit_user_coins (ensures transaction logging & cap checks)
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
  v_new_balance INTEGER;
  v_tx_id TEXT;
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

-- 3. Redefine process_game_session with individual game cap checking
CREATE OR REPLACE FUNCTION public.process_game_session(
  p_session_id UUID,
  p_user_id UUID,
  p_game_name TEXT,
  p_score INTEGER,
  p_duration_seconds INTEGER,
  p_tx_id TEXT,
  p_daily_cap INTEGER DEFAULT 1000
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inserted BOOLEAN := false;
  v_daily_total INTEGER;
  v_game_today_total INTEGER;
  v_game_limit INTEGER;
  v_allowed INTEGER;
  v_new_balance INTEGER;
BEGIN
  -- Compute today's validated game total (across all games)
  SELECT COALESCE(SUM(score), 0) INTO v_daily_total
  FROM public.game_sessions
  WHERE user_id = p_user_id
    AND validated = true
    AND created_at >= DATE_TRUNC('day', NOW());

  IF v_daily_total >= p_daily_cap THEN
    RETURN jsonb_build_object('success', false, 'error', 'Daily game cap reached.');
  END IF;

  -- Determine sub-game limit
  IF p_game_name = 'math_quiz' THEN
    v_game_limit := 120;
  ELSIF p_game_name = 'flappy_jump' THEN
    v_game_limit := 150;
  ELSIF p_game_name = 'tap_tap' THEN
    v_game_limit := 150;
  ELSIF p_game_name = 'flip_card' THEN
    v_game_limit := 60;
  ELSE
    v_game_limit := 0; -- Unknown game
  END IF;

  -- Compute today's validated score for this specific game
  SELECT COALESCE(SUM(score), 0) INTO v_game_today_total
  FROM public.game_sessions
  WHERE user_id = p_user_id
    AND game_name = p_game_name
    AND validated = true
    AND created_at >= DATE_TRUNC('day', NOW());

  IF v_game_today_total >= v_game_limit THEN
    RETURN jsonb_build_object('success', false, 'error', 'Daily game limit reached for ' || p_game_name);
  END IF;

  -- Clamp score against remaining daily cap and sub-game limit
  p_score := LEAST(p_score, p_daily_cap - v_daily_total, v_game_limit - v_game_today_total);

  IF p_score <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Daily game limit reached.');
  END IF;

  -- Atomic duplicate check: insert session, silently skip if duplicate
  INSERT INTO public.game_sessions (id, user_id, game_name, score, duration_seconds, validated, tx_id)
  VALUES (p_session_id, p_user_id, p_game_name, p_score, p_duration_seconds, true, p_tx_id)
  ON CONFLICT (id) DO NOTHING
  RETURNING true INTO v_inserted;

  IF NOT v_inserted THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duplicate session');
  END IF;

  -- Credit coins atomically using credit_user_coins (updates user balance and writes transaction)
  v_new_balance := public.credit_user_coins(p_user_id, p_score, 'game', p_tx_id);

  -- Update stats (best effort)
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
