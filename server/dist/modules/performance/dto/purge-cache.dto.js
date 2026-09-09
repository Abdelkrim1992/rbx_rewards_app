import { z } from 'zod';
export const purgeCacheSchema = z.object({
    target: z.enum(['leaderboard', 'economy', 'all']),
});
export const updateTtlSchema = z.object({
    leaderboardTtlSeconds: z.number().int().min(10).max(86400),
    economyTtlSeconds: z.number().int().min(10).max(86400),
});
