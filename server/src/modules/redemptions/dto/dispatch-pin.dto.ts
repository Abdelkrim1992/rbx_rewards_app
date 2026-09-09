import { z } from 'zod';

export const dispatchPinSchema = z.object({
  redemptionId: z.string().uuid('Valid redemption UUID required'),
  pinCode: z
    .string()
    .min(8, 'PIN code must be at least 8 characters')
    .max(64, 'PIN code maximum length is 64 characters'),
  adminNotes: z.string().max(250).optional(),
});

export type DispatchPinDto = z.infer<typeof dispatchPinSchema>;
