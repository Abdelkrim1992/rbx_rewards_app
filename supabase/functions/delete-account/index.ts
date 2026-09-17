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
    // 1. Delete associated records from public schema
    await supabase.from("transactions").delete().eq("user_id", uid);
    await supabase.from("game_sessions").delete().eq("user_id", uid);
    await supabase.from("game_stats").delete().eq("user_id", uid);
    await supabase.from("redeemed_rewards").delete().eq("user_id", uid);
    await supabase.from("user_ad_stats").delete().eq("user_id", uid);
    await supabase.from("referrals").delete().or(`referrer_id.eq.${uid},referee_id.eq.${uid}`);
    
    // Delete profile from public.users
    await supabase.from("users").delete().eq("id", uid);

    // 2. Permanently delete from auth.users via admin API
    const { error: deleteAuthError } = await supabase.auth.admin.deleteUser(uid);
    if (deleteAuthError) {
      console.warn("Notice deleting auth user:", deleteAuthError);
    }

    // 3. Clear Redis cache
    redis.del(`user:profile:${uid}`).catch(() => {});

    return jsonResponse({ success: true, message: "Account permanently deleted" });
  } catch (e) {
    console.error("delete-account error:", e);
    return errorResponse("Internal error during deletion", 500);
  }
});
