#!/usr/bin/env bash
# One command to push a change live.
#
#   ./deploy.sh            build the web app + deploy the backend
#   ./deploy.sh --apk      also build a release APK against production
#
# The backend serves both the API and the web app, so a single deploy updates
# what the institute sees in a browser. Android users get the new build from
# the next GitHub Release (push a tag: git tag v1.0.1 && git push --tags).
set -euo pipefail
cd "$(dirname "$0")"

API_URL="${API_BASE_URL:-https://brightpath-coaching.vercel.app/api}"

echo "▸ building Flutter web…"
./build-web.sh

echo "▸ deploying backend + web to Vercel…"
(cd backend && vercel deploy --prod --yes)

if [ "${1:-}" = "--apk" ]; then
  echo "▸ building release APK against $API_URL …"
  (cd mobile && flutter build apk --release --dart-define=API_BASE_URL="$API_URL")
  echo "✓ mobile/build/app/outputs/flutter-apk/app-release.apk"
fi

echo "✓ live at https://brightpath-coaching.vercel.app"
