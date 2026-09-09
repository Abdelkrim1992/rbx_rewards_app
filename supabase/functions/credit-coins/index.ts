import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";
import { redis } from "../_shared/redis.ts";

Deno.serve(async (req: Request) => {
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
  const { amount, source, txId } = body;

  if (!amount || amount <= 0) {
    return errorResponse("Invalid amount", 400);
  }
  const validSources = ['in_app', 'game', 'daily_reward', 'spin', 'chest', 'ad', 'survey', 'scratch', 'quiz', 'redeem'];
  if (!source || typeof source !== "string") {
    return errorResponse("source required", 400);
  }
  if (!validSources.includes(source)) {
    return errorResponse(`Invalid source. Must be one of: ${validSources.join(', ')}`, 400);
  }
  if (!txId || typeof txId !== "string") {
    return errorResponse("txId required", 400);
  }

  // Enforce rate limit (max 60 coin credits per hour)
  const rateLimitKey = `ratelimit:credit:${uid}`;
  try {
    await enforceRateLimit(rateLimitKey, 60, 3600);
  } catch (e) {
    if (e instanceof Response) {
      return e;
    }
    throw e;
  }

  // Security: Fetch dynamic limits to prevent client-side manipulation
  try {
    const { data: distData, error: distError } = await supabase
      .from("coin_distributions")
      .select("premium_reward")
      .eq("id", source)
      .single();

    if (!distError && distData && distData.premium_reward !== null) {
      // The absolute maximum a client can claim in a single transaction for this source
      // is the premium_reward multiplied by 2 (to account for "Double Reward" ad placements)
      const absoluteMaxClaim = distData.premium_reward * 2;
      if (amount > absoluteMaxClaim) {
        console.warn(`Security block: User ${uid} tried to claim ${amount} for ${source} (max allowed: ${absoluteMaxClaim})`);
        return errorResponse("Amount exceeds maximum allowed for this feature", 400);
      }
    }
  } catch (e) {
    console.error("Failed to query coin_distributions for security check:", e);
  }

  try {
    const { data: newBalance, error: rpcError } = await supabase.rpc("credit_user_coins", {
      p_user_id: uid,
      p_amount: amount,
      p_source: source,
      p_tx_id: txId,
    });

    if (rpcError) {
      console.error("Credit coins RPC error:", rpcError);
      return errorResponse(rpcError.message, 500);
    }

    // Sync weekly leaderboard and invalidate user profile cache (non-blocking)
    if (userRow) {
      redis.zadd("leaderboard:weekly", { score: userRow.total_earned, member: uid }).catch(() => {});
      redis.del("leaderboard:compiled:weekly:50").catch(() => {});
    }

    // Invalidate the user profile cache so the next fetch gets the fresh balance
    redis.del(`user:profile:${uid}`).catch(() => {});

    return jsonResponse({ success: true, balance: newBalance });
  } catch (e) {
    console.error("Credit coins error:", e);
    return errorResponse("Failed to credit coins", 500);
  }
});
