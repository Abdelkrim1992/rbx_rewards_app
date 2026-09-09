import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return corsPreflight();
  }

  if (req.method !== "GET" && req.method !== "POST") {
    return errorResponse("Method Not Allowed", 405);
  }

  const { user, error: authError } = await verifyAuth(req);
  if (authError || !user) {
    return errorResponse(authError || "Unauthorized", 401);
  }

  const uid = user.id;

  // Optional limit parameter
  let limit = 50;
  try {
    const urlObj = new URL(req.url);
    const limitParam = urlObj.searchParams.get("limit");
    if (limitParam) {
      limit = parseInt(limitParam, 10) || 50;
    }
  } catch (_e) {
    // Ignored
  }

  if (limit < 1 || limit > 100) limit = 50;

  const cacheKey = `reward_history_v2:${uid}:${limit}`;

  // 1. Try Redis cache first (fault-tolerant)
  try {
    const cached = await redis.get(cacheKey);
    if (cached) {
      const parsed = typeof cached === "string" ? JSON.parse(cached) : cached;
      return jsonResponse(parsed, 200, { "X-Cache": "HIT" });
    }
  } catch (redisErr) {
    console.warn("get-reward-history Redis read failed, falling through to Postgres:", redisErr);
  }

  // 2. Fallback to Postgres
  const { data, error } = await supabase
    .from("redeemed_rewards")
    .select("*")
    .eq("user_id", uid)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    console.error("DB reward history error:", error);
    return errorResponse(error.message, 500);
  }

  const responseData = { history: data };

  // 3. Cache for 60 seconds (fire-and-forget)
  redis.set(cacheKey, JSON.stringify(responseData), { ex: 60 }).catch((e) =>
    console.warn("get-reward-history Redis write failed:", e)
  );

  return jsonResponse(responseData, 200, { "X-Cache": "MISS" });
});
