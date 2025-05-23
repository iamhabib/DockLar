ARG PHP_VERSION=8.1
ARG user=appuser
ARG ENABLE_MONGODB_EXTENSION=false
ARG ENABLE_MONGODB_EXTENSION_VERSION=2.0.0
ARG ENABLE_SQLITE_EXTENSION=false

FROM php:${PHP_VERSION}-fpm

# Redeclare ARGs and export as ENV for access in RUN blocks
ARG user
ARG ENABLE_MONGODB_EXTENSION
ARG ENABLE_MONGODB_EXTENSION_VERSION

ENV ENABLE_MONGODB_EXTENSION=${ENABLE_MONGODB_EXTENSION}
ENV ENABLE_MONGODB_EXTENSION_VERSION=${ENABLE_MONGODB_EXTENSION_VERSION}

ENV ENABLE_SQLITE_EXTENSION=${ENABLE_SQLITE_EXTENSION}

# Install necessary packages and dependencies for the project
RUN apt-get update
# Add this line for git support
RUN apt-get install git -y
# Add this line for curl support
RUN apt-get install curl -y
# Add this line for the gd extension support
RUN apt-get install libpng-dev -y
# Add this line for the intl extension support
RUN apt-get install libonig-dev  -y
# Add this line for the xml extension support
RUN apt-get install libxml2-dev -y
# Add this line for the zip support
RUN apt-get install zip -y
# Add this line for the unzip support
RUN apt-get install unzip -y
# Add this line for the zip extension support
RUN apt-get install libzip-dev -y
# Add this line for the ssl support
RUN apt-get install libssl-dev -y
# Add this line for the ssl support
RUN apt-get install pkg-config -y
 # Add this line for the intl extension support
RUN apt-get install libicu-dev -y
# Install SQLite system dependency
RUN apt-get install -y libsqlite3-dev

# Clear cache(optional)
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql
RUN docker-php-ext-install mbstring
RUN docker-php-ext-install exif
RUN docker-php-ext-install pcntl
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install gd
RUN docker-php-ext-install zip
RUN docker-php-ext-install intl
RUN docker-php-ext-install calendar

# Install the PHP Redis extension via PECL
RUN pecl install redis && docker-php-ext-enable redis

# Conditionally install MongoDB extension
RUN if [ "$ENABLE_MONGODB_EXTENSION" = "true" ] && [ -n "$ENABLE_MONGODB_EXTENSION_VERSION" ]; then \
    pecl install mongodb-${ENABLE_MONGODB_EXTENSION_VERSION} && docker-php-ext-enable mongodb; \
fi

# Conditionally install SQLite3 extension
RUN if [ "$ENABLE_SQLITE_EXTENSION" = "true" ]; then \
    docker-php-ext-install pdo_sqlite sqlite3; \
fi

# install composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create application user
RUN useradd -ms /bin/bash -g www-data -u 1000 $user

# Copy application code and set ownership
COPY --chown=$user:www-data . /var/www

# Switch to non-root user
USER $user

EXPOSE 9000

CMD ["php-fpm"]
