#!/bin/bash

export CRAFT_DB_SERVER=$MYSQL_HOST
export CRAFT_DB_USER=$MYSQL_USER
export CRAFT_DB_PASSWORD=$MYSQL_PASSWORD
export CRAFT_DB_NAME=$MYSQL_DATABASE
export CRAFT_DB_PORT=$MYSQL_PORT
exec "$@"

