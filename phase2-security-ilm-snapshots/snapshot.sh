#!/usr/bin/env bash
# Backup + disaster-recovery drill: snapshot app-logs, delete it, restore it, verify.
set -euo pipefail
source "$(dirname "$0")/common.sh"
SNAP="snap-$(date +%Y%m%d-%H%M%S)"

step "Register a shared-filesystem snapshot repository (path.repo is mounted on all 3 nodes)"
es PUT /_snapshot/lab-backups '{"type":"fs","settings":{"location":"/usr/share/elasticsearch/snapshots/lab-backups"}}'
es POST /_snapshot/lab-backups/_verify   # every node must be able to write to it

step "Doc count BEFORE"
es GET "/_cat/count/app-logs?v"

step "Take snapshot $SNAP"
es PUT "/_snapshot/lab-backups/$SNAP?wait_for_completion=true" '{"indices":"app-logs","include_global_state":false}' \
  | grep -o '"state":"[A-Z_]*"' || true

step "DISASTER: delete the app-logs index"
es DELETE /app-logs
echo -n "app-logs now -> HTTP "; code_as elastic "$ELASTIC_PASSWORD" HEAD /app-logs; echo

step "Restore from $SNAP"
es POST "/_snapshot/lab-backups/$SNAP/_restore?wait_for_completion=true" '{"indices":"app-logs"}' >/dev/null
es GET '/_cluster/health/app-logs?wait_for_status=green&timeout=60s&filter_path=status'

step "Doc count AFTER (should match BEFORE)"
es GET "/_cat/count/app-logs?v"

step "Snapshot Lifecycle Management: nightly snapshot at 01:30, keep 7 days (min 3, max 14)"
es PUT /_slm/policy/nightly '{
  "schedule": "0 30 1 * * ?",
  "name": "<nightly-{now/d}>",
  "repository": "lab-backups",
  "config": { "indices": ["*"], "include_global_state": true },
  "retention": { "expire_after": "7d", "min_count": 3, "max_count": 14 } }'
es POST /_slm/policy/nightly/_execute
sleep 5
es GET '/_cat/snapshots/lab-backups?v&h=id,status,indices,duration'
