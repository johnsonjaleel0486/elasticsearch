#!/usr/bin/env bash
# Create app-logs index with explicit shards/replicas/mapping, bulk load sample docs
set -euo pipefail
ES=localhost:9200
curl -s -X PUT $ES/app-logs -H 'Content-Type: application/json' -d '{
  "settings": { "number_of_shards": 3, "number_of_replicas": 1 },
  "mappings": { "properties": {
    "@timestamp": { "type": "date" },
    "host":       { "type": "keyword" },
    "level":      { "type": "keyword" },
    "message":    { "type": "text" },
    "latency_ms": { "type": "integer" }
  }}}'; echo
curl -s -X POST "$ES/_bulk?refresh" -H 'Content-Type: application/x-ndjson' --data-binary $'{"index":{"_index":"app-logs"}}
{"@timestamp":"2026-11-10T20:00:00Z","host":"web01","level":"ERROR","message":"db timeout","latency_ms":5021}
{"index":{"_index":"app-logs"}}
{"@timestamp":"2026-11-10T20:01:00Z","host":"web02","level":"INFO","message":"login ok","latency_ms":87}
'; echo
curl -s "$ES/_cat/shards/app-logs?v"
