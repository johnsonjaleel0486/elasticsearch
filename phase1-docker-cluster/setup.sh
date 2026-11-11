#!/usr/bin/env bash
# Phase 1: bring up a 3-node Elasticsearch cluster + Kibana and verify health
# Works on Linux and macOS (Docker Desktop).
set -euo pipefail
cd "$(dirname "$0")"

# Elasticsearch needs vm.max_map_count >= 262144.
# Linux: set it on the host. macOS: Docker Desktop's VM already sets it.
if [[ "$(uname)" == "Linux" ]]; then
  sudo sysctl -w vm.max_map_count=262144
fi

docker compose up -d

echo "Waiting for Elasticsearch on localhost:9200 (first run pulls ~2GB of images, can take a few minutes)..."
for i in $(seq 1 60); do
  if curl -s localhost:9200 >/dev/null 2>&1; then break; fi
  if [[ $i -eq 60 ]]; then
    echo "Elasticsearch did not come up after 10 minutes. Diagnostics:"
    docker compose ps
    docker compose logs --tail=40 es01
    exit 1
  fi
  sleep 10
  echo "  still waiting... ($((i*10))s)"; docker compose ps --format '    {{.Name}}: {{.Status}}' 2>/dev/null || true
done

curl -s 'localhost:9200/_cluster/health?wait_for_status=green&timeout=120s&pretty'
curl -s 'localhost:9200/_cat/nodes?v'
echo "Kibana: http://localhost:5601 (give it ~1 minute to finish starting)"
