#!/usr/bin/env bash
# Shared helpers for Phase 2 scripts: load .env, talk to Elasticsearch over HTTPS.
cd "$(dirname "${BASH_SOURCE[0]}")"
set -a; source .env; set +a
ES_URL=https://localhost:9200

# es METHOD /path [json-body]   -> runs as the elastic superuser, prints the response
es() {
  local m=$1 p=$2; shift 2
  if [[ $# -gt 0 ]]; then
    curl -s --cacert ca.crt -u "elastic:${ELASTIC_PASSWORD}" -X "$m" "$ES_URL$p" -H 'Content-Type: application/json' -d "$1"
  else
    curl -s --cacert ca.crt -u "elastic:${ELASTIC_PASSWORD}" -X "$m" "$ES_URL$p"
  fi
  echo
}

# code_as USER PASS METHOD /path [json-body]   -> prints only the HTTP status code
code_as() {
  local u=$1 pw=$2 m=$3 p=$4; shift 4
  if [[ $# -gt 0 ]]; then
    curl -s -o /dev/null -w "%{http_code}" --cacert ca.crt -u "$u:$pw" -X "$m" "$ES_URL$p" -H 'Content-Type: application/json' -d "$1"
  else
    curl -s -o /dev/null -w "%{http_code}" --cacert ca.crt -u "$u:$pw" -X "$m" "$ES_URL$p"
  fi
}

step() { echo; echo "== $* =="; }
