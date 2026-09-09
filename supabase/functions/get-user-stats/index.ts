// Supabase Edge Function: Get User Stats
// Uses Redis cache-aside: serve from cache, fall through to Postgres on miss.
// Cache TTL: 60 seconds — keeps reads fast at scale while staying fresh.

import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

const CACHE_TTL_SECONDS = 60;

export function userCacheKey(uid: string): string {
  return `user:profile:${uid}`;
}

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
  const cacheKey = userCacheKey(uid);

  // 1. Try Redis cache first — degrade gracefully if Redis is unavailable
  let cacheHit = false;
  try {
    const cached = await redis.get(cacheKey);
    if (cached) {
      const profile = typeof cached === "string" ? JSON.parse(cached) : cached;
      cacheHit = true;
      return jsonResponse(profile, 200, { "X-Cache": "HIT" });
    }
  } catch (redisErr) {
    // Redis unavailable — log and fall through to Postgres
    console.warn("Redis cache read failed, falling through to Postgres:", redisErr);
  }

  if (cacheHit) {
    // Should never reach here, but guards against logic drift
    return errorResponse("Unexpected cache state", 500);
  }

  try {
    // 2. Cache miss — query Postgres
    let { data, error } = await supabase
      .from("users")
      .select("*")
      .eq("id", uid)
      .single();

    if (error || !data) {
      // 2.5 Auto-heal: If the user exists in Auth but not in public.users, create the row
      console.log(`User ${uid} not found in public.users, creating...`);
      const { data: newUser, error: insertError } = await supabase
        .from("users")
        .insert([{ id: uid }])
        .select()
        .single();

      if (insertError || !newUser) {
        console.error("Failed to auto-heal user row:", insertError);
        return errorResponse("User not found and could not be created", 404);
      }
      data = newUser;
    }

    // 3. Populate Redis cache (fire-and-forget, swallow errors)
    redis.set(cacheKey, JSON.stringify(data), { ex: CACHE_TTL_SECONDS }).catch((e: unknown) =>
      console.warn("Redis cache write failed (non-fatal):", e)
    );

    return jsonResponse(data, 200, { "X-Cache": "MISS" });
  } catch (e) {
    console.error("get-user-stats Postgres error:", e);
    return errorResponse("Internal error", 500);
  }
});
