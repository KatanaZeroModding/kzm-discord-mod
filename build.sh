#!/usr/bin/env bash
# Build the x86 DLL into dist/ (Git Bash). kzm build does not compile this.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${KZM_NATIVE_TARGET:-i686-pc-windows-msvc}"
OUT="${ROOT}/dist/kzm_discord.dll"

cd "$ROOT"
mkdir -p dist
rustup target add "$TARGET" 2>/dev/null || true
cargo build --release --target "$TARGET"
cp "${ROOT}/target/${TARGET}/release/kzm_discord.dll" "$OUT"
echo "Built ${OUT}"
