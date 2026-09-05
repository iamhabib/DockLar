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
   │  reverse proxy → 127.0.0.1:CONTAINER_PORT
   ▼
Nginx container  (alpine, localhost-only publish)
   │  FastCGI :9000
   └──────────────► PHP-FPM container
                    │
                    ├── job  (optional)  php artisan queue:work
                    └── cron (optional)  php artisan schedule:run every 60s (flock)
```

- PHP-FPM, queue, and cron share one image: `${COMPOSE_PROJECT_NAME}-php:latest`.
- PHP-FPM master runs as root; pool workers run as `appuser` (uid `1000`).
- Queue and cron drop to `appuser` so files in `storage/` stay writable by PHP-FPM.
- The Nginx container publishes `127.0.0.1:CONTAINER_PORT` only — not on the public interface. Traffic must go through host Nginx (or SSH tunnel).
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

   Or use Make: `make up` / `make down` / `make rebuild` / `make ps`.

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
| Docker Compose Up | Cached image build, start stack; includes cron/job compose files when those flags are `true`; `--remove-orphans` |
| Docker Compose Rebuild (no-cache) | Full `--no-cache` rebuild + recreate (use after PHP version / extension / `NPM` / `NODE_VERSION` changes) |
| Docker Compose Down | Stop this project's containers only. Does **not** delete images or volumes |
| Docker PS | `docker ps` |
| Goto Bash | Shell as `appuser` (uid `1000`) in `${ENV}_${APP_NAME}_php` — same user as PHP-FPM workers |
| Delete All Unused Docker Images | `docker image prune -a -f` (images only, not volumes) |
| Set Swap Memory | Create `/swapfile` (`1G`, `512M`, …). `M` and `G` sizes are calculated correctly |
| Create NGINX Server Block | Install host Nginx if needed, write reverse proxy from `bash/reverse_proxy.conf`. Asks before overwriting an existing file (protects Certbot SSL) |
| Delete NGINX Server Block | Remove this project's site from `sites-enabled` / `sites-available` and reload Nginx |
| Install Lets Encrypt SSL Certificate | Requires the server block first and `HOST_PORT=80`; `certbot --nginx -d ${HOST_URL}` |
| Quit | Exit |

Compose v2 (`docker compose`) is used when available; otherwise `docker-compose`.

## Project layout

```
docker/
├── magic.sh                   Menu entrypoint
├── Makefile                   up / down / rebuild / ps wrappers
├── Dockerfile                 PHP-FPM image (also used by job/cron)
├── docker-compose.yml         php + nginx
├── docker-compose.job.yml     queue worker (ENABLE_JOB=true)
├── docker-compose.cron.yml    scheduler (ENABLE_CRON=true)
├── .env.example               Copy to .env
├── bash/
│   ├── utility.sh             Env load, prompts, swap
│   ├── docker.sh              Docker install, compose up/down/rebuild, prune
│   ├── nginx.sh               Host Nginx site create/delete
│   ├── certbot.sh             Let's Encrypt
│   └── reverse_proxy.conf     Host reverse-proxy template
├── nginx/
│   └── nginx.conf             Container Nginx template (upload size from .env)
└── php/
    ├── local.ini              PHP ini template (values applied at container start)
    ├── www-custom.conf        PHP-FPM pool (replaces default www.conf)
    └── entrypoint.sh          Render ini; fix storage ownership; php-fpm as root, artisan as appuser
```

Laravel project root is the parent of this folder. Containers mount `../:/var/www`.

## Environment reference

All keys live in `docker/.env` (not the Laravel `.env`, though Laravel still needs its own file in the project root).

| Variable | Default | Purpose |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `prod_abc` | Compose project / PHP image name `${COMPOSE_PROJECT_NAME}-php:latest` |
| `APP_NAME` | `abc` | Container names: `${ENV}_${APP_NAME}_php` / `_nginx` / `_job` / `_cron` |
| `ENV` | `prod` | Same naming + Docker network `${ENV}_${APP_NAME}_network` |
| `CONTAINER_PORT` | `8000` | Host loopback port published by the Nginx container (`127.0.0.1` only) |
| `HOST_URL` | `abc.com` | Host Nginx `server_name` and Certbot domain |
| `HOST_PORT` | `80` | Host Nginx listen port (must be `80` for Certbot HTTP-01) |
| `ENABLE_CRON` | `false` | `true` to run `docker-compose.cron.yml` |
| `ENABLE_JOB` | `false` | `true` to run `docker-compose.job.yml` |
| `QUEUE_COMMAND` | `queue:work` | Artisan command for the job container |
| `QUEUE_OPTIONS` | `--sleep=5 --tries=2 --timeout=300` | Extra artisan flags; **must be quoted** in `.env` |
| `PHP_VERSION` | `8.3` | `php:${PHP_VERSION}-fpm` |
| `PHP_MEMORY_LIMIT` | `512M` | Written into container `php.ini` at start |
| `PHP_UPLOAD_MAX_FILESIZE` | `30M` | PHP upload limit **and** Nginx `client_max_body_size` |
| `PHP_POST_MAX_SIZE` | `30M` | PHP `post_max_size` |
| `PHP_MAX_EXECUTION_TIME` | `60` | PHP `max_execution_time` |
| `PHP_CONTAINER_MEMORY` | `1g` | Docker `mem_limit` for the PHP container |
| `NGINX_CONTAINER_MEMORY` | `128m` | Docker `mem_limit` for Nginx |
| `JOB_CONTAINER_MEMORY` | `512m` | Docker `mem_limit` for the queue worker |
| `CRON_CONTAINER_MEMORY` | `256m` | Docker `mem_limit` for the scheduler |
| `ENABLE_MONGODB_EXTENSION` | `false` | Build-time PECL `mongodb` |
| `ENABLE_MONGODB_EXTENSION_VERSION` | `1.20.0` | PECL version when Mongo is enabled |
| `ENABLE_SQLITE_EXTENSION` | `false` | Build-time `pdo_sqlite` + `sqlite3` |
| `NPM` | `false` | Build-time Node.js + npm in the PHP image (for Vite / React / Vue) |
| `NODE_VERSION` | `20` | Node.js **major** version when `NPM=true` (e.g. `18`, `20`, `22`). Uses NodeSource `setup_${NODE_VERSION}.x` |

Changing PHP version, extension flags, `NPM`, or `NODE_VERSION` requires **Docker Compose Rebuild (no-cache)** (or `make rebuild`). Changing ini / upload / queue / memory values applies on container recreate (`Docker Compose Up` / `make up`).

## How the stack works

### PHP image

- Base: official `php:${PHP_VERSION}-fpm`.
- Always installed: `pdo_mysql`, `mbstring`, `exif`, `pcntl`, `bcmath`, `gd`, `zip`, `intl`, `calendar`, `redis`, Composer.
- Optional: MongoDB, SQLite, and Node.js/npm via build args from `.env` (SQLite build deps only when enabled).
- Default FPM `www.conf` is replaced by `php/www-custom.conf` (single `[www]` pool, `listen = 9000`, workers as `appuser`).
- `php/entrypoint.sh` substitutes `.env` values into `local.ini`, aligns `storage/` and `bootstrap/cache` ownership to uid `1000` when needed, then:
  - `php-fpm` → stay root (workers are `appuser`)
  - queue/cron → `gosu appuser` so artisan is not root

### Node.js / npm (`NPM=true`)

When `NPM=true`, the PHP image installs **Node.js** (NodeSource) and **npm**. Use this for Laravel Vite, React, Vue, or any frontend build inside the container.

```env
NPM=true
NODE_VERSION=20
```

`NODE_VERSION` is the Node **major** only (`18`, `20`, `22`, …). Default is `20`. Change it and run **Docker Compose Rebuild (no-cache)**.

Then from the host menu use **Goto Bash** (opens as `appuser`), or:

```bash
docker exec -u appuser -it ${ENV}_${APP_NAME}_php bash
cd /var/www
npm install
npm run build
```

`node` and `npm` are on PATH for `appuser`. Job/cron share the same image when `NPM=true` (harmless if unused). Set `NPM=false` and rebuild if you no longer need Node.

Rare cases that need root inside the container (e.g. installing a system package):

```bash
docker exec -u 0 -it ${ENV}_${APP_NAME}_php bash
```

### Container Nginx

- Image `nginx:alpine`.
- Publishes **`127.0.0.1:CONTAINER_PORT:80`** only (not `0.0.0.0`).
- `nginx/nginx.conf` is an official envsubst template; only `PHP_UPLOAD_MAX_FILESIZE` is substituted (`NGINX_ENVSUBST_FILTER`).
- Serves `/var/www/public`, FastCGI to `php:9000`.
- `/health` returns `200 ok` for healthchecks (no PHP).
- Denies PHP under `/storage/`, hidden paths (`/.`), and common secret extensions.
- Sets `HTTPS=on` for PHP only when `X-Forwarded-Proto` is `https` (correct URLs behind the host proxy).
- JSON-file logs rotated (`max-size` 10m, `max-file` 3).

### Host Nginx + SSL

- Template: `bash/reverse_proxy.conf` → `/etc/nginx/sites-available/${HOST_URL}_${HOST_PORT}_${CONTAINER_PORT}.conf`.
- Proxies to `http://127.0.0.1:${CONTAINER_PORT}`.
- WebSocket: `Upgrade` / `Connection` only when the client asks (`map $http_upgrade`).
- Denies `/.` and common secret extensions (`.env`, `.git`, …).
- Gzip + security headers on the host vhost.
- If a site file already exists, the script asks before overwrite so Let's Encrypt lines are not wiped. After SSL is installed, answer **no** unless you intend to recreate the vhost and run Certbot again.
- Certbot requires `HOST_PORT=80` (HTTP-01).

### Queue and cron

Enabled independently:

```env
ENABLE_JOB=true
ENABLE_CRON=true
```

- Job: `php artisan ${QUEUE_COMMAND} ${QUEUE_OPTIONS}` (defaults to `queue:work`).
- Cron: `schedule:run` every 60 seconds under `flock -n` so overlapping ticks are skipped; output goes to `docker logs`.
- Both use the PHP image already built for the `php` service (no second Dockerfile build).

Turning a flag from `true` to `false` and running Compose Up/Down removes the extra container (`--remove-orphans`).

## Production notes

- Run `./magic.sh` as the SSH user (`ubuntu`), not as a custom app user, unless that user has passwordless sudo.
- **Do not expose `CONTAINER_PORT` publicly** — it is bound to loopback. Keep host firewall/`ufw` allowing 80/443 only; reach the app through host Nginx.
- Compose Down is safe for data: it does not `docker compose down --volumes` or `--rmi`.
- Image prune is host-wide unused images only; it does not prune volumes.
- Entrypoint fixes `storage/` and `bootstrap/cache` ownership to uid `1000` when the top-level dir is not already owned by `appuser`. You can still fix manually on the host if needed.
- Use **Docker Compose Up** for routine restarts (cached builds). Use **Rebuild (no-cache)** when PHP/extensions/`NPM`/`NODE_VERSION` change.
- Do not recreate the host Nginx server block after Certbot unless you confirm overwrite and re-issue SSL.
- For frontend builds with `NPM=true`, run `npm install` / `npm run build` as `appuser` so `node_modules` and build output are not root-owned on the bind mount.
- Containers have `mem_limit` and rotated logs to reduce OOM / disk-fill risk.

## Troubleshooting

**Permission denied on `storage/` or `bootstrap/cache`**

```bash
chmod -R 775 storage bootstrap/cache
chown -R 1000:1000 storage bootstrap/cache
```

Restart the PHP container afterward (entrypoint will skip chown if ownership is already correct).

**`docker: permission denied`**

`magic.sh` should still work via `sudo docker`. To use `docker` directly, log out and back in after install so the `docker` group applies.

**Port already in use on Compose Up**

If this project's Nginx container already owns `CONTAINER_PORT`, Up/Rebuild proceeds and recreates. If another process owns the port, stop it or change `CONTAINER_PORT`.

**Cannot reach the app on `CONTAINER_PORT` from another machine**

Expected: the port is localhost-only. Use the host Nginx vhost (`HOST_URL`) or `ssh -L`.

**SSL / Certbot fails**

Create the Nginx server block first. `HOST_URL` must resolve to this machine on port 80. `HOST_PORT` must be `80`.

**Queue not starting**

Set `ENABLE_JOB=true`, quote `QUEUE_OPTIONS`, then Compose Up. Confirm with Docker PS (`${ENV}_${APP_NAME}_job`).

**Upload fails with 413**

Raise `PHP_UPLOAD_MAX_FILESIZE` and `PHP_POST_MAX_SIZE` together (post should be ≥ upload), then recreate containers so both PHP and Nginx pick up the size.

**`npm: command not found`**

Set `NPM=true` (and optionally `NODE_VERSION=20`) in `docker/.env`, then **Docker Compose Rebuild (no-cache)** so the image rebuilds with Node. Confirm with `node -v` and `npm -v` inside Goto Bash.

**Nginx test on the host**

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## License

MIT
