-- 015_dynamic_coin_distributions.sql
-- Create table to hold coin caps and rewards dynamically.
CREATE TABLE IF NOT EXISTS public.coin_distributions (
  id TEXT PRIMARY KEY,
  daily_cap INTEGER NOT NULL,
  base_reward INTEGER,
  premium_reward INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS and add read policies so users can read limits
ALTER TABLE public.coin_distributions ENABLE ROW LEVEL SECURITY;

-- Check if policy exists before creating, or drop and recreate
DROP POLICY IF EXISTS "Allow public read access to coin_distributions" ON public.coin_distributions;
CREATE POLICY "Allow public read access to coin_distributions" ON public.coin_distributions
  FOR SELECT USING (true);

-- Seed default caps matching current strategy
INSERT INTO public.coin_distributions (id, daily_cap, base_reward, premium_reward) VALUES
  ('global_features', 1000, NULL, NULL),
  ('global_offerwalls', 1000, NULL, NULL),
  ('survey', 1000, NULL, NULL),
  ('daily_reward', 30, 15, 30),
  ('chest', 120, NULL, NULL),
  ('spin', 150, NULL, NULL),
  ('scratch', 100, NULL, NULL),
  ('quiz', 120, NULL, NULL),
  ('math_quiz', 120, NULL, NULL),
  ('flappy_jump', 150, NULL, NULL),
  ('tap_tap', 150, NULL, NULL),
  ('flip_card', 60, NULL, NULL)
ON CONFLICT (id) DO UPDATE SET
  daily_cap = EXCLUDED.daily_cap,
  base_reward = EXCLUDED.base_reward,
  premium_reward = EXCLUDED.premium_reward,
  updated_at = NOW();

-- Redefine credit_user_coins to use public.coin_distributions
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
  v_global_features_cap INTEGER;
  v_global_offerwalls_cap INTEGER;
BEGIN
  -- Check deduplication
  IF EXISTS (
    SELECT 1 FROM public.transactions WHERE tx_id = p_tx_id
  ) THEN
    RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
  END IF;

  -- Load global caps dynamically from coin_distributions table
  SELECT COALESCE((SELECT daily_cap FROM public.coin_distributions WHERE id = 'global_offerwalls'), 1000) INTO v_global_offerwalls_cap;
  SELECT COALESCE((SELECT daily_cap FROM public.coin_distributions WHERE id = 'global_features'), 1000) INTO v_global_features_cap;

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
      
    IF v_today_earned >= v_global_offerwalls_cap THEN
      RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
    END IF;
    
    v_allowed_amount := LEAST(p_amount, v_global_offerwalls_cap - v_today_earned);
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
      
    IF v_today_earned >= v_global_features_cap THEN
      RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
    END IF;

    -- Query specific feature limit from public.coin_distributions table dynamically
    SELECT daily_cap INTO v_feature_limit
    FROM public.coin_distributions
    WHERE id = p_source;

    -- Fallback to default if not found in table
    IF v_feature_limit IS NULL THEN
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
        v_feature_limit := v_global_features_cap;
      ELSE
        v_feature_limit := 0; -- Unknown source gets 0 limit
      END IF;
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
    
    v_allowed_amount := LEAST(p_amount, v_global_features_cap - v_today_earned, v_feature_limit - v_feature_today_earned);
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

-- Redefine process_game_session with individual game cap checking
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
  v_global_features_cap INTEGER;
BEGIN
  -- Load global features cap from public.coin_distributions dynamically
  SELECT COALESCE((SELECT daily_cap FROM public.coin_distributions WHERE id = 'global_features'), 1000) INTO v_global_features_cap;

  -- Compute today's validated game total (across all games)
  SELECT COALESCE(SUM(score), 0) INTO v_daily_total
  FROM public.game_sessions
  WHERE user_id = p_user_id
    AND validated = true
    AND created_at >= DATE_TRUNC('day', NOW());

  IF v_daily_total >= v_global_features_cap THEN
    RETURN jsonb_build_object('success', false, 'error', 'Daily game cap reached.');
  END IF;

  -- Query specific game limit from public.coin_distributions table dynamically
  SELECT daily_cap INTO v_game_limit
  FROM public.coin_distributions
  WHERE id = p_game_name;

  -- Fallback to default if not found in table
  IF v_game_limit IS NULL THEN
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
  p_score := LEAST(p_score, v_global_features_cap - v_daily_total, v_game_limit - v_game_today_total);

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
