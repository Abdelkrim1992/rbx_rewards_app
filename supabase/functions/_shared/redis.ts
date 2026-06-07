import { Redis } from "https://esm.sh/@upstash/redis@1.31.5";

export const redis = new Redis({
  url: Deno.env.get('UPSTASH_REDIS_REST_URL')!,
  token: Deno.env.get('UPSTASH_REDIS_REST_TOKEN')!,
});
