#!/bin/bash

# ps auxww
# echo $@
# export

set -euo pipefail

if [[ "$1" == apache2* ]] || [[ "$1" == php-fpm* ]]; then
	if [ "$(id -u)" = '0' ]; then
		user="${APACHE_RUN_USER:-www-data}"
		group="${APACHE_RUN_GROUP:-www-data}"
	else
		user="$(id -u)"
		group="$(id -g)"
	fi

	settingsf="${WEB_DOCUMENT_ROOT}/sites/default/settings.php";
	if [ ! -f $settingsf ]; then
		cp -a ${WEB_DOCUMENT_ROOT}/sites/default/default.settings.php $settingsf
		if [ ! -z "${DEBUG:-}" ]; then
			echo -e "\$conf['theme_debug'] = TRUE;\n" >> $settingsf
		fi

    echo -e "\n"\
"\$local_settings = __DIR__ . '/settings.local.php';\n" \
"if (file_exists(\$local_settings)) {\n" \
"  include \$local_settings;\n" \
"}\n"  >> $settingsf

		echo -e "\$settings['hash_salt'] = \"Dq7Y_ipY3UsSdf23q5VsQuJa2OIjuOicQ_zOumlF4gQsb9Hvh1WW_a5-55IskNO0GibY26aBKQ\";\n\n" >> $settingsf

		chown "$user:$group" $settingsf;
	fi

fi


exec "$@"