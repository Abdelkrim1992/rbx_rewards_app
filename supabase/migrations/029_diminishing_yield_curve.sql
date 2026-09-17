-- ============================================================================
-- Migration 029: 3-Tier Diminishing Yield Curve & Soft Cap Economy
-- ============================================================================

-- 1. Redefine process_game_session with 3-tier diminishing yield curve
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
  v_multiplier NUMERIC;
  v_scaled_score INTEGER;
  v_new_balance INTEGER;
BEGIN
  -- Compute today's validated game total (across all games, UTC day)
  SELECT COALESCE(SUM(score), 0) INTO v_daily_total
  FROM public.game_sessions
  WHERE user_id = p_user_id
    AND validated = true
    AND created_at >= DATE_TRUNC('day', NOW());

  -- 3-Tier Diminishing Yield Schedule
  -- Tier 1 (0 – 1,200 coins): 1.0x full speed
  -- Tier 2 (1,201 – 2,200 coins): 0.5x normal speed
  -- Tier 3 (2,201+ coins - Grinders): 0.15x micro-rewards (min 1 coin)
  IF v_daily_total < 1200 THEN
    v_multiplier := 1.0;
  ELSIF v_daily_total <= 2200 THEN
    v_multiplier := 0.5;
  ELSE
    v_multiplier := 0.15;
  END IF;

  v_scaled_score := GREATEST(1, ROUND(p_score * v_multiplier));

  -- Atomic duplicate check: insert session, silently skip if duplicate
  INSERT INTO public.game_sessions (id, user_id, game_name, score, duration_seconds, validated, tx_id)
  VALUES (p_session_id, p_user_id, p_game_name, v_scaled_score, p_duration_seconds, true, p_tx_id)
  ON CONFLICT (id) DO NOTHING
  RETURNING true INTO v_inserted;

  IF NOT v_inserted THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duplicate session');
  END IF;

  -- Credit coins atomically using credit_user_coins
  v_new_balance := public.credit_user_coins(p_user_id, v_scaled_score, 'game', p_tx_id);

  -- Update stats (best effort)
  BEGIN
    PERFORM public.upsert_game_stats(p_user_id, p_game_name, v_scaled_score);
    PERFORM public.increment_games(p_user_id);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'credited', v_scaled_score,
    'balance', v_new_balance,
    'dailyTotal', v_daily_total + v_scaled_score
  );
END;
$$;

-- 2. Redefine credit_user_coins with diminishing returns for non-game features
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
  v_allowed_amount INTEGER;
  v_global_offerwalls_cap INTEGER;
  v_multiplier NUMERIC;
BEGIN
  -- Check deduplication
  IF EXISTS (
    SELECT 1 FROM public.transactions WHERE tx_id = p_tx_id
  ) THEN
    RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
  END IF;

  -- Load global offerwalls cap dynamically
  SELECT COALESCE((SELECT daily_cap FROM public.coin_distributions WHERE id = 'global_offerwalls'), 1000)
  INTO v_global_offerwalls_cap;

  -- Enforce cap or curve based on source
  IF p_source = 'survey' THEN
    -- Offerwalls keep their dedicated cap
    SELECT COALESCE(SUM(amount), 0)
    INTO v_today_earned
    FROM public.transactions
    WHERE user_id = p_user_id
      AND amount > 0
      AND source = 'survey'
      AND processed_at >= DATE_TRUNC('day', NOW());

    IF v_today_earned >= v_global_offerwalls_cap THEN
      RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
    END IF;

    v_allowed_amount := LEAST(p_amount, v_global_offerwalls_cap - v_today_earned);

  ELSIF p_source = 'daily_reward' THEN
    -- Single daily claim per day
    SELECT COALESCE(SUM(amount), 0)
    INTO v_feature_today_earned
    FROM public.transactions
    WHERE user_id = p_user_id
      AND amount > 0
      AND source = 'daily_reward'
      AND processed_at >= DATE_TRUNC('day', NOW());

    IF v_feature_today_earned >= 30 THEN
      RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
    END IF;

    v_allowed_amount := LEAST(p_amount, 30 - v_feature_today_earned);

  ELSIF p_source = 'game' THEN
    -- Game sessions are already scaled by process_game_session
    v_allowed_amount := p_amount;

  ELSIF p_source IN ('ad', 'watch_video', 'spin', 'chest', 'scratch', 'quiz', 'in_app') THEN
    -- Calculate total earned from features today (UTC day)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_today_earned
    FROM public.transactions
    WHERE user_id = p_user_id
      AND amount > 0
      AND source != 'survey'
      AND source != 'redeem'
      AND source != 'refund'
      AND processed_at >= DATE_TRUNC('day', NOW());

    -- Apply 3-Tier Diminishing Returns Curve
    IF v_today_earned < 1200 THEN
      v_multiplier := 1.0;
    ELSIF v_today_earned <= 2200 THEN
      v_multiplier := 0.5;
    ELSE
      v_multiplier := 0.15;
    END IF;

    v_allowed_amount := GREATEST(1, ROUND(p_amount * v_multiplier));

  ELSE
    -- Uncapped sources: mega_chest, promo codes, welcome bonus, redeem, refund
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.process_game_session(UUID, UUID, TEXT, INTEGER, INTEGER, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.credit_user_coins(UUID, INTEGER, TEXT, TEXT) TO authenticated;
