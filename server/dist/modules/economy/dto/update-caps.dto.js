import { z } from 'zod';
export const updateMiniGameCapsSchema = z.object({
    tap_tap: z.number().int().min(10).max(10000),
    math_quiz: z.number().int().min(10).max(10000),
    flappy_jump: z.number().int().min(10).max(10000),
    flip_cards: z.number().int().min(10).max(10000),
    scratch_card: z.number().int().min(10).max(10000),
});
export const updateGlobalCapSchema = z.object({
    cap: z.number().int().min(100).max(100000),
});
