# Deploying to Cloudflare Pages with Wrangler

The site normally deploys through the Cloudflare Pages Git integration (see
[README.md](README.md)). This guide covers deploying by hand, setting up D1 and
secrets, and an optional GitHub Actions deploy.

---

## Prerequisites

1. Node.js 18 or newer, and npm.
2. A [Cloudflare account](https://dash.cloudflare.com/sign-up). The free plan is enough.
3. A local clone of this repository.

---

## Manual deploy

From the `website/` directory:

```bash
cd website
```

### 1. Authenticate with Cloudflare
If you haven't logged in with Wrangler yet, run:
```bash
npx wrangler login
```
This opens a browser window to authorize Wrangler.

### 2. Build
```bash
npm run build
```
The output goes to `website/dist/`.

### 3. Deploy
```bash
npx wrangler pages deploy dist --project-name=project-vanguard
```
On the first run, Wrangler offers to create the `project-vanguard` project.

Expected output:
```text
✨ Success! Uploaded 31 files (2.4 sec)
✨ Deployment complete! Take a peek over at https://project-vanguard.pages.dev
```

## D1 database and secrets

`wrangler.toml` binds the D1 database `vanguard-db` as `DB`. To set up a new
database:

```bash
npx wrangler d1 create vanguard-db          # put the returned id in wrangler.toml
npx wrangler d1 execute vanguard-db --remote --file=./schema.sql
```

Set the secrets for the Pages project instead of committing them:

```bash
npx wrangler pages secret put AUTH_SECRET --project-name=project-vanguard
npx wrangler pages secret put BREVO_API_KEY --project-name=project-vanguard
```

---

## Setting Up a Custom Domain (Optional)

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

## Continuous Deployment via GitHub Actions (Automated CI/CD)

Only needed if you deploy from GitHub Actions instead of the Pages Git integration. This workflow doesn't exist in the repo yet. To add it, create `.github/workflows/deploy-pages.yml`:

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

## Configuration Files Explained

- **[`wrangler.toml`](wrangler.toml)**: project name, build output (`dist`), plain vars and the D1 binding.
- **[`public/_headers`](public/_headers)**: copied to `dist/_headers` by Vite. Sets security headers (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`) and cache rules.
