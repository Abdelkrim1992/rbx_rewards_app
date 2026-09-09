/**
 * RBX Rewards - Global App Data & Configuration
 * Exact data reflecting the live Flutter application code, tokenomics, and backend services.
 */
const AppConfig = {
  appName: "RBX Rewards",
  appPackageName: "com.example.rbx_rewards",
  appTagline: "Play Mini-Games, Complete Quests & Redeem Official Roblox Gift Cards",
  companyName: "RBX Rewards Studio",
  supportEmail: "support@rbxrewards.app",
  privacyEmail: "privacy@rbxrewards.app",
  legalEmail: "legal@rbxrewards.app",
  effectiveDate: "September 9, 2026",
  lastUpdatedDate: "September 9, 2026",
  policyVersion: "1.4.0",
  deliveryWindow: "Within 48 hours",
  
  // Real Reward Catalog (Exact match with lib/presentation/screens/rewards_screen.dart)
  rewardsCatalog: [
    {
      id: "roblox-3usd",
      title: "$3 Roblox Gift Card",
      costCoins: 20000,
      costFormatted: "20,000",
      valueUSD: "$3.00 USD",
      approxRobux: "~240 Robux",
      color: "#2ECC71",
      assetImage: "assets/roblox_3usd_card.png",
      description: "Official digital Roblox Gift Card PIN code purchased from authorized distributors."
    },
    {
      id: "roblox-5usd",
      title: "$5 Roblox Gift Card",
      costCoins: 40000,
      costFormatted: "40,000",
      valueUSD: "$5.00 USD",
      approxRobux: "~400 Robux",
      color: "#9B5CFF",
      assetImage: "assets/roblox_5usd_card.png",
      description: "Official digital Roblox Gift Card PIN code purchased from authorized distributors."
    },
    {
      id: "roblox-10usd",
      title: "$10 Roblox Gift Card",
      costCoins: 70000,
      costFormatted: "70,000",
      valueUSD: "$10.00 USD",
      approxRobux: "~800 Robux",
      color: "#6A2FD8",
      assetImage: "assets/roblox_10usd_card.png",
      description: "Official digital Roblox Gift Card PIN code purchased from authorized distributors."
    }
  ],

  // Real Mini-Games (Exact match with lib/presentation/screens/games_screen.dart)
  miniGames: [
    { name: "Tap Tap", type: "Reflex Challenge", dailyCap: 150, description: "Fast-paced reflex reaction tapping game against shrinking timers." },
    { name: "Math Quiz", type: "10-Question Arithmetic", dailyCap: 120, description: "Rapid-fire addition, subtraction, and multiplication speed challenges." },
    { name: "Flappy Jump", type: "Arcade Skill Runner", dailyCap: 150, description: "Flame engine physics jumper where you navigate through obstacle gates." },
    { name: "Flip Cards", type: "Memory Match", dailyCap: 60, description: "Visual memory card flipping game matching tile pairs before time runs out." },
    { name: "Scratch Card", type: "Instant Win", dailyCap: 100, description: "Interactive scratch surface game powered by the Scratcher framework." }
  ],

  // Real Earning Features & Mechanics (Exact match with DailyCapService & HomeScreen)
  features: {
    dailyStreak: {
      cycleHours: 24,
      firstWeekAmounts: [15, 20, 25, 30, 35, 40, 100],
      postFirstWeekBase: 15,
      day7Jackpot: 100,
      description: "Claim once every 24 hours. Consecutive streaks unlock higher multipliers culminating in the Day 7 (100 Coin) jackpot."
    },
    megaChest: {
      payoutCoins: 1000,
      description: "Milestone achievement chest granting 1,000 bonus coins upon completing daily engagement objectives."
    },
    treasureChest: {
      cooldownHours: 4,
      dailyCap: 120,
      description: "Recurring chest with a 4-hour cooldown timer rewarding active players throughout the day."
    },
    spinWheel: {
      segments: ["5 RBX", "8 RBX", "10 RBX", "15 RBX", "20 RBX", "JACKPOT 25 RBX!"],
      dailyCap: 150,
      description: "Daily lucky wheel with 3 free spins plus extra spins available by viewing rewarded ads."
    },
    twoTierAds: {
      quickOption: "Rewarded Interstitial Ad (~5 sec) for standard base coins.",
      premiumOption: "Rewarded Video Ad for 2x Double Coins multiplier."
    },
    offerwalls: {
      providers: ["Tapjoy (SDK v14.4.0)", "PubScale (SDK v1.0.11)"],
      dailyCap: 1000,
      description: "Partner surveys and game quests crediting RBX Coins directly to user profiles."
    },
    levels: {
      xpPerLevel: 5000,
      formula: "Level = floor(totalEarned / 5000) + 1",
      description: "Every 5,000 total earned coins advances your player rank and unlocks new profile avatar frames."
    }
  },

  // Real Tech Stack & Security Infrastructure
  infrastructure: {
    client: "Flutter (Dart 3.x) with Riverpod State Management",
    localCache: "SharedPreferences & Encrypted Hive / Flutter Secure Storage",
    backendDatabase: "Supabase Postgres with Row Level Security (RLS)",
    edgeFunctions: ["credit-coins", "spend-coins", "get-user-stats", "get-reward-history", "get-quizzes"],
    cachingAndRateLimiting: "Upstash Redis (cooldowns, session locks, fraud velocity)",
    networkProtection: "Cloudflare DDoS Mitigation & Edge Bot Management",
    adNetworks: ["Google Mobile Ads (AdMob) with Apple App Tracking Transparency (ATT)"]
  },

  // Backend API URL: default empty string uses same origin / Netlify proxy.
  // Can be set via window.API_BASE_URL = 'https://your-backend.netlify.app'
  apiBaseUrl: (typeof window !== 'undefined' && window.API_BASE_URL) || "",

  robloxDisclaimer: "RBX Rewards is an independent utility and promotional entertainment application and is NOT affiliated with, sponsored by, or endorsed by Roblox Corporation. 'Roblox' and 'Robux' are registered trademarks of Roblox Corporation."
};

if (typeof module !== 'undefined' && module.exports) {
  module.exports = AppConfig;
}
