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
`https://github.com/maxzhirnov/stackscope/releases/tag/v0.0.2`

## One-line install (Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/agent/install.sh -o install.sh
sudo bash install.sh
```

## Run

```bash
./stackscope-agent -addr ":9100"
```

With token:

```bash
STACKSCOPE_TOKEN="secret" ./stackscope-agent -addr ":9100"
```

## Systemd (auto-restart)

```bash
sudo tee /etc/systemd/system/stackscope-agent.service > /dev/null <<EOF
[Unit]
Description=StackScope Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/stackscope-agent
ExecStart=/opt/stackscope-agent/stackscope-agent -addr ":9100"
Environment=STACKSCOPE_TOKEN=secret
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now stackscope-agent
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
