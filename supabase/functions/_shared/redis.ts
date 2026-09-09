import { Redis } from "https://esm.sh/@upstash/redis@1.31.5";

const redisUrl = Deno.env.get("UPSTASH_REDIS_REST_URL");
const redisToken = Deno.env.get("UPSTASH_REDIS_REST_TOKEN");

/** A dynamic no-op proxy that safely intercepts any Redis command when disabled */
const noopRedisHandler: ProxyHandler<object> = {
  get(_target, prop) {
    if (prop === "then") return undefined; // avoid treating as thenable
    return async (..._args: unknown[]) => {
      if (prop === "zrange") return [];
      if (prop === "incrby" || prop === "del" || prop === "expire") return 0;
      return null;
    };
  },
};

const noopRedis = new Proxy({}, noopRedisHandler) as unknown as Redis;

export const isRedisConfigured = Boolean(redisUrl && redisToken);

export const redis: Redis = isRedisConfigured
  ? new Redis({ url: redisUrl!, token: redisToken! })
  : (() => {
      console.warn(
        "UPSTASH_REDIS_REST_URL or UPSTASH_REDIS_REST_TOKEN not set — Redis disabled"
      );
      return noopRedis;
    })();
