# DockLar

Docker-based Laravel runtime for production, staging, and development. Clone this repository into your Laravel project as `docker/`. Host automation (`magic.sh`) installs Docker, brings containers up, and can configure host Nginx plus Let's Encrypt in front of the PHP/Nginx stack.

**Host OS:** Ubuntu/Debian (EC2 `ubuntu` or the user you SSH in as).  
**App code:** parent directory (`../`) is mounted at `/var/www` inside containers.

## Architecture

```
Internet
   │
   ▼
Host Nginx  (HOST_URL:HOST_PORT)     optional SSL via Certbot
   │  reverse proxy → localhost:CONTAINER_PORT
   ▼
Nginx container  (alpine)            PHP-FPM container
   │  FastCGI :9000                         │
   └──────────────► php:9000 ───────────────┘
                    │
                    ├── job  (optional)  php artisan queue:work
                    └── cron (optional)  php artisan schedule:run every 60s
```

- PHP-FPM, queue, and cron share one image: `${COMPOSE_PROJECT_NAME}-php:latest`.
- PHP-FPM master runs as root; pool workers run as `appuser` (uid `1000`).
- Queue and cron drop to `appuser` so files in `storage/` stay writable by PHP-FPM.
- Host scripts use the login user. If the current session is not in the `docker` group yet, they call `sudo docker` (passwordless on typical EC2 `ubuntu`). Do not use `newgrp` (it can hang the installer).

## Quick start

1. Put this repo inside the Laravel project:

   ```bash
   git clone <this-repo-url> docker
   cd docker
   cp .env.example .env
   ```

2. Edit `.env` (see [Environment reference](#environment-reference)). Quote values that contain spaces:

   ```env
   QUEUE_OPTIONS="--sleep=5 --tries=2 --timeout=300"
   ```

3. Run the menu:

   ```bash
   chmod +x magic.sh
   ./magic.sh
   ```

Typical first-host order:

1. Install Docker & Docker Compose  
2. Docker Compose Up  
3. Create NGINX Server Block  
4. Install Lets Encrypt SSL Certificate  

After Docker install, log out and back in once if you want `docker` without sudo. Until then, `magic.sh` already falls back to `sudo docker`.

## magic.sh options

| Option | What it does |
|---|---|
| Install Docker & Docker Compose | `apt` install `docker.io` + `docker-compose`, enable/start Docker, add the login user to the `docker` group |
| Docker Compose Up | Rebuild with `--no-cache`, start stack; includes cron/job compose files when those flags are `true`; `--remove-orphans` |
| Docker Compose Down | Stop this project's containers only. Does **not** delete images or volumes |
| Docker PS | `docker ps` |
| Goto Bash | Root shell in `${ENV}_${APP_NAME}_php` |
| Delete All Unused Docker Images | `docker image prune -a -f` (images only, not volumes) |
| Set Swap Memory | Create `/swapfile` (`1G`, `512M`, …). `M` and `G` sizes are calculated correctly |
| Create NGINX Server Block | Install host Nginx if needed, write reverse proxy from `bash/reverse_proxy.conf`. Asks before overwriting an existing file (protects Certbot SSL) |
| Delete NGINX Server Block | Remove this project's site from `sites-enabled` / `sites-available` and reload Nginx |
| Install Lets Encrypt SSL Certificate | Requires the server block first; `certbot --nginx -d ${HOST_URL}` |
| Quit | Exit |

Compose v2 (`docker compose`) is used when available; otherwise `docker-compose`.

## Project layout

```
docker/
├── magic.sh                   Menu entrypoint
├── Dockerfile                 PHP-FPM image (also used by job/cron)
├── docker-compose.yml         php + nginx
├── docker-compose.job.yml     queue worker (ENABLE_JOB=true)
├── docker-compose.cron.yml    scheduler (ENABLE_CRON=true)
├── .env.example               Copy to .env
├── bash/
│   ├── utility.sh             Env load, prompts, swap
│   ├── docker.sh              Docker install, compose up/down, prune
│   ├── nginx.sh               Host Nginx site create/delete
│   ├── certbot.sh             Let's Encrypt
│   └── reverse_proxy.conf     Host reverse-proxy template
├── nginx/
│   └── nginx.conf             Container Nginx template (upload size from .env)
└── php/
    ├── local.ini              PHP ini template (values applied at container start)
    ├── www-custom.conf        PHP-FPM pool (user, pm.*)
    └── entrypoint.sh          Render ini; php-fpm as root, artisan as appuser
```

Laravel project root is the parent of this folder. Containers mount `../:/var/www`.

## Environment reference

All keys live in `docker/.env` (not the Laravel `.env`, though Laravel still needs its own file in the project root).

| Variable | Default | Purpose |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `prod_abc` | Compose project / PHP image name `${COMPOSE_PROJECT_NAME}-php:latest` |
| `APP_NAME` | `abc` | Container names: `${ENV}_${APP_NAME}_php` / `_nginx` / `_job` / `_cron` |
| `ENV` | `prod` | Same naming + Docker network `${ENV}_${APP_NAME}_network` |
| `CONTAINER_PORT` | `8000` | Host port published by the Nginx container |
| `HOST_URL` | `abc.com` | Host Nginx `server_name` and Certbot domain |
| `HOST_PORT` | `80` | Host Nginx listen port (Certbot later adds 443) |
| `ENABLE_CRON` | `false` | `true` to run `docker-compose.cron.yml` |
| `ENABLE_JOB` | `false` | `true` to run `docker-compose.job.yml` |
| `QUEUE_COMMAND` | `queue:work` | Artisan command for the job container |
| `QUEUE_OPTIONS` | `--sleep=5 --tries=2 --timeout=300` | Extra artisan flags; **must be quoted** in `.env` |
| `PHP_VERSION` | `8.3` | `php:${PHP_VERSION}-fpm` |
| `PHP_MEMORY_LIMIT` | `512M` | Written into container `php.ini` at start |
| `PHP_UPLOAD_MAX_FILESIZE` | `30M` | PHP upload limit **and** Nginx `client_max_body_size` |
| `PHP_POST_MAX_SIZE` | `30M` | PHP `post_max_size` |
| `PHP_MAX_EXECUTION_TIME` | `60` | PHP `max_execution_time` |
| `ENABLE_MONGODB_EXTENSION` | `false` | Build-time PECL `mongodb` |
| `ENABLE_MONGODB_EXTENSION_VERSION` | `1.20.0` | PECL version when Mongo is enabled |
| `ENABLE_SQLITE_EXTENSION` | `false` | Build-time `pdo_sqlite` + `sqlite3` |

Changing PHP version or extension flags requires Compose Up (image rebuild). Changing ini / upload / queue values applies on container recreate.

## How the stack works

### PHP image

- Base: official `php:${PHP_VERSION}-fpm`.
- Always installed: `pdo_mysql`, `mbstring`, `exif`, `pcntl`, `bcmath`, `gd`, `zip`, `intl`, `calendar`, `redis`, Composer.
- Optional: MongoDB and SQLite via build args from `.env`.
- `php/entrypoint.sh` substitutes `.env` values into `local.ini`, then:
  - `php-fpm` → stay root (workers are `appuser` via `www-custom.conf`)
  - queue/cron → `gosu appuser` so artisan is not root

### Container Nginx

- Image `nginx:alpine`.
- `nginx/nginx.conf` is an official envsubst template; only `PHP_UPLOAD_MAX_FILESIZE` is substituted (`NGINX_ENVSUBST_FILTER`).
- Serves `/var/www/public`, FastCGI to `php:9000`.
- Sets `HTTPS=on` for PHP only when `X-Forwarded-Proto` is `https` (correct URLs behind the host proxy).

### Host Nginx + SSL

- Template: `bash/reverse_proxy.conf` → `/etc/nginx/sites-available/${HOST_URL}_${HOST_PORT}_${CONTAINER_PORT}.conf`.
- Proxies to `http://localhost:${CONTAINER_PORT}`.
- WebSocket: `Upgrade` / `Connection` only when the client asks (`map $http_upgrade`).
- Denies `/.` and common secret extensions (`.env`, `.git`, …).
- Gzip + security headers on the host vhost.
- If a site file already exists, the script asks before overwrite so Let's Encrypt lines are not wiped. After SSL is installed, answer **no** unless you intend to recreate the vhost and run Certbot again.

### Queue and cron

Enabled independently:

```env
ENABLE_JOB=true
ENABLE_CRON=true
```

- Job: `php artisan ${QUEUE_COMMAND} ${QUEUE_OPTIONS}` (defaults to `queue:work`).
- Cron: `schedule:run` every 60 seconds; output goes to `docker logs` (not discarded).
- Both use the PHP image already built for the `php` service (no second Dockerfile build).

Turning a flag from `true` to `false` and running Compose Up/Down removes the extra container (`--remove-orphans`).

## Production notes

- Run `./magic.sh` as the SSH user (`ubuntu`), not as a custom app user, unless that user has passwordless sudo.
- Compose Down is safe for data: it does not `docker compose down --volumes` or `--rmi`.
- Image prune is host-wide unused images only; it does not prune volumes.
- Keep host Laravel `storage/` and `bootstrap/cache` owned by uid `1000` (same as `appuser`).
- Rebuild (`--no-cache`) on every Compose Up so PHP/extension changes are not served from a stale layer.
- Do not recreate the host Nginx server block after Certbot unless you confirm overwrite and re-issue SSL.

## Troubleshooting

**Permission denied on `storage/` or `bootstrap/cache`**

```bash
chmod -R 775 storage bootstrap/cache
chown -R 1000:1000 storage bootstrap/cache
```

**`docker: permission denied`**

`magic.sh` should still work via `sudo docker`. To use `docker` directly, log out and back in after install so the `docker` group applies.

**Port already in use on Compose Up**

Stop this stack first (Compose Down), or change `CONTAINER_PORT`. The script refuses to start if `CONTAINER_PORT` is taken.

**SSL / Certbot fails**

Create the Nginx server block first. `HOST_URL` must resolve to this machine on port 80.

**Queue not starting**

Set `ENABLE_JOB=true`, quote `QUEUE_OPTIONS`, then Compose Up. Confirm with Docker PS (`${ENV}_${APP_NAME}_job`).

**Upload fails with 413**

Raise `PHP_UPLOAD_MAX_FILESIZE` and `PHP_POST_MAX_SIZE` together (post should be ≥ upload), then recreate containers so both PHP and Nginx pick up the size.

**Nginx test on the host**

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## License

MIT
