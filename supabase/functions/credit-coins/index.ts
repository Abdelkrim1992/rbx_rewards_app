// Supabase Edge Function: Credit Coins (generic)
// Used for non-game coin additions: chests, spin wheel, ads, surveys, scratch cards, quizzes.

import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";

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

    return jsonResponse({ success: true, balance: newBalance });
  } catch (e) {
    console.error("Credit coins error:", e);
    return errorResponse("Failed to credit coins", 500);
  }
});
