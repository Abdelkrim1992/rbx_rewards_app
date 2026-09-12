import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

const GAME_DAILY_CAP = 1000;

const SUB_GAME_LIMITS: Record<string, number> = {
  math_quiz: 120,
  flappy_jump: 120,
  tap_tap: 120,
  flip_card: 120,
  quiz: 120,
};

// Strict game whitelist — unknown games are REJECTED
const GAME_FEASIBILITY: Record<string, { maxScorePerMinute: number }> = {
  flappy_jump: { maxScorePerMinute: 300 },
  tap_tap: { maxScorePerMinute: 2000 },
  math_quiz: { maxScorePerMinute: 1000 },
  flip_card: { maxScorePerMinute: 1000 },
};

function isSessionFeasible(
  gameName: string,
  score: number,
  durationSeconds: number
): { valid: boolean; reason?: string } {
  // Reject unknown games entirely
  const rules = GAME_FEASIBILITY[gameName];
  if (!rules) {
    return { valid: false, reason: `Unknown game: ${gameName}` };
  }

  const scorePerMinute = (score / durationSeconds) * 60;
  if (scorePerMinute > rules.maxScorePerMinute) {
    return {
      valid: false,
      reason: `Score rate too high. Max ${rules.maxScorePerMinute} per minute for ${gameName}.`,
    };
  }

  return { valid: true };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return corsPreflight();
  }
  if (req.method !== "POST") {
    return errorResponse("Method Not Allowed", 405);
  }

  const { user, error: authError } = await verifyAuth(req);
  if (authError || !user) {
    return errorResponse(authError || "Unauthorized", 401);
  }

  const uid = user.id;
  const body = await req.json();
  const { amount, gameName, sessionId, durationSeconds, originalScore, multiplier, txId: clientTxId } = body;

  if (!sessionId || typeof sessionId !== "string") {
    return errorResponse("sessionId required", 400);
  }

  // 1. Session Lock: Prevent double-submit race conditions (Fast Redis path)
  const lockKey = `lock:session:${sessionId}`;
  try {
    const locked = await redis.set(lockKey, "1", { nx: true, ex: 30 });
    // If Redis explicitly reported duplicate (locked === null or false)
    if (locked === null || locked === 0 || locked === false) {
      return errorResponse("Duplicate submission in progress", 409);
    }
  } catch (lockErr) {
    console.warn("Redis session lock check failed, proceeding to Postgres atomic check:", lockErr);
  }

  // Ensure the user row exists (covers legacy accounts created before trigger setup).
  const displayName =
    (user.user_metadata?.display_name as string) ||
    `Player_${uid.substring(0, 6)}`;

  const { error: userUpsertError } = await supabase
    .from("users")
    .upsert(
      { id: uid, display_name: displayName },
      { onConflict: "id", ignoreDuplicates: true }
    );
  if (userUpsertError) {
    const { data: existingUser } = await supabase
      .from("users")
      .select("id")
      .eq("id", uid)
      .maybeSingle();

    if (!existingUser) {
      console.error("User upsert error in add-game-coins:", userUpsertError);
      return errorResponse(`Failed to initialize user profile: ${userUpsertError.message}`, 500);
    }
  }

  if (!amount || amount <= 0) {
    return errorResponse("Invalid amount", 400);
  }
  if (!gameName || typeof gameName !== "string") {
    return errorResponse("gameName required", 400);
  }
  if (!durationSeconds || durationSeconds <= 0) {
    return errorResponse("durationSeconds required", 400);
  }
  if (durationSeconds > 3600) {
    return errorResponse("durationSeconds exceeds maximum of 3600", 400);
  }

  // Validate original score against anti-cheat if multiplier is present
  const scoreToValidate = (originalScore !== undefined && originalScore > 0) ? originalScore : amount;
  const finalScore = scoreToValidate * (multiplier ?? 1);

  // 2. Fetch limits dynamically from coin_distributions table
  let gameDailyCap = GAME_DAILY_CAP;
  let subGameLimit = SUB_GAME_LIMITS[gameName] ?? 0;

  try {
    const { data: distData, error: distError } = await supabase
      .from("coin_distributions")
      .select("id, daily_cap");
    
    if (!distError && distData) {
      const globalFeatures = distData.find((d) => d.id === "global_features");
      if (globalFeatures) {
        gameDailyCap = globalFeatures.daily_cap;
      }
      const specificGame = distData.find((d) => d.id === gameName);
      if (specificGame) {
        subGameLimit = specificGame.daily_cap;
      }
    }
  } catch (e) {
    console.error("Failed to query coin_distributions:", e);
  }

  // Daily Cap Check in Redis (overall games limit & subgame limit) - Fast path
  const todayStr = new Date().toISOString().split("T")[0];
  const capKey = `cap:game:${uid}:${todayStr}`;
  const subGameCapKey = `cap:game:${uid}:${gameName}:${todayStr}`;
  try {
    const currentDailyCap = parseInt(await redis.get(capKey) || "0", 10);
    if (currentDailyCap + finalScore > gameDailyCap) {
      const allowed = Math.max(0, gameDailyCap - currentDailyCap);
      return errorResponse(`Daily game cap reached. Max allowed: ${allowed}`, 400);
    }

    const currentSubGameCap = parseInt(await redis.get(subGameCapKey) || "0", 10);
    if (currentSubGameCap + finalScore > subGameLimit) {
      const allowed = Math.max(0, subGameLimit - currentSubGameCap);
      return errorResponse(`Daily limit reached for ${gameName}. Max allowed: ${allowed}`, 400);
    }
  } catch (capErr) {
    console.warn("Redis cap check failed, relying on Postgres RPC process_game_session:", capErr);
  }

  // Feasibility check first — reject unknown games and impossible scores
  const feasibility = isSessionFeasible(gameName, scoreToValidate, durationSeconds);
  if (!feasibility.valid) {
    // Log the rejected session anyway
    await supabase.from("game_sessions").insert({
      id: sessionId,
      user_id: uid,
      game_name: gameName,
      score: scoreToValidate,
      duration_seconds: durationSeconds,
      validated: false,
    });
    return errorResponse(feasibility.reason || "Session validation failed", 400);
  }

  const txId = (typeof clientTxId === "string" && clientTxId.length > 0)
    ? clientTxId
    : `game_${sessionId}`;

  // Atomic session processing via single RPC (prevents double-crediting race condition)
  const { data: result, error: processError } = await supabase.rpc("process_game_session", {
    p_session_id: sessionId,
    p_user_id: uid,
    p_game_name: gameName,
    p_score: finalScore,
    p_duration_seconds: durationSeconds,
    p_tx_id: txId,
    p_daily_cap: gameDailyCap,
  });

  if (processError) {
    return errorResponse(processError.message, 500);
  }

  const resultJson = typeof result === "string" ? JSON.parse(result) : result;
  if (!resultJson.success) {
    return errorResponse(resultJson.error || "Session processing failed", 400);
  }

  // 3. Update Redis caps, leaderboard, and user profile cache in background (best-effort)
  (async () => {
    try {
      await redis.incrby(capKey, finalScore);
      await redis.expire(capKey, 86400);
      await redis.incrby(subGameCapKey, finalScore);
      await redis.expire(subGameCapKey, 86400);

      // Update Game High Score Leaderboard in Redis
      const currentHighScoreStr = await redis.zscore(`leaderboard:${gameName}`, uid);
      const currentHighScore = currentHighScoreStr ? parseInt(currentHighScoreStr, 10) : 0;
      if (scoreToValidate > currentHighScore) {
        await redis.zadd(`leaderboard:${gameName}`, { score: scoreToValidate, member: uid });
      }

      // Invalidate compiled leaderboard and user profile cache
      await redis.del(`leaderboard:compiled:${gameName}:50`);
      await redis.del(`user:profile:${uid}`);
    } catch (e) {
      console.warn("Post-session Redis update failed (non-fatal):", e);
    }
  })();

  console.log(`User ${uid} earned ${finalScore} from ${gameName} (session ${sessionId})`);
  return jsonResponse({
    success: true,
    credited: finalScore,
    dailyTotal: resultJson.dailyTotal ?? finalScore,
    balance: resultJson.balance,
  });
});
