-- ============================================
-- RBX Rewards - Add Level Column to Users
-- ============================================

-- Add level column
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS level INTEGER NOT NULL DEFAULT 1;

-- Backfill existing users based on total earned (5000 coins per level)
UPDATE public.users SET level = (total_earned / 5000) + 1;

-- Update new user trigger to include default level
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.users (id, balance, total_earned, total_spent, level)
  VALUES (NEW.id, 0, 0, 0, 1)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Update credit_user_coins to compute level on each credit
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
BEGIN
  -- Check deduplication
  IF EXISTS (
    SELECT 1 FROM public.transactions WHERE tx_id = p_tx_id
  ) THEN
    RETURN (SELECT balance FROM public.users WHERE id = p_user_id);
  END IF;

  -- Insert transaction
  INSERT INTO public.transactions (user_id, amount, source, tx_id)
  VALUES (p_user_id, p_amount, p_source, p_tx_id);

  -- Update user balance, total earned, and level
  UPDATE public.users
  SET
    balance = balance + p_amount,
    total_earned = total_earned + p_amount,
    level = ((total_earned + p_amount) / 5000) + 1,
    updated_at = NOW()
  WHERE id = p_user_id
  RETURNING balance INTO v_current_balance;

  RETURN v_current_balance;
END;
$$;

-- Update claim_daily_reward to compute level on daily claim
CREATE OR REPLACE FUNCTION public.claim_daily_reward(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_now TIMESTAMPTZ := NOW();
  v_last_claimed TIMESTAMPTZ;
  v_cooldown_ms BIGINT := 24 * 60 * 60 * 1000;
  v_daily_reward INTEGER := 100;
  v_consecutive_days INTEGER;
  v_diff_days INTEGER;
  v_result JSONB;
BEGIN
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
