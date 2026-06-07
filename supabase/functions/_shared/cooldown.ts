import { redis } from './redis.ts';

export async function checkCooldown(key: string): Promise<number> {
  const ttl = await redis.ttl(key); // -2 = key gone, -1 = no TTL, >0 = seconds remaining
  return Math.max(0, ttl);
}

export async function setCooldown(key: string, ttlSecs: number) {
  await redis.set(key, '1', { ex: ttlSecs });
}
