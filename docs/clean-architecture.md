## Architecture - RBX Rewards

This is the 3-layer architecture of the RBX Rewards application:

Flutter
Riverpod

Presentation Layer
      ↓
Business Layer (Services)
      ↓
Data Layer (Repositories)

Supabase
Redis
Cloudflare
Hive


This is the system design of the RBX Rewards application:

┌───────────────────────────────────────────┐
│ Flutter App (iOS / Android)               │
│                                           │
│ Riverpod                                  │
│ Optimistic UI                             │
│ Offline Queue                             │
│ Local Cache (Hive)                        │
└─────────────────┬─────────────────────────┘
                  │
                  ▼
┌───────────────────────────────────────────┐
│ Cloudflare                                │
│                                           │
│ DDoS Protection                           │
│ Rate Limiting                             │
│ Bot Protection                            │
│ API Routing                               │
└─────────────────┬─────────────────────────┘
                  │
                  ▼
┌───────────────────────────────────────────┐
│ Supabase Edge Functions                   │
│                                           │
│ claimDailyReward()                        │
│ openChest()                               │
│ spinWheel()                               │
│ submitGameScore()                         │
│ redeemReward()                            │
│ offerwallWebhook()                        │
└─────────────┬───────────────┬─────────────┘
              │               │
              ▼               ▼

┌─────────────────────┐  ┌──────────────────┐
│ Upstash Redis       │  │ Supabase Postgres│
│                     │  │                  │
│ Rate Limits         │  │ Source of Truth  │
│ Cooldowns           │  │ Transactions     │
│ Leaderboards        │  │ Users            │
│ Session Locks       │  │ Rewards          │
│ Temporary Cache     │  │ Game Sessions    │
└─────────────────────┘  └──────────────────┘
              │
              ▼
┌───────────────────────────────────────────┐
│ Read Replica                              │
│                                           │
│ Leaderboards                              │
│ Analytics                                 │
│ Statistics                                │
└───────────────────────────────────────────┘