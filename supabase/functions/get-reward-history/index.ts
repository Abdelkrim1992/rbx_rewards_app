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
  } catch (e) {
    // Ignored
  }

  const cacheKey = `reward_history:${uid}:${limit}`;
  const cached = await redis.get(cacheKey);

  if (cached) {
    const parsed = typeof cached === "string" ? JSON.parse(cached) : cached;
    return jsonResponse(parsed, 200, { "X-Cache": "HIT" });
  }

  // Fetch from Postgres
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

  // Cache for 60 seconds
  await redis.setex(cacheKey, 60, JSON.stringify(data));

  return jsonResponse(data, 200, { "X-Cache": "MISS" });
});
