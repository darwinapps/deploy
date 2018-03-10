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
     if [[ ! -e $MYSQL_DOCKERFILE ]]; then
         echo "MYSQL's Dockerfile '$MYSQL_DOCKERFILE' does not exist"
         exit 1
     fi
     MYSQL_IMAGE=$MYSQL_CONTAINER
fi

if [[ $APP_DOCKERFILE ]]; then
     if [[ ! -e $APP_DOCKERFILE ]]; then
         echo "App's Dockerfile '$APP_DOCKERFILE' does not exist"
         exit 1
     fi
     APP_IMAGE=$APP_CONTAINER
else
    if [[ -z $APP_IMAGE ]]; then
        case $APP_TYPE in
            wordpress)
                APP_DOCKERFILE="Dockerfile.wordpress"
                APP_IMAGE=$APP_CONTAINER
                ;;
            *)
                echo "Unsupported project type $TYPE"
                exit 1
                ;;
        esac
    fi
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
        envsubst < docker-compose.yml | docker-compose -f - ${*:2}
        ;;
    run)
        envsubst < docker-compose.yml | docker-compose -f - run --rm webapp ${*:3}
        ;;
    exec)
        envsubst < docker-compose.yml | docker-compose -f - exec webapp ${*:3}
        ;;
    *)
        display_usage
        ;;
esac
