#!/usr/bin/env bash
# Phase 2: secure 3-node cluster (TLS + passwords) + Kibana.
set -euo pipefail
cd "$(dirname "$0")"

# Phase 1 uses the same ports (9200/5601): stop it first (its data volumes are kept)
if docker ps --format '{{.Names}}' | grep -q '^phase1-docker-cluster-'; then
  echo "Stopping Phase 1 cluster (data kept)..."
  (cd ../phase1-docker-cluster && docker compose down)
fi

# Create .env with random passwords the first time
if [[ ! -f .env ]]; then
  cp .env.example .env
  for v in ELASTIC_PASSWORD KIBANA_PASSWORD ANALYST_PASSWORD INGEST_PASSWORD; do
    pw=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20)
    sed -i.bak "s/^$v=.*/$v=$pw/" .env
  done
  rm -f .env.bak
  echo "Created .env with random passwords (git-ignored). Your elastic password is in there."
fi

if [[ "$(uname)" == "Linux" ]]; then sudo sysctl -w vm.max_map_count=262144; fi

docker compose up -d

echo "Waiting for certificates..."
until docker compose cp es01:/usr/share/elasticsearch/config/certs/ca/ca.crt ./ca.crt >/dev/null 2>&1; do sleep 5; done

source ./common.sh
echo "Waiting for Elasticsearch over HTTPS (first run can take a few minutes)..."
for i in $(seq 1 60); do
  if curl -s --cacert ca.crt -u "elastic:${ELASTIC_PASSWORD}" "$ES_URL" >/dev/null 2>&1; then break; fi
  if [[ $i -eq 60 ]]; then echo "Timed out. Diagnostics:"; docker compose ps; docker compose logs --tail=40 setup es01; exit 1; fi
  sleep 10; echo "  still waiting... ($((i*10))s)"
done

es GET '/_cluster/health?wait_for_status=green&timeout=120s&pretty'
es GET '/_cat/nodes?v'
step "Proof that security is on"
echo -n "No password  -> HTTP "; curl -s -o /dev/null -w "%{http_code}\n" --cacert ca.crt "$ES_URL"
echo -n "Plain HTTP   -> "; curl -s -m 5 http://localhost:9200 >/dev/null 2>&1 && echo "answered (bad)" || echo "refused (good, HTTPS only)"
echo
echo "Kibana: http://localhost:5601  (user: elastic, password: ELASTIC_PASSWORD in .env)"
