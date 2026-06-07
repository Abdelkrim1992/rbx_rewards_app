// Supabase Edge Function: Offerwall Webhook
// Deno runtime — handles and verifies postback webhooks from Lootably, Monlix, IronSource, and Tapjoy

import { supabase, jsonResponse, errorResponse } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

function getConfig(provider: string) {
  const maxHourly = parseInt(Deno.env.get("MAX_OFFERS_PER_HOUR") || "10", 10);

  if (provider === "lootably") {
    const secret = Deno.env.get("LOOTABLY_SECRET");
    if (!secret) {
      console.warn("⚠️ LOOTABLY_SECRET not configured. Using fallback 'mock_secret' for sandbox/testing.");
      return { secret: "mock_secret", maxHourly };
    }
    return { secret, maxHourly };
  }
  if (provider === "monlix") {
    const secret = Deno.env.get("MONLIX_SECRET");
    if (!secret) {
      console.warn("⚠️ MONLIX_SECRET not configured. Using fallback 'mock_secret' for sandbox/testing.");
      return { secret: "mock_secret", maxHourly };
    }
    return { secret, maxHourly };
  }
  if (provider === "ironsource") {
    const secret = Deno.env.get("IRONSOURCE_SECRET");
    if (!secret) {
      console.warn("⚠️ IRONSOURCE_SECRET not configured. Using fallback 'mock_secret' for sandbox/testing.");
      return { secret: "mock_secret", maxHourly };
    }
    return { secret, maxHourly };
  }
  if (provider === "tapjoy") {
    const secret = Deno.env.get("TAPJOY_SECRET");
    if (!secret) {
      console.warn("⚠️ TAPJOY_SECRET not configured. Using fallback 'mock_secret' for sandbox/testing.");
      return { secret: "mock_secret", maxHourly };
    }
    return { secret, maxHourly };
  }
  if (provider === "pubscale") {
    const secret = Deno.env.get("PUBSCALE_SECRET");
    if (!secret) {
      console.warn("⚠️ PUBSCALE_SECRET not configured. Using fallback 'mock_secret' for sandbox/testing.");
      return { secret: "mock_secret", maxHourly };
    }
    return { secret, maxHourly };
  }

  const fallback = Deno.env.get("LOOTABLY_SECRET") || Deno.env.get("MONLIX_SECRET") || Deno.env.get("IRONSOURCE_SECRET") || Deno.env.get("TAPJOY_SECRET");
  return { secret: fallback || "mock_secret", maxHourly };
}

// Helper: SHA256 HMAC
async function hmacSha256(message: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Helper: MD5 Hash
async function md5Hash(message: string): Promise<string> {
  const encoder = new TextEncoder();
  const hash = await crypto.subtle.digest("MD5", encoder.encode(message));
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Verifier: Lootably (HMAC SHA-256 of: userId + ip + payout + id)
async function verifyLootablySignature(
  userId: string,
  ip: string,
  payout: string,
  id: string,
  signature: string,
  secret: string
): Promise<boolean> {
  const payload = `${userId}${ip}${payout}${id}`;
  const expected = await hmacSha256(payload, secret);
  return signature === expected;
}

// Verifier: Monlix (MD5 of: transactionId + userId + payout + secretKey)
async function verifyMonlixSignature(
  userId: string,
  payout: string,
  id: string,
  signature: string,
  secret: string
): Promise<boolean> {
  const payload = `${id}${userId}${payout}${secret}`;
  const expected = await md5Hash(payload);
  return signature.toLowerCase() === expected.toLowerCase();
}

// Verifier: IronSource
async function verifyIronSourceSignature(
  params: Record<string, string>,
  secret: string
): Promise<boolean> {
  const sortedKeys = Object.keys(params).filter((k) => k !== "signature" && k !== "provider").sort();
  const payload = sortedKeys.map((k) => `${k}=${params[k]}`).join("&");
  const expected = await hmacSha256(payload, secret);
  return params["signature"] === expected;
}

// Verifier: Tapjoy
async function verifyTapjoySignature(
  params: Record<string, string>,
  secret: string
): Promise<boolean> {
  const id = params["id"] || "";
  const snuid = params["snuid"] || "";
  const currency = params["currency"] || "";
  const msg = `${id}:${snuid}:${currency}:${secret}`;
  const expected = await md5Hash(msg);
  return params["verifier"] === expected;
}

// Verifier: PubScale
async function verifyPubscaleSignature(
  params: Record<string, string>,
  secret: string
): Promise<boolean> {
  const userId = params["user_id"] || "";
  const value = params["value"] || "";
  const token = params["token"] || "";
  
  // Format: {secret_key}.{user_id}.{int(value)}.{token}
  const valueInt = parseInt(value, 10).toString(); // ensure integer format
  const msg = `${secret}.${userId}.${valueInt}.${token}`;
  const expected = await md5Hash(msg);
  return params["signature"] === expected;
}

Deno.serve(async (req) => {
  // Support both GET and POST requests
  if (req.method !== "POST" && req.method !== "GET") {
    return errorResponse("Method Not Allowed", 405);
  }

  // 1. Gather all parameters from URL and/or JSON body
  const urlObj = new URL(req.url);
  const queryParams: Record<string, string> = {};
  for (const [key, value] of urlObj.searchParams.entries()) {
    queryParams[key] = value;
  }

  let bodyParams: Record<string, string> = {};
  if (req.method === "POST") {
    try {
      const body = await req.json();
      for (const key in body) {
        bodyParams[key] = String(body[key]);
      }
    } catch (_e) {
      // Not a JSON body, proceed with query parameters
    }
  }

  // Combine parameters (body overrides query parameters)
  const params = { ...queryParams, ...bodyParams };

  const provider = params.provider?.toLowerCase() || "lootably";
  const config = getConfig(provider);

  let userId = "";
  let eventId = "";
  let amountStr = "";
  let signature = "";
  let isValid = false;

  // 2. Normalize and check params per provider
  if (provider === "lootably") {
    userId = params.userId || params.userID || "";
    eventId = params.id || "";
    amountStr = params.payout || "";
    signature = params.signature || "";
    const ip = params.ip || "";

    if (!userId || !eventId || !amountStr || !signature) {
      return errorResponse("Missing required Lootably parameters", 400);
    }
    isValid = await verifyLootablySignature(userId, ip, amountStr, eventId, signature, config.secret);

  } else if (provider === "monlix") {
    userId = params.userId || "";
    eventId = params.transactionId || params.id || "";
    amountStr = params.payout || params.amount || "";
    signature = params.signature || "";

    if (!userId || !eventId || !amountStr || !signature) {
      return errorResponse("Missing required Monlix parameters", 400);
    }
    isValid = await verifyMonlixSignature(userId, amountStr, eventId, signature, config.secret);

  } else if (provider === "ironsource") {
    userId = params.userId || "";
    eventId = params.eventId || "";
    amountStr = params.amount || "";
    signature = params.signature || "";

    if (!userId || !eventId || !amountStr || !signature) {
      return errorResponse("Missing required IronSource parameters", 400);
    }
    isValid = await verifyIronSourceSignature(params, config.secret);

  } else if (provider === "tapjoy") {
    userId = params.snuid || "";
    eventId = params.id || "";
    amountStr = params.currency || "";
    signature = params.verifier || "";

    if (!userId || !eventId || !amountStr || !signature) {
      return errorResponse("Missing required Tapjoy parameters", 400);
    }
    isValid = await verifyTapjoySignature(params, config.secret);
  } else if (provider === "pubscale") {
    userId = params.user_id || "";
    eventId = params.token || "";
    amountStr = params.value || "";
    signature = params.signature || "";

    if (!userId || !eventId || !amountStr || !signature) {
      return errorResponse("Missing required PubScale parameters", 400);
    }
    isValid = await verifyPubscaleSignature(params, config.secret);
  } else {
    return errorResponse(`Unsupported provider: ${provider}`, 400);
  }

  // 3. Verify Signature
  if (!isValid) {
    console.error(`Invalid signature for provider ${provider}, event ${eventId}`);
    // For sandbox / testing mode: if secret is 'mock_secret' and signature is 'sandbox', allow it.
    if (config.secret === "mock_secret" && signature === "sandbox") {
      console.log("⚠️ Sandbox bypass enabled for testing.");
    } else {
      return errorResponse("Invalid signature", 403);
    }
  }

  // 4. Validate UUID format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(userId)) {
    console.error(`Invalid UUID format for userId: ${userId}`);
    return errorResponse("Invalid user ID format", 400);
  }

  const amount = parseInt(amountStr, 10);
  if (isNaN(amount) || amount <= 0) {
    return errorResponse("Invalid amount", 400);
  }

  // 5. Deduplication Check (Redis first, then Postgres fallback)
  const txId = `${provider}_${eventId}`;
  const dedupKey = `dedup:webhook:${txId}`;
  const isNew = await redis.set(dedupKey, "1", { nx: true, ex: 86400 });
  if (!isNew) {
    return jsonResponse({ success: true, credited: 0, reason: "already_processed" });
  }

  const { data: existingTx } = await supabase
    .from("transactions")
    .select("id")
    .eq("tx_id", txId)
    .maybeSingle();

  if (existingTx) {
    return jsonResponse({ success: true, credited: 0, reason: "already_processed" });
  }

  // 6. Rate Limit Check (prevent spamming completions)
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count } = await supabase
    .from("transactions")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId)
    .in("source", ["offerwall_lootably", "offerwall_monlix", "offerwall_ironsource", "offerwall_tapjoy", "offerwall_pubscale"])
    .gte("processed_at", oneHourAgo);

  if ((count || 0) >= config.maxHourly) {
    console.warn(`Rate limit exceeded for user ${userId}`);
    return errorResponse("Rate limit exceeded", 429);
  }

  // 7. Credit coins atomically via SQL function
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

  // 8. Increment offers completed
  await supabase.rpc("increment_offers", { p_user_id: userId });

  console.log(`Credited ${amount} coins to ${userId} from provider ${provider}`);
  return jsonResponse({ success: true, credited: amount });
});
