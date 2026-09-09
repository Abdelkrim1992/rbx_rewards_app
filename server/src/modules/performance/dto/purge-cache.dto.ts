import { z } from 'zod';

export const purgeCacheSchema = z.object({
  target: z.enum(['leaderboard', 'economy', 'all']),
});

export type PurgeCacheDto = z.infer<typeof purgeCacheSchema>;

export const updateTtlSchema = z.object({
  leaderboardTtlSeconds: z.number().int().min(10).max(86400),
  economyTtlSeconds: z.number().int().min(10).max(86400),
});

export type UpdateTtlDto = z.infer<typeof updateTtlSchema>;
