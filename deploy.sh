#!/bin/bash


function get_latest_db_dump() {
    BUCKET=$1
    FILENAME=${2:-latest.sql.gz}
    if [[ ! -f mysql-init-script/latest.sql.gz ]]; then
        echo "Building AWS CLI image..."
        read -d '' DOCKERFILE <<EOF
FROM alpine:latest

ENV PAGER='cat'
ENV HOME=/
WORKDIR $HOME

RUN apk add --update \
    python \
    groff \
    py2-pip

RUN pip install --upgrade pip && \
    pip install awscli

EOF

        echo "$DOCKERFILE" | docker build -f - .
        AWSID=$(echo "$DOCKERFILE" | docker build -f - . -q)
        echo "Downloading database dump from AWS..."
        docker run --rm -it -v "$PWD/mysql-init-script/:/mysql-init-script/" \
             -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
             -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
             -e AWS_DEFAULT_REGION=$AWS_REGION \
             $AWSID \
                 aws s3 cp s3://$BUCKET/$FILENAME /mysql-init-script/$FILENAME
    fi
}

function git_clone() {
    if [[ ! -d src/ ]]; then
        echo "Cloning $REPOSITORY"
        mkdir src/
        git clone $1 src/
    fi
}

#function configure_wordpress() {
#        read -r -d '' SCRIPT <<- EOF
#sed 's/\r//' < ./src/wp-config-sample.php | \
#sed "s/define('DB_NAME'.*/define('DB_NAME', getenv('MYSQL_DATABASE'));/" | \
#sed "s/define('DB_USER'.*/define('DB_NAME', getenv('MYSQL_USERNAME'));/" | \
#sed "s/define('DB_PASSWORD'.*/define('DB_PASSWORD', getenv('MYSQL_PASSWORD'));/" | \
#sed "s/define('DB_HOST'.*/define('DB_HOST', getenv('MYSQL_HOST'));/" | \
#sed "/^\/\*.*stop editing.*\*\/$/i if (isset(\\\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \\\$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {\n    \\\$_SERVER['HTTPS'] = 'on';\n}" | \
#sed "/^\/\*.*stop editing.*\*\/$/i define( 'WP_HOME', 'http://' . \\\$_SERVER['HTTP_HOST'] . '/');" | \
#sed "/^\/\*.*stop editing.*\*\/$/i define( 'WP_SITEURL', 'http://' . \\\$_SERVER['HTTP_HOST'] . '/');" > src/wp-config.php
#EOF
#
#
#    echo "$SCRIPT"
#    echo $SCRIPT | docker run --rm -i -v "$PWD/src/:/src/" bash:latest 
#    exit
#}

function display_usage {
    echo "Usage:"
    echo "    $0 ( development | staging ) ( prepare | up | down )"
    exit 1;
}

set -a

case $1 in
    development|staging)
        SUFFIX=$1
        ;;
    *)
        display_usage
        ;;
esac

source "config.$SUFFIX"
MYSQL_CONTAINER="$PROJECT-$SUFFIX-mysql"
APP_CONTAINER="$PROJECT-$SUFFIX-app"

if [[ $MYSQL_DOCKERFILE ]]; then
     MYSQL_IMAGE=$MYSQL_CONTAINER
fi

if [[ $APP_DOCKERFILE ]]; then
     APP_IMAGE=$APP_CONTAINER
fi

if [[ -z $USERID ]]; then
    USERID=$(id -u)
fi

if [[ -z $GROPID ]]; then
    GROUPID=$(id -g)
fi

case $2 in
    prepare)
        git_clone $REPOSITORY
        get_latest_db_dump $BUCKET

        if [[ $MYSQL_DOCKERFILE ]]; then
            envsubst < $MYSQL_DOCKERFILE | \
                docker build -f - -t $MYSQL_IMAGE . || exit 1
        fi

        if [[ $APP_DOCKERFILE ]]; then
            envsubst < $APP_DOCKERFILE | \
                docker build -f - \
                    --build-arg USERID=$USERID \
                    --build-arg GROUPID=$GROUPID \
                    -t $APP_IMAGE . || exit 1
        fi

        if [[ ! -d log/apache2 ]]; then
             mkdir -p log/apache2
        fi
        if [[ ! -d log/mysql ]]; then
             mkdir -p log/mysql
        fi

        touch log/apache2/access.log
        touch log/apache2/error.log
        touch log/mysql/error.log

        ;;
    down)
        envsubst < docker-compose.yml | docker-compose -f - ${*:2}
        ;;
    up)
        if [[ ! -e ./src/wp-config.php && -e ./src/wp-config-sample.php ]]; then
            envsubst < docker-compose.yml | docker-compose -f - run --rm \
                -v "$PWD/wordpress-setup.sh:/usr/bin/wordpress-setup.sh" \
                -v "$PWD/src:/var/www/html" \
                webapp bash /usr/bin/wordpress-setup.sh
        fi
        envsubst < docker-compose.yml | docker-compose -f - ${*:2}
        ;;
    *)
        display_usage
        ;;
esac
