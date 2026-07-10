#!/bin/bash
# Content-only redeploy for shabbat.olami.moscow.
# Pulls the latest widget build and swaps the files in /var/www/shabbat.
# NEVER touches the nginx config or the TLS certificate — so it can't cause
# the "SSL got wiped on re-run" outage that re-running setup.sh once did.
set -euo pipefail

WEB_ROOT="/var/www/shabbat"
REPO_URL="https://github.com/saldkova2016-gif/olami-shabbat-vps.git"

if [ "$EUID" -ne 0 ]; then echo "Run as root (sudo)"; exit 1; fi

TMP_REPO=$(mktemp -d)
git clone --depth 1 "$REPO_URL" "$TMP_REPO" >/dev/null 2>&1
mkdir -p "$WEB_ROOT"
rm -rf "$WEB_ROOT"/*
cp -r "$TMP_REPO/dist/"* "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"
rm -rf "$TMP_REPO"

# Reload (not restart) — picks up new static files, keeps TLS/config as-is.
systemctl reload nginx
echo "✅ Deployed $(ls "$WEB_ROOT"/assets/index-*.js 2>/dev/null | xargs -n1 basename | head -1) at $(date '+%H:%M:%S')"
