#!/bin/bash

set -euo pipefail




if [ -n "${MAILGUN_USER}" ] && [ -n "${MAILGUN_PASSWORD}" ]; then
cat <<EOF > /etc/msmtprc
defaults
port 587
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account mailgun
host smtp.mailgun.org
from ${MAILGUN_USER}
auth on
user ${MAILGUN_USER}
password ${MAILGUN_PASSWORD}
account default : mailgun
EOF
fi









if [[ "$1" == apache2* ]] || [[ "$1" == php-fpm* ]]; then
        if [ "$(id -u)" = '0' ]; then
                user="${APACHE_RUN_USER:-www-data}"
                group="${APACHE_RUN_GROUP:-www-data}"
        else
                user="$(id -u)"
                group="$(id -g)"
        fi

	if [ ! -e /var/www/html/${WEB_ROOT}config.php ]; then
		cat <<EOF > /var/www/html/${WEB_ROOT}config.php
<?php
// HTTP
define('HTTP_SERVER', 'http://' . \$_SERVER['HTTP_HOST'] .'/');

// HTTPS
define('HTTPS_SERVER', 'https://' . \$_SERVER['HTTP_HOST'] .'/');

// DIR
define('DIR_APPLICATION', '/var/www/html/${WEB_ROOT}catalog/');
define('DIR_SYSTEM', '/var/www/html/${WEB_ROOT}system/');
define('DIR_IMAGE', '/var/www/html/${WEB_ROOT}image/');
define('DIR_LANGUAGE', '/var/www/html/${WEB_ROOT}catalog/language/');
define('DIR_TEMPLATE', '/var/www/html/${WEB_ROOT}catalog/view/theme/');
define('DIR_CONFIG', '/var/www/html/${WEB_ROOT}system/config/');
define('DIR_CACHE', '/var/www/html/${WEB_ROOT}system/storage/cache/');
define('DIR_DOWNLOAD', '/var/www/html/${WEB_ROOT}system/storage/download/');
define('DIR_LOGS', '/var/www/html/${WEB_ROOT}system/storage/logs/');
define('DIR_MODIFICATION', '/var/www/html/${WEB_ROOT}system/storage/modification/');
define('DIR_UPLOAD', '/var/www/html/${WEB_ROOT}system/storage/upload/');

// DB
define('DB_DRIVER', 'mysqli');
define('DB_HOSTNAME', '${MYSQL_HOST}');
define('DB_USERNAME', '${MYSQL_USER}');
define('DB_PASSWORD', '${MYSQL_PASSWORD}');
define('DB_DATABASE', '${MYSQL_DATABASE}');
define('DB_PORT', '${MYSQL_PORT}');
define('DB_PREFIX', 'oc_');
EOF
	fi

	if [ ! -e /var/www/html/${WEB_ROOT}admin/config.php ]; then
		cat <<EOF > /var/www/html/${WEB_ROOT}admin/config.php
<?php
// HTTP
define('HTTP_SERVER', 'http://' . \$_SERVER['HTTP_HOST'] .'/admin/');
define('HTTP_CATALOG', 'http://' . \$_SERVER['HTTP_HOST'] .'/');

// HTTPS
define('HTTPS_SERVER', 'https://' . \$_SERVER['HTTP_HOST'] .'/admin/');
define('HTTPS_CATALOG', 'https://' . \$_SERVER['HTTP_HOST'] .'/');

// DIR
define('DIR_APPLICATION', '/var/www/html/${WEB_ROOT}admin/');
define('DIR_SYSTEM', '/var/www/html/${WEB_ROOT}system/');
define('DIR_IMAGE', '/var/www/html/${WEB_ROOT}image/');
define('DIR_LANGUAGE', '/var/www/html/${WEB_ROOT}admin/language/');
define('DIR_TEMPLATE', '/var/www/html/${WEB_ROOT}admin/view/template/');
define('DIR_CONFIG', '/var/www/html/${WEB_ROOT}system/config/');
define('DIR_CACHE', '/var/www/html/${WEB_ROOT}system/storage/cache/');
define('DIR_DOWNLOAD', '/var/www/html/${WEB_ROOT}system/storage/download/');
define('DIR_LOGS', '/var/www/html/${WEB_ROOT}system/storage/logs/');
define('DIR_MODIFICATION', '/var/www/html/${WEB_ROOT}system/storage/modification/');
define('DIR_UPLOAD', '/var/www/html/${WEB_ROOT}system/storage/upload/');
define('DIR_CATALOG', '/var/www/html/${WEB_ROOT}catalog/');
define('DIR_ATREX_UPLOAD', '/var/www/html/${WEB_ROOT}atrex/');

// DB
define('DB_DRIVER', 'mysqli');
define('DB_HOSTNAME', '${MYSQL_HOST}');
define('DB_USERNAME', '${MYSQL_USER}');
define('DB_PASSWORD', '${MYSQL_PASSWORD}');
define('DB_DATABASE', '${MYSQL_DATABASE}');
define('DB_PORT', '${MYSQL_PORT}');
define('DB_PREFIX', 'oc_');
EOF

	fi
fi


exec "$@"
