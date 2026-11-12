#!/usr/bin/env bash
# Least-privilege roles and users, then prove each user can only do its job.
set -euo pipefail
source "$(dirname "$0")/common.sh"

step "Role: logs_reader (search app-logs* only)"
es PUT /_security/role/logs_reader '{
  "indices": [{ "names": ["app-logs*"], "privileges": ["read", "view_index_metadata"] }]
}'

step "Role: logs_writer (add documents to app-logs* only, no reading)"
es PUT /_security/role/logs_writer '{
  "indices": [{ "names": ["app-logs*"], "privileges": ["create_doc", "create_index", "view_index_metadata"] }]
}'

step "Users: analyst (reader) and ingest_svc (writer)"
es PUT /_security/user/analyst "{\"password\":\"${ANALYST_PASSWORD}\",\"roles\":[\"logs_reader\"],\"full_name\":\"Lab Analyst\"}"
es PUT /_security/user/ingest_svc "{\"password\":\"${INGEST_PASSWORD}\",\"roles\":[\"logs_writer\"],\"full_name\":\"Ingest service account\"}"

step "Index app-logs with explicit mapping (as elastic)"
if [[ "$(code_as elastic "$ELASTIC_PASSWORD" HEAD /app-logs)" != "200" ]]; then
  es PUT /app-logs '{
    "settings": { "number_of_shards": 3, "number_of_replicas": 1 },
    "mappings": { "properties": {
      "@timestamp": { "type": "date" }, "host": { "type": "keyword" },
      "level": { "type": "keyword" }, "message": { "type": "text" },
      "latency_ms": { "type": "integer" } } } }'
fi

step "Load data AS ingest_svc (the service account, not the superuser)"
curl -s --cacert ca.crt -u "ingest_svc:${INGEST_PASSWORD}" -X POST "$ES_URL/_bulk?refresh" \
  -H 'Content-Type: application/x-ndjson' --data-binary $'{"index":{"_index":"app-logs","_id":"log-0001"}}
{"@timestamp":"2026-11-11T20:00:00Z","host":"web01","level":"ERROR","message":"db timeout","latency_ms":5021}
{"index":{"_index":"app-logs","_id":"log-0002"}}
{"@timestamp":"2026-11-11T20:01:00Z","host":"web02","level":"INFO","message":"login ok","latency_ms":87}
{"index":{"_index":"app-logs","_id":"log-0003"}}
{"@timestamp":"2026-11-11T20:02:00Z","host":"web01","level":"WARN","message":"slow query","latency_ms":1800}
' | grep -o '"errors":[a-z]*' || true

step "Permission checks (expected vs actual HTTP code)"
check() { local want=$1 desc=$2; shift 2; local got; got=$(code_as "$@")
  printf "%-55s expected %s  got %s  %s\n" "$desc" "$want" "$got" "$([[ $got == "$want" ]] && echo OK || echo CHECK)"; }
check 200 "analyst searches app-logs"            analyst "$ANALYST_PASSWORD" GET /app-logs/_search
check 403 "analyst tries to write to app-logs"   analyst "$ANALYST_PASSWORD" POST /app-logs/_doc '{"level":"INFO"}'
check 403 "analyst tries to delete app-logs"     analyst "$ANALYST_PASSWORD" DELETE /app-logs
check 403 "analyst reads the .security index"    analyst "$ANALYST_PASSWORD" GET /.security/_search
check 403 "ingest_svc tries to search app-logs"  ingest_svc "$INGEST_PASSWORD" GET /app-logs/_search
check 401 "wrong password"                       analyst wrongpassword GET /app-logs/_search
