import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

export function userCacheKey(uid: string): string {
  return `user:profile:${uid}`;
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

  try {
    const body = await req.json();
    const updateData: Record<string, any> = {};

    if (body.display_name !== undefined) {
      updateData.display_name = body.display_name;
    }
    if (body.profile_photo_url !== undefined) {
      updateData.profile_photo_url = body.profile_photo_url;
    }

    if (Object.keys(updateData).length === 0) {
      return errorResponse("No fields to update", 400);
    }

    // 1. Update PostgreSQL
    const { error: updateError } = await supabase
      .from("users")
      .update(updateData)
      .eq("id", uid);

    if (updateError) {
      console.error("Update profile error:", updateError);
      return errorResponse("Failed to update profile", 500);
    }

    // 2. Invalidate Redis Cache so next fetch is immediate
    await redis.del(userCacheKey(uid)).catch(console.error);

    return jsonResponse({ success: true });
  } catch (e) {
    console.error("update-profile error:", e);
    return errorResponse("Internal error", 500);
  }
});
