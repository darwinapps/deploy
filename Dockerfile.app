ARG APP_BASE_IMAGE
FROM $APP_BASE_IMAGE

# APP_BASE_IMAGE must be declared again after FROM
ARG APP_BASE_IMAGE

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get install -y --no-install-recommends apt-transport-https apt-utils gnupg
RUN apt-get install -y --no-install-recommends \
    less \
    libjpeg-dev \
    libpng-dev \
    libgeoip-dev \
    libmcrypt-dev

# NATIVE
RUN docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr
RUN docker-php-ext-install -j$(nproc) gd mysqli pdo_mysql opcache zip

RUN \
    if echo "${APP_BASE_IMAGE}" | egrep -q ^php:7.2-apache$; \
    then \
        pecl install channel://pecl.php.net/mcrypt-1.0.1; \
        docker-php-ext-enable mcrypt; \
    else \
        docker-php-ext-configure mcrypt; \
        docker-php-ext-install -j$(nproc) mcrypt; \
    fi


# RUNKIT
RUN curl -sL https://github.com/runkit7/runkit7/releases/download/1.0.9/runkit-1.0.9.tgz > /tmp/runkit-1.0.9.tgz

# PECL
RUN pecl install geoip-1.1.1 xdebug /tmp/runkit-1.0.9.tgz
RUN docker-php-ext-enable geoip


RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN { \
    echo 'short_open_tag=Off'; \
    echo 'memory_limit=512M'; \
    echo 'post_max_size=6152M'; \
    echo 'upload_max_filesize=6144M'; \
    echo 'max_execution_time=3600'; \
    echo 'max_input_time=3600'; \
    echo 'error_reporting=E_ALL'; \
    echo 'display_errors=On'; \
    echo 'display_startup_errors=On'; \
    echo 'log_errors=On'; \
    echo 'log_errors_max_len=0'; \
    echo 'error_log=/dev/stderr'; \
    echo 'date.timezone = "UTC"'; \
} > /usr/local/etc/php/conf.d/php.ini

RUN a2enmod rewrite expires
RUN mkdir -p /usr/share/GeoIP/ && curl -s http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz | gunzip - > /usr/share/GeoIP/GeoIPCity.dat

RUN (cd ~/ && (curl -s https://getcomposer.org/installer | php)) \
    && ln -sf ~/composer.phar /usr/bin/composer


RUN curl -s https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar > /usr/bin/wp \
    && chmod a+x /usr/bin/wp


# --- fixing user permissions

ARG USERID
ARG GROUPID

RUN groupadd -g $GROUPID mapped || groupmod -n mapped $(getent group $GROUPID | cut -d: -f1)
RUN useradd \
      --uid $USERID \
      --gid $GROUPID \
      --home-dir /var/www/html/ \
      mapped

# -- end fixing user permissions

# --- app-type related code

ARG APP_TYPE
COPY scripts/${APP_TYPE}/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

# -- end app-type related code

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]

ENV APACHE_RUN_USER mapped
ENV APACHE_RUN_GROUP mapped

ARG PROJECT
ARG APACHE_DOCUMENT_ROOT

RUN sed -ri -e "s!#ServerName .*!ServerName $PROJECT!" /etc/apache2/sites-enabled/000-default.conf
RUN sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/apache2.conf /etc/apache2/sites-enabled/*.conf
