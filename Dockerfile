# syntax=docker/dockerfile:1.7
# Docker Official Image manifest index verified 2026-08-22:
# php:8.5.9-apache-bookworm -> sha256:68e1de9a82af09f1b0ae70611bd64a8702069ac1e036bdc5a12eb48e1a5cab2b
ARG PHP_BASE_IMAGE=php@sha256:68e1de9a82af09f1b0ae70611bd64a8702069ac1e036bdc5a12eb48e1a5cab2b
FROM ${PHP_BASE_IMAGE}

LABEL org.opencontainers.image.title="PHP 8.5.9 Apache runtime"
LABEL org.opencontainers.image.description="Runtime-only PHP image; it contains no SimpleSAMLphp application or PostgreSQL service."

# Keep only the libraries needed at runtime after compiling the PHP extensions.
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends libicu-dev libpq-dev libxml2-dev; \
    docker-php-ext-install -j"$(nproc)" intl pdo_mysql pdo_pgsql simplexml; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    apt-mark manual libicu72 libpq5; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

COPY docker/apache/ports.conf /etc/apache2/ports.conf
COPY docker/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY docker/apache/zz-runtime.conf /etc/apache2/conf-available/zz-runtime.conf
COPY docker/php/conf.d/zz-runtime.ini /usr/local/etc/php/conf.d/zz-runtime.ini

# Composer's official binary image keeps Composer out of the runtime package set.
COPY --from=composer/composer:2-bin /composer /usr/local/bin/composer

RUN set -eux; \
    a2enconf zz-runtime; \
    a2enmod rewrite; \
    mkdir -p /var/run/apache2 /var/lock/apache2; \
    chown -R www-data:www-data /var/run/apache2 /var/lock/apache2 /var/www/html; \
    rm -f /var/www/html/index.html

USER www-data
EXPOSE 8080

CMD ["apache2-foreground"]
