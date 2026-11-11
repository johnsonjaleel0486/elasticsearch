#!/usr/bin/env bash
# Drill 1: lose a node -> cluster goes YELLOW -> recover to GREEN
# Drill 2: proper rolling restart (same process as AMI/patch rollouts)
set -euo pipefail
cd "$(dirname "$0")"
ES=localhost:9200
echo "== Drill 1: stop es02 =="
docker compose stop es02; sleep 20
curl -s "$ES/_cluster/health?pretty"
curl -s "$ES/_cluster/allocation/explain?pretty" | head -40 || true
docker compose start es02
curl -s "$ES/_cluster/health?wait_for_status=green&timeout=180s&pretty"

echo "== Drill 2: rolling restart of es03 =="
curl -s -X PUT $ES/_cluster/settings -H 'Content-Type: application/json' \
  -d '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}'; echo
curl -s -X POST $ES/_flush; echo
docker compose restart es03
until curl -s "$ES/_cat/nodes?h=name" | grep -q es03; do sleep 5; done
curl -s -X PUT $ES/_cluster/settings -H 'Content-Type: application/json' \
  -d '{"persistent":{"cluster.routing.allocation.enable":null}}'; echo
curl -s "$ES/_cluster/health?wait_for_status=green&timeout=180s&pretty"
