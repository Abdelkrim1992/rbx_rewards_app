import { z } from 'zod';
export const createPublicContactSchema = z.object({
    name: z.string().min(2).max(100),
    email: z.string().email(),
    topic: z.string().min(2).max(100),
    message: z.string().min(10).max(2000),
});
export const createPublicDeletionSchema = z.object({
    email: z.string().email(),
    userId: z.string().optional(),
    reason: z.string().min(3).max(500),
});
