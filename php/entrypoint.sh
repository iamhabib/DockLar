#!/bin/sh
set -e

ini_template="/usr/local/etc/php/conf.d/local.ini.template"
ini_target="/usr/local/etc/php/conf.d/local.ini"

if [ -f "$ini_template" ] && [ "$(id -u)" = "0" ]; then
    sed \
        -e "s/\${PHP_MEMORY_LIMIT}/${PHP_MEMORY_LIMIT:-512M}/g" \
        -e "s/\${PHP_UPLOAD_MAX_FILESIZE}/${PHP_UPLOAD_MAX_FILESIZE:-30M}/g" \
        -e "s/\${PHP_POST_MAX_SIZE}/${PHP_POST_MAX_SIZE:-30M}/g" \
        -e "s/\${PHP_MAX_EXECUTION_TIME}/${PHP_MAX_EXECUTION_TIME:-60}/g" \
        "$ini_template" > "$ini_target"
fi

# php-fpm master must stay root so pool workers can run as appuser.
# Queue and cron must not run as root (storage files would be unwritable by PHP-FPM).
if [ "$(id -u)" = "0" ] && [ "$1" != "php-fpm" ]; then
    exec docker-php-entrypoint gosu appuser "$@"
fi

exec docker-php-entrypoint "$@"
