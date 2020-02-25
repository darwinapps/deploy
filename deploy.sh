#!/bin/bash

LOGFILE="debug.log"
if [[ $1 == '-v' ]]; then
   LOGFILE=/dev/stdout
   shift
fi

function delay()
{
    sleep 0.1;
}

CURRENT_PROGRESS=0
function progress()
{
    if [[ $LOGFILE == /dev/stdout ]]; then return; fi

    PARAM_PROGRESS=$1;
	PARAM_PHASE=$( printf "%-60s%-4s"  "${2:0:60}");
	
    if [ $CURRENT_PROGRESS -le 0 -a $PARAM_PROGRESS -ge 0 ]  ; then echo -ne "[..........................] (0%)  $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 5 -a $PARAM_PROGRESS -ge 5 ]  ; then echo -ne "[#.........................] (5%)  $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 10 -a $PARAM_PROGRESS -ge 10 ]; then echo -ne "[##........................] (10%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 15 -a $PARAM_PROGRESS -ge 15 ]; then echo -ne "[###.......................] (15%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 20 -a $PARAM_PROGRESS -ge 20 ]; then echo -ne "[####......................] (20%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 25 -a $PARAM_PROGRESS -ge 25 ]; then echo -ne "[#####.....................] (25%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 30 -a $PARAM_PROGRESS -ge 30 ]; then echo -ne "[######....................] (30%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 35 -a $PARAM_PROGRESS -ge 35 ]; then echo -ne "[#######...................] (35%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 40 -a $PARAM_PROGRESS -ge 40 ]; then echo -ne "[########..................] (40%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 45 -a $PARAM_PROGRESS -ge 45 ]; then echo -ne "[#########.................] (45%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 50 -a $PARAM_PROGRESS -ge 50 ]; then echo -ne "[##########................] (50%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 55 -a $PARAM_PROGRESS -ge 55 ]; then echo -ne "[###########...............] (55%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 60 -a $PARAM_PROGRESS -ge 60 ]; then echo -ne "[############..............] (60%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 65 -a $PARAM_PROGRESS -ge 65 ]; then echo -ne "[#############.............] (65%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 70 -a $PARAM_PROGRESS -ge 70 ]; then echo -ne "[###############...........] (70%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 75 -a $PARAM_PROGRESS -ge 75 ]; then echo -ne "[#################.........] (75%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 80 -a $PARAM_PROGRESS -ge 80 ]; then echo -ne "[####################......] (80%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 85 -a $PARAM_PROGRESS -ge 85 ]; then echo -ne "[#######################...] (85%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 90 -a $PARAM_PROGRESS -ge 90 ]; then echo -ne "[##########################] (100%) $PARAM_PHASE \r" ; delay; fi;
    if [ $CURRENT_PROGRESS -le 100 -a $PARAM_PROGRESS -ge 100 ];then echo -ne 'Done!                                                             \r\n' ; delay; fi;

    CURRENT_PROGRESS=$PARAM_PROGRESS;

} > /dev/tty


{

set -o pipefail

function get_aws_cli {
    DOCKERFILE='
FROM debian:stable-slim

ENV DEBIAN_FRONTEND noninteractive

ARG USERID
ARG GROUPID

RUN groupadd -g $GROUPID mapped || groupmod -n mapped $(getent group $GROUPID | cut -d: -f1)
RUN useradd \
      --uid $USERID \
      --gid $GROUPID \
      --home-dir / \
      mapped

WORKDIR /

RUN apt-get update && apt-get install -y \
    python \
    wget
    
RUN wget https://bootstrap.pypa.io/get-pip.py && python get-pip.py

RUN pip install --upgrade pip && \
    pip install awscli

USER mapped
'
    echo "$DOCKERFILE" | docker build -f - \
        --build-arg USERID=$USERID \
        --build-arg GROUPID=$GROUPID \
        . -q
}

function get_git_cli {
    REPOSITORY_KEY=$(echo "$1" | perl -pe 's/\n/\\n/g')

    DOCKERFILE="
FROM debian:stable-slim

ENV DEBIAN_FRONTEND noninteractive

ARG USERID
ARG GROUPID

RUN groupadd -g \$GROUPID mapped || groupmod -n mapped \$(getent group \$GROUPID | cut -d: -f1)
RUN useradd \
      --uid \$USERID \
      --gid \$GROUPID \
      --home-dir /git \
      mapped

WORKDIR /git

# install git
RUN apt-get -y update && apt-get -y install git

RUN echo -ne \"${REPOSITORY_KEY}\" > /id_rsa
RUN chown mapped: /id_rsa
RUN chmod 0600 /id_rsa

USER mapped
ENTRYPOINT [\"git\"]
"

    echo "$DOCKERFILE" | docker build -f - \
        --build-arg USERID=$USERID \
        --build-arg GROUPID=$GROUPID \
        . -q
}

function get_terminus_cli {
    DOCKERFILE='
FROM php:7.0-cli

ENV DEBIAN_FRONTEND noninteractive

ARG USERID
ARG GROUPID

RUN groupadd -g $GROUPID mapped || groupmod -n mapped $(getent group $GROUPID | cut -d: -f1)
RUN useradd \
      --uid $USERID \
      --gid $GROUPID \
      --home-dir / \
      mapped

WORKDIR /

RUN apt-get update
RUN apt-get install -y \
    curl \
    unzip \
    ssh

RUN curl -O https://raw.githubusercontent.com/pantheon-systems/terminus-installer/master/builds/installer.phar && php installer.phar install

USER mapped
'

    echo "$DOCKERFILE" | docker build -f - \
        --build-arg USERID=$USERID \
        --build-arg GROUPID=$GROUPID \
        . -q
}


function get_latest_files_from_aws {
    FILENAME=${1:-files.tgz}
    if [[ ! -f remote-files/latest.tgz ]]; then
        if [[ ! -d remote-files/ ]]; then
            mkdir remote-files/
        fi

        AWSID=$(get_aws_cli)
        echo "Downloading files from AWS..."
        docker run --rm -it -v "$PWD/remote-files/:/remote-files/" \
            -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
            -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
            -e AWS_DEFAULT_REGION=$AWS_REGION \
            $AWSID \
                aws s3 cp s3://$BUCKET/$FILENAME /remote-files/latest.tgz
    fi
}

function get_latest_files_from_pantheon {
    FILENAME=${1:-latest.tgz}
    if [[ ! -f remote-files/latest.tgz ]]; then
        if [[ ! -d remote-files/ ]]; then
            mkdir remote-files/
        fi
        TERMINUSID=$(get_terminus_cli)
        docker run --rm -it -e HOME=/tmp -v "$PWD/remote-files/:/remote-files/" \
            $TERMINUSID bash -c "terminus auth:login --machine-token=$PANTHEON_MACHINE_TOKEN && echo \"Downloading files ...\" && terminus -v backup:get $PANTHEON_SITE_NAME --element=files --to=/remote-files/latest.tgz"
    fi
}

function get_latest_db_dump_pantheon {
    FILENAME=${1:-latest.sql.gz}
    TERMINUSID=$(get_terminus_cli)
    docker run --rm -it -e HOME=/tmp -v "$PWD/mysql-init-script/:/mysql-init-script/" \
        $TERMINUSID bash -c "terminus auth:login --machine-token=$PANTHEON_MACHINE_TOKEN && echo \"Downloading database ...\" && terminus -v backup:get $PANTHEON_SITE_NAME --element=db --to=/mysql-init-script/latest.sql.gz"
}

function get_latest_db_dump_wpengine {
    FILENAME=${1:-latest.sql}

    # username:password@hostname:port
    IFS=@ read -r USERNAMEPASSWORD HOSTPORTPATH <<< "${WPENGINE_SFTP}"
    IFS=: read -r PROTO USERNAME PASSWORD <<< "${USERNAMEPASSWORD}"
    IFS=/ read -r HOSTPORT JUNK<<< "$HOSTPORTPATH"
    DBDUMP_URI="${PROTO}:${USERNAME}@${HOSTPORT}/wp-content/mysql.sql"

    echo "Downloading database dump from WPENGINE..."
    /usr/bin/expect <<EOD
        log_user 0
        set timeout 300
        spawn sftp -o StrictHostKeyChecking=no  -q $DBDUMP_URI mysql-init-script/$FILENAME
        expect "password:" { send "${PASSWORD}\n" }
        expect eof
EOD

    gzip mysql-init-script/$FILENAME
}

function get_latest_db_dump_generic_ssh {
    FILENAME=${1:-latest.sql.gz}

    # username:password@hostname:port
    IFS=@ read -r USERNAMEPASSWORD HOSTPORTPATH <<< "${GENERIC_SSH}"
    IFS=: read -r USERNAME PASSWORD <<< "${USERNAMEPASSWORD}"
    IFS=/ read -r HOSTPORT JUNK<<< "$HOSTPORTPATH"
    IFS=: read -r HOST PORT <<< "${HOSTPORT}"

    # username:password@hostname:port/database
    IFS=@ read -r _MYSQL_USERNAMEPASSWORD _MYSQL_HOSTPORTPATH <<< "${REMOTE_MYSQL}"
    IFS=: read -r _MYSQL_USERNAME _MYSQL_PASSWORD <<< "${_MYSQL_USERNAMEPASSWORD}"
    IFS=/ read -r _MYSQL_HOSTPORT _MYSQL_PATH <<< "${_MYSQL_HOSTPORTPATH}"
    IFS=: read -r _MYSQL_HOST _MYSQL_PORT <<< "${_MYSQL_HOSTPORT}"

    echo "Downloading database dump from generic SSH..."
    # ssh -p $PORT $USERNAME@$HOST mysqldump -u"${_MYSQL_USERNAME}" -p"${_MYSQL_PASSWORD}" -h"${_MYSQL_HOST}" -P"${_MYSQL_PORT}" "${_MYSQL_PATH}" \
    #     | gzip > mysql-init-script/$FILENAME

    /usr/bin/expect <<EOD
        set timeout 300
        spawn ssh -o StrictHostKeyChecking=no -p $PORT $USERNAME@$HOST mysqldump -u"${_MYSQL_USERNAME}" -p"${_MYSQL_PASSWORD}" -h"${_MYSQL_HOST}" -P"${_MYSQL_PORT}" "${_MYSQL_PATH}" \
              | gzip > $FILENAME
        expect "password:" { send "${PASSWORD}\r" }
        expect eof
EOD

    /usr/bin/expect <<EOD
        set timeout 300
        spawn rsync -e "ssh -o StrictHostKeyChecking=no -p $PORT" --remove-source-files $USERNAME@$HOST:$FILENAME mysql-init-script/$FILENAME
        expect "password:" { send "${PASSWORD}\r" }
        expect eof
EOD
}

function get_latest_db_dump_aws {
    FILENAME=${1:-latest.sql.gz}
    AWSID=$(get_aws_cli)
    echo "Downloading database dump from AWS..."
    docker run --rm -it -v "$PWD/mysql-init-script/:/mysql-init-script/" \
         -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
         -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
         -e AWS_DEFAULT_REGION=$AWS_REGION \
         $AWSID \
             aws s3 cp s3://$BUCKET/$FILENAME /mysql-init-script/$FILENAME
}

function get_latest_db_dump {
    if [[ ! -f mysql-init-script/latest.sql.gz ]]; then
        if [[ ! -d mysql-init-script/ ]]; then
            mkdir mysql-init-script/
        fi
        if [[ $BUCKET ]]; then
            get_latest_db_dump_aws
        elif [[ $PANTHEON_SITE_NAME ]]; then
            get_latest_db_dump_pantheon
        elif [[ $GENERIC_SSH && $REMOTE_MYSQL ]]; then
            get_latest_db_dump_generic_ssh
        elif [[ $WPENGINE_SFTP ]]; then
            get_latest_db_dump_wpengine
        fi
    fi
}

function upload_dump {
    BUCKET=$1
    FILENAME=$2
    AWSCLI=$(get_aws_cli)
    echo "Uploading $FILENAME to AWS..."

    docker run --rm -it -v "$PWD/backup/:/backup/" \
             -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
             -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
             -e AWS_DEFAULT_REGION=$AWS_REGION \
             $AWSCLI \
                 aws s3 cp /backup/$FILENAME s3://$BUCKET/$FILENAME

    docker run --rm -it -v "$PWD/backup/:/backup/" \
             -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
             -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
             -e AWS_DEFAULT_REGION=$AWS_REGION \
             $AWSCLI \
                 aws s3 cp /backup/$FILENAME s3://$BUCKET/latest.sql.gz
}

function gitcmd {
    if [[ $REPOSITORY_KEY != "" ]]; then
        GIT=$(get_git_cli "$REPOSITORY_KEY")
        docker run -ti --rm -v $PWD:/git -e GIT_SSH_COMMAND='ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i /id_rsa' $GIT "$@"
    else
        git "$@"
    fi
}

function extract_remote_files {
    DIR=$1
    STRIP=${2:0}
    if [[ -f remote-files/latest.tgz ]] && [[ $DIR ]]; then
        [[ ! -d webroot/$DIR ]] && mkdir -p webroot/$DIR
        echo "Unpacking files ..."
        tar xf remote-files/latest.tgz -C webroot/$DIR $( [[ $STRIP -gt 0 ]] && echo "--strip-components=$STRIP" ) 
    fi
}

function self_update {
    # self-update
    echo "Checking for a new version of me..."
    git fetch
    if [[ -n $(git diff --name-only origin/master) ]]; then
        echo "Found a new version of me, updating..."
        git reset --hard origin/master
        echo "Restarting..."
        if [[ $LOGFILE == /dev/stdout ]]; then 
            exec "$0" "-v" "$@"
        else
            exec "$0" "$@"
        fi 
        exit 1
    fi
}

function display_usage {
    echo "Usage:"
    echo "    $0 ( prepare | down | up | status | run | su-run | exec | git | dump-database | sync-database | sync-files | upload | clean | realclean )"
    exit 1;
}

set -a

USERID=$(id -u)
GROUPID=$(id -g)

if [[ $USERID == "0" ]]; then
    echo "Running as root is not supported. Please run the following command to add user to the docker group:"
    echo "    \$ sudo usermod -aG docker \$USER"
    exit 1;
fi


[[ ! -f ./config ]] && echo "No config file found. Exiting ..." && exit 1;

source ./config

[[ -z "${WORDPRESS_TABLE_PREFIX}" ]] && WORDPRESS_TABLE_PREFIX=""

[[ -z "${PHP_SHORT_OPEN_TAG}" ]] && PHP_SHORT_OPEN_TAG="Off"

MYSQL_CONTAINER="$PROJECT-mysql"
MYSQL_IMAGE=$MYSQL_CONTAINER
MYSQL_DOCKERFILE=${MYSQL_DOCKERFILE:-Dockerfile.mysql}
MYSQL_BASE_IMAGE=${MYSQL_BASE_IMAGE:-mysql:5.6}

APP_CONTAINER="$PROJECT-app"
APP_IMAGE=$APP_CONTAINER
APP_DOCKERFILES=("Dockerfile.app")
APP_BASE_IMAGE=${APP_BASE_IMAGE:-php:7.2-apache}

if [[ -e "Dockerfile.${APP_TYPE}" ]]; then
    APP_DOCKERFILES+=("Dockerfile.${APP_TYPE}")
fi
APACHE_DOCUMENT_ROOT=/var/www/html/${APP_ROOT%/}

DOCKER_COMPOSE_ARGS=("-f" "docker-compose.yml")

if [[ $MYSQL_PORT_MAP ]]; then
     if [[ ! $MYSQL_PORT ]]; then
        IFS=: read -r MYSQL_EXTERNAL_PORT MYSQL_PORT <<< "$MYSQL_PORT_MAP"
     fi
     DOCKER_COMPOSE_ARGS+=("-f" "docker-compose-mysql.yml")
fi
MYSQL_PORT=${MYSQL_PORT:-3306}

if [[ $APP_PORT_MAP ]]; then
     DOCKER_COMPOSE_ARGS+=("-f" "docker-compose-app.yml")
fi

if [[ $APP_NETWORK ]]; then
     DOCKER_COMPOSE_ARGS+=("-f" "docker-compose-app-network.yml")
fi

if [[ -e "docker-compose.${PROJECT}.yml" ]]; then
     DOCKER_COMPOSE_ARGS+=("-f" "docker-compose.${PROJECT}.yml")
fi

case $1 in
    prepare)
        progress 10 Initialize
        self_update "$@"

        if [[ $(declare -F preinstall) ]]; then
            echo "running preinstall function";
            preinstall
        fi

        if [[ $MYSQL_DOCKERFILE ]]; then
            docker pull ${MYSQL_BASE_IMAGE}
            docker --log-level "error" build \
                --build-arg MYSQL_BASE_IMAGE=$MYSQL_BASE_IMAGE \
                --build-arg USERID=$USERID \
                --build-arg GROUPID=$GROUPID \
                -f $MYSQL_DOCKERFILE \
                -t $MYSQL_IMAGE . || exit 1
        fi
        progress 10 "docker pull"
        docker pull ${APP_BASE_IMAGE}
        progress 20 "docker build"
        cat ${APP_DOCKERFILES[@]} | docker --log-level "error" build \
            --build-arg APP_BASE_IMAGE=$APP_BASE_IMAGE \
            --build-arg USERID=$USERID \
            --build-arg GROUPID=$GROUPID \
            --build-arg PROJECT=$PROJECT \
            --build-arg APP_TYPE=$APP_TYPE \
            --build-arg APACHE_DOCUMENT_ROOT=$APACHE_DOCUMENT_ROOT \
            --build-arg PHP_SHORT_OPEN_TAG=$PHP_SHORT_OPEN_TAG \
            -f - \
            -t $APP_IMAGE . || exit 1
        progress 70 "Get latest DB Dump"
        get_latest_db_dump

        if [[ $PANTHEON_SITE_NAME ]] && [[ $FILES_DIR ]]; then
            get_latest_files_from_pantheon
        elif [[ $FILES_DIR ]]; then
            get_latest_files_from_aws
        fi
	
        if [[ $REPOSITORY ]] &&[[ ! -d webroot/.git ]]; then
            gitcmd clone --recurse-submodules $REPOSITORY webroot/
            (cd webroot/ && gitcmd submodule update --init --recursive)
        fi


        if [[ $(declare -F postinstall) ]]; then
            echo "running postinstall function";
            docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} -f docker-compose-app-user.yml \
                run --no-deps --rm webapp \
                    bash -c "source /tmp/config && HOME=/tmp && postinstall"

        fi
        progress 80 "Extract files"
        extract_remote_files $FILES_DIR $( [[ $PANTHEON_SITE_NAME ]] && echo 1 )
        progress 100 "Done"
        ;;
    down)
        progress 10 "Shutting down"
        docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} $@
        progress 100 "Done"
        ;;
    up)
        [[ $2 == "-d" ]] || progress 10 "Self update"
        self_update "$@"
        if [[ ! -d data/db ]]; then
            mkdir -p data/db/
        fi
        [[ $2 == "-d" ]] || progress 20 "Check git tracked"
        if [[ ! -d webroot/.git ]]; then
            echo "Content in your webroot is not tracked by git"
        fi
        if [[ ! -d log/apache2 ]]; then
             mkdir -p log/apache2
        fi
        [[ $2 == "-d" ]] || progress 50 "Setting up apache/mysql logs.."
        # error.log might be created as directory if not exists and mounted by docker-compose
        if [[ ! -f log/apache2/error.log ]]; then
            rm -rf log/apache2/error.log
            touch log/apache2/error.log
        fi
        # access.log might be created as directory if not exists and mounted by docker-compose
        if [[ ! -f log/apache2/access.log ]]; then
            rm -rf log/apache2/access.log
            touch log/apache2/access.log
        fi

        if [[ ! -d log/mysql ]]; then
             mkdir -p log/mysql
        fi
        # error.log might be created as directory if not exists and mounted by docker-compose
        if [[ ! -f log/mysql/error.log ]]; then
            rm -rf log/mysql/error.log
            touch log/mysql/error.log
        fi


        [[ $2 == "-d" ]] || progress 90 "Wait 2-3 min. Exit: ctrl+c"
        [[ $2 == "-d" ]] || progress 95 "\n"	

        docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} $@
        ;;
    status)
        docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} ps > /dev/tty
        ;;
    run)
        docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} run --no-deps --rm webapp su mapped -c "HOME=/tmp; ${*:2}" > /dev/tty
        ;;
    su-run)
        docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} run --no-deps --rm webapp "${@:2}" > /dev/tty
        ;;	
    exec)
        docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} exec webapp ${*:2} > /dev/tty
        ;;
    git)
        gitcmd -C webroot/ ${*:2} > /dev/tty
        ;;
    dump-database)
        if [[ $(docker ps -f id=$(docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} ps -q mysql) -q) != ""  ]]; then
            docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} exec -T mysql mysqldump -uroot $MYSQL_DATABASE "${@:2}" > /dev/tty
        else
            echo "MYSQL container is not running"
            exit 1
        fi
        ;;
    sync-database)
        rm -rf data/
        rm -rf mysql-init-script/
        get_latest_db_dump
        ;;
    sync-files)
        if [[ $PANTHEON_SITE_NAME ]] && [[ $FILES_DIR ]]; then
            rm -rf remote-files/
            get_latest_files_from_pantheon
            extract_remote_files $FILES_DIR 1
        elif [[ $FILES_DIR ]]; then
            rm -rf remote-files/
            get_latest_files_from_aws
            extract_remote_files $FILES_DIR
        fi
        ;;
    upload)
        if [[ ! -d backup ]]; then
            mkdir backup
        fi 
        FILENAME=$MYSQL_CONTAINER-$(date +%Y-%m-%d.%H:%M:%S).sql.gz
        if [[ $(docker ps -f id=$(docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} ps -q mysql) -q) != ""  ]]; then
            docker-compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} exec -T mysql mysqldump -uroot $MYSQL_DATABASE | gzip - > backup/$FILENAME
        else
            echo "MYSQL container is not running"
            exit 1
        fi
        upload_dump $BUCKET $FILENAME
        ;;
    clean)
        cat .gitignore | grep -v 'webroot' | grep -v '/config' | sed -e 's#^/#.//#' | xargs rm -rf
        ;;
    realclean)
        cat .gitignore | sed -e 's#^/#./#' | grep -v '/config' | xargs rm -rf
        ;;
    *)
        display_usage
        ;;

esac

} >> $LOGFILE 2>&1
