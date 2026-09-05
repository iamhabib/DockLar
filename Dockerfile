ARG PHP_VERSION=8.3
ARG user=appuser
ARG ENABLE_MONGODB_EXTENSION=false
ARG ENABLE_MONGODB_EXTENSION_VERSION=1.20.0
ARG ENABLE_SQLITE_EXTENSION=false

FROM php:${PHP_VERSION}-fpm

# Redeclare ARGs and export as ENV for access in RUN blocks
ARG user
ARG ENABLE_MONGODB_EXTENSION
ARG ENABLE_MONGODB_EXTENSION_VERSION
ARG ENABLE_SQLITE_EXTENSION

ENV ENABLE_MONGODB_EXTENSION=${ENABLE_MONGODB_EXTENSION}
ENV ENABLE_MONGODB_EXTENSION_VERSION=${ENABLE_MONGODB_EXTENSION_VERSION}
ENV ENABLE_SQLITE_EXTENSION=${ENABLE_SQLITE_EXTENSION}

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
    libsqlite3-dev \
    gosu \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip intl calendar

RUN pecl install redis && docker-php-ext-enable redis

RUN if [ "$ENABLE_MONGODB_EXTENSION" = "true" ] && [ -n "$ENABLE_MONGODB_EXTENSION_VERSION" ]; then \
    pecl install mongodb-${ENABLE_MONGODB_EXTENSION_VERSION} && docker-php-ext-enable mongodb; \
fi

RUN if [ "$ENABLE_SQLITE_EXTENSION" = "true" ]; then \
    docker-php-ext-install pdo_sqlite sqlite3; \
fi

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN useradd -ms /bin/bash -g www-data -u 1000 $user

COPY --chown=$user:www-data . /var/www

COPY php/entrypoint.sh /usr/local/bin/php-entrypoint.sh
RUN chmod +x /usr/local/bin/php-entrypoint.sh

WORKDIR /var/www

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/php-entrypoint.sh"]
CMD ["php-fpm"]
