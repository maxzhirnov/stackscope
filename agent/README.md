# StackScope Agent

Tiny Go HTTP server that exposes `/metrics` for the StackScope web app to pull.

## One-line Install (Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/maxzhirnov/stackscope/main/agent/install.sh -o install.sh
sudo bash install.sh
```

The installer:
- Detects architecture (amd64/arm64)
- Downloads the release binary
- Installs a systemd service with auto-restart

Upgrade:
- Re-run the installer to download a new version and keep current settings.

## Manual Install

Download the latest release:
- https://github.com/maxzhirnov/stackscope/releases/tag/v0.0.3

Linux amd64:
```bash
curl -L -o stackscope-agent https://github.com/maxzhirnov/stackscope/releases/download/v0.0.3/stackscope-agent-linux-amd64
chmod +x stackscope-agent
```

Linux arm64 (Raspberry Pi 4):
```bash
curl -L -o stackscope-agent https://github.com/maxzhirnov/stackscope/releases/download/v0.0.3/stackscope-agent-linux-arm64
chmod +x stackscope-agent
```

## Run

```bash
./stackscope-agent -addr ":9100"
```

With token:
```bash
STACKSCOPE_TOKEN="secret" ./stackscope-agent -addr ":9100"
```

## Systemd (Auto-restart)

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

Check status:
```bash
systemctl status stackscope-agent
```

Test:
```bash
curl -H "X-Stackscope-Token: secret" http://localhost:9100/metrics
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
- If you expose it publicly, protect with a token or a reverse proxy.
