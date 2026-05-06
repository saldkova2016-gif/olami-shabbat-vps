# olami-shabbat-vps

Deployment package for the OLAMI Shabbat seating-widget VPS at
`shabbat.olami.moscow`.

## Files

- `dist/` — pre-built React widget (output of `vite build` from the
  main repo)
- `nginx.conf` — site config: serves the SPA, proxies `/sb/*` to
  Supabase REST/Storage/Auth, and `/sb/realtime/*` with WebSocket
  Upgrade headers.
- `setup.sh` — idempotent one-shot installer. Run it on a fresh
  Ubuntu 24.04 server (TimeWeb / Selectel / etc.) as root.

## Why this exists

Vercel deployments (`*.vercel.app` and freshly-issued custom-domain
certs) get caught in RU ISP-side SNI filters, leaving guests in RU
unable to reach the widget without VPN. A Russian VPS with a
domain on a TLD that's already passed the filter (`olami.moscow`)
solves this for good.

## Deploying

```bash
curl -fsSL https://raw.githubusercontent.com/saldkova2016-gif/olami-shabbat-vps/main/setup.sh | sudo bash
```
