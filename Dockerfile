ARG PHP_VERSION=8.3
ARG user=appuser
ARG ENABLE_MONGODB_EXTENSION=false
ARG ENABLE_MONGODB_EXTENSION_VERSION=1.20.0
ARG ENABLE_SQLITE_EXTENSION=false
ARG NPM=false
ARG NODE_VERSION=20

FROM php:${PHP_VERSION}-fpm

# Redeclare ARGs for use in RUN blocks (not exported as runtime ENV)
ARG user
ARG ENABLE_MONGODB_EXTENSION
ARG ENABLE_MONGODB_EXTENSION_VERSION
ARG ENABLE_SQLITE_EXTENSION
ARG NPM
ARG NODE_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    libzip-dev \
    libssl-dev \
    pkg-config \
    libicu-dev \
    gosu \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip intl calendar

RUN pecl install redis && docker-php-ext-enable redis

RUN if [ "$ENABLE_MONGODB_EXTENSION" = "true" ] && [ -n "$ENABLE_MONGODB_EXTENSION_VERSION" ]; then \
    pecl install mongodb-${ENABLE_MONGODB_EXTENSION_VERSION} && docker-php-ext-enable mongodb; \
fi

RUN if [ "$ENABLE_SQLITE_EXTENSION" = "true" ]; then \
    apt-get update && apt-get install -y --no-install-recommends libsqlite3-dev \
    && docker-php-ext-install pdo_sqlite sqlite3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*; \
fi

# Optional Node.js + npm (Vite / React / Vue frontend builds)
# NODE_VERSION = major only (18, 20, 22) → NodeSource setup_${NODE_VERSION}.x
RUN if [ "$NPM" = "true" ]; then \
    if ! echo "$NODE_VERSION" | grep -Eq '^[0-9]+$'; then \
      echo "NODE_VERSION must be a major number (e.g. 18, 20, 22), got: ${NODE_VERSION}" >&2; \
      exit 1; \
    fi; \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates gnupg \
    && curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && node --version && npm --version; \
fi

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN useradd -ms /bin/bash -g www-data -u 1000 $user \
    && mkdir -p /var/www \
    && chown $user:www-data /var/www

# Replace default pool so only one [www] definition exists
COPY php/www-custom.conf /usr/local/etc/php-fpm.d/www.conf

COPY php/entrypoint.sh /usr/local/bin/php-entrypoint.sh
RUN chmod +x /usr/local/bin/php-entrypoint.sh

WORKDIR /var/www

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/php-entrypoint.sh"]
CMD ["php-fpm"]
