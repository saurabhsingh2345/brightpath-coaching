#!/usr/bin/env bash
# Builds the Flutter web app into backend/public so one Vercel deployment
# serves both the app and the API from the same origin (no CORS, no config).
set -euo pipefail
cd "$(dirname "$0")"

echo "→ building Flutter web…"
(cd mobile && flutter build web --release)

echo "→ copying into backend/public…"
rm -rf backend/public
mkdir -p backend/public
cp -R mobile/build/web/. backend/public/

echo "✓ backend/public ready ($(du -sh backend/public | cut -f1))"
