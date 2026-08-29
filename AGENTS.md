# AGENTS.md

Guidance for coding agents working in this repository. `CLAUDE.md` is a symlink
to this file, so any agent that looks for either name reads the same instructions.

## What this repository is

Deployment configuration for one self-hosted n8n instance — no application code,
no build, no tests, no linters. Everything here is Docker Compose, two shell
scripts, a cloudflared config template and CI. "Working on this repo" means
changing how the stack is deployed.

## Commands

```bash
./start.sh              # render tunnel config, docker compose pull, up -d
./stop.sh               # docker compose stop (volumes untouched) + remove generated config.yml
docker compose ps       # status
docker compose logs -f n8n
```

Both scripts require `.env` and `cloudflared/credentials.json` present, and both
are what CI runs on the production host — they are not local-only helpers.

Trigger a deploy without a commit:

```bash
gh workflow run ci.yml -R <owner>/<repo>          # deploy current master
gh workflow run auto-update.yml -R <owner>/<repo> # same pipeline, "update" label
gh run list -R <owner>/<repo> -L 5
```

## Pushing to master deploys to production

There is no staging. `.github/workflows/ci.yml` triggers on push to `master`/`main`
and runs on a **self-hosted runner that is the production host**: it writes `.env`
and `cloudflared/credentials.json` from the `ENV_FILE` and `CREDENTIALS_JSON`
repository secrets, dumps the database, then runs `./stop.sh` and `./start.sh`.

Two consequences worth internalising before pushing anything:

- **A deploy is also an upgrade.** `start.sh` runs `docker compose pull` and the
  n8n image is `n8nio/n8n:latest`, so any push can jump n8n several versions and
  run irreversible database migrations. That is why the pipeline dumps the
  database first (`~/backups/n8n`, 8 most recent kept).
- **Every push restarts the stack**, including pushes that only touch a README.

`auto-update.yml` reuses the same pipeline via `workflow_call` on a Saturday cron
purely to pick up new n8n releases. Keep deploy logic in `ci.yml` only — the
schedule file must stay a thin caller.

## How the pieces fit

**The tunnel identifies itself by UUID, taken from the credentials.** `start.sh`
reads `TunnelID` out of `cloudflared/credentials.json` with `sed` (no `jq`/`python`
dependency on the host) and passes it to `envsubst` as `TUNNEL_ID`. So
`config.yml.template` never contains a real tunnel id — the rendered config always
points at the tunnel whose keys are mounted beside it, and the two cannot drift
apart. `cloudflared/config.yml` is generated, gitignored, and deleted by `stop.sh`.

**Nothing is published on the host.** Only n8n's own port is mapped; postgres and
redis use `expose`. The production host runs many unrelated stacks, so publishing
a port there collides with someone else's service and aborts the whole deploy.

**`N8N_PROXY_HOPS=2`** because there are two proxies in front of n8n: the
Cloudflare edge, then the cloudflared container. Lower it and n8n trusts the wrong
entry in `X-Forwarded-For`.

**The compose project name comes from the checkout directory name**, and its
volumes are prefixed with it (`<project>_n8n_data`). Renaming the repository or
moving the runner's working directory silently creates a *new, empty* set of
volumes while the old data sits untouched under the previous prefix — the stack
comes up looking like a fresh install. If data ever "disappears" after an
infrastructure change, check `docker volume ls` before anything else.

## Configuration

`.env` holds every runtime variable; `.env.example` documents them. The whole file
is stored as the `ENV_FILE` secret for CI, so **changing a variable means editing
both** — the repo copy and the secret (`gh secret set ENV_FILE < .env`).

Per the Cursor rule in `.cursor/rules/project.mdc`: do not create or edit `.env`.

`.mcp.json` configures the n8n MCP server and **is tracked**, because it carries
no secret: Claude Code expands `${VAR}` in a server's `url` and `headers`, so the
file holds `${N8N_MCP_URL}` and `${N8N_MCP_TOKEN}` and the real values live in the
shell environment (exported from `~/.profile`). Miss a variable and the config
still loads — you get a missing-variable warning and the literal `${VAR}` reaches
the server, which then fails as an invalid URL or an HTTP 401.

Deliberately untracked: `flows/` (workflow exports belong in n8n and in the
database dumps, a copy in git only goes stale). `.gitattributes` routes binaries
through Git LFS; SVG is excluded on purpose since it diffs as text.

## Known-wrong things, so you don't rediscover them

- **Redis runs but nothing connects to it.** Queue mode is not configured — there
  is no worker service and no `EXECUTIONS_MODE=queue`/`QUEUE_BULL_REDIS_*`.
  Executions run in regular mode inside the main container. Either wire queue mode
  up properly or drop Redis and its volume; don't assume it does anything today.
- **`N8N_BASIC_AUTH_*` are dead variables.** Basic auth was removed in n8n 1.x.
  They are still in `.env` and compose but almost certainly ignored; access is
  governed by n8n's own user management.
- **`n8nio/n8n:latest` is not reproducible.** Pinning it is the single change that
  would make deploys predictable, at the cost of manual upgrades.
