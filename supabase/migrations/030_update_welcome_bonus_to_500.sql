-- ============================================
-- Migration 030: Update Welcome Bonus to 500 Coins
-- ============================================

-- Update atomic claim_welcome_bonus RPC to grant 500 Welcome Coins (guarantees 11% endowed progress to 4,500 Starter Robux)
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_already_claimed BOOLEAN;
  v_bonus_amount INT := 500;
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

-- Ensure execute grant is intact
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus() TO authenticated;
