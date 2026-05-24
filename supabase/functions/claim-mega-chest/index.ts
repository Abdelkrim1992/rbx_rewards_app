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

  const { data, error } = await supabase.rpc("credit_user_coins", {
    p_user_id: uid,
    p_amount: 500,
    p_source: "mega_chest",
    p_tx_id: txId,
  });

  if (error) {
    return errorResponse(error.message, 400);
  }

  return jsonResponse({ success: true, newBalance: data });
});
