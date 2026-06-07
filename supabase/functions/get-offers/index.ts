// Supabase Edge Function: Get Offers
// Deno runtime — fetches live offers from Lootably and Monlix feeds

import { corsPreflight, errorResponse, jsonResponse, verifyAuth } from "../_shared/supabase_client.ts";

interface UnifiedOffer {
  id: string;
  title: string;
  subtitle: string;
  reward: number;
  category: string;
  difficulty: "Easy" | "Medium" | "Hard";
  estimatedTime: string;
  iconUrl: string;
  targetUrl: string;
  isFeatured?: boolean;
}

Deno.serve(async (req) => {
  // Handle CORS Preflight
  if (req.method === "OPTIONS") {
    return corsPreflight();
  }

  // 1. Authenticate the User
  const { user, error: authError } = await verifyAuth(req);
  if (authError || !user) {
    return errorResponse(authError || "Unauthorized", 401);
  }

  // 2. Parse request body
  let body = { platform: "android" };
  try {
    if (req.body) {
      body = await req.json();
    }
  } catch (_e) {
    // Fallback to default if body is empty
  }

  const platform = body.platform || "android";
  const userId = user.id;

  // 3. Extract Client IP & User Agent (crucial for offerwall geo-targeting)
  const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0].trim() || "127.0.0.1";
  const userAgent = req.headers.get("user-agent") || "";

  // 4. Retrieve credentials from environment
  const LOOTABLY_API_KEY = Deno.env.get("LOOTABLY_API_KEY");
  const LOOTABLY_PUB_ID = Deno.env.get("LOOTABLY_PUB_ID");
  const MONLIX_API_KEY = Deno.env.get("MONLIX_API_KEY");

  const offers: UnifiedOffer[] = [];
  let fetchedReal = false;

  // --- Fetch Lootably Offers ---
  if (LOOTABLY_API_KEY && LOOTABLY_PUB_ID) {
    try {
      // Map platform to Lootably format: android, ios, web
      const lootPlatform = platform === "ios" ? "ios" : platform === "web" ? "web" : "android";
      const url = `https://api.lootably.com/api/v1/offers/get?apiKey=${LOOTABLY_API_KEY}&pubId=${LOOTABLY_PUB_ID}&userId=${userId}&ip=${clientIp}&userAgent=${encodeURIComponent(userAgent)}&platform=${lootPlatform}`;
      
      const response = await fetch(url);
      if (response.ok) {
        const data = await response.json();
        if (data.success && Array.isArray(data.offers)) {
          data.offers.forEach((o: any) => {
            offers.push({
              id: `lootably_${o.id}`,
              title: o.title || "No Title",
              subtitle: o.requirement || o.description || "Complete requirements",
              reward: Math.round(o.payout * 100), // Scale Lootably payout to coins (e.g. $1.00 = 1000 coins)
              category: mapCategory(o.category || "Apps"),
              difficulty: mapDifficulty(o.difficulty || "medium"),
              estimatedTime: o.timeEstimate || "5 min",
              iconUrl: o.image || "https://cdn-icons-png.flaticon.com/512/3408/3408506.png",
              targetUrl: o.link || "",
            });
          });
          fetchedReal = true;
        }
      } else {
        console.error("Lootably API Error response status:", response.status);
      }
    } catch (e) {
      console.error("Failed to fetch Lootably offers:", e);
    }
  }

  // --- Fetch Monlix Offers ---
  if (MONLIX_API_KEY) {
    try {
      // Map platform to Monlix format: android, ios, desktop
      const monlixPlatform = platform === "ios" ? "ios" : platform === "web" ? "desktop" : "android";
      const url = `https://api.monlix.com/api/v1/offers?apiKey=${MONLIX_API_KEY}&userId=${userId}&ip=${clientIp}&userAgent=${encodeURIComponent(userAgent)}&platform=${monlixPlatform}`;
      
      const response = await fetch(url);
      if (response.ok) {
        const data = await response.json();
        if (data.success && Array.isArray(data.offers)) {
          data.offers.forEach((o: any) => {
            offers.push({
              id: `monlix_${o.id}`,
              title: o.name || "No Title",
              subtitle: o.requirement || o.description || "Complete requirements",
              reward: Math.round(o.payout * 100), // Scale payout to coins
              category: mapCategory(o.category || "Apps"),
              difficulty: mapDifficulty(o.difficulty || "medium"),
              estimatedTime: o.timeEstimate || "10 min",
              iconUrl: o.image_url || "https://cdn-icons-png.flaticon.com/512/3408/3408506.png",
              targetUrl: o.click_url || "",
            });
          });
          fetchedReal = true;
        }
      } else {
        console.error("Monlix API Error response status:", response.status);
      }
    } catch (e) {
      console.error("Failed to fetch Monlix offers:", e);
    }
  }

  // 5. Fallback to Premium Mock Offers (if no API keys or all failed)
  if (!fetchedReal || offers.length === 0) {
    offers.push(
      {
        id: "mock_1",
        title: "Monopoly GO! Payout Plus",
        subtitle: "Install app and complete Board 15",
        reward: 5800,
        category: "Games",
        difficulty: "Hard",
        estimatedTime: "2 hours",
        iconUrl: "https://cdn-icons-png.flaticon.com/512/3408/3408506.png",
        targetUrl: "https://play.google.com/store/apps/details?id=com.scopely.monopolygo&referrer=utm_source%3Drbx_rewards",
        isFeatured: true,
      },
      {
        id: "mock_2",
        title: "Survey Junkie Premium",
        subtitle: "Complete your profile survey & answer 3 short polls",
        reward: 1200,
        category: "Surveys",
        difficulty: "Easy",
        estimatedTime: "8 min",
        iconUrl: "https://cdn-icons-png.flaticon.com/512/2618/2618245.png",
        targetUrl: "https://www.surveyjunkie.com/?utm_source=rbx_rewards",
      },
      {
        id: "mock_3",
        title: "Raid: Shadow Legends Arena",
        subtitle: "Download, play and summon 2 Ancient Shards",
        reward: 7200,
        category: "Games",
        difficulty: "Hard",
        estimatedTime: "3 days",
        iconUrl: "https://cdn-icons-png.flaticon.com/512/3408/3408506.png",
        targetUrl: "https://plarium.com/en/games/raid-shadow-legends/",
      },
      {
        id: "mock_4",
        title: "SHEIN Shopping Extravaganza",
        subtitle: "Install SHEIN app, register a new account & add 1 item to cart",
        reward: 1800,
        category: "Apps",
        difficulty: "Easy",
        estimatedTime: "3 min",
        iconUrl: "https://cdn-icons-png.flaticon.com/512/2991/2991148.png",
        targetUrl: "https://play.google.com/store/apps/details?id=com.zzkko",
      },
      {
        id: "mock_5",
        title: "Credit Karma Credit Score",
        subtitle: "Register free account & verify credit health index",
        reward: 2500,
        category: "Trials",
        difficulty: "Easy",
        estimatedTime: "5 min",
        iconUrl: "https://cdn-icons-png.flaticon.com/512/3074/3074058.png",
        targetUrl: "https://www.creditkarma.com/",
      },
      {
        id: "mock_6",
        title: "Coin Master Village Booster",
        subtitle: "Install Coin Master & upgrade Village 4",
        reward: 3200,
        category: "Games",
        difficulty: "Medium",
        estimatedTime: "1.5 hours",
        iconUrl: "https://cdn-icons-png.flaticon.com/512/3408/3408506.png",
        targetUrl: "https://play.google.com/store/apps/details?id=com.moonactive.coinmaster",
      },
      {
        id: "mock_7",
        title: "Spotify Music Trial",
        subtitle: "Start a 30-day free trial of Spotify Premium",
        reward: 4100,
        category: "Trials",
        difficulty: "Easy",
        estimatedTime: "2 min",
        iconUrl: "https://cdn-icons-png.flaticon.com/512/3074/3074058.png",
        targetUrl: "https://www.spotify.com/",
      }
    );
  }

  // 6. Sort by reward (coins size) descending to MAXIMIZE user earnings visibility
  offers.sort((a, b) => b.reward - a.reward);

  // Set the first offer as Featured if none is flagged yet
  if (!offers.some(o => o.isFeatured)) {
    offers[0].isFeatured = true;
  }

  return jsonResponse({ success: true, offers }, 200, { "Cache-Control": "public, max-age=10, s-maxage=30" });
});

// Helper: Standardize Categories
function mapCategory(cat: string): string {
  const c = cat.toLowerCase();
  if (c.includes("game") || c.includes("play")) return "Games";
  if (c.includes("survey") || c.includes("poll") || c.includes("opinion")) return "Surveys";
  if (c.includes("trial") || c.includes("credit") || c.includes("sub")) return "Trials";
  return "Apps";
}

// Helper: Standardize Difficulty
function mapDifficulty(diff: string): "Easy" | "Medium" | "Hard" {
  const d = diff.toLowerCase();
  if (d.includes("easy") || d.includes("simple") || d.includes("low")) return "Easy";
  if (d.includes("hard") || d.includes("difficult") || d.includes("high")) return "Hard";
  return "Medium";
}
