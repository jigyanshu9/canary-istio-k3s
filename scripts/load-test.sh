#!/usr/bin/env bash
# Usage: ./load-test.sh <url> [requests]
# Prints how many responses came from each version, split by HTTP status.
set -euo pipefail
URL="${1:?url, e.g. http://<ec2-public-ip>/}"
N="${2:-100}"
for _ in $(seq 1 "$N"); do
  curl -s -w ' %{http_code}\n' "$URL" \
    | sed -n 's/.*"version":"\([^"]*\)".* \([0-9]*\)$/\1 \2/p'
done | sort | uniq -c
