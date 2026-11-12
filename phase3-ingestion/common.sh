#!/usr/bin/env bash
# Shared helpers for Phase 3: reuse the Phase 2 cluster's passwords and CA.
cd "$(dirname "${BASH_SOURCE[0]}")"
P2=../phase2-security-ilm-snapshots
set -a; source "$P2/.env"; [[ -f .env ]] && source .env; set +a
ES_URL=https://localhost:9200
es() {   # es METHOD /path [json-body]   (as elastic)
  local m=$1 p=$2; shift 2
  if [[ $# -gt 0 ]]; then
    curl -s --cacert ca.crt -u "elastic:${ELASTIC_PASSWORD}" -X "$m" "$ES_URL$p" -H 'Content-Type: application/json' -d "$1"
  else
    curl -s --cacert ca.crt -u "elastic:${ELASTIC_PASSWORD}" -X "$m" "$ES_URL$p"
  fi
  echo
}
step() { echo; echo "== $* =="; }
