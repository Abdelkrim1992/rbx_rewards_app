-- ============================================================
-- Migration: 027_add_ad_reward_distribution
-- Description: Adds 'ad' and 'watch_video' reward distributions and updates credit_user_coins
-- ============================================================

-- 1. Insert coin_distributions for rewarded video ads and mega chests
INSERT INTO public.coin_distributions (id, daily_cap, base_reward, premium_reward)
VALUES 
  ('ad', 1000, 50, 50),
  ('watch_video', 1000, 50, 50),
  ('mega_chest', 1000, 1000, 1000),
  ('mega_chest_double', 1000, 1000, 1000)
ON CONFLICT (id) DO UPDATE 
SET 
  daily_cap = EXCLUDED.daily_cap,
  base_reward = EXCLUDED.base_reward,
  premium_reward = EXCLUDED.premium_reward;

-- 2. Update credit_user_coins fallback to support video ad and mega chest rewards
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
      ELSIF p_source = 'ad' OR p_source = 'watch_video' THEN
        v_feature_limit := 1000;
      ELSIF p_source = 'game' OR p_source = 'welcome_bonus' OR p_source = 'mega_chest' OR p_source = 'mega_chest_double' OR p_source LIKE 'promo_code%' THEN
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
