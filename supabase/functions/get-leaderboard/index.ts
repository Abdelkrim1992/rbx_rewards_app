import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

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

  const key = gameName ? `leaderboard:${gameName}` : "leaderboard:weekly";

  try {
    // 2. Query Redis for top entries (Sorted Set)
    const redisEntries = await redis.zrange(key, 0, limit - 1, { rev: true, withScores: true });

    let parsedEntries: { userId: string; score: number }[] = [];
    if (Array.isArray(redisEntries) && redisEntries.length > 0) {
      if (typeof redisEntries[0] === "object" && redisEntries[0] !== null) {
        parsedEntries = redisEntries.map((item: any) => ({
          userId: item.member,
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

    // 3. Fallback: If cache is empty, query DB and populate Redis
    if (parsedEntries.length === 0) {
      let entries: any[] = [];
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

        if (error) {
          console.error("DB stats query error:", error);
          return errorResponse(error.message, 500);
        }

        if (stats) {
          entries = stats.map((item: any, idx: number) => ({
            rank: idx + 1,
            user_id: item.user_id,
            display_name: (item.users as any)?.display_name || "Player",
            score: item.high_score,
            profile_photo_url: (item.users as any)?.profile_photo_url || null,
          }));

          // Populate cache asynchronously
          for (const entry of entries) {
            redis.zadd(key, { score: entry.score, member: entry.user_id }).catch(console.error);
          }
        }
      } else {
        const { data: users, error } = await supabase
          .from("users")
          .select("id, display_name, profile_photo_url, total_earned")
          .order("total_earned", { ascending: false })
          .limit(limit);

        if (error) {
          console.error("DB users query error:", error);
          return errorResponse(error.message, 500);
        }

        if (users) {
          entries = users.map((item: any, idx: number) => ({
            rank: idx + 1,
            user_id: item.id,
            display_name: item.display_name || "Player",
            score: item.total_earned,
            profile_photo_url: item.profile_photo_url || null,
          }));

          // Populate cache asynchronously
          for (const entry of entries) {
            redis.zadd(key, { score: entry.score, member: entry.user_id }).catch(console.error);
          }
        }
      }

      return jsonResponse({ entries }, 200, { "Cache-Control": "public, max-age=10, s-maxage=30" });
    }

    // 4. Cache Hit: Fetch profile details (names, avatars) for Redis users from Postgres using efficient PK lookup
    const userIds = parsedEntries.map((e) => e.userId);
    const { data: users, error: dbError } = await supabase
      .from("users")
      .select("id, display_name, profile_photo_url")
      .in("id", userIds);

    if (dbError) {
      console.error("DB profiles lookup error:", dbError);
      return errorResponse(dbError.message, 500);
    }

    const userMap = new Map();
    if (users) {
      for (const u of users) {
        userMap.set(u.id, u);
      }
    }

    const entries = parsedEntries.map((pe, idx) => {
      const u = userMap.get(pe.userId);
      return {
        rank: idx + 1,
        user_id: pe.userId,
        display_name: u?.display_name || "Player",
        score: pe.score,
        profile_photo_url: u?.profile_photo_url || null,
      };
    });

    return jsonResponse({ entries }, 200, { "Cache-Control": "public, max-age=10, s-maxage=30" });
  } catch (e) {
    console.error("Get leaderboard error:", e);
    return errorResponse("Failed to load leaderboard", 500);
  }
});
