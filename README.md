# Elasticsearch / OpenSearch Platform Lab

Hands-on lab standing up and operating Elasticsearch and OpenSearch clusters: cluster configuration, shards and replicas, mappings, index lifecycle, ingestion pipelines (Logstash, Filebeat, NiFi), snapshot backup/restore, monitoring, Kubernetes (ECK), and offline (air-gapped) installs.

## Phases
| Phase | Folder | Focus | Status |
|---|---|---|---|
| 1 | `phase1-docker-cluster/` | 3-node Elasticsearch + Kibana, shards/replicas, explicit mappings, failure + rolling-restart drills | Done |
| 2 | `phase2-security-ilm-snapshots/` | TLS + users/roles, ILM hot-warm-delete, snapshot backup/restore, SLM | In progress |
| 3 | `phase3-ingestion/` | Logstash + Filebeat pipeline, NiFi flow into Elasticsearch | Planned |
| 4 | `phase4-opensearch/` | Same cluster on OpenSearch, ISM policies, Dashboards | Planned |
| 5 | `phase5-k8s-eck/` | ECK operator on Kubernetes, scaling nodes | Planned |
| 6 | `phase6-airgapped-rpm/` | Offline RPM install on RHEL VMs (low-to-high simulation) | Planned |

## Phase 1 quick start
**Prereqs:** Docker (Docker Desktop on macOS: Settings > Resources > Memory at 6GB+), curl.

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
- Bulk loads without an explicit `_id` create duplicates when re-run (each run gets new auto-generated IDs). Explicit `_id`s make ingestion idempotent: a retry overwrites instead of duplicating.

## Phase 1 results (run on Docker Desktop, macOS, 2026-11-11)
**Drill 1: lose a node (es02 stopped)**
- Status went **yellow**: 2 of 3 nodes, all 33 primaries still active (no data loss), 22 replicas unassigned, 66.7% of shards active.
- `_cluster/allocation/explain` reported `NODE_LEFT` / `allocation_delayed`: Elasticsearch waits `index.unassigned.node_left.delayed_timeout` (default 60s) before re-replicating, so a short restart doesn't trigger a full data copy.
- es02 rejoined, so the cluster went **green** with 66 active shards (33 primaries + 33 replicas), reusing the replica data already on es02's disk.

**Drill 2: rolling restart (es03)**
- Set `cluster.routing.allocation.enable: primaries`, flushed (34/34 shards succeeded), restarted the node, re-enabled allocation, cluster **green**.
- Lesson: the first version of the script re-enabled allocation before es03 had actually left and rejoined. The script now waits for the node count to drop to 2 and come back to 3 before re-enabling allocation.

## Phase 2 quick start
```bash
cd phase2-security-ilm-snapshots
./setup.sh      # stops Phase 1, generates passwords in .env, TLS certs, secure 3-node cluster + Kibana
./security.sh   # least-privilege roles/users + permission checks (expected vs actual HTTP codes)
./ilm.sh        # ILM policy + template + rollover alias; then ./ilm.sh status to watch hot -> warm -> delete
./snapshot.sh   # snapshot repo, backup, delete index, restore, verify counts, nightly SLM policy
```
- Passwords live in `phase2-security-ilm-snapshots/.env` (git-ignored). Kibana login: `elastic` / `ELASTIC_PASSWORD`.
- TLS on both layers: HTTP (clients to nodes, port 9200) and transport (node to node, port 9300), all certs signed by a lab CA generated with `elasticsearch-certutil`.
- ILM timings are shortened for the lab (rollover at 3 docs, delete after 3 minutes, poll every 10s). Real values would be days/size-based, e.g. rollover at 50GB primary shard size or 1 day.
- Modern alternative to rollover aliases: data streams (same ILM policy, Elasticsearch manages the backing indices).
