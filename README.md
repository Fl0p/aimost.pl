# n8n + Cloudflare Tunnel

Self-hosted n8n exposed through a Cloudflare Tunnel — no ports forwarded on the router.
The public hostname is configured via `N8N_HOST` in `.env`.

## Architecture

- **n8n**: Workflow automation platform (port 5678)
- **PostgreSQL 15**: n8n database
- **Cloudflare Tunnel**: Traffic proxying from `$N8N_HOST` to n8n
- **Docker Compose**: Container orchestration
- **Redis**: running, but ⚠️ **not actually used** — see below

### ⚠️ Queue mode is NOT set up

An earlier version of this README claimed Redis was the queue backend and that a
separate n8n worker executed jobs from it. Neither is true:

- there is no `n8n-worker` service in `docker-compose.yml`;
- the `n8n` service sets neither `EXECUTIONS_MODE=queue` nor any `QUEUE_BULL_REDIS_*`.

So executions run in **regular mode**, inside the main n8n container. Redis starts,
holds an AOF volume and consumes resources without anything connecting to it.

Pick a direction before relying on either: add queue mode plus a worker service,
or drop Redis entirely and delete the `redis_data` volume.

## Requirements

1. Docker and Docker Compose
2. `.env` file with environment variables
3. `cloudflared/credentials.json` file with Cloudflare credentials

## Setup

### 1. Create `.env` file:
```bash
cp .env.example .env
# then fill in real values
```
See [.env.example](.env.example) for the full list of variables and what they do.
`.env` is gitignored; in CI the whole file is stored as the `ENV_FILE` repository
secret and written out by the workflow before `./start.sh` runs.

⚠️ `N8N_BASIC_AUTH_*` are leftovers: basic auth was removed in n8n 1.x, so these
are most likely ignored and access is governed by n8n's built-in user management.
Verify how the instance is actually protected before assuming it is closed.

### 2. Add Cloudflare credentials:
```bash
# Copy from your Cloudflare dashboard
cp ~/.cloudflared/credentials.json cloudflared/credentials.json
```

## Usage

### Start:
```bash
./start.sh
```

### Stop:
```bash
./stop.sh
```

### Check status:
```bash
docker compose ps
```

## Data Management

### Backup n8n data:
```bash
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n_backup.tar.gz -C /data .
```

### Restore n8n data:
```bash
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n_backup.tar.gz -C /data
```

### Migrate from local folder (if upgrading):
```bash
# If you have existing n8n_data/ folder, run this once:
docker run --rm -v n8n_data:/dest -v $(pwd)/n8n_data:/src alpine cp -a /src/. /dest/
```

## Access

After startup, n8n is available at `https://$N8N_HOST` (the value set in `.env`).

## Project Structure

```
project_root/
├── cloudflared/
│   ├── config.yml          # Cloudflare Tunnel configuration (not in git)
│   ├── config.yml.template # Cloudflare Tunnel configuration template
│   └── credentials.json    # Credentials (not in git)
├── docker-compose.yml     # Docker Compose configuration
├── start.sh              # Start script
├── stop.sh               # Stop script
└── .env                  # Environment variables (not in git)

Docker volumes:
└── n8n_data              # n8n persistent data (Docker named volume)
└── postgres_data         # Postgres persistent data
└── redis_data            # Redis persistent data (AOF)
```

## Important

- n8n data is saved in Docker named volume `n8n_data` (persistent across deployments)
- Make sure `.env` and `credentials.json` files are not committed to git
- n8n is configured with basic authentication and HTTPS protocol
