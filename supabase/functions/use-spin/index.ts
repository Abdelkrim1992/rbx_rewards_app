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

  const { data, error } = await supabase.rpc("use_spin", {
    p_user_id: uid,
  });

  if (error) {
    return errorResponse(error.message, 400);
  }

  if (data && data.success === true) {
    // Invalidate user profile cache so updated balance is reflected
    redis.del(`user:profile:${uid}`).catch(console.error);
  }

  return jsonResponse(data);
});
