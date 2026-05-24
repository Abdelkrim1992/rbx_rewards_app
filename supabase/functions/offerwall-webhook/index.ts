// Supabase Edge Function: Offerwall Webhook
// Deno runtime — uses Supabase JS client for DB operations

import { supabase, jsonResponse, errorResponse } from "../_shared/supabase_client.ts";

function getConfig(provider: string) {
  const maxHourly = parseInt(Deno.env.get("MAX_OFFERS_PER_HOUR") || "3", 10);

  if (provider === "ironsource") {
    const secret = Deno.env.get("IRONSOURCE_SECRET");
    if (!secret) throw new Error("IRONSOURCE_SECRET not configured");
    return { secret, maxHourly };
  }
  if (provider === "tapjoy") {
    const secret = Deno.env.get("TAPJOY_SECRET");
    if (!secret) throw new Error("TAPJOY_SECRET not configured");
    return { secret, maxHourly };
  }

  const fallback = Deno.env.get("IRONSOURCE_SECRET") || Deno.env.get("TAPJOY_SECRET");
  if (!fallback) throw new Error("No offerwall secret configured");
  return { secret: fallback, maxHourly };
}

async function verifyIronSourceSignature(
  params: Record<string, string>,
  secret: string
): Promise<boolean> {
  const sortedKeys = Object.keys(params).filter((k) => k !== "signature").sort();
  const payload = sortedKeys.map((k) => `${k}=${params[k]}`).join("&");
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
  const expected = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return params["signature"] === expected;
}

async function verifyTapjoySignature(
  params: Record<string, string>,
  secret: string
): Promise<boolean> {
  const id = params["id"] || "";
  const snuid = params["snuid"] || "";
  const currency = params["currency"] || "";
  const msg = `${id}:${snuid}:${currency}:${secret}`;
  const encoder = new TextEncoder();
  const hash = await crypto.subtle.digest("MD5", encoder.encode(msg));
  const expected = Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return params["verifier"] === expected;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return errorResponse("Method Not Allowed", 405);
  }

  let body;
  try {
    body = await req.json();
  } catch (_e) {
    return errorResponse("Invalid JSON body", 400);
  }
  const {
    eventId,
    userId,
    amount: amountStr,
    currency,
    signature,
    provider = "ironsource",
  } = body;
  const config = getConfig(provider);

  if (!eventId || !userId || !amountStr || !currency || !signature) {
    return errorResponse("Missing required fields", 400);
  }

  const amount = parseInt(amountStr, 10);
  if (isNaN(amount) || amount <= 0) {
    return errorResponse("Invalid amount", 400);
  }

  // Verify signature
  const params: Record<string, string> = { ...body };
  let isValid = false;
  if (provider === "ironsource") {
    isValid = await verifyIronSourceSignature(params, config.secret);
  } else if (provider === "tapjoy") {
    isValid = await verifyTapjoySignature(params, config.secret);
  } else {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(config.secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const payloadBody = { ...body };
    delete payloadBody.signature;
    const sig = await crypto.subtle.sign(
      "HMAC",
      key,
      encoder.encode(JSON.stringify(payloadBody))
    );
    const expected = Array.from(new Uint8Array(sig))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    isValid = signature === expected;
  }

  if (!isValid) {
    console.error(`Invalid signature for event ${eventId}`);
    return errorResponse("Invalid signature", 403);
  }

  // Check deduplication
  const txId = `${provider}_${eventId}`;
  const { data: existingTx } = await supabase
    .from("transactions")
    .select("id")
    .eq("tx_id", txId)
    .single();

  if (existingTx) {
    return jsonResponse({ success: true, credited: 0, reason: "already_processed" });
  }

  // Rate limit check
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count } = await supabase
    .from("transactions")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .in("source", ["offerwall_ironsource", "offerwall_tapjoy", "offerwall_adgem"])
    .gte("processed_at", oneHourAgo);

  if ((count || 0) >= config.maxHourly) {
    console.warn(`Rate limit exceeded for user ${userId}`);
    return errorResponse("Rate limit exceeded", 429);
  }

  // Credit coins via RPC for atomicity
  const { data: _creditResult, error: creditError } = await supabase.rpc(
    "credit_user_coins",
    {
      p_user_id: userId,
      p_amount: amount,
      p_source: `offerwall_${provider}`,
      p_tx_id: txId,
    }
  );

  if (creditError) {
    console.error("Credit error:", creditError);
    return errorResponse("Failed to credit coins", 500);
  }

  // Increment offers completed
  await supabase.rpc("increment_offers", { p_user_id: userId });

  console.log(`Credited ${amount} coins to ${userId} from ${provider}`);
  return jsonResponse({ success: true, credited: amount });
});
