#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POC_DIR="${POC_DIR:-$ROOT/.poc/php2shell-bypass-aslr-exp}"
POC_REPO="${POC_REPO:-https://github.com/9bie/php2shell-bypass-aslr-exp.git}"
POC_COMMIT="${POC_COMMIT:-17e98ee81025cccfd94b4f9c9a17bf269c65ff75}"

if ! command -v git >/dev/null 2>&1; then
  echo "[-] git is required to fetch the third-party PoC" >&2
  exit 1
fi

if [ -e "$POC_DIR" ] && [ ! -d "$POC_DIR/.git" ]; then
  echo "[-] $POC_DIR exists but is not a git checkout. Move it or set POC_DIR." >&2
  exit 1
fi

if [ ! -d "$POC_DIR/.git" ]; then
  echo "[*] cloning third-party PoC into $POC_DIR"
  git clone "$POC_REPO" "$POC_DIR"
fi

git -C "$POC_DIR" fetch --tags --quiet
git -C "$POC_DIR" checkout --detach "$POC_COMMIT" --quiet

actual="$(git -C "$POC_DIR" rev-parse HEAD)"
if [ "$actual" != "$POC_COMMIT" ]; then
  echo "[-] PoC commit mismatch: expected $POC_COMMIT, got $actual" >&2
  exit 1
fi

echo "[+] PoC pinned at $POC_COMMIT"
echo "[!] Third-party code: $POC_REPO (no license file). Review it before running."
