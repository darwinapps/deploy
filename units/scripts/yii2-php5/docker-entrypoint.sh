#!/bin/bash

set -euo pipefail

if [[ "$1" == apache2* ]] || [[ "$1" == php-fpm* ]]; then
	if [ "$(id -u)" = '0' ]; then
		user="${APACHE_RUN_USER:-www-data}"
		group="${APACHE_RUN_GROUP:-www-data}"
	else
		user="$(id -u)"
		group="$(id -g)"
	fi
fi

exec "$@"
