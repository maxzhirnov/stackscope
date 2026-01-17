#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION="v0.0.2"
DEFAULT_PORT="9100"
DEFAULT_DIR="/opt/stackscope-agent"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (sudo)." >&2
    exit 1
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64) echo "linux-amd64" ;;
    aarch64|arm64) echo "linux-arm64" ;;
    *) echo "unsupported" ;;
  esac
}

prompt() {
  local label="$1"
  local default="$2"
  local value
  read -r -p "$label [$default]: " value
  echo "${value:-$default}"
}

require_root

arch="$(detect_arch)"
if [ "$arch" = "unsupported" ]; then
  echo "Unsupported architecture: $(uname -m)" >&2
  exit 1
fi

version="$(prompt "Release version" "$DEFAULT_VERSION")"
install_dir="$(prompt "Install directory" "$DEFAULT_DIR")"
port="$(prompt "Listen port" "$DEFAULT_PORT")"

read -r -p "Agent token (leave blank for none): " token

mkdir -p "$install_dir"

binary_url="https://github.com/maxzhirnov/stackscope/releases/download/${version}/stackscope-agent-${arch}"
binary_path="${install_dir}/stackscope-agent"

echo "Downloading ${binary_url}..."
curl -fsSL -o "$binary_path" "$binary_url"
chmod +x "$binary_path"

service_path="/etc/systemd/system/stackscope-agent.service"
cat >"$service_path" <<EOF
[Unit]
Description=StackScope Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=${install_dir}
ExecStart=${binary_path} -addr ":${port}"
Environment=STACKSCOPE_TOKEN=${token}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now stackscope-agent

echo "StackScope Agent installed."
echo "Check status: systemctl status stackscope-agent"
echo "Test: curl -H \"X-Stackscope-Token: ${token}\" http://localhost:${port}/metrics"
