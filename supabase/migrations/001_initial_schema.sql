-- ============================================
-- RBX Rewards - Supabase Initial Schema
-- ============================================

-- Users table (replaces Firestore users collection)
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
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Transactions table (replaces Firestore transactions collection)
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  source TEXT NOT NULL,
  tx_id TEXT NOT NULL UNIQUE,
  reward_title TEXT,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_tx_id ON public.transactions(tx_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_source_processed ON public.transactions(user_id, source, processed_at);
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON public.transactions(user_id, processed_at);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Users can only read their own data
DROP POLICY IF EXISTS "Users can read own data" ON public.users;
CREATE POLICY "Users can read own data" ON public.users
  FOR SELECT USING (auth.uid() = id);

-- Users can only update their own data (server-side functions bypass RLS)
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
CREATE POLICY "Users can update own data" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Users can read their own transactions
DROP POLICY IF EXISTS "Users can read own transactions" ON public.transactions;
CREATE POLICY "Users can read own transactions" ON public.transactions
  FOR SELECT USING (auth.uid() = user_id);

-- ============================================
-- DATABASE FUNCTIONS (Atomic Operations)
-- These bypass RLS because they run with service role key
-- ============================================

-- Credit user coins atomically (offerwall + game rewards)
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

  -- Update user balance
  UPDATE public.users
  SET
    balance = balance + p_amount,
    total_earned = total_earned + p_amount,
    updated_at = NOW()
  WHERE id = p_user_id
  RETURNING balance INTO v_current_balance;

  RETURN v_current_balance;
END;
$$;

-- Spend user coins atomically (redemptions)
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
BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO v_total
  FROM public.transactions
  WHERE user_id = p_user_id
    AND source = 'game'
    AND processed_at >= p_date;

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

-- Create user row on auth signup (trigger)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.users (id, balance, total_earned, total_spent)
  VALUES (NEW.id, 0, 0, 0)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- GAME SESSIONS (Anti-cheat validation)
-- ============================================

CREATE TABLE IF NOT EXISTS public.game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  game_name TEXT NOT NULL,
  score INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  validated BOOLEAN NOT NULL DEFAULT false,
  tx_id TEXT REFERENCES public.transactions(tx_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_game_sessions_user_id ON public.game_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_game_sessions_user_game ON public.game_sessions(user_id, game_name);
CREATE INDEX IF NOT EXISTS idx_game_sessions_created_at ON public.game_sessions(created_at);

ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own game sessions" ON public.game_sessions;
CREATE POLICY "Users can read own game sessions" ON public.game_sessions
  FOR SELECT USING (auth.uid() = user_id);

-- ============================================
-- GAME STATS (Leaderboard + personal records)
-- ============================================

CREATE TABLE IF NOT EXISTS public.game_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  game_name TEXT NOT NULL,
  high_score INTEGER NOT NULL DEFAULT 0,
  total_plays INTEGER NOT NULL DEFAULT 0,
  last_played_at TIMESTAMPTZ,
  UNIQUE(user_id, game_name)
);

CREATE INDEX IF NOT EXISTS idx_game_stats_game_name_high_score ON public.game_stats(game_name, high_score DESC);

ALTER TABLE public.game_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own game stats" ON public.game_stats;
CREATE POLICY "Users can read own game stats" ON public.game_stats
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can read leaderboard" ON public.game_stats;
CREATE POLICY "Users can read leaderboard" ON public.game_stats
  FOR SELECT USING (true);

-- ============================================
-- GAME STATS FUNCTIONS
-- ============================================

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

-- Get leaderboard for a specific game
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
    COALESCE(au.raw_user_meta_data->>'display_name', 'Anonymous') as display_name,
    gs.high_score,
    gs.total_plays,
    gs.last_played_at
  FROM public.game_stats gs
  LEFT JOIN auth.users au ON au.id = gs.user_id
  WHERE gs.game_name = p_game_name
  ORDER BY gs.high_score DESC
  LIMIT p_limit;
END;
$$;
