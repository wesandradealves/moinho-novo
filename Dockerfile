FROM php:8.3-apache

ARG WORDPRESS_DOWNLOAD_URL="https://wordpress.org/latest.tar.gz"
ARG OXYGEN_ZIP_URL=""
ARG OXYGEN_ZIP_SHA256=""

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl \
        unzip \
        default-mysql-client \
        libzip-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libwebp-dev \
        libfreetype6-dev \
        libicu-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j"$(nproc)" \
        gd \
        mysqli \
        pdo_mysql \
        zip \
        intl \
        exif \
        opcache; \
    a2enmod rewrite headers expires; \
    rm -rf /var/lib/apt/lists/*

COPY php.ini /usr/local/etc/php/conf.d/zzz-custom.ini

RUN set -eux; \
    mkdir -p /usr/src/wordpress; \
    curl -fsSL "${WORDPRESS_DOWNLOAD_URL}" -o /tmp/wordpress.tar.gz; \
    tar -xzf /tmp/wordpress.tar.gz -C /usr/src/wordpress --strip-components=1; \
    rm -f /tmp/wordpress.tar.gz; \
    if [ -n "${OXYGEN_ZIP_URL}" ]; then \
        curl -fsSL "${OXYGEN_ZIP_URL}" -o /tmp/oxygen.zip; \
        if [ -n "${OXYGEN_ZIP_SHA256}" ]; then \
            echo "${OXYGEN_ZIP_SHA256}  /tmp/oxygen.zip" | sha256sum -c -; \
        fi; \
        unzip -q /tmp/oxygen.zip -d /usr/src/wordpress/wp-content/plugins; \
        rm -f /tmp/oxygen.zip; \
    fi; \
    chown -R www-data:www-data /usr/src/wordpress

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
