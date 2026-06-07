// Supabase Edge Function: Claim Mega Chest

import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";

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
  const txId = `mega_${crypto.randomUUID()}`;

  // Parse amount from client (variable chest reward), clamp to max 90
  let amount = 45;
  try {
    const body = await req.json();
    if (body.amount && typeof body.amount === 'number') {
      amount = Math.max(1, Math.min(90, body.amount));
    }
  } catch {
    // No body, use default
  }

  const { data, error } = await supabase.rpc("credit_user_coins", {
    p_user_id: uid,
    p_amount: amount,
    p_source: "mega_chest",
    p_tx_id: txId,
  });

  if (error) {
    return errorResponse(error.message, 400);
  }

  return jsonResponse({ success: true, newBalance: data });
});
