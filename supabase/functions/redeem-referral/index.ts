// Supabase Edge Function: Redeem Referral Code with Fraud Verification & Cache Invalidation

import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";
import { redis } from "../_shared/redis.ts";

interface RedeemRequestBody {
  code?: unknown;
  deviceFingerprint?: unknown;
}

interface RedeemRpcResponse {
  success: boolean;
  error?: string;
  message?: string;
  coins_awarded?: number;
  referrer_name?: string;
  referrer_id?: string;
  balance?: number;
}

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

  let body: RedeemRequestBody = {};
  try {
    const rawBody: unknown = await req.json();
    if (typeof rawBody === "object" && rawBody !== null) {
      body = rawBody as RedeemRequestBody;
    }
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  const rawCode = typeof body.code === "string" ? body.code.trim().toUpperCase() : "";
  const deviceFingerprint = typeof body.deviceFingerprint === "string" ? body.deviceFingerprint.trim() : "";

  if (!rawCode || rawCode.length < 5) {
    return errorResponse("Please enter a valid invite code", 400);
  }

  // Rate limiting: max 5 code redemption attempts per 10 minutes per user
  try {
    await enforceRateLimit(`ratelimit:referral:${uid}`, 5, 600);
  } catch (e) {
    if (e instanceof Response) return e;
    throw e;
  }

  try {
    const { data, error } = await supabase.rpc("redeem_referral_code", {
      p_code: rawCode,
      p_device_fingerprint: deviceFingerprint,
    });

    if (error) {
      return errorResponse(error.message, 400);
    }

    const rpcResult = data as RedeemRpcResponse;
    if (!rpcResult.success) {
      return errorResponse(rpcResult.error || "Failed to redeem code", 400);
    }

    // Invalidate user profile caches for both referee and referrer
    redis.del(`user:profile:${uid}`).catch(console.error);
    if (rpcResult.referrer_id) {
      redis.del(`user:profile:${rpcResult.referrer_id}`).catch(console.error);
    }

    return jsonResponse(rpcResult);
  } catch (err: unknown) {
    console.error("Redeem referral error:", err);
    return errorResponse("Could not process referral redemption", 500);
  }
});
