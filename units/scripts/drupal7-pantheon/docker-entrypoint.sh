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

	settingsf="${WEB_DOCUMENT_ROOT}/sites/default/local.settings.php";
	if [ ! -f $settingsf ]; then
		echo -e "<?php\n" > $settingsf;
		if [ ! -z "${DEBUG:-}" ]; then
			echo -e "\$conf['theme_debug'] = TRUE;\n" >> $settingsf
		fi
		echo -e "\$databases['default']['default'] = array(\n" \
			"  'driver' => 'mysql',\n" \
			"  'database' => '${MYSQL_DATABASE}',\n" \
			"  'username' => '${MYSQL_USER}',\n" \
			"  'password' => '${MYSQL_PASSWORD}',\n" \
			"  'host' => '${MYSQL_HOST}',\n" \
			"  'collation' => 'utf8_general_ci',\n" \
			");\n\n" \
			"if (!class_exists('DrupalFakeCache')) {\n" \
			"    \$conf['cache_backends'][] = 'includes/cache-install.inc';\n" \
			"}\n" \
			"// Default to throwing away cache data.\n" \
			"\$conf['cache_default_class'] = 'DrupalFakeCache';\n" \
			"// Rely on the DB cache for form caching - otherwise forms fail.\n" \
			"\$conf['cache_class_cache_form'] = 'DrupalDatabaseCache';\n" >> $settingsf
		chown "$user:$group" $settingsf;
	fi

fi

exec "$@"
