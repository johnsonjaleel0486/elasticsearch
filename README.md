# Elasticsearch / OpenSearch Platform Lab

Hands-on lab standing up and operating Elasticsearch and OpenSearch clusters: cluster configuration, shards and replicas, mappings, index lifecycle, ingestion pipelines (Logstash, Filebeat, NiFi), snapshot backup/restore, monitoring, Kubernetes (ECK), and offline (air-gapped) installs.

## Phases
| Phase | Folder | Focus | Status |
|---|---|---|---|
| 1 | `phase1-docker-cluster/` | 3-node Elasticsearch + Kibana, shards/replicas, explicit mappings, failure + rolling-restart drills | In progress |
| 2 | `phase2-security-ilm-snapshots/` | TLS + users/roles, ILM hot-to-delete, snapshot backup/restore | Planned |
| 3 | `phase3-ingestion/` | Logstash + Filebeat pipeline, NiFi flow into Elasticsearch | Planned |
| 4 | `phase4-opensearch/` | Same cluster on OpenSearch, ISM policies, Dashboards | Planned |
| 5 | `phase5-k8s-eck/` | ECK operator on Kubernetes, scaling nodes | Planned |
| 6 | `phase6-airgapped-rpm/` | Offline RPM install on RHEL VMs (low-to-high simulation) | Planned |

## Phase 1 quick start
```bash
cd phase1-docker-cluster
./setup.sh            # cluster up, wait for green
./index-and-load.sh   # index with 3 shards / 1 replica + explicit mapping
./failure-drill.sh    # yellow/green recovery + rolling restart
```
Kibana: http://localhost:5601

## Notes / lessons learned
- `vm.max_map_count` must be >= 262144 or Elasticsearch won't start.
- Losing a node with 1 replica => cluster YELLOW (replicas unassigned), no data loss; recovers to GREEN when the node returns.
- Rolling restarts: set `cluster.routing.allocation.enable: primaries`, flush, restart one node, re-enable allocation, wait for green, repeat.
