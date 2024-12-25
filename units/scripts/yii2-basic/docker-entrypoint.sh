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
	
	if [ ! -e $APP_ROOT/.env ]; then
		cat <<EOF > $APP_ROOT/.env
YII_DEBUG=${DEBUG}
YII_ENV=dev

MYSQL_HOST=${MYSQL_HOST}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
EOF
	fi

        if [ -e /tmp/config ]; then
            source /tmp/config
        fi
        if [[ $(declare -F postdatabaseup) ]]; then
            echo "running postdatabaseup function";
            maxcounter=45
 
            counter=1
            echo "waiting for database to start";
            while ! mysql --protocol TCP -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h"$MYSQL_HOST" -e "show databases;" > /dev/null 2>&1; do
                sleep 1
                counter=`expr $counter + 1`
                if [ $counter -gt $maxcounter ]; then
                    >&2 echo "We have been waiting for MySQL too long already; failing."
                    exit 1
                fi;
            done
            echo "Database is up!";
            postdatabaseup
        fi

fi

exec "$@"
