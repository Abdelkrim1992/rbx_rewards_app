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

  const txId = `scratch_${crypto.randomUUID()}`;

  // 1. Fetch random limits dynamically from coin_distributions table
  let baseReward = 5;
  let premiumReward = 50;

  try {
    const { data: distData, error: distError } = await supabase
      .from("coin_distributions")
      .select("base_reward, premium_reward")
      .eq("id", "scratch")
      .single();
    
    if (!distError && distData) {
      if (distData.base_reward !== null) baseReward = distData.base_reward;
      if (distData.premium_reward !== null) premiumReward = distData.premium_reward;
    }
  } catch (e) {
    console.error("Failed to query coin_distributions for scratch:", e);
  }

  // Ensure minimum valid range
  if (premiumReward < baseReward) {
    premiumReward = baseReward;
  }

  // Parse amount from client (variable scratch reward), default to random between base and premium
  let amount = Math.floor(baseReward + Math.random() * (premiumReward - baseReward + 1));
  try {
    const body = await req.json();
    if (body.amount && typeof body.amount === 'number') {
      amount = Math.max(1, Math.min(premiumReward, body.amount));
    }
  } catch {
    // No body
  }

  const { data, error } = await supabase.rpc("credit_user_coins", {
    p_user_id: uid,
    p_amount: amount,
    p_source: "scratch",
    p_tx_id: txId,
  });

  if (error) {
    return errorResponse(error.message, 400);
  }

  // Invalidate user profile cache so updated balance is reflected
  redis.del(`user:profile:${uid}`).catch(console.error);

  return jsonResponse({ success: true, coinsEarned: amount, newBalance: data });
});
