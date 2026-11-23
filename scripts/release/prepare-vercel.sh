#!/usr/bin/env bash
set -euo pipefail

: "${VERCEL_TOKEN:?Set the VERCEL_TOKEN GitHub Actions secret}"
: "${VERCEL_ORG_ID:?Set the VERCEL_ORG_ID GitHub Actions secret}"
: "${VERCEL_PROJECT_ID:?Set the VERCEL_PROJECT_ID GitHub Actions secret}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root/frontend"

mkdir -p .vercel
node -e 'const fs = require("node:fs"); fs.writeFileSync(".vercel/project.json", JSON.stringify({ orgId: process.env.VERCEL_ORG_ID, projectId: process.env.VERCEL_PROJECT_ID }, null, 2) + "\n")'
npx --yes vercel@66.6.0 pull --yes --environment=production --token="$VERCEL_TOKEN"
