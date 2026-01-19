#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION="v0.0.4"
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

prompt_secret() {
  local label="$1"
  local default="$2"
  local value
  if [ -n "$default" ]; then
    read -r -p "$label [set]: " value
    echo "${value:-$default}"
  else
    read -r -p "$label (leave blank for none): " value
    echo "$value"
  fi
}

require_root

arch="$(detect_arch)"
if [ "$arch" = "unsupported" ]; then
  echo "Unsupported architecture: $(uname -m)" >&2
  exit 1
fi

if [ -f "/etc/systemd/system/stackscope-agent.service" ]; then
  current_dir="$(grep -E '^WorkingDirectory=' /etc/systemd/system/stackscope-agent.service | cut -d= -f2- || true)"
  current_port="$(grep -E '^ExecStart=' /etc/systemd/system/stackscope-agent.service | sed -E 's/.*-addr \"?[:]([0-9]+)\"?.*/\1/' || true)"
  current_token="$(grep -E '^Environment=STACKSCOPE_TOKEN=' /etc/systemd/system/stackscope-agent.service | cut -d= -f3- || true)"
  DEFAULT_DIR="${current_dir:-$DEFAULT_DIR}"
  DEFAULT_PORT="${current_port:-$DEFAULT_PORT}"
  DEFAULT_TOKEN="${current_token:-}"
else
  DEFAULT_TOKEN=""
fi

version="$(prompt "Release version" "$DEFAULT_VERSION")"
install_dir="$(prompt "Install directory" "$DEFAULT_DIR")"
install_dir="$(eval echo "$install_dir")"
if [ ! -d "$install_dir" ]; then
  mkdir -p "$install_dir"
fi
install_dir="$(cd "$install_dir" && pwd)"
port="$(prompt "Listen port" "$DEFAULT_PORT")"

token="$(prompt_secret "Agent token" "$DEFAULT_TOKEN")"

binary_url="https://github.com/maxzhirnov/stackscope/releases/download/${version}/stackscope-agent-${arch}"
binary_path="${install_dir}/stackscope-agent"
tmp_binary="$(mktemp)"
cache_bust="$(date +%s)"

if systemctl is-active --quiet stackscope-agent; then
  systemctl stop stackscope-agent
fi

echo "Downloading ${binary_url}..."
curl -fsSL -o "$tmp_binary" "${binary_url}?ts=${cache_bust}"
install -m 0755 "$tmp_binary" "$binary_path"
rm -f "$tmp_binary"

service_path="/etc/systemd/system/stackscope-agent.service"
{
cat <<EOF
[Unit]
Description=StackScope Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=${install_dir}
ExecStart=${binary_path} -addr ":${port}"
Restart=always
RestartSec=3
EOF

if [ -n "$token" ]; then
  printf 'Environment=STACKSCOPE_TOKEN=%s\n' "$token"
fi

cat <<EOF
[Install]
WantedBy=multi-user.target
EOF
} >"$service_path"

systemctl daemon-reload
systemctl enable stackscope-agent
systemctl restart stackscope-agent

echo "StackScope Agent installed."
echo "Check status: systemctl status stackscope-agent"
echo "Test: curl -H \"X-Stackscope-Token: ${token}\" http://localhost:${port}/metrics"
