# VidhAI Portfolio

An interactive case study for VidhAI, an AI-powered agriculture platform. Built with Next.js, React, Tailwind CSS, and Framer Motion.

Live website: https://VISHNUVS-1315.github.io/vidhai-portfolio/

## Local development

Requires Node.js 22 or newer.

```sh
npm ci
npm run dev
```

Open http://localhost:3000.

## Production build

```sh
npm run build
```

The build checks the screenshot manifest and exports the static website to `out/`. Serve that folder with a static web server. This static export does not use `next start`.

## GitHub Pages

Pushing to `main` runs `.github/workflows/deploy.yml`, which builds and deploys the website. The repository's Pages source must be **GitHub Actions**.

The workflow sets `NEXT_PUBLIC_BASE_PATH` and `NEXT_PUBLIC_SITE_URL` so images, scripts, and sharing metadata use the deployed address. Local development uses the root path. Update these values if the repository is renamed or a custom domain is added.

The portfolio demonstrations run in the browser. This website does not host the mobile app's AI gateway or require API keys.
