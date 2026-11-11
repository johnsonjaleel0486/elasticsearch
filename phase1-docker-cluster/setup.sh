#!/usr/bin/env bash
# Phase 1: bring up a 3-node Elasticsearch cluster + Kibana and verify health
set -euo pipefail
cd "$(dirname "$0")"
sudo sysctl -w vm.max_map_count=262144
docker compose up -d
echo "Waiting for cluster..."
until curl -s localhost:9200/_cluster/health >/dev/null; do sleep 5; done
curl -s 'localhost:9200/_cluster/health?wait_for_status=green&timeout=120s&pretty'
curl -s 'localhost:9200/_cat/nodes?v'
