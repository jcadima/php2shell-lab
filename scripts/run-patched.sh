#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-18089}"
POC_DIR="${POC_DIR:-$ROOT/.poc/php2shell-bypass-aslr-exp}"
PROOF="$ROOT/out/pwned"

"$ROOT/scripts/fetch-poc.sh"

mkdir -p out
chmod 777 out 2>/dev/null || true

echo
echo "[*] building and starting the patched target"
docker compose --profile patched up -d --build patched
"$ROOT/scripts/wait-for-http.sh" "$PORT"

echo "[*] target says: $(python3 - "$PORT" <<'PY'
import sys, urllib.request
print(urllib.request.urlopen(f"http://127.0.0.1:{sys.argv[1]}/", timeout=5).read().decode().strip())
PY
)"
docker exec php2shell-patched php -v | head -1

version="$(docker exec php2shell-patched php -r 'echo PHP_VERSION;')"
if [ "$version" != "8.4.27" ]; then
  echo "[-] expected PHP 8.4.27, got $version" >&2
  exit 1
fi

rm -f "$PROOF" 2>/dev/null || true

echo
echo "[*] running the same PoC against patched PHP"
echo

python3 "$POC_DIR/exploit.py" \
  --port "$PORT" \
  --workers 1 \
  --retries 1 \
  --proof "$PROOF" || true

if [ ! -s "$PROOF" ] && docker compose exec -T patched test -s /out/pwned; then
  docker compose exec -T patched cat /out/pwned > "$PROOF"
fi

if [ -s "$PROOF" ]; then
  echo
  echo "[-] UNEXPECTED: the patched target was exploited" >&2
  cat "$PROOF" >&2
  exit 1
fi

echo
echo "[+] PASS: no proof on the patched target"
echo "[*] stop the lab with: docker compose --profile patched down -v"
