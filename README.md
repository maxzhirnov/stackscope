# StackScope

StackScope is a web dashboard for monitoring home servers and VPS nodes. It provides a unified list of servers, real-time status (ping), and lightweight system metrics via a tiny agent. It also includes shortcut tiles for quick access to services (Homarr-style, but integrated).

## Quick start (Docker)

1. Download compose and env:
   - `curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/docker-compose.yml -o docker-compose.yml`
   - `curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/.env.example -o .env`
2. Fill `.env`:
   - `STACKSCOPE_ADMIN_USER`, `STACKSCOPE_ADMIN_PASSWORD`
3. Start:
   - `docker compose up -d`
4. Open:
   - `http://localhost:3000`

Secrets:
- `SECRET_KEY_BASE` is auto-generated on first boot and persisted in the shared storage volume.
- `RAILS_MASTER_KEY` is not required for the default self-hosted setup.

Notes:
- If your password contains `$`, escape it as `$$` in `.env` (Docker Compose treats `$VAR` as interpolation).

## Goals

- Single web UI that works well on desktop and mobile.
- Fast overview: status, last ping, and recent metrics at a glance.
- Simple setup: minimal agent, no heavy dependencies.
- Clean visual language inspired by ServerCat.

## Non-goals (MVP)

- Complex alerting rules or incident management.
- Multi-user permissions or team workflows.
- Full historical analytics and anomaly detection.

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
Metrics are collected by a local agent running on the server and exposed via HTTP as JSON. The web app periodically pulls from the agent and stores a `MetricSample`.

Initial metrics set:

- CPU usage (%)
- Memory usage (%)
- Disk usage (%)
- Load average (1m)

### Shortcuts
Bookmarks to frequently used services. Each shortcut has:

- Name
- URL
- Optional icon (emoji or short label)
- Category
- Order

## Data Model (MVP)

- `Server`
  - `name`, `host`, `agent_url`, `status`
  - `last_ping_at`, `last_metrics_at`
- `MetricSample`
  - `server_id`
  - `cpu_usage`, `memory_usage`, `disk_usage`, `load_avg`
  - `collected_at`
- `Shortcut`
  - `name`, `url`, `icon`, `category`, `position`

## System Architecture

### Web App (Rails)
- UI + CRUD for servers and shortcuts.
- Background jobs:
  - Ping checks for server status.
  - Metrics polling from agents.
- Data stored in SQLite for development, with an easy path to PostgreSQL.

### Agent (Go binary)
- Single HTTP server exposing `/metrics`.
- Responds with JSON payload (see contract below).
- Meant to be installed on target servers (home and VPS).

## Metrics API Contract

Endpoint:

- `GET /metrics`

Response (JSON):

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
- The web app stores the payload as a new `MetricSample`.

See `agent/README.md` for build and run details of the Go agent, plus releases:
`https://github.com/maxzhirnov/stackscope/releases/tag/v0.0.2`.

## Status Flow

1. Scheduler triggers ping for each server `host`.
2. Result updates `Server.status` and `last_ping_at`.
3. Scheduler triggers metrics poll for each server `agent_url`.
4. On success:
   - store a `MetricSample`
   - update `Server.last_metrics_at`
5. On failure:
   - keep previous metrics, mark status as `unknown` or `degraded` (future).

## UI Layout (MVP)

- Top hero area: name, quick stats.
- Server grid cards: name, host, status, recent metrics.
- Shortcut grid: icon + name + category.
- Empty states with clear onboarding message.

## Security (initial scope)

- Agent should be bound to a trusted network or protected by token.
- Web app stores agent token per server.
- No public exposure by default.

## Authentication

StackScope uses a single admin account. You can:

- Create it via the UI on first launch (`/setup`).
- Or set env vars on first boot:
  - `STACKSCOPE_ADMIN_USER`
  - `STACKSCOPE_ADMIN_PASSWORD`

## Roadmap (next)

- CRUD UI for servers and shortcuts.
- Scheduled jobs (ping + metrics polling).
- Basic alerting via Telegram.
- Agent auth token.
- Charts for short-term history.

## Local Development

1. `bundle install`
2. `bin/rails db:create db:migrate`
3. `bin/rails s`

## Docker Compose (self-hosted)

1. Download compose and env:
   - `curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/docker-compose.yml -o docker-compose.yml`
   - `curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/.env.example -o .env`
2. Set admin credentials in `.env`:
   - `STACKSCOPE_ADMIN_USER`, `STACKSCOPE_ADMIN_PASSWORD`
3. Start services:
   - `docker compose up -d`
4. Open:
   - `http://localhost:3000`

Notes:
- `web` serves the UI; `jobs` runs background checks.
- SQLite database and uploads are stored in Docker volumes.

## Deploy on server (Docker)

1. Pull latest image:
   - `docker compose pull`
2. Start or update services:
   - `docker compose up -d`

## Open Questions

- Polling interval defaults (e.g., 30s vs 60s)?
- Agent distribution format (single binary vs package)?
- Auth method between app and agent?
