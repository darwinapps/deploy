#!/bin/bash

set -euo pipefail

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

	if [ ! -e .env ]; then
		cat <<EOF > .env
DB_NAME=${MYSQL_DATABASE}
DB_PASS=${MYSQL_PASSWORD}
DB_USER=${MYSQL_USER}
DB_HOST=${MYSQL_HOST}
PROTOCOL=http
ENVIRONMENT=development
#SMTP_HOST=smtp.sendgrid.net
#SMTP_USERNAME=appmailer
#SMTP_PASSWORD=
#SMTP_PORT=587
#SMTP_ENCRYPTION=tls
<<<<<<< HEAD
#MAIL_SENDER_ADDRESS=
#MAIL_SENDER_NAME=
#MAIL_ADMIN_ADDRESS=
#MAIL_DEV_ADDRESS=
#MAIL_SWAP_ADMIN_TO_DEV=True
FACEBOOK_APP_ID=
BASE_DOMAIN=${PROJECT}.web
COOKIE_VALIDATION_KEY=ogCtZNMnOLWhAKDp6x9dFNFc0iJo5wpI2
APP_DOMAIN=${PROJECT}.web
APP_URL=http://${PROJECT}.web
STATIC_DOMAIN=${PROJECT}.web
STATIC_URL=http://${PROJECT}.web
=======
#MAIL_SENDER_ADDRESS=thehub@youthmarketing.com
#MAIL_SENDER_NAME='The Hub'
#MAIL_ADMIN_ADDRESS=thehub@youthmarketing.com
#MAIL_DEV_ADDRESS=jeremy.litten@gmail.com,jon@linesandwaves.com
#MAIL_SWAP_ADMIN_TO_DEV=True
FACEBOOK_APP_ID=326108764242439
BASE_DOMAIN=thehub.web
COOKIE_VALIDATION_KEY=ogCtZNMnOLWhAKDp6x9dFNFc0iJo5wpI2
APP_DOMAIN=thehub.web
APP_URL=http://thehub.web
STATIC_DOMAIN=thehub.web
STATIC_URL=http://thehub.web
>>>>>>> getting rid of compromised credentials
EOF
	fi

fi

exec "$@"
