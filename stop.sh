#!/bin/bash

set -e

echo "🛑 Stopping n8n + Cloudflare Tunnel for aimost.pl"

# 0️⃣ Check if .env file exists
if [ -f .env ]; then
  source .env
  #rm -f .env
else
  echo "❌ .env file not found!"
fi

if [ -f cloudflared/config.yml ]; then
  rm -f cloudflared/config.yml
else
  echo "❌ cloudflared/config.yml file not found!"
fi

echo "🔍 Checking if containers are running..."
CONTAINER_COUNT=$(docker compose ps -q | wc -l)

if [ $CONTAINER_COUNT -eq 0 ]; then
  echo "❌ Containers are not running!"
  exit 0
fi

echo "📋 Found running containers:"
docker compose ps

# 1️⃣ Stop containers without removing volumes
docker compose stop

# 2️⃣ Optionally remove containers (uncomment if you want to delete them completely)
# echo "🗑 Removing containers..."
# docker compose down

# 3️⃣ Show status
echo "📋 Containers status after stop:"
docker compose ps

echo "✅ project stopped!"
