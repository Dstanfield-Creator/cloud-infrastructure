# Docker Compose: Monitoring Stack

> Prometheus, Alertmanager, Grafana, node_exporter, cAdvisor and blackbox_exporter in one compose project, with SSH reachability probes and a starter alert set.

**Status:** Active · **Updated:** 2026-10-08

## Services and ports

| Service | Image | Container port | Host port | Purpose |
|---|---|---|---|---|
| prometheus | `prom/prometheus:v3.5.0` | 9090 | 9090 | Metrics storage, scraping and rule evaluation |
| alertmanager | `prom/alertmanager:v0.28.1` | 9093 | 9093 | Alert routing, grouping, silences |
| grafana | `grafana/grafana-oss:12.1.1` | 3000 | 3000 | Dashboards |
| node_exporter | `prom/node-exporter:v1.9.1` | 9100 | not published | Host CPU, memory, disk, network |
| cadvisor | `gcr.io/cadvisor/cadvisor:v0.52.1` | 8080 | not published | Per-container resource usage |
| blackbox_exporter | `prom/blackbox-exporter:v0.27.0` | 9115 | not published | TCP, HTTP and ICMP probes of remote endpoints |

Exporters are only reachable on the internal `monitoring` network, so nothing but the three UIs is exposed on the host. Put a reverse proxy with TLS and authentication in front of the UIs before exposing them beyond a trusted network; Prometheus and Alertmanager have no built-in login.

## Quick start

```bash
cp .env.example .env            # set GRAFANA_ADMIN_PASSWORD
docker compose config --quiet   # validates the compose file and .env
docker compose up -d
docker compose ps
```

Then open:

- Prometheus targets: `http://localhost:9090/targets`
- Alerts: `http://localhost:9090/alerts` and `http://localhost:9093`
- Grafana: `http://localhost:3000` (user from `.env`, default `admin`)

Compose refuses to start if `GRAFANA_ADMIN_PASSWORD` is unset. Add `.env` to `.gitignore`.

## Files

```
docker-compose.yml
.env.example                 -> copy to .env
prometheus/prometheus.yml    scrape jobs and Alertmanager address
prometheus/alerts.yml        alerting rules
grafana/provisioning/        datasource and dashboard-provider YAML (included)
grafana/dashboards/          dashboard JSON picked up by the provider (you create these)
alertmanager/alertmanager.yml  optional receiver config (you create this)
```

Named volumes `prometheus_data`, `alertmanager_data` and `grafana_data` hold all state. `docker compose down` keeps them; `docker compose down -v` deletes them.

## Adding a target

### Another SSH endpoint

Append the address to the `blackbox_ssh` job in `prometheus/prometheus.yml`, then reload:

```yaml
      - targets:
          - 192.0.2.11:22
          - 192.0.2.12:22
          - 192.0.2.13:22
          - 192.0.2.14:22
```

```bash
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
curl -X POST http://localhost:9090/-/reload
```

The relabel block rewrites each listed address into the `?target=` parameter and the `instance` label, and sends the request to `blackbox_exporter:9115`. To probe something other than SSH, add a second job with a different `module` (for example `http_2xx` with targets like `https://www.example.com`).

### A remote host running node_exporter

Add a new job rather than extending the local one, so the `host` label stays meaningful:

```yaml
  - job_name: node_exporter_remote
    static_configs:
      - targets: ["192.0.2.14:9100"]
        labels:
          host: app01
```

Restrict port 9100 on the remote host to the address of this monitoring host.

## Alerts

| Alert | Condition | For | Severity |
|---|---|---|---|
| `TargetDown` | `up == 0` for any scrape target | 10m | critical |
| `HostDiskUsageHigh` | Any real filesystem above 85% used | 1h | warning |
| `ContainerRestarting` | More than 3 CPU-counter resets (restarts) for a container in 1h | 5m | warning |
| `SSHProbeFailed` | `probe_success == 0` for a `blackbox_ssh` target | 10m | critical |

Validate after editing:

```bash
docker compose exec prometheus promtool check rules /etc/prometheus/alerts.yml
curl -X POST http://localhost:9090/-/reload
```

### Sending notifications

The Alertmanager image ships a default configuration whose only receiver is a placeholder webhook, so alerts show up in the Alertmanager UI but go nowhere. To notify, create `alertmanager/alertmanager.yml` with your receiver (email, Slack, webhook, PagerDuty), uncomment the bind mount in `docker-compose.yml` and run `docker compose up -d alertmanager`. Keep tokens in that file out of version control, or reference them with `*_file` options where the receiver supports it.

## Grafana provisioning

Grafana reads provisioning YAML at startup from `/etc/grafana/provisioning/`. Two bind mounts in the compose file map that to `grafana/provisioning/` in this folder.

### Datasource

`grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

### Dashboard provider

`grafana/provisioning/dashboards/dashboards.yml`:

```yaml
apiVersion: 1
providers:
  - name: local
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
```

### Where to put dashboard JSON

Drop exported dashboard JSON files into `grafana/dashboards/`. Subfolders become Grafana folders. Grafana picks up new or changed files within `updateIntervalSeconds` without a restart. Good starting points from grafana.com: Node Exporter Full (ID 1860), cAdvisor exporter (ID 14282) and Prometheus Blackbox Exporter (ID 7587). When you export JSON from grafana.com it usually contains a `${DS_PROMETHEUS}` input; either replace it with the datasource `uid` above (`prometheus`) or import once through the UI and export from there.

## Operations

```bash
docker compose logs -f prometheus          # follow one service
docker compose pull && docker compose up -d # upgrade to the pinned versions after bumping tags
docker compose down                        # stop, keep data
docker compose down -v                     # stop and delete all metrics and dashboards
```

Retention is controlled by `PROMETHEUS_RETENTION` in `.env`. Size the `prometheus_data` volume accordingly; a small stack like this uses roughly 1 to 2 GB per 30 days.

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
