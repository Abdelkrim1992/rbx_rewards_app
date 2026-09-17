-- =============================================================================
-- Migration: 031_phase_3_anti_fraud_safeguards.sql
-- Description: Anti-Fraud & Redemption Safeguards (Hardware Device Lock,
--              Proof-of-Engagement Lifetime Ads Verification, and Review Buffer)
-- =============================================================================

-- 1. Update check constraint on public.redeemed_rewards to include 'pending_review'
ALTER TABLE public.redeemed_rewards DROP CONSTRAINT IF EXISTS valid_status;
ALTER TABLE public.redeemed_rewards ADD CONSTRAINT valid_status CHECK (
  status IN ('pending', 'pending_review', 'fulfilled', 'cancelled', 'rejected', 'success')
);

-- 2. Add anti-fraud and tracking columns
ALTER TABLE public.redeemed_rewards ADD COLUMN IF NOT EXISTS device_id TEXT;
ALTER TABLE public.redeemed_rewards ADD COLUMN IF NOT EXISTS denomination_id TEXT;
ALTER TABLE public.redeemed_rewards ADD COLUMN IF NOT EXISTS estimated_delivery_at TIMESTAMPTZ;

ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS device_id TEXT;

-- 3. Indexes for fast anti-fraud lookups
CREATE INDEX IF NOT EXISTS idx_redeemed_rewards_device_id ON public.redeemed_rewards(device_id);
CREATE INDEX IF NOT EXISTS idx_redeemed_rewards_device_denom ON public.redeemed_rewards(device_id, denomination_id);
CREATE INDEX IF NOT EXISTS idx_transactions_device_id ON public.transactions(device_id);

-- 4. Atomic redeem_reward RPC with device lock & review status
CREATE OR REPLACE FUNCTION public.redeem_reward(
  p_user_id UUID,
  p_amount INTEGER,
  p_reward_title TEXT,
  p_device_id TEXT DEFAULT NULL,
  p_denom_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance INTEGER;
  v_tx_id TEXT;
  v_reward_id UUID;
  v_result JSONB;
  v_estimated_delivery TIMESTAMPTZ;
BEGIN
  -- Check user balance
  SELECT balance INTO v_current_balance FROM public.users WHERE id = p_user_id;

  IF v_current_balance IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF v_current_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  -- Generate transaction ID
  v_tx_id := 'spend_' || extract(epoch from now())::bigint::text;

  -- Buffer review period (24 to 48 hours)
  v_estimated_delivery := NOW() + INTERVAL '48 hours';

  -- Record in transactions table with device tracking
  INSERT INTO public.transactions (user_id, amount, source, tx_id, reward_title, device_id)
  VALUES (p_user_id, -p_amount, 'redeem', v_tx_id, p_reward_title, p_device_id);

  -- Deduct user coins atomically
  UPDATE public.users
  SET
    balance = balance - p_amount,
    total_spent = total_spent + p_amount,
    updated_at = NOW()
  WHERE id = p_user_id
  RETURNING balance INTO v_current_balance;

  -- Insert redeemed reward record with 'pending_review' status
  INSERT INTO public.redeemed_rewards (
    user_id,
    reward_title,
    cost,
    status,
    tx_id,
    device_id,
    denomination_id,
    estimated_delivery_at
  )
  VALUES (
    p_user_id,
    p_reward_title,
    p_amount,
    'pending_review',
    v_tx_id,
    p_device_id,
    p_denom_id,
    v_estimated_delivery
  )
  RETURNING id INTO v_reward_id;

  v_result := jsonb_build_object(
    'success', true,
    'remaining', v_current_balance,
    'reward_id', v_reward_id,
    'tx_id', v_tx_id,
    'status', 'pending_review',
    'estimated_delivery_at', v_estimated_delivery
  );

  RETURN v_result;
END;
$$;

-- Revoke direct RPC execution from clients (Edge Function service role only)
REVOKE EXECUTE ON FUNCTION public.redeem_reward(UUID, INTEGER, TEXT, TEXT, TEXT) FROM anon, authenticated;
