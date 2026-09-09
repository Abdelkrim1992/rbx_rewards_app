import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

export interface LeaderboardEntry {
  rank: number;
  user_id: string;
  display_name: string;
  score: number;
  profile_photo_url: string | null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return corsPreflight();
  }

  // Allow both GET and POST requests
  if (req.method !== "GET" && req.method !== "POST") {
    return errorResponse("Method Not Allowed", 405);
  }

  const { error: authError } = await verifyAuth(req);
  if (authError) {
    return errorResponse(authError, 401);
  }

  // 1. Parse query/body parameters
  let gameName: string | null = null;
  let limit = 50;

  const urlObj = new URL(req.url);
  gameName = urlObj.searchParams.get("gameName");
  const limitParam = urlObj.searchParams.get("limit");
  if (limitParam) {
    limit = parseInt(limitParam, 10) || 50;
  }

  if (req.method === "POST") {
    try {
      const body = await req.json();
      if (body.gameName) gameName = body.gameName;
      if (body.limit) limit = parseInt(body.limit, 10) || 50;
    } catch {
      // Ignored
    }
  }

  // Limit capped to safe range
  if (limit < 1 || limit > 100) limit = 50;

  const key = gameName ? `leaderboard:${gameName}` : "leaderboard:weekly";
  const compiledCacheKey = `leaderboard:compiled:${gameName || "weekly"}:${limit}`;

  // 2. High-Performance Tier A: Check compiled leaderboard cache in Redis (0 Postgres queries)
  try {
    const cachedCompiled = await redis.get(compiledCacheKey);
    if (cachedCompiled) {
      const parsed = typeof cachedCompiled === "string" ? JSON.parse(cachedCompiled) : cachedCompiled;
      return jsonResponse(
        { entries: parsed },
        200,
        { "Cache-Control": "public, max-age=15, s-maxage=30", "X-Cache": "HIT" }
      );
    }
  } catch (err) {
    console.warn("Compiled leaderboard cache read failed:", err);
  }

  // 3. Tier B: Query Redis Sorted Set
  let parsedEntries: { userId: string; score: number }[] = [];
  try {
    const redisEntries = await redis.zrange(key, 0, limit - 1, { rev: true, withScores: true });

    if (Array.isArray(redisEntries) && redisEntries.length > 0) {
      if (typeof redisEntries[0] === "object" && redisEntries[0] !== null) {
        parsedEntries = redisEntries.map((item: any) => ({
          userId: String(item.member),
          score: Number(item.score),
        }));
      } else {
        // Flat array format [member1, score1, member2, score2...]
        for (let i = 0; i < redisEntries.length; i += 2) {
          if (i + 1 < redisEntries.length) {
            parsedEntries.push({
              userId: String(redisEntries[i]),
              score: Number(redisEntries[i + 1]),
            });
          }
        }
      }
    }
  } catch (redisErr) {
    console.warn("Redis zrange failed, falling through to Postgres:", redisErr);
    parsedEntries = [];
  }

  // 4. Tier C: Fallback to Postgres if Redis sorted set is empty or unavailable
  if (parsedEntries.length === 0) {
    try {
      let entries: LeaderboardEntry[] = [];
      if (gameName) {
        const { data: stats, error } = await supabase
          .from("game_stats")
          .select(`
            user_id,
            high_score,
            users:user_id ( display_name, profile_photo_url )
          `)
          .eq("game_name", gameName)
          .order("high_score", { ascending: false })
          .limit(limit);

        if (error) throw error;

        if (stats) {
          entries = stats.map((item: any, idx: number) => ({
            rank: idx + 1,
            user_id: item.user_id,
            display_name: (item.users as any)?.display_name || "Player",
            score: item.high_score,
            profile_photo_url: (item.users as any)?.profile_photo_url || null,
          }));

          // Seed sorted set asynchronously
          for (const entry of entries) {
            redis.zadd(key, { score: entry.score, member: entry.user_id }).catch(() => {});
          }
        }
      } else {
        const { data: users, error } = await supabase
          .from("users")
          .select("id, display_name, profile_photo_url, total_earned")
          .order("total_earned", { ascending: false })
          .limit(limit);

        if (error) throw error;

        if (users) {
          entries = users.map((item: any, idx: number) => ({
            rank: idx + 1,
            user_id: item.id,
            display_name: item.display_name || "Player",
            score: item.total_earned,
            profile_photo_url: item.profile_photo_url || null,
          }));

          // Seed sorted set asynchronously
          for (const entry of entries) {
            redis.zadd(key, { score: entry.score, member: entry.user_id }).catch(() => {});
          }
        }
      }

      // Populate compiled cache for 30 seconds (fire-and-forget)
      redis.set(compiledCacheKey, JSON.stringify(entries), { ex: 30 }).catch(() => {});

      return jsonResponse(
        { entries },
        200,
        { "Cache-Control": "public, max-age=15, s-maxage=30", "X-Cache": "MISS" }
      );
    } catch (dbErr) {
      console.error("Leaderboard Postgres fallback failed:", dbErr);
      return errorResponse("Failed to load leaderboard", 500);
    }
  }

  // 5. Cache Hit on Sorted Set: Fetch profile details (names, avatars) for Redis users
  try {
    const userIds = parsedEntries.map((e) => e.userId);
    const { data: users, error: dbError } = await supabase
      .from("users")
      .select("id, display_name, profile_photo_url")
      .in("id", userIds);

    if (dbError) throw dbError;

    const userMap = new Map<string, any>();
    if (users) {
      for (const u of users) {
        userMap.set(u.id, u);
      }
    }

    const entries: LeaderboardEntry[] = parsedEntries.map((pe, idx) => {
      const u = userMap.get(pe.userId);
      return {
        rank: idx + 1,
        user_id: pe.userId,
        display_name: u?.display_name || "Player",
        score: pe.score,
        profile_photo_url: u?.profile_photo_url || null,
      };
    });

    // Populate compiled cache for 30s so subsequent requests don't hit Postgres
    redis.set(compiledCacheKey, JSON.stringify(entries), { ex: 30 }).catch(() => {});

    return jsonResponse(
      { entries },
      200,
      { "Cache-Control": "public, max-age=15, s-maxage=30", "X-Cache": "MISS" }
    );
  } catch (e) {
    console.error("Leaderboard profile lookup error:", e);
    return errorResponse("Failed to load leaderboard", 500);
  }
});
