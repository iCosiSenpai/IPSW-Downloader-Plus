#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

APP="$ROOT_DIR/Releases/IPSW Downloader Plus.app"

if [[ -d "$APP" ]]; then
  "$ROOT_DIR/scripts/sign-and-notarize-app.sh" "$APP"
else
  echo "App bundle not found: $APP"
  exit 1
fi
