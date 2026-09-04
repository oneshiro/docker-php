# syntax=docker/dockerfile:1.7
# Docker Official Image manifest index verified 2026-09-04:
# php:7.3.33-apache-bullseye -> sha256:de13b730d81098236cde5fe90810e1572dc5c51cd190f83024ccf9e7a142ec05
ARG PHP_BASE_IMAGE=php@sha256:de13b730d81098236cde5fe90810e1572dc5c51cd190f83024ccf9e7a142ec05
FROM ${PHP_BASE_IMAGE}

LABEL org.opencontainers.image.title="PHP 7.3.33 Apache runtime"
LABEL org.opencontainers.image.description="Runtime-only PHP image; it contains no application payload or PostgreSQL service."

# Keep only the libraries needed at runtime after compiling the PHP extensions.
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends libicu-dev libldap2-dev libmemcached-dev libpq-dev libsqlite3-dev libxml2-dev; \
    docker-php-ext-configure ldap --with-libdir="lib/$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
    docker-php-ext-install -j"$(nproc)" intl ldap mbstring pdo_mysql pdo_pgsql pdo_sqlite simplexml; \
    pecl install memcached-3.1.5; \
    docker-php-ext-enable memcached; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    apt-mark manual libicu67 libldap-2.4-2 libmemcached11 libpq5 libsqlite3-0; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

# Composer 2.2 LTS supports the legacy PHP runtime; the multi-platform source is pinned.
COPY --from=composer/composer:2.2-bin@sha256:47adfdf4370e7ec65f826166d563752ba2f4afedf499a9f963b0a04d5c38f05c /composer /usr/local/bin/composer

RUN set -eux; \
    mkdir -p /opt/predis; \
    COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_CACHE_DIR=/tmp/composer-cache composer --working-dir=/opt/predis require --no-dev --prefer-dist --no-interaction predis/predis:1.1.10; \
    rm -rf /tmp/composer-cache; \
    chown -R www-data:www-data /opt/predis

COPY docker/apache/ports.conf /etc/apache2/ports.conf
COPY docker/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY docker/apache/zz-runtime.conf /etc/apache2/conf-available/zz-runtime.conf
COPY docker/php/conf.d/zz-runtime.ini /usr/local/etc/php/conf.d/zz-runtime.ini

RUN set -eux; \
    a2enconf zz-runtime; \
    a2enmod rewrite; \
    mkdir -p /var/run/apache2 /var/lock/apache2; \
    chown -R www-data:www-data /var/run/apache2 /var/lock/apache2 /var/www/html; \
    rm -f /var/www/html/index.html

USER www-data
EXPOSE 8080

CMD ["apache2-foreground"]
