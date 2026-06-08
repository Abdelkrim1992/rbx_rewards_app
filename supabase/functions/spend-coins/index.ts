// Supabase Edge Function: Spend Coins (Redeem)

import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

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
  const { amount, rewardTitle } = body;

  if (!amount || amount <= 0) {
    return errorResponse("Invalid amount", 400);
  }

  const { data, error } = await supabase.rpc("redeem_reward", {
    p_user_id: uid,
    p_amount: amount,
    p_reward_title: rewardTitle || "Unknown",
  });

  if (error) {
    const status = error.message.includes("Insufficient") ? 400 : 500;
    return errorResponse(error.message, status);
  }

  // Invalidate the user profile cache so the next fetch gets the fresh balance
  redis.del(`user:profile:${uid}`).catch(console.error);
  redis.del(`reward_history:${uid}:50`).catch(console.error);

  return jsonResponse({
    success: true,
    remaining: data.remaining,
    rewardId: data.reward_id,
    txId: data.tx_id,
  });
});
