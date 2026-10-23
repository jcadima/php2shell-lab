#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-18088}"

fail() {
  echo "[-] $*" >&2
  exit 1
}

case "$(uname -m)" in
  x86_64|amd64) ;;
  *)
    fail "This PoC is calibrated for x86_64/amd64. Detected $(uname -m). Use an x86_64 host or VM. ARM is not supported by this lab."
    ;;
esac

command -v docker >/dev/null 2>&1 || fail "docker was not found"
docker compose version >/dev/null 2>&1 || fail "docker compose was not found"
command -v python3 >/dev/null 2>&1 || fail "python3 was not found"

python3 - <<'PY' || fail "Python 3.10 or newer is required"
import sys
raise SystemExit(0 if sys.version_info >= (3, 10) else 1)
PY

mkdir -p out
chmod 777 out 2>/dev/null || true

echo "[*] building and starting the vulnerable target"
docker compose up -d --build vuln
"$ROOT/scripts/wait-for-http.sh" "$PORT"

echo
echo "[*] runtime fingerprint"
docker exec php2shell-vuln php -v | head -1
docker exec php2shell-vuln php -i 2>/dev/null | grep -E '^(display_errors|display_startup_errors|memory_limit|post_max_size|zend.assertions|session.upload_progress.enabled|session.upload_progress.cleanup|session.save_path|max_file_uploads)'
echo

version="$(docker exec php2shell-vuln php -r 'echo PHP_VERSION;')"
[ "$version" = "8.4.26" ] || fail "expected PHP 8.4.26, got $version"

zend_assertions="$(docker exec php2shell-vuln php -r 'echo ini_get("zend.assertions");')"
[ "$zend_assertions" = "-1" ] || fail "expected zend.assertions=-1, got '$zend_assertions'"

memory_limit="$(docker exec php2shell-vuln php -r 'echo ini_get("memory_limit");')"
[ "$memory_limit" = "128M" ] || fail "expected memory_limit=128M, got '$memory_limit'"

post_max_size="$(docker exec php2shell-vuln php -r 'echo ini_get("post_max_size");')"
[ "$post_max_size" = "8M" ] || fail "expected post_max_size=8M, got '$post_max_size'"

display_errors="$(docker exec php2shell-vuln php -r 'echo ini_get("display_errors") ? "1" : "0";')"
[ "$display_errors" = "0" ] || fail "expected display_errors=Off"

upload_progress="$(docker exec php2shell-vuln php -r 'echo ini_get("session.upload_progress.enabled") ? "1" : "0";')"
[ "$upload_progress" = "1" ] || fail "expected session.upload_progress.enabled=On"

docker exec php2shell-vuln apache2ctl -M 2>/dev/null | grep -q 'php_module' || fail "Apache php_module is not loaded"
docker exec php2shell-vuln apache2ctl -M 2>/dev/null | grep -q 'mpm_prefork_module' || fail "Apache mpm_prefork_module is not loaded"

image_arch="$(docker image inspect php2shell-lab:8.4.26 --format '{{.Architecture}}')"
[ "$image_arch" = "amd64" ] || fail "expected an amd64 image, got $image_arch"

echo "[+] preflight passed"
