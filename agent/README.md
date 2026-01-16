# StackScope Agent

Tiny Go HTTP server that exposes `/metrics` for the StackScope web app to pull.

## Features

- Single endpoint: `GET /metrics`
- Optional auth token via `X-Stackscope-Token` header or `?token=` query param
- Linux-only metrics sourced from `/proc`

## Build

```bash
cd agent

go build -o stackscope-agent
```

Multi-platform binaries (local build):

```bash
./build.sh
```

Prebuilt binaries:
`https://github.com/maxzhirnov/stackscope/releases/tag/v0.0.1`

## Run

```bash
./stackscope-agent -addr ":9100"
```

With token:

```bash
STACKSCOPE_TOKEN="secret" ./stackscope-agent -addr ":9100"
```

## Response Example

```json
{
  "cpu_usage": 12.4,
  "memory_usage": 41.2,
  "disk_usage": 73.8,
  "load_avg": 0.42,
  "collected_at": "2026-01-16T13:57:00Z"
}
```

## Notes

- Designed for Linux servers (uses `/proc`).
- Reverse proxy or firewall is recommended if exposed publicly.
