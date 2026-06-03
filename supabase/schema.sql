-- ============================================
-- RBX Rewards - Complete Supabase Database Schema
-- ============================================

-- --------------------------------------------
-- 1. TABLES & CONSTRAINTS
-- --------------------------------------------

-- Users table
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance INTEGER NOT NULL DEFAULT 0,
  total_earned INTEGER NOT NULL DEFAULT 0,
  total_spent INTEGER NOT NULL DEFAULT 0,
  games_played INTEGER NOT NULL DEFAULT 0,
  offers_completed INTEGER NOT NULL DEFAULT 0,
  consecutive_days INTEGER NOT NULL DEFAULT 0,
  last_active_date TIMESTAMPTZ,
  daily_reward_claimed_at TIMESTAMPTZ,
  spin_free_spins INTEGER NOT NULL DEFAULT 3,
  spin_cooldown_end TIMESTAMPTZ,
  display_name TEXT DEFAULT 'Player',
  profile_photo_url TEXT,
  level INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Transactions table
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  source TEXT NOT NULL,
  tx_id TEXT NOT NULL UNIQUE,
  reward_title TEXT,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Game Sessions table (with deferred foreign key validation)
CREATE TABLE IF NOT EXISTS public.game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  game_name TEXT NOT NULL,
  score INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  validated BOOLEAN NOT NULL DEFAULT false,
  tx_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT game_sessions_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES public.transactions(tx_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED
);

-- Game Stats table
CREATE TABLE IF NOT EXISTS public.game_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  game_name TEXT NOT NULL,
  high_score INTEGER NOT NULL DEFAULT 0,
  total_plays INTEGER NOT NULL DEFAULT 0,
  last_played_at TIMESTAMPTZ,
  UNIQUE(user_id, game_name)
);

-- Redeemed Rewards table
CREATE TABLE IF NOT EXISTS public.redeemed_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reward_title TEXT NOT NULL,
  cost INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  tx_id TEXT REFERENCES public.transactions(tx_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'fulfilled', 'cancelled', 'rejected', 'success'))
);

-- --------------------------------------------
-- 2. INDEXES
-- --------------------------------------------

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_tx_id ON public.transactions(tx_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_source_processed ON public.transactions(user_id, source, processed_at);
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON public.transactions(user_id, processed_at);

CREATE INDEX IF NOT EXISTS idx_game_sessions_user_id ON public.game_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_game_sessions_user_game ON public.game_sessions(user_id, game_name);
CREATE INDEX IF NOT EXISTS idx_game_sessions_created_at ON public.game_sessions(created_at);

CREATE INDEX IF NOT EXISTS idx_game_stats_game_name_high_score ON public.game_stats(game_name, high_score DESC);

CREATE INDEX IF NOT EXISTS idx_redeemed_rewards_user_id ON public.redeemed_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_redeemed_rewards_user_status ON public.redeemed_rewards(user_id, status);
CREATE INDEX IF NOT EXISTS idx_redeemed_rewards_created_at ON public.redeemed_rewards(created_at);

-- --------------------------------------------
-- 3. ROW LEVEL SECURITY (RLS) & POLICIES
-- --------------------------------------------

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redeemed_rewards ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can read own data" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own data" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Transactions policies
CREATE POLICY "Users can read own transactions" ON public.transactions
  FOR SELECT USING (auth.uid() = user_id);

-- Game Sessions policies
CREATE POLICY "Users can read own game sessions" ON public.game_sessions
  FOR SELECT USING (auth.uid() = user_id);

-- Game Stats policies
CREATE POLICY "Users can read own game stats" ON public.game_stats
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can read leaderboard" ON public.game_stats
  FOR SELECT USING (true);

-- Redeemed Rewards policies
CREATE POLICY "Users can read own redeemed rewards" ON public.redeemed_rewards
  FOR SELECT USING (auth.uid() = user_id);

-- --------------------------------------------
-- 4. DATABASE FUNCTIONS (RPC APIs)
-- --------------------------------------------

-- Credit user coins atomically
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

-- Spend user coins atomically (Legacy/Fallback)
CREATE OR REPLACE FUNCTION public.spend_user_coins(
  p_user_id UUID,
  p_amount INTEGER,
  p_reward_title TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance INTEGER;
  v_tx_id TEXT;
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

  RETURN v_current_balance;
END;
$$;

-- Claim daily reward
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

-- Get daily game coins total
CREATE OR REPLACE FUNCTION public.get_daily_game_total(
  p_user_id UUID,
  p_date TIMESTAMPTZ
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total INTEGER;
  v_start_of_day TIMESTAMPTZ;
BEGIN
  v_start_of_day := DATE_TRUNC('day', p_date);
  
  SELECT COALESCE(SUM(amount), 0) INTO v_total
  FROM public.transactions
  WHERE user_id = p_user_id
    AND source = 'game'
    AND processed_at >= v_start_of_day;

  RETURN v_total;
END;
$$;

-- Increment games played
CREATE OR REPLACE FUNCTION public.increment_games(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET games_played = games_played + 1, updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- Increment offers completed
CREATE OR REPLACE FUNCTION public.increment_offers(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.users
  SET offers_completed = offers_completed + 1, updated_at = NOW()
  WHERE id = p_user_id;
END;
$$;

-- Upsert game stats
CREATE OR REPLACE FUNCTION public.upsert_game_stats(
  p_user_id UUID,
  p_game_name TEXT,
  p_score INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_current FROM public.game_stats
  WHERE user_id = p_user_id AND game_name = p_game_name;

  IF v_current IS NULL THEN
    INSERT INTO public.game_stats (user_id, game_name, high_score, total_plays, last_played_at)
    VALUES (p_user_id, p_game_name, p_score, 1, NOW());
    v_result := jsonb_build_object('new_high_score', true, 'high_score', p_score, 'total_plays', 1);
  ELSE
    UPDATE public.game_stats
    SET
      high_score = GREATEST(v_current.high_score, p_score),
      total_plays = v_current.total_plays + 1,
      last_played_at = NOW()
    WHERE id = v_current.id;
    v_result := jsonb_build_object(
      'new_high_score', p_score > v_current.high_score,
      'high_score', GREATEST(v_current.high_score, p_score),
      'total_plays', v_current.total_plays + 1
    );
  END IF;

  RETURN v_result;
END;
$$;

-- Get game high-score leaderboard
CREATE OR REPLACE FUNCTION public.get_leaderboard(
  p_game_name TEXT,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  rank BIGINT,
  user_id UUID,
  display_name TEXT,
  high_score INTEGER,
  total_plays INTEGER,
  last_played_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY gs.high_score DESC) as rank,
    gs.user_id,
    COALESCE(u.display_name, 'Anonymous') as display_name,
    gs.high_score,
    gs.total_plays,
    gs.last_played_at
  FROM public.game_stats gs
  LEFT JOIN public.users u ON u.id = gs.user_id
  WHERE gs.game_name = p_game_name
  ORDER BY gs.high_score DESC
  LIMIT p_limit;
END;
$$;

-- Use spin (spin cooldown & state check)
CREATE OR REPLACE FUNCTION public.use_spin(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_now TIMESTAMPTZ := NOW();
  v_cooldown_hours INTEGER := 24;
  v_result JSONB;
BEGIN
  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- If cooldown expired, reset free spins
  IF v_user.spin_cooldown_end IS NOT NULL AND v_now >= v_user.spin_cooldown_end THEN
    UPDATE public.users
    SET spin_free_spins = 3, spin_cooldown_end = NULL, updated_at = v_now
    WHERE id = p_user_id;
    v_user.spin_free_spins := 3;
    v_user.spin_cooldown_end := NULL;
  END IF;

  -- Check if on cooldown with no spins left
  IF v_user.spin_free_spins <= 0 THEN
    IF v_user.spin_cooldown_end IS NOT NULL THEN
      v_result := jsonb_build_object(
        'success', false,
        'error', 'cooldown',
        'next_in', extract(epoch from (v_user.spin_cooldown_end - v_now)) * 1000
      );
    ELSE
      -- Should not happen, but recover
      UPDATE public.users SET spin_free_spins = 3, spin_cooldown_end = NULL WHERE id = p_user_id;
      v_user.spin_free_spins := 3;
    END IF;
  END IF;

  -- Use one spin
  IF v_user.spin_free_spins > 0 THEN
    DECLARE
      v_new_spins INTEGER := v_user.spin_free_spins - 1;
      v_new_cooldown TIMESTAMPTZ := NULL;
    BEGIN
      IF v_new_spins = 0 THEN
        v_new_cooldown := v_now + (v_cooldown_hours || ' hours')::interval;
      END IF;

      UPDATE public.users
      SET spin_free_spins = v_new_spins, spin_cooldown_end = v_new_cooldown, updated_at = v_now
      WHERE id = p_user_id;

      v_result := jsonb_build_object(
        'success', true,
        'spins_remaining', v_new_spins,
        'cooldown_end', CASE WHEN v_new_cooldown IS NOT NULL THEN extract(epoch from (v_new_cooldown - v_now)) * 1000 ELSE 0 END
      );
    END;
  END IF;

  RETURN v_result;
END;
$$;

-- Get spin state
CREATE OR REPLACE FUNCTION public.get_spin_state(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user RECORD;
  v_now TIMESTAMPTZ := NOW();
  v_result JSONB;
BEGIN
  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Auto-reset cooldown if expired
  IF v_user.spin_cooldown_end IS NOT NULL AND v_now >= v_user.spin_cooldown_end THEN
    UPDATE public.users
    SET spin_free_spins = 3, spin_cooldown_end = NULL, updated_at = v_now
    WHERE id = p_user_id;
    v_user.spin_free_spins := 3;
    v_user.spin_cooldown_end := NULL;
  END IF;

  v_result := jsonb_build_object(
    'spins_remaining', v_user.spin_free_spins,
    'cooldown_end', CASE WHEN v_user.spin_cooldown_end IS NOT NULL
      THEN extract(epoch from (v_user.spin_cooldown_end - v_now)) * 1000
      ELSE 0 END
  );

  RETURN v_result;
END;
$$;

-- Redeem reward
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

-- Get user redeemed rewards
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

-- Process game session (anti-cheat validations + crediting)
CREATE OR REPLACE FUNCTION public.process_game_session(
  p_session_id UUID,
  p_user_id UUID,
  p_game_name TEXT,
  p_score INTEGER,
  p_duration_seconds INTEGER,
  p_tx_id TEXT,
  p_daily_cap INTEGER DEFAULT 5000
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

  IF v_daily_total + p_score > p_daily_cap THEN
    v_allowed := GREATEST(0, p_daily_cap - v_daily_total);
    RETURN jsonb_build_object('success', false, 'error', 'Daily game cap reached. Max allowed: ' || v_allowed);
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

-- Get weekly leaderboard based on total user earnings
CREATE OR REPLACE FUNCTION public.get_weekly_leaderboard(p_limit INTEGER DEFAULT 50)
RETURNS TABLE (
  rank BIGINT,
  user_id UUID,
  display_name TEXT,
  coins BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY u.total_earned DESC) as rank,
    u.id as user_id,
    COALESCE(u.display_name, 'Anonymous') as display_name,
    u.total_earned::bigint as coins
  FROM public.users u
  WHERE u.total_earned > 0
  ORDER BY u.total_earned DESC
  LIMIT p_limit;
END;
$$;

-- Generic user stat incrementer
CREATE OR REPLACE FUNCTION public.increment_user_stat(
  p_user_id UUID,
  p_stat TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_stat = 'offers_completed' THEN
    UPDATE public.users
    SET offers_completed = offers_completed + 1, updated_at = NOW()
    WHERE id = p_user_id;
  ELSIF p_stat = 'games_played' THEN
    UPDATE public.users
    SET games_played = games_played + 1, updated_at = NOW()
    WHERE id = p_user_id;
  END IF;
END;
$$;

-- --------------------------------------------
-- 5. TRIGGER FUNCTIONS & TRIGGERS
-- --------------------------------------------

-- Create user row on auth signup
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
    display_name,
    profile_photo_url,
    level
  )
  VALUES (
    NEW.id,
    0,
    0,
    0,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'Player'),
    NEW.raw_user_meta_data->>'profile_photo_url',
    1
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- --------------------------------------------
-- 6. PERMISSIONS & SECURITY HARDENING
-- --------------------------------------------

-- Revoke direct access to sensitive execution functions from client roles
REVOKE EXECUTE ON FUNCTION public.credit_user_coins(UUID, INTEGER, TEXT, TEXT) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.spend_user_coins(UUID, INTEGER, TEXT) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(UUID) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_games(UUID) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_offers(UUID) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.upsert_game_stats(UUID, TEXT, INTEGER) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_daily_game_total(UUID, TIMESTAMPTZ) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.redeem_reward(UUID, INTEGER, TEXT) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_redeemed_rewards(UUID) FROM anon, authenticated;

-- Revoke spin state execution from anonymous roles
REVOKE EXECUTE ON FUNCTION public.use_spin(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_spin_state(UUID) FROM anon;

-- Explicitly grant client execution permissions for designated authenticated client APIs
GRANT EXECUTE ON FUNCTION public.use_spin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_spin_state(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_game_session(UUID, UUID, TEXT, INTEGER, INTEGER, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_weekly_leaderboard(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_user_stat(UUID, TEXT) TO authenticated;
