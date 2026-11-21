# Project Vanguard website

The site at <https://project-vanguard.pages.dev>. It contains:

- **Landing page** (`index.html`, `src/main.js`): missions, downloads (pulled
  from the latest GitHub release), leaderboards, pilot login and rewards.
- **Phone controller** (`controller.html`, `src/controller.js`): the page the
  in-game QR code opens. See
  [`docs/ZERO_COST_INFRASTRUCTURE_AND_CONTROLLER_SPEC.md`](../docs/ZERO_COST_INFRASTRUCTURE_AND_CONTROLLER_SPEC.md).
- **Email verification page** (`verify.html`).
- **API** (`functions/api/`): Cloudflare Pages Functions backed by D1. Covers
  auth, sync, leaderboards, lobbies, presence and rewards.

Built with Vite 6 and Tailwind CSS 3.

## Local development

```sh
cd website
npm install
npm run dev        # Vite dev server
npm run build      # production build into dist/, plus the standalone controller
npm run preview    # serve dist/
```

`npm run build` also runs `scripts/bundle-standalone-controller.js`, which
inlines the controller into a single HTML file. The game serves that copy
itself on port 8080.

To run the API locally against a local D1, copy `.dev.vars.example` to
`.dev.vars` (git-ignored), fill in `AUTH_SECRET`, then:

```sh
npx wrangler d1 execute vanguard-db --local --file=./schema.sql
npx wrangler pages dev dist
```

## Configuration

`wrangler.toml` defines the D1 binding (`DB`) and plain vars. The functions
also read:

| Variable | Used for |
| :--- | :--- |
| `AUTH_SECRET` | Signing login and email tokens. At least 32 random characters, set as a secret (`npx wrangler pages secret put AUTH_SECRET`). Auth requests fail with a server error if it's missing |
| `BREVO_API_KEY` | Sending verification emails |
| `DIAG_TOKEN` | Optional secret (16+ characters) that enables `/api/diag`. Leave unset to keep it off |
| `BREVO_SENDER_EMAIL`, `BREVO_SENDER_NAME` | Email sender |

## Deployment

Cloudflare Pages builds `main` from `bokk3/Vanguard` (`npm run build`, output
`dist`). The `functions/` directory deploys as Pages Functions. For manual
deploys and the D1 setup, see
[`CLOUDFLARE_WRANGLER_GUIDE.md`](CLOUDFLARE_WRANGLER_GUIDE.md).

The GitHub workflow [`.github/workflows/website.yml`](../.github/workflows/website.yml)
builds the site on pushes and pull requests to catch build errors. It doesn't
deploy.

## Layout

```text
website/
├── functions/api/   Pages Functions (auth, pilot, leaderboard, network, diag)
├── public/          Static files copied as-is (_headers, images, audio, video)
├── scripts/         Build helpers
├── src/             main.js, missions.js, controller.js, style.css
├── index.html       Landing page
├── controller.html  Phone controller
├── verify.html      Email verification landing page
├── schema.sql       D1 schema
└── wrangler.toml    Cloudflare config
```
