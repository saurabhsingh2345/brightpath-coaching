#!/usr/bin/env bash
# Applies pending Prisma migrations to the hosted (Neon) database.
# Run after changing prisma/schema.prisma and creating a migration locally
# with:  cd backend && npx prisma migrate dev --name <what-changed>
set -euo pipefail
cd "$(dirname "$0")/backend"

if [ ! -f .env.local ]; then
  echo "backend/.env.local is missing. Run:  cd backend && vercel env pull" >&2
  exit 1
fi

export DATABASE_URL="$(grep -E '^DATABASE_URL=' .env.local | cut -d= -f2- | tr -d '"')"
export DIRECT_URL="$(grep -E '^DATABASE_URL_UNPOOLED=' .env.local | cut -d= -f2- | tr -d '"')"

npx prisma migrate deploy
echo "✓ hosted database is up to date"
