#!/bin/bash

set -euo pipefail

cd /var/www/html

yarn install
yarn build:prod
yarn global add nodemon

exec "$@"
