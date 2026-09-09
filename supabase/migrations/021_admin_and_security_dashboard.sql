-- Migration: 021_admin_and_security_dashboard.sql
-- Description: Adds tables and columns for Admin Dashboard, Anti-Fraud Defense, Dynamic Economy, Redemptions, and Compliance.

-- 1. Extend Users table with anti-fraud & security attributes
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS ban_reason TEXT,
  ADD COLUMN IF NOT EXISTS is_emulator BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS device_id VARCHAR(255),
  ADD COLUMN IF NOT EXISTS last_ip VARCHAR(64),
  ADD COLUMN IF NOT EXISTS role VARCHAR(32) DEFAULT 'user';

-- 2. Extend Redeemed Rewards table with fulfillment tracking & PIN dispatching
ALTER TABLE public.redeemed_rewards
  ADD COLUMN IF NOT EXISTS pin_code VARCHAR(255),
  ADD COLUMN IF NOT EXISTS dispatched_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS admin_notes TEXT;

-- 3. System Configuration Table (Dynamic Caps, Card Pricing, Feature Flags)
CREATE TABLE IF NOT EXISTS public.system_configs (
  key VARCHAR(64) PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

-- Seed default economy and system configs
INSERT INTO public.system_configs (key, value, description)
VALUES 
  ('mini_game_caps', '{"tap_tap": 150, "math_quiz": 120, "flappy_jump": 150, "flip_cards": 60, "scratch_card": 100}'::jsonb, 'Mini game daily coin caps'),
  ('global_feature_cap', '{"cap": 1000}'::jsonb, 'Global feature daily cap'),
  ('reward_cards', '[
    {"id": "card_3", "denomination": "$3", "coin_price": 20000, "in_stock": true},
    {"id": "card_5", "denomination": "$5", "coin_price": 40000, "in_stock": true},
    {"id": "card_10", "denomination": "$10", "coin_price": 70000, "in_stock": true}
  ]'::jsonb, 'Roblox gift card stock and coin pricing'),
  ('cache_settings', '{"leaderboard_ttl_seconds": 60, "economy_ttl_seconds": 300}'::jsonb, 'Redis Edge Caching TTL configs')
ON CONFLICT (key) DO NOTHING;

-- 4. Fraud Alerts Table (Bot detection, Velocity violations, Emulator flags)
CREATE TABLE IF NOT EXISTS public.fraud_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  alert_type VARCHAR(64) NOT NULL,
  severity VARCHAR(16) NOT NULL DEFAULT 'medium',
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_resolved BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fraud_alerts_user ON public.fraud_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_fraud_alerts_resolved ON public.fraud_alerts(is_resolved);

-- 5. Data Deletion Requests Table (Google Play & Apple Store Compliance - 7-day queue)
CREATE TABLE IF NOT EXISTS public.deletion_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  email VARCHAR(255) NOT NULL,
  reason TEXT,
  status VARCHAR(32) DEFAULT 'pending',
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  scheduled_purge_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_deletion_requests_status ON public.deletion_requests(status);

-- 6. Support Tickets Table
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  email VARCHAR(255) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  category VARCHAR(64) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(32) DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets(status);

-- 7. Immutable Admin Audit Logs
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID,
  admin_email VARCHAR(255) NOT NULL,
  action VARCHAR(64) NOT NULL,
  target_type VARCHAR(64) NOT NULL,
  target_id VARCHAR(255) NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  ip_address VARCHAR(64),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_action ON public.admin_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON public.admin_audit_logs(created_at DESC);
