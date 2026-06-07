import { redis } from './redis.ts';

export async function enforceRateLimit(key: string, max: number, windowSecs: number) {
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, windowSecs);
  if (count > max) {
    throw new Response(JSON.stringify({ error: 'Rate limit exceeded' }), { 
      status: 429, 
      headers: { 'Content-Type': 'application/json' } 
    });
  }
}
