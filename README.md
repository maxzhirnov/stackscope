# StackScope

StackScope is a web dashboard for monitoring home servers and VPS nodes. It provides a unified list of servers, real-time status (ping), and lightweight system metrics via a tiny agent. It also includes shortcut tiles for quick access to services.

## Quick Start (Service)

1) Download compose + env:
```
curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/.env.example -o .env
```

2) Set admin credentials in `.env`:
```
STACKSCOPE_ADMIN_USER=admin
STACKSCOPE_ADMIN_PASSWORD=change-me
```

3) Start:
```
docker compose up -d
```

4) Open:
```
http://localhost:3000
```

Notes:
- `SECRET_KEY_BASE` is auto-generated on first boot and stored in the shared volume.
- If your password contains `$`, escape it as `$$` in `.env`.

## Quick Start (Agent)

One-line install (Linux):
```
curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/agent/install.sh -o install.sh
sudo bash install.sh
```

What it does:
- Detects architecture (amd64/arm64)
- Downloads the latest agent binary
- Installs a systemd service with auto-restart

After install, set in StackScope:
- Agent URL: `http://<server-ip>:9100/metrics`
- Agent token: the token you entered during install (if any)

## Deploy on Server (Docker)

```
docker compose pull
docker compose up -d
```

## Auto-update with Watchtower

```
curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/docker-compose.watchtower.yml -o docker-compose.watchtower.yml
```

Edit `WATCHTOWER_NOTIFICATION_URL`:
```
telegram://<BOT_TOKEN>@telegram?channels=<CHAT_ID>
```

Start Watchtower:
```
docker compose -f docker-compose.yml -f docker-compose.watchtower.yml up -d
```

Notes:
- Only containers with label `com.centurylinklabs.watchtower.enable=true` are updated.
- Watchtower checks every 15 minutes.

## Shortcuts Monitoring

Shortcuts can be pinged (HTTP 2xx/3xx) automatically.

- Default interval: 60s
- Per-shortcut toggle + interval in the shortcut form
- Dashboard controls:
  - Toggle periodic checks
  - Run checks now

## Core Concepts

### Servers
Represents a target node (home server or VPS). Each server has:
- Name
- Host (IP or DNS)
- Agent URL (where metrics are pulled)
- Status (online/offline/unknown)
- Last ping timestamp
- Last metrics timestamp

### Metrics
Metrics are collected by a local agent and exposed via HTTP as JSON. The web app periodically pulls from the agent and stores a `MetricSample`.

Initial metrics set:
- CPU usage (% used)
- Memory usage (% used)
- Disk usage (% used)
- Load average (1m)

### Shortcuts
Bookmarks to frequently used services.

## Metrics API Contract

Endpoint:
- `GET /metrics`

Response:
```json
{
  "cpu_usage": 12.4,
  "memory_usage": 41.2,
  "disk_usage": 73.8,
  "load_avg": 0.42,
  "collected_at": "2026-01-16T13:57:00Z"
}
```

Notes:
- Percent values are 0..100.
- `collected_at` should be RFC3339.

See `agent/README.md` for details and releases:
`https://github.com/maxzhirnov/stackscope/releases/tag/v0.0.2`.

## Authentication

Single admin account:
- Create via `/setup` on first launch, or
- Set `STACKSCOPE_ADMIN_USER` and `STACKSCOPE_ADMIN_PASSWORD` in `.env`

## Local Development

```
bundle install
bin/rails db:create db:migrate
bin/rails s
```
