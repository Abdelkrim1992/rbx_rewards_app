# Upstash Redis & Cloudflare Setup Guide

This guide outlines the steps to deploy and configure the Redis caching layer and Cloudflare proxy rules for the RBX Rewards App to handle 10k+ daily active users.

---

## 1. Upstash Redis Provisioning

1. Go to [Upstash Console](https://console.upstash.com/) and log in/sign up.
2. Click **Create Database**.
3. Configure the database:
   - **Name**: `rbx-rewards-cache`
   - **Type**: Global (Recommended for low latency) or Regional (select a region close to your Supabase project region).
   - **TLS**: Enabled (default).
4. Click **Create**.
5. Once provisioned, scroll down to the **REST API** section and copy:
   - `UPSTASH_REDIS_REST_URL`
   - `UPSTASH_REDIS_REST_TOKEN`

---

## 2. Supabase Secrets Configuration

Execute the following commands in your local terminal (where the Supabase CLI is installed) to inject your Redis credentials into your Supabase project environment:

```bash
# Set Upstash Redis REST URL
supabase secrets set UPSTASH_REDIS_REST_URL=https://knowing-werewolf-144576.upstash.io"

# Set Upstash Redis REST Token
supabase secrets set UPSTASH_REDIS_REST_TOKEN="gQAAAAAAAjTAAAIgcDI4ZDc4ODY2OWI1NDk0NmI0YjIzM2IyMTg3YzdjMTE0MA"
```

To verify that the secrets are applied:
```bash
supabase secrets list
```

---

## 3. Deploy Edge Functions

Deploy the updated edge functions to your Supabase project:

```bash
supabase functions deploy use-spin
supabase functions deploy get-spin-state
supabase functions deploy add-game-coins
supabase functions deploy credit-coins
supabase functions deploy offerwall-webhook
supabase functions deploy open-chest
supabase functions deploy get-leaderboard
```

---

## 4. Cloudflare Proxy & Rate Limiting Configuration

Using Cloudflare in front of Supabase Edge Functions shields the backend from DDoS attacks and adds edge-level caching for public endpoints.

### Step 4.1: Custom Domain Proxying
1. In the Cloudflare Dashboard, select your domain.
2. Go to **DNS** -> **Records** and add a CNAME record:
   - **Name**: `api` (or any subdomain)
   - **Target**: `<your-supabase-project-ref>.supabase.co` (Do NOT include `https://` or trailing slashes, just the raw domain)
   - **Proxy status**: Proxied (Orange cloud enabled)

### Step 4.2: Cache Rules (Edge Caching for Leaderboard)
To bypass the 2-hour Page Rule limitation on Cloudflare's Free tier, configure a Cache Rule under Caching:
1. Go to **Caching** -> **Cache Rules** in the Cloudflare sidebar.
2. Click **Create rule**.
3. Configure:
   - **Rule Name**: `Cache Leaderboard`
   - **When incoming requests match...**:
     - Field: `URI Path`
     - Operator: `contains`
     - Value: `/functions/v1/get-leaderboard`
   - **Cache status**: Select **Eligible for cache**
   - *Note: You do not need to configure Edge Cache TTL or Browser Cache TTL here. Our Edge Functions are now programmed to send a `Cache-Control: public, s-maxage=30, max-age=10` header automatically. By simply setting "Eligible for cache", Cloudflare will automatically read and respect the 30-second Edge caching rule from our code!*
4. Click **Deploy**.

### Step 4.3: Cloudflare WAF Rate Limiting (Unified Guard)
Since Cloudflare's Free plan limits you to exactly **1 active rate limiting rule**, combine all interactive/transactional endpoints into a single rule to protect the entire app:
1. Go to **Security** -> **Security rules** (and select the **WAF** or **Rate limiting rules** tab/section).
2. Click **Create rate limiting rule**.
3. Configure:
   - **Rule Name**: `Limit Critical Actions`
   - **Expression**: 
     ```text
     (http.request.uri.path contains "/functions/v1/credit-coins" or http.request.uri.path contains "/functions/v1/add-game-coins" or http.request.uri.path contains "/functions/v1/use-spin" or http.request.uri.path contains "/functions/v1/open-chest")
     ```
   - **Rate Limit**: 30 requests per 10 seconds per IP.
   - **Action**: *JS Challenge* (Recommended) or *Block*.
4. Click **Deploy**.

### Step 4.4: Cache Rule (Static Caching for get-offers)
The `get-offers` endpoint returns static offers data. Caching this at the Edge avoids invoking Supabase Edge Functions entirely:
1. Go to **Caching** -> **Cache Rules** in the Cloudflare sidebar.
2. Click **Create rule**.
3. Configure:
   - **Rule Name**: `Cache Offers List`
   - **When incoming requests match...**:
     - Field: `URI Path`
     - Operator: `contains`
     - Value: `/functions/v1/get-offers`
   - **Cache status**: Select **Eligible for cache**
   - **Edge Cache TTL**: Select **Override origin** -> **Enter custom TTL** -> **1 hour**
   - **Browser Cache TTL**: Select **Respect origin** (or choose **30 minutes**)
4. Click **Deploy**.

