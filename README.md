# aimost.pl - n8n + Cloudflare Tunnel

Project for running n8n with access through aimost.pl domain using Cloudflare Tunnel.

## Architecture

- **n8n**: Workflow automation platform (port 5678)
- **Cloudflare Tunnel**: Traffic proxying from aimost.pl to n8n
- **Docker Compose**: Container orchestration
- **Redis**: Queue backend for n8n executions
- **n8n worker**: Executes jobs from the Redis queue

## Requirements

1. Docker and Docker Compose
2. `.env` file with environment variables
3. `cloudflared/credentials.json` file with Cloudflare credentials

## Setup

### 1. Create `.env` file:
```bash
DOMAIN_NAME=example.com
WEBHOOK_URL=https://n8n.example.com
N8N_HOST=n8n.example.com
N8N_PORT=5678
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin@example.com
N8N_BASIC_AUTH_PASSWORD=supersecret

# Database
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=changeme

# n8n
N8N_ENCRYPTION_KEY=please_set_a_secure_random_key

```

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
docker ps --filter "name=n8n" --filter "name=n8n-worker" --filter "name=redis" --filter "name=cloudflared"
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

After startup, n8n will be available at: https://aimost.pl

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
