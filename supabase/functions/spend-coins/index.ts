// Supabase Edge Function: Spend Coins (Redeem) with Anti-Fraud Safeguards

import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

interface SpendCoinsPayload {
  amount: number;
  rewardTitle: string;
  denomId?: string;
  deviceId?: string;
  txId?: string;
}

const MIN_LIFETIME_ADS_MAP: Record<string, number> = {
  starter_rbx_50c: 70,
  rbx_card_3: 500,
  rbx_card_5: 850,
  rbx_card_10: 1600,
  rbx_card_25: 3600,
  robux_code_400: 850,
  robux_code_800: 1600,
  robux_code_2000: 3200,
  robux_code_4500: 6000,
};

const STARTER_DENOM_ID = "starter_rbx_50c";
const STARTER_COIN_COST = 4500;

function parsePayload(body: unknown): { payload: SpendCoinsPayload | null; error: string | null } {
  if (typeof body !== "object" || body === null) {
    return { payload: null, error: "Invalid JSON body" };
  }
  const b = body as Record<string, unknown>;
  const amount = typeof b.amount === "number" ? b.amount : 0;
  if (amount <= 0) {
    return { payload: null, error: "Invalid amount" };
  }
  const rewardTitle = typeof b.rewardTitle === "string" ? b.rewardTitle : "Unknown Reward";
  const denomId = typeof b.denomId === "string" ? b.denomId : undefined;
  const deviceId = typeof b.deviceId === "string" ? b.deviceId : undefined;
  const txId = typeof b.txId === "string" ? b.txId : undefined;

  return {
    payload: { amount, rewardTitle, denomId, deviceId, txId },
    error: null,
  };
}

async function verifyLifetimeAds(
  userId: string,
  denomId?: string,
  amount?: number
): Promise<{ isValid: boolean; error?: string }> {
  let requiredAds = 0;
  if (denomId && MIN_LIFETIME_ADS_MAP[denomId] !== undefined) {
    requiredAds = MIN_LIFETIME_ADS_MAP[denomId]!;
  } else if (amount === STARTER_COIN_COST) {
    requiredAds = MIN_LIFETIME_ADS_MAP[STARTER_DENOM_ID]!;
  }

  if (requiredAds <= 0) {
    return { isValid: true };
  }

  const { data, error } = await supabase
    .from("user_ad_stats")
    .select("lifetime_forced_ads, lifetime_optional_ads")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    console.error("Failed to query user_ad_stats:", error);
  }

  const forced = typeof data?.lifetime_forced_ads === "number" ? data.lifetime_forced_ads : 0;
  const optional = typeof data?.lifetime_optional_ads === "number" ? data.lifetime_optional_ads : 0;
  const totalLifetimeAds = forced + optional;

  if (totalLifetimeAds < requiredAds) {
    return {
      isValid: false,
      error: "Please complete more game sessions before claiming this reward",
    };
  }

  return { isValid: true };
}

async function checkStarterHardwareLock(
  userId: string,
  deviceId?: string,
  denomId?: string,
  amount?: number
): Promise<{ isAllowed: boolean; error?: string }> {
  const isStarter = denomId === STARTER_DENOM_ID || amount === STARTER_COIN_COST;
  if (!isStarter) {
    return { isAllowed: true };
  }

  // 1. Check if user has already redeemed starter voucher
  const { data: userClaim, error: userError } = await supabase
    .from("redeemed_rewards")
    .select("id")
    .eq("user_id", userId)
    .or(`denomination_id.eq.${STARTER_DENOM_ID},cost.eq.${STARTER_COIN_COST}`)
    .not("status", "in", '("cancelled","rejected")')
    .limit(1);

  if (userError) {
    console.warn("Error checking user starter claim:", userError);
  }

  if (userClaim && userClaim.length > 0) {
    return {
      isAllowed: false,
      error: "The Starter Reward can only be redeemed once per account",
    };
  }

  // 2. Check if physical hardware deviceId has already redeemed starter voucher
  if (deviceId && deviceId.length > 0) {
    const { data: deviceClaim, error: deviceError } = await supabase
      .from("redeemed_rewards")
      .select("id")
      .eq("device_id", deviceId)
      .or(`denomination_id.eq.${STARTER_DENOM_ID},cost.eq.${STARTER_COIN_COST}`)
      .not("status", "in", '("cancelled","rejected")')
      .limit(1);

    if (deviceError) {
      console.warn("Error checking device starter claim:", deviceError);
    }

    if (deviceClaim && deviceClaim.length > 0) {
      return {
        isAllowed: false,
        error: "The Starter Reward can only be redeemed once per physical device",
      };
    }
  }

  return { isAllowed: true };
}

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
  const rawBody: unknown = await req.json().catch(() => null);
  const { payload, error: parseError } = parsePayload(rawBody);
  if (parseError || !payload) {
    return errorResponse(parseError || "Bad Request", 400);
  }

  // 1. Proof-of-engagement: Minimum lifetime ads check
  const adsVerification = await verifyLifetimeAds(uid, payload.denomId, payload.amount);
  if (!adsVerification.isValid) {
    return errorResponse(adsVerification.error || "Requirements not met", 403);
  }

  // 2. Anti-farming: Hardware device lock check
  const deviceCheck = await checkStarterHardwareLock(uid, payload.deviceId, payload.denomId, payload.amount);
  if (!deviceCheck.isAllowed) {
    return errorResponse(deviceCheck.error || "Device lock violation", 403);
  }

  // 3. Process atomic redemption via RPC
  const { data, error } = await supabase.rpc("redeem_reward", {
    p_user_id: uid,
    p_amount: payload.amount,
    p_reward_title: payload.rewardTitle,
    p_device_id: payload.deviceId || null,
    p_denom_id: payload.denomId || null,
  });

  if (error) {
    const isInsufficient = error.message.includes("Insufficient");
    const status = isInsufficient ? 400 : 500;
    return errorResponse(error.message, status);
  }

  // Invalidate Redis profile & reward history caches
  redis.del(`user:profile:${uid}`).catch(() => {});
  redis.del(`reward_history_v2:${uid}:50`).catch(() => {});

  return jsonResponse({
    success: true,
    remaining: data.remaining,
    rewardId: data.reward_id,
    txId: data.tx_id,
    status: data.status || "pending_review",
    estimatedDeliveryAt: data.estimated_delivery_at,
  });
});
