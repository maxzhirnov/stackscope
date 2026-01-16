#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$ROOT_DIR/dist"

mkdir -p "$OUT_DIR"

build() {
  local goos="$1"
  local goarch="$2"
  local name="stackscope-agent-${goos}-${goarch}"

  echo "Building ${name}..."
  GOOS="$goos" GOARCH="$goarch" go build -o "$OUT_DIR/$name" "$ROOT_DIR/main.go"
}

build linux amd64
build linux arm64
build darwin amd64
build darwin arm64

echo "Binaries are in $OUT_DIR"
