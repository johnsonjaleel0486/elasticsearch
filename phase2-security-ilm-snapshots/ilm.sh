#!/usr/bin/env bash
# Index Lifecycle Management: rollover + retention, sped up so you can watch it.
#   ./ilm.sh          set it up and trigger a rollover
#   ./ilm.sh status   watch indices move through the phases
set -euo pipefail
source "$(dirname "$0")/common.sh"

show() {
  es GET '/_cat/indices/lab-logs-*?v&s=index&h=index,health,docs.count,pri,rep'
  es GET '/_cat/aliases/lab-logs?v&h=alias,index,is_write_index'
  es GET '/lab-logs-*/_ilm/explain?filter_path=indices.*.phase,indices.*.action,indices.*.age&pretty'
}
if [[ "${1:-}" == "status" ]]; then show; exit 0; fi

step "LAB ONLY: check ILM every 10s instead of every 10m"
es PUT /_cluster/settings '{"persistent":{"indices.lifecycle.poll_interval":"10s"}}'

step "Policy: hot (rollover at 3 docs or 1 day) -> warm after 1m (read-only, force merge) -> delete after 3m"
es PUT /_ilm/policy/lab-logs-policy '{
  "policy": { "phases": {
    "hot":    { "actions": { "rollover": { "max_docs": 3, "max_age": "1d" } } },
    "warm":   { "min_age": "1m", "actions": { "readonly": {}, "forcemerge": { "max_num_segments": 1 } } },
    "delete": { "min_age": "3m", "actions": { "delete": {} } }
  } } }'

step "Index template: every lab-logs-* index gets the policy, settings and mapping"
es PUT /_index_template/lab-logs-template '{
  "index_patterns": ["lab-logs-*"],
  "template": {
    "settings": { "number_of_shards": 1, "number_of_replicas": 1,
                  "index.lifecycle.name": "lab-logs-policy",
                  "index.lifecycle.rollover_alias": "lab-logs" },
    "mappings": { "properties": {
      "@timestamp": { "type": "date" }, "host": { "type": "keyword" },
      "level": { "type": "keyword" }, "message": { "type": "text" } } } } }'

step "Bootstrap the first index; the lab-logs alias points writes at it"
if [[ "$(code_as elastic "$ELASTIC_PASSWORD" HEAD /lab-logs-000001)" != "200" ]]; then
  es PUT /lab-logs-000001 '{"aliases":{"lab-logs":{"is_write_index":true}}}'
fi

step "Write 4 docs through the alias (more than max_docs=3)"
for i in 1 2 3 4; do
  es POST '/lab-logs/_doc' "{\"@timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"host\":\"web0$i\",\"level\":\"INFO\",\"message\":\"event $i\"}" >/dev/null
done
es POST /lab-logs/_refresh >/dev/null

echo "Waiting 30s for ILM to roll over..."; sleep 30
show
echo
echo "Run ./ilm.sh status every minute or so: lab-logs-000001 should go hot -> warm -> deleted (~3-4 min)."
