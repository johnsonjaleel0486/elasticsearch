#!/usr/bin/env bash
# Check what Logstash indexed: data stream, counts, levels, status codes, parse failures, a sample doc.
set -euo pipefail
source "$(dirname "$0")/common.sh"

step "Data stream (backing index, template, ILM policy)"
es GET '/_data_stream/logs-web-lab?filter_path=data_streams.name,data_streams.indices.index_name,data_streams.template,data_streams.ilm_policy,data_streams.status&pretty'

step "Document count"
es GET '/_cat/count/logs-web-lab?v'

step "Events by log level and HTTP status"
es POST '/logs-web-lab/_search?size=0&filter_path=aggregations.*.buckets.key,aggregations.*.buckets.doc_count&pretty' '{
  "aggs": {
    "by_level":  { "terms": { "field": "log.level" } },
    "by_status": { "terms": { "field": "http.response.status_code" } }
  } }'

step "Slow requests (>1000ms) and lines that failed parsing"
echo -n "slow_request:      "; es GET '/logs-web-lab/_count?q=tags:slow_request&filter_path=count'
echo -n "_grokparsefailure: "; es GET '/logs-web-lab/_count?q=tags:_grokparsefailure&filter_path=count'

step "Newest parsed document"
es POST '/logs-web-lab/_search?filter_path=hits.hits._source&pretty' '{
  "size": 1, "sort": [{ "@timestamp": "desc" }],
  "query": { "bool": { "must_not": { "term": { "tags": "_grokparsefailure" } } } },
  "_source": ["@timestamp","web_host","http","url","user","latency_ms","log.level","tags"] }'
