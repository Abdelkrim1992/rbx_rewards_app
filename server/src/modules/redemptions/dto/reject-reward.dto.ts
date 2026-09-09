import { z } from 'zod';

export const rejectRewardSchema = z.object({
  redemptionId: z.string().uuid('Valid redemption UUID required'),
  reason: z.string().min(5, 'Rejection reason must be at least 5 characters'),
});

export type RejectRewardDto = z.infer<typeof rejectRewardSchema>;
