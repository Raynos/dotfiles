# Vercel notes for agents

## REST API token

 - Some things have no CLI flag, such as renaming a project or changing
   deployment protection. Use the REST API at `https://api.vercel.com` for
   those.
 - The token is in `~/.config/vercel/api-token`: mode 600, long-lived, no
   expiry, created 2026-11-10, scope `raynos-projects`. Read it from the file
   and never print it.
 - The file is per machine and not in this repo. If it is missing, ask Jake.
 - Don't use the CLI's own token in
   `~/Library/Application Support/com.vercel.cli/auth.json` for REST calls.
   Since CLI 59.x it expires after 8 hours, and only the CLI renews it, on its
   next command.
 - If the CLI says the login expired, run `vercel whoami` before asking Jake to
   `vercel login`.
 - Install the CLI with `pnpm add -g vercel`, not npm (see
   `bin/node-global-doctor`).

## Name the project before the first deploy

 - `vercel deploy --prod --yes` run from a build-output directory names the
   Vercel project after that directory. One game shipped on
   `dist-three-rho-86.vercel.app` because its project was called `dist`.
 - Deploy from the repo root, or pass an explicit name.
 - Renaming afterwards does not move the domain. Rename with
   `PATCH /v9/projects/<id>`, then attach `<name>.vercel.app` with
   `POST /v10/projects/<name>/domains`. Without the second call the new URL
   returns 404 and the old one keeps serving.
