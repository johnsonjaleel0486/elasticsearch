# Phase 3: Ingestion (ETL) into the secure cluster

Runs against the **Phase 2** cluster (TLS + users), joining its Docker network.

## 3a: Filebeat -> Logstash -> Elasticsearch (scripted)
```bash
./setup.sh     # service account, start loggen + Filebeat + Logstash, then verify
./verify.sh    # re-run any time: counts, levels, status codes, parse failures, newest doc
```
| Stage | What it does |
|---|---|
| `loggen` | Writes ~1 raw access-log line/sec, ~20% 4xx/5xx, every 25th line corrupted |
| Filebeat | Tails `/logs/*.log`, ships raw lines to Logstash (no parsing at the edge) |
| Logstash | `grok` parses into ECS fields, `date` sets `@timestamp` from the log line, adds `log.level` + `slow_request` tag, keeps bad lines tagged `_grokparsefailure` |
| Elasticsearch | Data stream `logs-web-lab` (built-in `logs-*-*` template + `logs` ILM policy), written by `logstash_svc` (`create_doc` + `auto_configure` only) |

Kibana: create a data view for `logs-web-lab`, then try `log.level : "ERROR"` or `tags : "slow_request"`.

## 3b: NiFi flow (built by hand in the UI)
```bash
./nifi.sh        # NiFi service account, strict-mapped nifi-orders index, truststore, sample files, start NiFi
```
Open https://localhost:8443/nifi and build:

1. **GetFile**: Input Directory `/opt/nifi/lab/input`, File Filter `.*\.json`.
2. **UpdateRecord** (Record Reader: JsonTreeReader, Record Writer: JsonRecordSetWriter, Replacement Value Strategy: Literal Value). Add properties:
   - `/pipeline` = `nifi`
   - `/source_file` = `${filename}`
3. **PutElasticsearchRecord**: Index `nifi-orders`, Index Operation `index`, Record Reader JsonTreeReader,
   Client Service = new **ElasticSearchClientServiceImpl**:
   - HTTP Hosts `https://es01:9200`, Authorization Scheme `Basic`, Username `nifi_svc`, Password (printed by nifi.sh)
   - SSL Context Service = new **StandardSSLContextService**: Truststore `/opt/nifi/lab/truststore.p12`, type `PKCS12`, password (printed by nifi.sh)
4. Connections: GetFile success -> UpdateRecord; UpdateRecord success -> PutElasticsearchRecord; UpdateRecord failure -> a Funnel.
   PutElasticsearchRecord: success / successful records -> auto-terminate; **errors** and **failure** -> a Funnel (inspect the queue); **retry** -> back into itself.
5. Enable the controller services, start everything, then `./nifi.sh drop` and `./nifi.sh check`.

Expected: 4 good orders indexed with `pipeline` and `source_file` added; the record with `"amount":"not-a-number"` is rejected by the strict mapping and lands in the **errors** queue instead of silently polluting the index.

**Lesson learned:** a PKCS12 truststore built with one Java version (Elasticsearch's bundled JDK) was rejected by NiFi with `keystore password was incorrect`, even though `keytool -list` with the same password worked. Rebuilding it with NiFi's own `keytool` fixed it. That error message can mean a format/JDK mismatch, not just a wrong password.
