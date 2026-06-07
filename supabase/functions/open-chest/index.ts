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
  const lockKey = `lock:chest:${uid}`;

  // Acquire 5 second lock
  const locked = await redis.set(lockKey, "1", { nx: true, ex: 5 });
  if (!locked) {
    return errorResponse("Chest unlock in progress. Please wait.", 429);
  }

  const txId = `chest_${crypto.randomUUID()}`;

  // Parse amount from client (variable chest reward), default to random 15-45
  let amount = Math.floor(15 + Math.random() * 31);
  try {
    const body = await req.json();
    if (body.amount && typeof body.amount === 'number') {
      amount = Math.max(1, Math.min(45, body.amount));
    }
  } catch {
    // No body
  }

  const { data, error } = await supabase.rpc("credit_user_coins", {
    p_user_id: uid,
    p_amount: amount,
    p_source: "chest",
    p_tx_id: txId,
  });

  if (error) {
    return errorResponse(error.message, 400);
  }

  return jsonResponse({ success: true, coinsEarned: amount, newBalance: data });
});
