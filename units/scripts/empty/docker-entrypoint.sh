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



exec "$@"
