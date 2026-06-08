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

  try {
    const body = await req.json();
    const statName = body.stat_name || body.p_stat_name;

    if (!statName) {
      return errorResponse("stat_name is required", 400);
    }

    const { error: rpcError } = await supabase.rpc("increment_user_stat", {
      p_user_id: uid,
      p_stat_name: statName,
    });

    if (rpcError) {
      console.error("Increment stat error:", rpcError);
      return errorResponse("Failed to increment stat", 500);
    }

    // Invalidate Redis Cache so next fetch is immediate
    await redis.del(`user:profile:${uid}`).catch(console.error);

    return jsonResponse({ success: true });
  } catch (e) {
    console.error("increment-user-stat error:", e);
    return errorResponse("Internal error", 500);
  }
});
