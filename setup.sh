#!/bin/bash
# First-time provisioning for the shabbat.olami.moscow widget host.
# IDEMPOTENT — safe to re-run. It will NOT clobber the HTTPS config that
# certbot writes: once a certificate exists, the nginx site config is left
# untouched. For routine content updates use deploy.sh instead.
set -euo pipefail

DOMAIN="shabbat.olami.moscow"
WEB_ROOT="/var/www/shabbat"
REPO_URL="https://github.com/saldkova2016-gif/olami-shabbat-vps.git"
EMAIL="info@olami.moscow"
SITE_AVAILABLE="/etc/nginx/sites-available/shabbat"
SITE_ENABLED="/etc/nginx/sites-enabled/shabbat"

if [ "$EUID" -ne 0 ]; then echo "Run as root (sudo)"; exit 1; fi

echo "════════════════════════════════════════════════════════"
echo "Provisioning $DOMAIN"
echo "════════════════════════════════════════════════════════"

echo "===> Packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx git curl

echo "===> Deploy widget files"
TMP_REPO=$(mktemp -d)
git clone --depth 1 "$REPO_URL" "$TMP_REPO"
mkdir -p "$WEB_ROOT"
rm -rf "$WEB_ROOT"/*
cp -r "$TMP_REPO/dist/"* "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"

# nginx config: write the base HTTP config ONLY on first provision.
# If the site file already exists, certbot has probably added the 443
# server block + redirect — overwriting it here would drop HTTPS (that
# exact bug caused an ERR_CONNECTION_REFUSED outage). Leave it alone.
if [ -f "$SITE_AVAILABLE" ]; then
    echo "===> nginx config already present — leaving it untouched (preserves SSL)"
else
    echo "===> Writing initial nginx config"
    cp "$TMP_REPO/nginx.conf" "$SITE_AVAILABLE"
    ln -sf "$SITE_AVAILABLE" "$SITE_ENABLED"
    rm -f /etc/nginx/sites-enabled/default
fi

nginx -t
systemctl reload nginx

# certbot: only if there's no live cert yet. Re-running certbot when a cert
# exists is harmless but unnecessary; skipping keeps this fast + quiet.
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "===> TLS certificate already present — skipping certbot"
else
    SERVER_IP=$(curl -fsSL https://api.ipify.org 2>/dev/null || echo "")
    DNS_IP=$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1}' | head -1)
    if [ -n "$SERVER_IP" ] && [ "$SERVER_IP" = "$DNS_IP" ]; then
        echo "===> Issuing TLS certificate (DNS points here: $DNS_IP)"
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect || \
          echo "⚠️  certbot failed — re-run: certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect"
    else
        echo "⚠️  DNS not pointing here yet (server=$SERVER_IP, dns=${DNS_IP:-none})."
        echo "    After DNS propagates: certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect"
    fi
fi

echo "════════════════════════════════════════════════════════"
echo "✅ Provisioning done. For content updates use: bash deploy.sh"
echo "════════════════════════════════════════════════════════"
