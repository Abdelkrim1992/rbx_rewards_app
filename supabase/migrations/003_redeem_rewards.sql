-- ============================================
-- RBX Rewards - Redeemed Rewards Tracking
-- ============================================

-- Redeemed rewards table (tracks each reward redemption per user)
CREATE TABLE IF NOT EXISTS public.redeemed_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reward_title TEXT NOT NULL,
  cost INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  tx_id TEXT REFERENCES public.transactions(tx_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'fulfilled', 'cancelled', 'rejected', 'success'))
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_redeemed_rewards_user_id ON public.redeemed_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_redeemed_rewards_user_status ON public.redeemed_rewards(user_id, status);
CREATE INDEX IF NOT EXISTS idx_redeemed_rewards_created_at ON public.redeemed_rewards(created_at);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE public.redeemed_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own redeemed rewards" ON public.redeemed_rewards;
CREATE POLICY "Users can read own redeemed rewards" ON public.redeemed_rewards
  FOR SELECT USING (auth.uid() = user_id);

-- ============================================
-- REDEEM REWARD FUNCTION (Atomic)
-- Spends coins and records the redemption in one transaction.
-- ============================================
CREATE OR REPLACE FUNCTION public.redeem_reward(
  p_user_id UUID,
  p_amount INTEGER,
  p_reward_title TEXT
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
BEGIN
  -- Check balance
  SELECT balance INTO v_current_balance FROM public.users WHERE id = p_user_id;

  IF v_current_balance IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF v_current_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  -- Generate transaction ID
  v_tx_id := 'spend_' || extract(epoch from now())::bigint::text;

  -- Insert transaction
  INSERT INTO public.transactions (user_id, amount, source, tx_id, reward_title)
  VALUES (p_user_id, -p_amount, 'redeem', v_tx_id, p_reward_title);

  -- Update user balance
  UPDATE public.users
  SET
    balance = balance - p_amount,
    total_spent = total_spent + p_amount,
    updated_at = NOW()
  WHERE id = p_user_id
  RETURNING balance INTO v_current_balance;

  -- Insert redeemed reward record
  INSERT INTO public.redeemed_rewards (user_id, reward_title, cost, status, tx_id)
  VALUES (p_user_id, p_reward_title, p_amount, 'pending', v_tx_id)
  RETURNING id INTO v_reward_id;

  v_result := jsonb_build_object(
    'success', true,
    'remaining', v_current_balance,
    'reward_id', v_reward_id,
    'tx_id', v_tx_id
  );

  RETURN v_result;
END;
$$;

-- ============================================
-- GET USER REDEEMED REWARDS
-- ============================================
CREATE OR REPLACE FUNCTION public.get_redeemed_rewards(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  reward_title TEXT,
  cost INTEGER,
  status TEXT,
  tx_id TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    rr.id,
    rr.reward_title,
    rr.cost,
    rr.status,
    rr.tx_id,
    rr.created_at
  FROM public.redeemed_rewards rr
  WHERE rr.user_id = p_user_id
  ORDER BY rr.created_at DESC;
END;
$$;

-- ============================================
-- REVOKE DIRECT RPC ACCESS FROM CLIENTS
-- ============================================
REVOKE EXECUTE ON FUNCTION public.redeem_reward(UUID, INTEGER, TEXT) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_redeemed_rewards(UUID) FROM anon, authenticated;
