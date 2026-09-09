# Netlify Deployment Guide: Frontend & Backend Separated

This guide explains how to deploy the **Frontend Website (`website/`)** and the **Node.js / Express Backend (`server/`)** as two completely independent sites on **Netlify**.

---

## Architecture Overview

```
                          ┌─────────────────────────────┐
                          │     User / Web Browser      │
                          └──────────────┬──────────────┘
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │                                               │
                 ▼                                               ▼
   ┌───────────────────────────┐                   ┌───────────────────────────┐
   │    Netlify Site #1        │                   │     Netlify Site #2       │
   │       (FRONTEND)          │                   │        (BACKEND)          │
   │                           │                   │                           │
   │  - Directory: website/    │   /api/* proxy    │  - Directory: server/     │
   │  - Static Landing Pages   ├──────────────────►│  - Netlify Serverless     │
   │  - Admin SPA Portal       │   or Direct CORS  │    Functions (Express)    │
   │  - Zero build step needed │                   │  - REST API / Healthcheck │
   └───────────────────────────┘                   └───────────────────────────┘
```

---

## 1. Deploying the Backend Alone on Netlify

The backend is built with Express + TypeScript. We configured `serverless-http` and a dedicated `server/netlify.toml` so it runs natively as an AWS Lambda serverless function on Netlify.

### Option A: Using the Netlify Web Dashboard (Git)

1. Go to your [Netlify Dashboard](https://app.netlify.com/) and click **Add new site** > **Import an existing project**.
2. Connect your Git repository (GitHub / GitLab).
3. In the **Site configuration**, set:
   * **Site name**: e.g., `rbx-rewards-backend` (produces `https://rbx-rewards-backend.netlify.app`)
   * **Base directory**: `server`
   * **Build command**: `npm run build`
   * **Publish directory**: `public`
   * **Functions directory**: `netlify/functions`
4. Under **Environment variables**, click **Add a variable** and configure:
   * `NODE_ENV`: `production`
   * `JWT_SECRET`: *(A random secure 32+ character string used to sign admin session tokens)*
   * `ADMIN_EMAIL`: `admin@rbxrewards.com` *(The authorized admin email)*
   * `SUPABASE_URL`: `https://<your-project>.supabase.co`
   * `SUPABASE_ANON_KEY`: `your_supabase_anon_key`
   *(Note: Admins authenticate securely via Supabase Auth. No passwords or hashes are stored in the project or in Netlify environment variables).*
   * `UPSTASH_REDIS_REST_URL`: *(Optional, your Upstash Redis REST URL)*
   * `UPSTASH_REDIS_REST_TOKEN`: *(Optional, your Upstash Redis REST Token)*
5. Click **Deploy site**.

### Option B: Using the Netlify CLI

If you have `netlify-cli` installed (`npm i -g netlify-cli`):

```bash
# 1. Navigate to the server folder
cd server

# 2. Build the TypeScript bundle
npm run build

# 3. Log in and deploy
netlify login
netlify init     # Select "Create & configure a new site"
netlify deploy --prod
```

### Backend Verification:
Once deployed, verify your backend URLs:
* **Health Check**: `https://<your-backend-site>.netlify.app/health`  
  *(Returns `{"status":"ok", "timestamp":"..."}`)*
* **Public App Config API**: `https://<your-backend-site>.netlify.app/api/v1/public/app-config`  
  *(Returns tokenomics, reward catalog, and game limits)*

---

## 2. Deploying the Frontend Alone on Netlify

The frontend is pure HTML5, CSS3, Vanilla JS, and includes the responsive Admin Single Page Application.

### Option A: Using the Netlify Web Dashboard (Git)

1. Go to your [Netlify Dashboard](https://app.netlify.com/) and click **Add new site** > **Import an existing project**.
2. Select the **same** Git repository.
3. In the **Site configuration**, set:
   * **Site name**: e.g., `rbx-rewards-web` (produces `https://rbx-rewards-web.netlify.app`)
   * **Base directory**: `website`
   * **Build command**: *(Leave empty)*
   * **Publish directory**: `.` *(or leave blank / `website`)*
4. Click **Deploy site**.

### Option B: Using the Netlify CLI

```bash
# 1. Navigate to the website folder
cd website

# 2. Deploy directly
netlify deploy --prod
```

---

## 3. Connecting Frontend to Backend

You have two simple ways to connect the standalone frontend to the backend:

### Method 1: Netlify Proxy (Recommended — Zero CORS Issues)
Open `website/netlify.toml` and add this redirect rule at the bottom, replacing `<your-backend-site>` with your real backend Netlify domain:

```toml
[[redirects]]
  from = "/api/*"
  to = "https://<your-backend-site>.netlify.app/api/:splat"
  status = 200
  force = true
```

With this rule in place, every request to `/api/v1/...` made by the website is automatically and transparently forwarded to your backend with zero CORS issues!

### Method 2: Direct API Base URL
In `website/js/config.js`, set your backend URL directly:

```javascript
  apiBaseUrl: "https://<your-backend-site>.netlify.app",
```
*(The backend is already configured with CORS enabled for all origins).*

---

## Summary of Prepared Files

| File | Role |
| :--- | :--- |
| `website/netlify.toml` | Frontend caching headers, security policies, and `/admin/*` SPA fallback |
| `website/_redirects` | Netlify SPA rewrite rules |
| `website/js/config.js` | Configurable `apiBaseUrl` |
| `website/admin/js/api-client.js` | Admin API client supporting custom backend URLs |
| `website/js/dynamic-loader.js` | Public API loader supporting custom backend URLs |
| `server/netlify.toml` | Backend serverless configuration and Lambda routing |
| `server/netlify/functions/api.ts` | Serverless Function handler for Netlify |
| `server/src/lambda.ts` | Pre-compiled Express Lambda wrapper using `serverless-http` |
| `server/public/index.html` | Fallback root for backend site |
