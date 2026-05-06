#!/bin/bash
# One-shot installer for the shabbat.olami.moscow widget host.
# Idempotent — safe to re-run.
set -euo pipefail

DOMAIN="shabbat.olami.moscow"
WEB_ROOT="/var/www/shabbat"
REPO_URL="https://github.com/saldkova2016-gif/olami-shabbat-vps.git"
EMAIL="info@olami.moscow"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (or via sudo)"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "Setting up $DOMAIN widget host"
echo "════════════════════════════════════════════════════════"

echo ""
echo "===> Step 1/5: Installing packages (apt)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx certbot python3-certbot-nginx git curl

echo ""
echo "===> Step 2/5: Pulling latest widget files from $REPO_URL"
TMP_REPO=$(mktemp -d)
git clone --depth 1 "$REPO_URL" "$TMP_REPO"

echo ""
echo "===> Step 3/5: Deploying widget to $WEB_ROOT"
mkdir -p "$WEB_ROOT"
rm -rf "$WEB_ROOT"/*
cp -r "$TMP_REPO/dist/"* "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"

echo ""
echo "===> Step 4/5: Configuring nginx"
cp "$TMP_REPO/nginx.conf" /etc/nginx/sites-available/shabbat
ln -sf /etc/nginx/sites-available/shabbat /etc/nginx/sites-enabled/shabbat
# Remove the default page so port 80 is exclusively ours.
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

echo ""
echo "===> Step 5/5: Issuing SSL certificate via Let's Encrypt"
echo "(This works ONLY if DNS already points $DOMAIN at this server.)"
echo ""

# Resolve A record from a public DNS server. If it doesn't match the
# server's public IP yet, skip cert step gracefully — user can re-run
# `certbot --nginx -d $DOMAIN` later once DNS propagates.
SERVER_IP=$(curl -fsSL https://api.ipify.org 2>/dev/null || echo "")
DNS_IP=$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1}' | head -1)

if [ -n "$SERVER_IP" ] && [ -n "$DNS_IP" ] && [ "$SERVER_IP" = "$DNS_IP" ]; then
    echo "DNS check OK ($DOMAIN → $DNS_IP, server is $SERVER_IP)"
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect || {
        echo ""
        echo "⚠️  Certbot failed. Re-run after DNS propagation:"
        echo "    certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect"
    }
else
    echo "⚠️  DNS not pointing here yet:"
    echo "    Server IP:    ${SERVER_IP:-(unknown)}"
    echo "    $DOMAIN → ${DNS_IP:-(no record)}"
    echo ""
    echo "Update DNS at Reg.ru (delete CNAME, add A → $SERVER_IP),"
    echo "wait 5-15 min, then run on this server:"
    echo "    certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ Done. Widget is live at: http://$SERVER_IP/widget"
echo "════════════════════════════════════════════════════════"
