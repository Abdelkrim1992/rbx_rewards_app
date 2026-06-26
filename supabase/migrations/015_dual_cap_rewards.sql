-- 013_dual_cap_rewards.sql
-- Enforce dual caps: 1,000 daily coins limit for features, 1,000 for surveys.
-- Adjust default process_game_session cap to 400.

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
    
    v_allowed_amount := LEAST(p_amount, 1000 - v_today_earned);
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

CREATE OR REPLACE FUNCTION public.process_game_session(
  p_session_id UUID,
  p_user_id UUID,
  p_game_name TEXT,
  p_score INTEGER,
  p_duration_seconds INTEGER,
  p_tx_id TEXT,
  p_daily_cap INTEGER DEFAULT 400
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

  IF v_daily_total >= p_daily_cap THEN
    RETURN jsonb_build_object('success', false, 'error', 'Daily game cap reached.');
  END IF;

  IF v_daily_total + p_score > p_daily_cap THEN
    p_score := p_daily_cap - v_daily_total;
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

GRANT EXECUTE ON FUNCTION public.credit_user_coins(UUID, INTEGER, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_game_session(UUID, UUID, TEXT, INTEGER, INTEGER, TEXT, INTEGER) TO authenticated;
