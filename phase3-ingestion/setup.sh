#!/usr/bin/env bash
# Phase 3a: Filebeat -> Logstash -> Elasticsearch, into the secure Phase 2 cluster.
set -euo pipefail
cd "$(dirname "$0")"
P2=../phase2-security-ilm-snapshots

if ! docker ps --format '{{.Names}}' | grep -q '^phase2-security-ilm-snapshots-es01-1$'; then
  echo "The Phase 2 cluster isn't running. Start it first:"
  echo "  cd $P2 && docker compose start"
  exit 1
fi
[[ -f $P2/ca.crt ]] || { echo "Missing $P2/ca.crt. Run $P2/setup.sh first."; exit 1; }
cp "$P2/ca.crt" ./ca.crt && chmod 644 ./ca.crt

if [[ ! -f .env ]]; then
  gen() { openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20; }
  {
    echo "STACK_VERSION=$(grep '^STACK_VERSION=' $P2/.env | cut -d= -f2)"
    echo "LOGSTASH_ES_PASSWORD=$(gen)"
    echo "NIFI_ES_PASSWORD=$(gen)"
    echo "NIFI_ADMIN_PASSWORD=$(gen)"
    echo "NIFI_TRUSTSTORE_PASSWORD=$(gen)"
  } > .env
  echo "Created .env with random passwords (git-ignored)."
fi
source ./common.sh

step "Least-privilege account for Logstash: write to logs-web-* data streams only"
es PUT /_security/role/logstash_writer '{
  "cluster": ["monitor"],
  "indices": [{ "names": ["logs-web-*"], "privileges": ["create_doc", "auto_configure"] }]
}'
es PUT /_security/user/logstash_svc "{\"password\":\"${LOGSTASH_ES_PASSWORD}\",\"roles\":[\"logstash_writer\"],\"full_name\":\"Logstash service account\"}"

step "Start loggen, Filebeat and Logstash"
docker compose up -d loggen filebeat logstash

echo "Waiting for the Logstash pipeline to start (first run pulls images)..."
for i in $(seq 1 60); do
  if docker compose logs logstash 2>/dev/null | grep -q 'Pipelines running'; then break; fi
  if [[ $i -eq 60 ]]; then echo "Logstash didn't start. Last log lines:"; docker compose logs --tail=40 logstash; exit 1; fi
  sleep 5
done
echo "Pipeline running. Letting ~30s of logs flow..."; sleep 30
./verify.sh
