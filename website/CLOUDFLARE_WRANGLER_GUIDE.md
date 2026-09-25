# Deploying Project Vanguard to Cloudflare Pages via Wrangler

This guide provides step-by-step instructions for deploying and maintaining the Project Vanguard website on **Cloudflare Pages** using the official **Wrangler CLI**.

---

## 🛠️ Prerequisites

1. **Node.js 18+ and npm installed** (checked on your system: Node v24.19.0, npm 11.17.0).
2. A free [Cloudflare Account](https://dash.cloudflare.com/sign-up).
3. The Project Vanguard repository cloned locally.

---

## 🚀 Quick Deployment (3 Steps via Wrangler)

Navigate to the `website/` directory in your terminal:

```bash
cd website
```

### 1. Authenticate with Cloudflare
If you haven't logged in with Wrangler yet, run:
```bash
npx wrangler login
```
*A browser window will open asking you to authorize Wrangler with your Cloudflare account. Click **Allow**.*

### 2. Compile the Static Production Build
Compile the optimized HTML, Tailwind CSS, and bundled JavaScript assets into the `dist/` directory:
```bash
npm run build
```
*(This takes ~2-3 seconds and generates the production bundle in `website/dist/`).*

### 3. Deploy to Cloudflare Pages
Deploy the compiled `dist/` directory directly to Cloudflare Pages:
```bash
npx wrangler pages deploy dist --project-name=project-vanguard
```
*On your first run, Wrangler will ask if you want to create a new project named `project-vanguard`. Press **Enter** to confirm.*

**Wrangler Output:**
```text
✨ Success! Uploaded 31 files (2.4 sec)
✨ Deployment complete! Take a peek over at https://project-vanguard.pages.dev
```

Your website is now live globally across Cloudflare's edge network!

---

## 🌐 Setting Up a Custom Domain (Optional)

To link your own domain (e.g. `vanguard.yourdomain.com` or `projectvanguard.com`):

### Via Wrangler CLI:
```bash
npx wrangler pages domain set project-vanguard vanguard.yourdomain.com
```

### Via Cloudflare Dashboard:
1. Navigate to **Cloudflare Dashboard** &rarr; **Workers & Pages** &rarr; **project-vanguard**.
2. Go to the **Custom Domains** tab.
3. Click **Set up a domain**, enter your domain name, and follow the automatic DNS CNAME verification.

---

## 🤖 Continuous Deployment via GitHub Actions (Automated CI/CD)

If you prefer every `git push origin main` to automatically deploy to Cloudflare Pages via Wrangler, create `.github/workflows/deploy-pages.yml`:

```yaml
name: Deploy Website to Cloudflare Pages

on:
  push:
    branches: [ main ]
    paths:
      - 'website/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    name: Build & Deploy
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Install Dependencies
        run: |
          cd website
          npm ci

      - name: Build Static Site
        run: |
          cd website
          npm run build

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy website/dist --project-name=project-vanguard
```

### Required GitHub Secrets:
In your GitHub repo &rarr; **Settings** &rarr; **Secrets and variables** &rarr; **Actions**:
- `CLOUDFLARE_API_TOKEN`: Create a token with **Cloudflare Pages: Edit** permissions at [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens).
- `CLOUDFLARE_ACCOUNT_ID`: Found in your Cloudflare dashboard sidebar under **Overview** &rarr; **Account ID**.

---

## ⚙️ Configuration Files Explained

- **[`website/wrangler.toml`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/website/wrangler.toml)**: Defines the Cloudflare Pages project configuration, build directory (`dist`), and production environment variables.
- **[`website/public/_headers`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/website/public/_headers)**: Automatically copied to `dist/_headers` by Vite during `npm run build`. Enforces strict security headers (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`) and long-term asset caching on Cloudflare's edge.
