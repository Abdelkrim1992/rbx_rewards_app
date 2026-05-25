// Supabase Edge Function: Add Game Coins (with session validation)

import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";

const GAME_DAILY_CAP = 5000;

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

  // Ensure the user row exists (covers legacy accounts created before trigger setup).
  const { error: userUpsertError } = await supabase
    .from("users")
    .upsert({ id: uid }, { onConflict: "id", ignoreDuplicates: true });
  if (userUpsertError) {
    return errorResponse(`Failed to initialize user profile: ${userUpsertError.message}`, 500);
  }

  if (!amount || amount <= 0) {
    return errorResponse("Invalid amount", 400);
  }
  if (!gameName || typeof gameName !== "string") {
    return errorResponse("gameName required", 400);
  }
  if (!sessionId || typeof sessionId !== "string") {
    return errorResponse("sessionId required", 400);
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
    p_daily_cap: GAME_DAILY_CAP,
  });

  if (processError) {
    return errorResponse(processError.message, 500);
  }

  const resultJson = typeof result === "string" ? JSON.parse(result) : result;
  if (!resultJson.success) {
    return errorResponse(resultJson.error || "Session processing failed", 400);
  }

  console.log(`User ${uid} earned ${finalScore} from ${gameName} (session ${sessionId})`);
  return jsonResponse({
    success: true,
    credited: finalScore,
    dailyTotal: resultJson.dailyTotal ?? finalScore,
    balance: resultJson.balance,
  });
});
