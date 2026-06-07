import { supabase, verifyAuth, jsonResponse, errorResponse, corsPreflight } from "../_shared/supabase_client.ts";
import { checkCooldown, setCooldown } from "../_shared/cooldown.ts";

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
  const cooldownKey = `cooldown:spin:${uid}`;

  // Check Redis cooldown first
  const remainingCooldown = await checkCooldown(cooldownKey);
  if (remainingCooldown > 0) {
    return jsonResponse({
      success: false,
      error: "cooldown",
      spins_remaining: 0,
      cooldown_end: remainingCooldown * 1000,
    });
  }

  const { data, error } = await supabase.rpc("use_spin", {
    p_user_id: uid,
  });

  if (error) {
    return errorResponse(error.message, 400);
  }

  // Set Redis cooldown on successful claim if no spins left
  if (data && data.success === true && data.spins_remaining === 0) {
    await setCooldown(cooldownKey, 86400); // 24 hours
    data.cooldown_end = 86400 * 1000;
  }

  return jsonResponse(data);
});
