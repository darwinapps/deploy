#!/bin/bash


function get_aws_cli() {
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

    echo "$DOCKERFILE" | docker build -f - . -q
}

function get_latest_db_dump() {
    BUCKET=$1
    FILENAME=${2:-latest.sql.gz}
    if [[ ! -f mysql-init-script/latest.sql.gz ]]; then
        AWSID=$(get_aws_cli)
        echo "Downloading database dump from AWS..."
        docker run --rm -it -v "$PWD/mysql-init-script/:/mysql-init-script/" \
             -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
             -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
             -e AWS_DEFAULT_REGION=$AWS_REGION \
             $AWSID \
                 aws s3 cp s3://$BUCKET/$FILENAME /mysql-init-script/$FILENAME
    fi
}

function upload_dump() {
    BUCKET=$1
    FILENAME=$2
    AWSID=$(get_aws_cli)
    echo "Uploading $FILENAME to AWS..."

    docker run --rm -it -v "$PWD/backup/:/backup/" \
             -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
             -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
             -e AWS_DEFAULT_REGION=$AWS_REGION \
             $AWSID \
                 aws s3 cp /backup/$FILENAME s3://$BUCKET/$FILENAME

    docker run --rm -it -v "$PWD/backup/:/backup/" \
             -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
             -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
             -e AWS_DEFAULT_REGION=$AWS_REGION \
             $AWSID \
                 aws s3 cp /backup/$FILENAME s3://$BUCKET/latest.sql.gz
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
    echo "    $0 ( prepare | up | down | mysqldump | upload )"
    exit 1;
}

set -a

source ./config
MYSQL_CONTAINER="$PROJECT-mysql"
APP_CONTAINER="$PROJECT-app"

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

case $1 in
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
    mysqldump|upload)
        if [[ ! -d backup ]]; then
            mkdir backup
        fi 
        FILENAME=$MYSQL_CONTAINER-$(date +%Y-%m-%d.%H:%M:%S).sql.gz
        if [[ $(docker ps -f id=$(envsubst < docker-compose.yml | docker-compose -f - ps -q mysql) -q) != ""  ]]; then
            envsubst < docker-compose.yml | docker-compose -f - exec -T mysql mysqldump -uroot $MYSQL_DATABASE | gzip - > backup/$FILENAME
        else
            echo "MYSQL container is not running"
            exit 1
        fi

        if [[ $1 == "upload" ]]; then
            upload_dump $BUCKET $FILENAME
        fi
        ;;
    *)
        display_usage
        ;;
esac
