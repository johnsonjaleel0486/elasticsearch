#!/usr/bin/env bash
# Phase 3b: prepare everything NiFi needs, then start NiFi. The flow itself is built in the UI (see README).
#   ./nifi.sh        set up account, index, truststore, sample files; start NiFi
#   ./nifi.sh drop   copy the sample JSON files into the folder NiFi watches
#   ./nifi.sh check  show what landed in Elasticsearch
set -euo pipefail
source "$(dirname "$0")/common.sh"
mkdir -p nifi-lab/samples nifi-lab/input

if [[ "${1:-}" == "drop" ]]; then
  cp nifi-lab/samples/*.json nifi-lab/input/ && ls nifi-lab/input; exit 0
fi
if [[ "${1:-}" == "check" ]]; then
  es GET '/_cat/count/nifi-orders?v'
  es POST '/nifi-orders/_search?filter_path=hits.hits._source&pretty' '{"size":10,"sort":[{"order_id":"asc"}]}'
  exit 0
fi

step "Least-privilege account for NiFi: write to nifi-orders only"
es PUT /_security/role/nifi_writer '{
  "cluster": ["monitor"],
  "indices": [{ "names": ["nifi-orders*"], "privileges": ["index", "create_index", "view_index_metadata"] }]
}'
es PUT /_security/user/nifi_svc "{\"password\":\"${NIFI_ES_PASSWORD}\",\"roles\":[\"nifi_writer\"],\"full_name\":\"NiFi service account\"}"

step "Target index with a strict mapping (bad records must fail loudly, not pollute the index)"
if [[ "$(curl -s -o /dev/null -w '%{http_code}' -m 10 --cacert ca.crt -u "elastic:${ELASTIC_PASSWORD}" -I "$ES_URL/nifi-orders")" != "200" ]]; then
  es PUT /nifi-orders '{
    "settings": { "number_of_shards": 1, "number_of_replicas": 1 },
    "mappings": { "dynamic": "strict", "properties": {
      "order_id":    { "type": "keyword" },
      "customer":    { "type": "keyword" },
      "amount":      { "type": "float" },
      "created_at":  { "type": "date" },
      "pipeline":    { "type": "keyword" },
      "source_file": { "type": "keyword" } } } }'
fi

step "Sample files (one bad record on purpose)"
cat > nifi-lab/samples/orders-001.json <<'J'
[
  {"order_id":"A-1001","customer":"alice","amount":42.50,"created_at":"2026-11-12T14:00:00Z"},
  {"order_id":"A-1002","customer":"bob","amount":19.99,"created_at":"2026-11-12T14:05:00Z"},
  {"order_id":"A-1003","customer":"carol","amount":120.00,"created_at":"2026-11-12T14:10:00Z"}
]
J
cat > nifi-lab/samples/orders-002.json <<'J'
[
  {"order_id":"A-1004","customer":"alice","amount":7.25,"created_at":"2026-11-12T15:00:00Z"},
  {"order_id":"A-1005","customer":"bob","amount":"not-a-number","created_at":"2026-11-12T15:05:00Z"}
]
J
ls nifi-lab/samples

step "Start NiFi (first run pulls ~1.5GB and takes 1-3 minutes to boot)"
docker compose --profile nifi up -d nifi
for i in $(seq 1 60); do
  if docker compose logs nifi 2>/dev/null | grep -qE 'Started Application|NiFi has started'; then break; fi
  sleep 5
done
step "Truststore so NiFi trusts the cluster's CA (built with NiFi's own Java, so NiFi can read it)"
cp ca.crt nifi-lab/ca.crt
docker compose exec -T -e TSPW="${NIFI_TRUSTSTORE_PASSWORD}" nifi bash -c \
  'rm -f /opt/nifi/lab/truststore.p12 && "$JAVA_HOME/bin/keytool" -importcert -noprompt -alias lab-ca \
   -file /opt/nifi/lab/ca.crt -keystore /opt/nifi/lab/truststore.p12 -storetype PKCS12 -storepass "$TSPW" \
   && "$JAVA_HOME/bin/keytool" -list -keystore /opt/nifi/lab/truststore.p12 -storepass "$TSPW" | grep trustedCertEntry'

echo
echo "NiFi UI:    https://localhost:8443/nifi   (accept the browser's self-signed cert warning)"
echo "Login:      admin / ${NIFI_ADMIN_PASSWORD}"
echo "For the Elasticsearch client service in the flow:"
echo "  HTTP Hosts:           https://es01:9200"
echo "  Username / Password:  nifi_svc / ${NIFI_ES_PASSWORD}"
echo "  Truststore:           /opt/nifi/lab/truststore.p12  (PKCS12, password ${NIFI_TRUSTSTORE_PASSWORD})"
echo "Next: build the flow (README, Phase 3b), then ./nifi.sh drop"
