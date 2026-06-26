-- ============================================================
-- Migration: 020_seed_coin_distributions
-- Description: Sets mini-game daily caps to 120 and defines dynamic reward ranges for chest/scratch.
-- ============================================================

INSERT INTO public.coin_distributions (id, daily_cap, base_reward, premium_reward)
VALUES 
  ('daily_reward', 30, 15, 30),
  ('chest', 120, 15, 45),
  ('spin', 150, 5, 25),
  ('scratch', 100, 5, 50),
  ('quiz', 120, 2, 4),
  ('math_quiz', 120, 2, 4),
  ('flappy_jump', 120, 1, 2),
  ('tap_tap', 120, 1, 2),
  ('flip_card', 120, 15, 30),
  ('survey', 1000, NULL, NULL),
  ('global_features', 1000, NULL, NULL),
  ('global_offerwalls', 1000, NULL, NULL)
ON CONFLICT (id) DO UPDATE 
SET 
  daily_cap = EXCLUDED.daily_cap,
  base_reward = EXCLUDED.base_reward,
  premium_reward = EXCLUDED.premium_reward;
