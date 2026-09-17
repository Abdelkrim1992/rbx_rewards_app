-- ============================================
-- Migration 026: Production Referral & Invite System
-- ============================================

-- 1. Add referral columns to public.users
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS referral_code VARCHAR(32),
ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS referral_count INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS referral_earnings INTEGER NOT NULL DEFAULT 0;

-- 2. Backfill referral_code for all existing users deterministically
UPDATE public.users
SET referral_code = 'RBX-' || UPPER(SUBSTRING(MD5('rbx_ref_' || id::text), 1, 5))
WHERE referral_code IS NULL;

-- 3. Create unique index and constraints
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code);
CREATE INDEX IF NOT EXISTS idx_users_referred_by ON public.users(referred_by);

-- 4. Create referrals ledger table
CREATE TABLE IF NOT EXISTS public.referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referral_code VARCHAR(32) NOT NULL,
  referee_reward INTEGER NOT NULL DEFAULT 100,
  referrer_reward INTEGER NOT NULL DEFAULT 200,
  device_fingerprint TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_referrals_referee UNIQUE (referee_id)
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_device ON public.referrals(device_fingerprint);

-- 5. Enable Row Level Security (RLS) on referrals
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own referrals" ON public.referrals;
CREATE POLICY "Users can read own referrals" ON public.referrals
  FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referee_id);

-- 6. Update handle_new_user auth trigger to auto-assign deterministic referral_code
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.users (
    id,
    balance,
    total_earned,
    total_spent,
    games_played,
    offers_completed,
    consecutive_days,
    spin_free_spins,
    level,
    display_name,
    profile_photo_url,
    referral_code
  )
  VALUES (
    NEW.id,
    0,
    0,
    0,
    0,
    0,
    0,
    3,
    1,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'Player'),
    NEW.raw_user_meta_data->>'profile_photo_url',
    'RBX-' || UPPER(SUBSTRING(MD5('rbx_ref_' || NEW.id::text), 1, 5))
  )
  ON CONFLICT (id) DO UPDATE
  SET referral_code = EXCLUDED.referral_code
  WHERE public.users.referral_code IS NULL;
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- 7. Atomic RPC to redeem referral code with full anti-fraud validations
CREATE OR REPLACE FUNCTION public.redeem_referral_code(
  p_code TEXT,
  p_device_fingerprint TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referee_id UUID := auth.uid();
  v_clean_code TEXT;
  v_referee RECORD;
  v_referrer RECORD;
  v_referee_new_bal INT;
  v_referrer_new_bal INT;
  v_referee_reward INT := 100;
  v_referrer_reward INT := 200;
  v_tx_referee TEXT := 'ref_wel_' || gen_random_uuid()::text;
  v_tx_referrer TEXT := 'ref_bon_' || gen_random_uuid()::text;
BEGIN
  -- Verify authentication
  IF v_referee_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized. Please sign in.');
  END IF;

  -- Normalize and validate code format
  v_clean_code := TRIM(UPPER(COALESCE(p_code, '')));
  IF v_clean_code = '' OR LENGTH(v_clean_code) < 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Please enter a valid invite code.');
  END IF;

  -- Lock referee row for update
  SELECT id, is_banned, balance, referred_by
  INTO v_referee
  FROM public.users
  WHERE id = v_referee_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User profile not found.');
  END IF;

  -- Referee security checks
  IF v_referee.is_banned IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account is restricted.');
  END IF;

  IF v_referee.referred_by IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You have already redeemed an invite code.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.referrals WHERE referee_id = v_referee_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'You have already redeemed an invite code.');
  END IF;

  -- Hardware device fingerprint binding check (1 welcome bonus per physical device)
  IF p_device_fingerprint IS NOT NULL AND LENGTH(TRIM(p_device_fingerprint)) > 0 THEN
    IF EXISTS (
      SELECT 1 FROM public.referrals 
      WHERE device_fingerprint = TRIM(p_device_fingerprint)
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'This device has already claimed an invite bonus.');
    END IF;
  END IF;

  -- Lock referrer row for update by matching referral_code
  SELECT id, is_banned, balance, referral_count, referral_earnings, display_name, referred_by
  INTO v_referrer
  FROM public.users
  WHERE UPPER(referral_code) = v_clean_code
  FOR UPDATE;

  -- Validate code existence
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid invite code. No user found with this code.');
  END IF;

  -- Prevent self-referral
  IF v_referrer.id = v_referee_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'You cannot enter your own invite code!');
  END IF;

  -- Prevent referring from banned/fraudulent account
  IF v_referrer.is_banned IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'This invite code is no longer active.');
  END IF;

  -- Prevent circular referral loop (e.g. A invites B, B invites A)
  IF v_referrer.referred_by = v_referee_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Circular referral loop detected.');
  END IF;

  -- 1. Credit referee (+100 RBX) and bind referred_by
  UPDATE public.users
  SET
    balance = balance + v_referee_reward,
    total_earned = total_earned + v_referee_reward,
    referred_by = v_referrer.id,
    updated_at = NOW()
  WHERE id = v_referee_id
  RETURNING balance INTO v_referee_new_bal;

  -- 2. Credit referrer (+200 RBX) and increment referral statistics
  UPDATE public.users
  SET
    balance = balance + v_referrer_reward,
    total_earned = total_earned + v_referrer_reward,
    referral_count = referral_count + 1,
    referral_earnings = referral_earnings + v_referrer_reward,
    updated_at = NOW()
  WHERE id = v_referrer.id
  RETURNING balance INTO v_referrer_new_bal;

  -- 3. Insert transaction log for referee
  INSERT INTO public.transactions (
    user_id, amount, source, tx_id, processed_at
  ) VALUES (
    v_referee_id, v_referee_reward, 'referral_welcome', v_tx_referee, NOW()
  );

  -- 4. Insert transaction log for referrer
  INSERT INTO public.transactions (
    user_id, amount, source, tx_id, processed_at
  ) VALUES (
    v_referrer.id, v_referrer_reward, 'referral_bonus', v_tx_referrer, NOW()
  );

  -- 5. Insert ledger record in referrals table
  INSERT INTO public.referrals (
    referrer_id,
    referee_id,
    referral_code,
    referee_reward,
    referrer_reward,
    device_fingerprint,
    created_at
  ) VALUES (
    v_referrer.id,
    v_referee_id,
    v_clean_code,
    v_referee_reward,
    v_referrer_reward,
    p_device_fingerprint,
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Success! You received +100 RBX Welcome Bonus! 🎉',
    'coins_awarded', v_referee_reward,
    'referrer_name', COALESCE(v_referrer.display_name, 'Friend'),
    'referrer_id', v_referrer.id,
    'balance', v_referee_new_bal
  );
END;
$$;

-- 8. Grant execution privilege to authenticated users
GRANT EXECUTE ON FUNCTION public.redeem_referral_code(TEXT, TEXT) TO authenticated;
