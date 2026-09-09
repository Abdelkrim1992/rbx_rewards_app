import { z } from 'zod';
export const updateRewardCardSchema = z.object({
    id: z.string().min(1),
    coinPrice: z.number().int().min(1000).max(1000000),
    inStock: z.boolean(),
});
