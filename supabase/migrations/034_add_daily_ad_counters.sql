-- =============================================================================
-- Migration: 034_add_daily_ad_counters.sql
-- Description: Adds daily ad counter tracking to public.user_ad_stats table
--              so every ad watched/completed per day is tracked in the database.
-- =============================================================================

DO $$
BEGIN
  -- Create table if it doesn't exist yet
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_ad_stats') THEN
    CREATE TABLE public.user_ad_stats (
      user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
      lifetime_forced_ads INTEGER DEFAULT 0,
      lifetime_optional_ads INTEGER DEFAULT 0,
      daily_ads_completed INTEGER DEFAULT 0,
      daily_forced_ads INTEGER DEFAULT 0,
      daily_optional_ads INTEGER DEFAULT 0,
      last_ad_date TEXT,
      placement_counts JSONB DEFAULT '{}'::jsonb,
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    ALTER TABLE public.user_ad_stats ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "Users can manage own ad stats" ON public.user_ad_stats
      FOR ALL USING (auth.uid() = user_id);
  ELSE
    -- Add columns if missing
    ALTER TABLE public.user_ad_stats ADD COLUMN IF NOT EXISTS daily_ads_completed INTEGER DEFAULT 0;
    ALTER TABLE public.user_ad_stats ADD COLUMN IF NOT EXISTS daily_forced_ads INTEGER DEFAULT 0;
    ALTER TABLE public.user_ad_stats ADD COLUMN IF NOT EXISTS daily_optional_ads INTEGER DEFAULT 0;
    ALTER TABLE public.user_ad_stats ADD COLUMN IF NOT EXISTS last_ad_date TEXT;
    ALTER TABLE public.user_ad_stats ADD COLUMN IF NOT EXISTS placement_counts JSONB DEFAULT '{}'::jsonb;
    ALTER TABLE public.user_ad_stats ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END $$;
