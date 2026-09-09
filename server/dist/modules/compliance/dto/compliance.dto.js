import { z } from 'zod';
export const executePurgeSchema = z.object({
    requestId: z.string().uuid('Valid request UUID required'),
});
export const resolveTicketSchema = z.object({
    ticketId: z.string().uuid('Valid ticket UUID required'),
    status: z.enum(['open', 'in_progress', 'resolved']),
});
