#!/usr/bin/env bash
set -euo pipefail

: "${SMOKE_TEST_URL:?Set the PRODUCTION_URL GitHub Actions variable}"

curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --retry 5 \
  --retry-connrefused \
  --retry-delay 5 \
  --max-time 30 \
  --output /dev/null \
  --write-out 'HTTP %{http_code}\n' \
  "$SMOKE_TEST_URL"
