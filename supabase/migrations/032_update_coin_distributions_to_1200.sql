-- ============================================================
-- Migration 032: Update coin_distributions to Phase-6 Economy
-- Description:
--   Replaces all legacy 120/150/100/60/500 per-game daily caps with 1,200
--   (the Tier-1 soft cap used by the 3-Tier Diminishing Yield Curve).
--   Also refreshes base_reward / premium_reward to the Phase-6 harmonized
--   flat-bonus values (base + 25-coin ad bonus).
--
--   The "daily_cap" column in coin_distributions is now used only as a
--   UI progress-bar target for Tier-1.  Hard lockout is no longer enforced;
--   the backend yield curve handles earnings beyond 1,200 coins per day.
-- ============================================================

-- 1. Repeatable game features → Tier-1 target = 1,200 coins
UPDATE public.coin_distributions
SET
  daily_cap      = 1200,
  base_reward    = 6,
  premium_reward = 31        -- 6 base + 25 ad-bonus (Tier-1)
WHERE id IN ('quiz', 'math_quiz', 'flappy_jump', 'flip_card');

-- Tap Tap has base 5 coins (slightly lower skill floor)
UPDATE public.coin_distributions
SET
  daily_cap      = 1200,
  base_reward    = 5,
  premium_reward = 30        -- 5 base + 25 ad-bonus (Tier-1)
WHERE id = 'tap_tap';

-- Chest (3-hour cooldown, no quick-claim without ad)
UPDATE public.coin_distributions
SET
  daily_cap      = 1200,
  base_reward    = 45,
  premium_reward = 65        -- direct ad unlock
WHERE id = 'chest';

-- Spin (3 free spins/day + ad-recharge)
UPDATE public.coin_distributions
SET
  daily_cap      = 1200,
  base_reward    = 20,
  premium_reward = 50        -- 20 base + ~30 ad-bonus avg
WHERE id = 'spin';

-- Scratch & Win (15-min cooldown)
UPDATE public.coin_distributions
SET
  daily_cap      = 1200,
  base_reward    = 20,
  premium_reward = 45        -- 20 base + 25 ad-bonus (Tier-1)
WHERE id = 'scratch';

-- Watch Video / Ad task (no cooldown, pure rewarded ad)
UPDATE public.coin_distributions
SET
  daily_cap      = 1200,
  base_reward    = 25,
  premium_reward = 25        -- single ad, flat 25 coins
WHERE id = 'ad';

-- 2. Daily Reward keeps its hard cap (one-time daily claim)
UPDATE public.coin_distributions
SET
  daily_cap      = 30,
  base_reward    = 15,
  premium_reward = 30
WHERE id = 'daily_reward';

-- 3. Global caps — increase features cap to 1,200 (Tier-1 target)
UPDATE public.coin_distributions
SET daily_cap = 1200
WHERE id = 'global_features';

-- Offerwalls cap stays at 1,000 (separate budget)
UPDATE public.coin_distributions
SET daily_cap = 1000
WHERE id IN ('global_offerwalls', 'survey');
