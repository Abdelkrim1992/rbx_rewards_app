-- ============================================
-- Migration 023: Add Auth, Device ID, and Welcome Bonus Support
-- ============================================

-- 1. Add auth tracking and welcome bonus columns to public.users
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS welcome_bonus_claimed BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS google_id TEXT,
ADD COLUMN IF NOT EXISTS device_id TEXT;

-- 2. Create unique constraint / indexes for fast lookup and integrity
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_google_id ON public.users(google_id) WHERE google_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_device_id ON public.users(device_id) WHERE device_id IS NOT NULL;

-- 3. Atomic RPC to claim the 50 Welcome Coins safely (guarantees no double-claiming)
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_already_claimed BOOLEAN;
  v_bonus_amount INT := 50;
  v_new_balance INT;
  v_tx_id TEXT := 'welcome_' || gen_random_uuid()::text;
BEGIN
  -- Ensure authenticated call
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Row lock to prevent race conditions
  SELECT welcome_bonus_claimed, balance INTO v_already_claimed, v_new_balance
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User record not found');
  END IF;

  -- Block duplicate claims
  IF v_already_claimed IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Welcome bonus already claimed', 'balance', v_new_balance);
  END IF;

  -- Atomically credit user and mark bonus as claimed
  UPDATE public.users
  SET 
    balance = balance + v_bonus_amount,
    total_earned = total_earned + v_bonus_amount,
    welcome_bonus_claimed = TRUE,
    updated_at = NOW()
  WHERE id = v_user_id
  RETURNING balance INTO v_new_balance;

  -- Insert ledger record in transactions table
  INSERT INTO public.transactions (
    user_id,
    amount,
    source,
    tx_id,
    processed_at
  ) VALUES (
    v_user_id,
    v_bonus_amount,
    'welcome_bonus',
    v_tx_id,
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'claimed', true,
    'balance', v_new_balance,
    'amount', v_bonus_amount
  );
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus() TO authenticated;
