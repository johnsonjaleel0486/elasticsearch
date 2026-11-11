#!/usr/bin/env bash
# Create app-logs index with explicit shards/replicas/mapping, bulk load sample docs.
# Docs use explicit _ids so re-running overwrites instead of duplicating (idempotent load).
set -euo pipefail
ES=localhost:9200
# Create the index only if it doesn't exist yet (safe to re-run)
curl -s -o /dev/null -w "%{http_code}" -I $ES/app-logs | grep -q 200 || \
curl -s -X PUT $ES/app-logs -H 'Content-Type: application/json' -d '{
  "settings": { "number_of_shards": 3, "number_of_replicas": 1 },
  "mappings": { "properties": {
    "@timestamp": { "type": "date" },
    "host":       { "type": "keyword" },
    "level":      { "type": "keyword" },
    "message":    { "type": "text" },
    "latency_ms": { "type": "integer" }
  }}}'; echo
curl -s -X POST "$ES/_bulk?refresh" -H 'Content-Type: application/x-ndjson' --data-binary $'{"index":{"_index":"app-logs","_id":"log-0001"}}
{"@timestamp":"2026-11-10T20:00:00Z","host":"web01","level":"ERROR","message":"db timeout","latency_ms":5021}
{"index":{"_index":"app-logs","_id":"log-0002"}}
{"@timestamp":"2026-11-10T20:01:00Z","host":"web02","level":"INFO","message":"login ok","latency_ms":87}
'; echo
curl -s "$ES/_cat/shards/app-logs?v"
curl -s "$ES/_cat/count/app-logs?v"
