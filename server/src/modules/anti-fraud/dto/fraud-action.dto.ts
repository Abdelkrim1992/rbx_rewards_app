import { z } from 'zod';

export const banUserSchema = z.object({
  userId: z.string().uuid('Valid user UUID required'),
  reason: z.string().min(3, 'Ban reason must be at least 3 characters'),
});

export type BanUserDto = z.infer<typeof banUserSchema>;

export const unbanUserSchema = z.object({
  userId: z.string().uuid('Valid user UUID required'),
});

export type UnbanUserDto = z.infer<typeof unbanUserSchema>;
