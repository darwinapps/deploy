#!/bin/bash

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


export CRAFT_DB_SERVER=$MYSQL_HOST
export CRAFT_DB_USER=$MYSQL_USER
export CRAFT_DB_PASSWORD=$MYSQL_PASSWORD
export CRAFT_DB_NAME=$MYSQL_DATABASE
export CRAFT_DB_PORT=$MYSQL_PORT
exec "$@"

