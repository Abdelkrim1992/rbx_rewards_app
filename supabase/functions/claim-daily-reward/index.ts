// Supabase Edge Function: Claim Daily Reward with Redis Cooldown

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

  // Parse request body for amount (default 15)
  let amount = 15;
  try {
    const body = await req.json();
    if (body.amount && typeof body.amount === 'number') {
      amount = Math.max(1, Math.min(30, body.amount)); // Clamp between 1-30 (max premium double)
    }
  } catch {
    // No body or invalid JSON, use default
  }

  const { data, error } = await supabase.rpc("claim_daily_reward", {
    p_user_id: uid,
    p_amount: amount,
  });

  if (error) {
    return errorResponse(error.message, 400);
  }

  // Invalidate the user profile cache so the next fetch gets the fresh balance
  redis.del(`user:profile:${uid}`).catch(console.error);

  return jsonResponse({ success: true, amount: amount, data: data });
});
