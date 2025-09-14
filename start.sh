#!/bin/bash

set -e

echo "🚀 Starting web + n8n + Cloudflare Tunnel for aimost.pl"

# 1️⃣ Check if .env file exists
if [ ! -f .env ]; then
  echo "❌ .env file not found!"
  exit 1
fi

source .env

# 2️⃣ Generate config.yml from template
if [-z "$DOMAIN_NAME"] || [ -z "$WEB_HOST" ] || [ -z "$N8N_HOST" ]; then
  echo "❌ DOMAIN_NAME, WEB_HOST or N8N_HOST is not set in .env"
  exit 1
fi
echo "🔧 Generating cloudflared config.yml for $WEB_HOST and $N8N_HOST"
DOMAIN_NAME=$DOMAIN_NAME WEB_HOST=$WEB_HOST N8N_HOST=$N8N_HOST envsubst < cloudflared/config.yml.template > cloudflared/config.yml

# 3️⃣ Check if credentials.json exists
if [ ! -f cloudflared/credentials.json ]; then
  echo "❌ cloudflared/credentials.json not found!"
  echo "👉 Copy credentials from ~/.cloudflared/ to cloudflared/credentials.json"
  exit 1
fi

echo "🔍 Checking for updates..."
docker compose pull

# 4️⃣ Start Docker Compose
echo "🐳 Starting Docker Compose..."
docker compose up -d --build

# 5️⃣ Wait a few seconds
sleep 5

echo "🔍 Checking if containers are running..."
CONTAINER_COUNT=$(docker compose ps -q | wc -l)

if [ $CONTAINER_COUNT -eq 0 ]; then
  echo "❌ Containers are not running!"
  exit 0
fi

# 6️⃣ Show container status
echo "📋 Containers status:"
docker compose ps

echo "✅ Project started successfully: $WEB_HOST and $N8N_HOST"
