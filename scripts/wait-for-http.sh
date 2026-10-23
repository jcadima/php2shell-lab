#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-18088}"

for _ in $(seq 1 60); do
  if python3 - "$PORT" <<'PY' >/dev/null 2>&1
import sys
import urllib.request
urllib.request.urlopen(f"http://127.0.0.1:{sys.argv[1]}/", timeout=3).read()
PY
  then
    exit 0
  fi
  sleep 1
done

echo "target did not answer on port $PORT" >&2
exit 1
