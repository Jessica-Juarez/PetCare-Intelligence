#!/usr/bin/env bash
set -euo pipefail

: "${VERCEL_TOKEN:?Set the VERCEL_TOKEN GitHub Actions secret}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root/frontend"

npx --yes vercel@66.6.0 deploy --prebuilt --prod --yes --token="$VERCEL_TOKEN"
