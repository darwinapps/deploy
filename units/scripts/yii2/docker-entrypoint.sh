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


if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
	if [ "$(id -u)" = '0' ]; then
		case "$1" in
			apache2*)
				user="${APACHE_RUN_USER:-www-data}"
				group="${APACHE_RUN_GROUP:-www-data}"
				;;
			*) # php-fpm
				user='www-data'
				group='www-data'
				;;
		esac
	else
		user="$(id -u)"
		group="$(id -g)"
	fi
	# FIXME files and folders created under root uid/gid. Should be created under user.
	if [ ! -e runtime ]; then
		mkdir runtime && chmod 777 runtime
	fi
	
	if [ ! -e web/assets ]; then
		mkdir web/assets && chmod 777 web/assets
	fi	
	
	if [ ! -e config/db.php ]; then
		cat <<EOF > config/db.php
<?php
return [
    'class' => 'yii\db\Connection',
    'dsn' => 'mysql:host=${MYSQL_HOST};dbname=${MYSQL_DATABASE}',
    'username' => '${MYSQL_USER}',
    'password' => '${MYSQL_PASSWORD}',
    'charset' => 'utf8',
];
EOF
	fi
	
	if [ ! -e config/environment.php ]; then
		cat <<EOF > config/environment.php
<?php
// this var will include proper config (main_local.php)

define("YII_ENV", PROD);
EOF
	fi

fi

exec "$@"
