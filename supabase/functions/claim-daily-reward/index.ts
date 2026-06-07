// Supabase Edge Function: Claim Daily Reward with Redis Cooldown

import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { checkCooldown, setCooldown } from "../_shared/cooldown.ts";

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
  const cooldownKey = `cooldown:daily:${uid}`;

  // Check Redis cooldown first
  const remainingCooldown = await checkCooldown(cooldownKey);
  if (remainingCooldown > 0) {
    return errorResponse(`Daily reward is cooling down. Please wait ${remainingCooldown} seconds.`, 429);
  }
  
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

  // Set Redis cooldown on successful claim
  if (data && data.success === true) {
    await setCooldown(cooldownKey, 86400);
  }

  return jsonResponse(data);
});
