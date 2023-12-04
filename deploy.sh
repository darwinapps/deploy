#!/bin/bash

exec 3>&1

# Clearing all these variables occurs because when the script is restarted (self_update), these variables contain data from the first run
MYSQL_DOCKERFILE=""; MYSQL_BASE_IMAGE=""; MYSQL_PORT=""
MYSQL_INNODB_LOG_FILE_SIZE=""; APP_TYPE=""; AWS_FILENAME_DB=""; AWS_FILENAME_FILES=""
APACHE_IMAGE=""
###


# Load environment variables from .env file
if [[ ! -f .env ]]; then echo >&3; echo "No .env file found. Exiting..." >&3; exit 1; fi
for variable_str in $(grep -v '#.*' .env); do
    eval $variable_str
    export $(echo $variable_str | sed 's/=.*//')
done

LOGFILE=""
if [[ $1 == '-v' || $1 == 'dump-database' ]]; then
    if [[ $1 == '-v' ]]; then shift; fi
else LOGFILE="${DIR_WORK}/debug.log"; exec &>$LOGFILE
fi


function self_update {
    if [[ $SELFUPDATE == 'off' || $SELFUPDATE == 'OFF' ]]; then echo_red 'Self update off'; return; fi
    # return
    #self-update
    local CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
    echo_green "Checking for a new version of me..."
    git fetch
    if [[ -n $(git diff --name-only origin/$CURRENT_BRANCH) ]]; then
       echo_blue "Found a new version of me, updating..."
       git reset --hard origin/$CURRENT_BRANCH
       echo_blue "Restarting..."
       if [ -z "$LOGFILE" ]; then
           exec "$0" "-v" "$@"
       else
           exec "$0" "$@"
       fi
       exit 1
    fi
}

function project_git_submodule_update {
    if ! (git submodule update $GIT_MODUL); then git submodule deinit $GIT_MODUL; fi
    echo -ne "." >&3
}

function projects_configs_update {
    echo -ne "\nThe list of projects is being updated " >&3
    local WORKDIR=${PWD}
    cd $DIR_PROJECTS

    for GIT_MODUL in $(cat .gitmodules | grep path | sed 's!^.*path\s=\s!!g'); do
        git submodule init $GIT_MODUL > /dev/null 2>&1
        project_git_submodule_update > /dev/null 2>&1 &
    done
    wait

    echo

    cd $WORKDIR
}

function project_update {
    if [[ -f "$1/.git" ]]; then
        git --git-dir=$1/.git --work-tree=$1 checkout master > /dev/null 2>&1
        if [[ -n $(git --git-dir=$1/.git --work-tree=$1 diff --name-only origin/master) ]]; then
            echo_blue "\nFound a new version configuration file of project $SELECTED_PROJECT"
            git --git-dir=$1/.git --work-tree=$1 reset --hard origin/master
        fi
    fi

    if [[ -f $1/deploy-config.md ]]; then
        if [[ -f "$1/config" && -h "$1/config" ]]; then
            rm -f $1/config;
        fi

        sed '1,$ s/```//' $1/deploy-config.md > $1/config

        # sed -i '1,$ s/```//' $1/deploy-config.md > /dev/null 2>&1
        # ln -s ./deploy-config.md $1/config
    fi
}

function projects_update {
    if [[ ! -d "$DIR_PROJECTS" ]]; then mkdir $DIR_PROJECTS; fi

    local WORKDIR=${PWD}
    cd $DIR_PROJECTS

    if [[ ! -d ./.git ]]; then
        if ! (git clone $REPOSITORY_PROJECTS . > /dev/null 2>&1 ); then
            echo_red "\nPossible, you not have access to the git repository with configuration files of projects\n"
        fi
    else
        git fetch
        if [[ -n $(git diff --name-only origin/master) ]]; then
            echo_blue "\nFound a new versions configuration files of projects..."
            git reset --hard origin/master
        fi
    fi

    cd $WORKDIR

    # Search for the config in the root of the program and add it to the list of configs
    if [[ -f ./config ]]; then
        if [[ ! -d $DIR_PROJECTS/MyConfig ]]; then
            mkdir -p $DIR_PROJECTS/MyConfig
            ln -s ./../../config $DIR_PROJECTS/MyConfig/config
        fi
    fi
    ###

    if [[ -f $DIR_PROJECTS/.gitmodules ]]; then projects_configs_update; fi
}

function echo_green { printf "\e[1;32m${1}\n\e[0m"; }
function echo_blue  { printf "\e[1;34m${1}\n\e[0m"; }
function echo_red   { printf "\e[1;31m${1}\n\e[0m"; }

function delay()
{
    sleep 0.1;
}

CURRENT_PROGRESS=0
function progress()
{
    if [ -z "$LOGFILE" ]; then
        echo_green "$2...";
        return;
    fi

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

} >&3


#{

set -o pipefail

function get_aws_cli {
    DOCKERFILE='
FROM python:slim

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

RUN pip install awscli

USER mapped
'
    echo "$DOCKERFILE" | docker build -f - \
        --build-arg USERID=$USERID \
        --build-arg GROUPID=$GROUPID \
        -t aws_cli \
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
FROM php:7.4-cli

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

function get_latest_files_from_ssh {
    exit_code=0;
    if [[ ! -d $DIR_WEB/$FILES_DIR ]]; then mkdir -p $DIR_WEB/$FILES_DIR; fi
    progress 10 "Upload files synchronization from generic SSH"

    # username:password@hostname:port
    IFS=@ read -r USERNAMEPASSWORD HOSTPORTPATH <<< "${GENERIC_SSH}"
    IFS=: read -r USERNAME PASSWORD <<< "${USERNAMEPASSWORD}"
    IFS=/ read -r HOSTPORT JUNK<<< "$HOSTPORTPATH"
    IFS=: read -r HOST PORT <<< "${HOSTPORT}"

    if [[ -z ${PORT} ]]; then PORT=22; fi

    /usr/bin/expect <<EOD
        set timeout 3600
        spawn rsync -e "ssh -o StrictHostKeyChecking=no -p $PORT" --delete -av $USERNAME@$HOST:$RSYNC_DIR/ $DIR_WEB/$FILES_DIR
        expect "password:" {
            send "${PASSWORD}\r"
            expect eof
            }
        catch wait result
        exit [lindex \$result 3]
EOD

    if [[ $? != 0 ]]; then exit_code=1; fi

    # progress 100 "Done"

    return $exit_code
}

function get_latest_files_from_aws {
    FILENAME=${1:-files.tgz}
    if [[ ! -f $DIR_WORK/remote-files/latest.tgz ]]; then
        if [[ ! -d $DIR_WORK/remote-files/ ]]; then
            mkdir $DIR_WORK/remote-files/
        fi

        AWSID=$(get_aws_cli)
        echo_green "Downloading files from AWS..."
        docker run --rm -it -v "$PWD/$DIR_WORK/remote-files/:/remote-files/" \
            -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
            -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
            -e AWS_DEFAULT_REGION=$AWS_REGION \
            $AWSID \
                aws s3 cp s3://$BUCKET/$FILENAME /remote-files/latest.tgz
    fi
}

function get_latest_files_from_pantheon {
    FILENAME=${1:-latest.tgz}
    if [[ ! -f $DIR_WORK/remote-files/latest.tgz ]]; then
        if [[ ! -d $DIR_WORK/remote-files/ ]]; then
            mkdir $DIR_WORK/remote-files/
        fi
        TERMINUSID=$(get_terminus_cli)
        docker run --rm -it -e HOME=/tmp -v "$PWD/$DIR_WORK/remote-files/:/remote-files/" \
            $TERMINUSID bash -c "terminus auth:login --machine-token=$PANTHEON_MACHINE_TOKEN && echo \"Downloading files...\" && terminus -v backup:get $PANTHEON_SITE_NAME --element=files --to=/remote-files/latest.tgz"
    fi
}

function get_latest_db_dump_pantheon {
    FILENAME=${1:-latest.sql.gz}
    TERMINUSID=$(get_terminus_cli)
    docker run --rm -it -e HOME=/tmp -v "$PWD/$DIR_WORK/mysql-init-script/:/mysql-init-script/" \
        $TERMINUSID bash -c "terminus auth:login --machine-token=$PANTHEON_MACHINE_TOKEN && echo \"Downloading database...\" && terminus -v backup:get $PANTHEON_SITE_NAME --element=db --to=/mysql-init-script/latest.sql.gz"
}

function get_latest_db_dump_wpengine {
    FILENAME=${1:-latest.sql}

    # username:password@hostname:port
    IFS=@ read -r USERNAMEPASSWORD HOSTPORTPATH <<< "${WPENGINE_SFTP}"
    IFS=: read -r PROTO USERNAME PASSWORD <<< "${USERNAMEPASSWORD}"
    IFS=/ read -r HOSTPORT JUNK<<< "$HOSTPORTPATH"
    IFS=: read -r HOST PORT<<< "$HOSTPORT"
    DBDUMP_URI="${PROTO}:${USERNAME}@${HOSTPORT}/wp-content/mysql.sql"

    # Removes all keys belonging to the specified hostname from a known_hosts file
    ssh-keygen -f ~/.ssh/known_hosts -R "[$HOST]:$PORT" 2> /dev/null

    echo "Downloading database dump from WPENGINE..."

    /usr/bin/expect <<EOD
        log_user 0
        set timeout 300
        spawn sftp -o StrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -q $DBDUMP_URI $DIR_WORK/mysql-init-script/$FILENAME
        expect -re "(P|p)assword:" { send "${PASSWORD}\n" }
        expect eof
EOD

    gzip $DIR_WORK/mysql-init-script/$FILENAME
}

function get_latest_db_dump_generic_ssh {
    FILENAME=${1:-latest.sql.gz}

    # username:password@hostname:port
    IFS=@ read -r USERNAMEPASSWORD HOSTPORTPATH <<< "${GENERIC_SSH}"
    IFS=: read -r USERNAME PASSWORD <<< "${USERNAMEPASSWORD}"
    IFS=/ read -r HOSTPORT JUNK<<< "$HOSTPORTPATH"
    IFS=: read -r HOST PORT <<< "${HOSTPORT}"

    if [[ -z ${PORT} ]]; then PORT=22; fi

    # username:password@hostname:port/database
    IFS=@ read -r _MYSQL_USERNAMEPASSWORD _MYSQL_HOSTPORTPATH <<< "${REMOTE_MYSQL}"
    IFS=: read -r _MYSQL_USERNAME _MYSQL_PASSWORD <<< "${_MYSQL_USERNAMEPASSWORD}"
    IFS=/ read -r _MYSQL_HOSTPORT _MYSQL_PATH <<< "${_MYSQL_HOSTPORTPATH}"
    IFS=: read -r _MYSQL_HOST _MYSQL_PORT <<< "${_MYSQL_HOSTPORT}"

    echo_green "Downloading database dump from generic SSH..."
    # ssh -p $PORT $USERNAME@$HOST mysqldump -u"${_MYSQL_USERNAME}" -p"${_MYSQL_PASSWORD}" -h"${_MYSQL_HOST}" -P"${_MYSQL_PORT}" "${_MYSQL_PATH}" \
    #     | gzip > mysql-init-script/$FILENAME

    /usr/bin/expect <<EOD
        set timeout 3600
        spawn ssh -o StrictHostKeyChecking=no -p $PORT $USERNAME@$HOST mysqldump --no-tablespaces -u"${_MYSQL_USERNAME}" -p"${_MYSQL_PASSWORD}" -h"${_MYSQL_HOST}" -P"${_MYSQL_PORT}" "${_MYSQL_PATH}" \
              | gzip > $FILENAME
        expect "password:" {
            send "${PASSWORD}\r"
            expect eof
            }
EOD

    /usr/bin/expect <<EOD
        set timeout 3600
        spawn rsync -e "ssh -o StrictHostKeyChecking=no -p $PORT" --remove-source-files $USERNAME@$HOST:$FILENAME $DIR_WORK/mysql-init-script/$FILENAME
        expect "password:" {
            send "${PASSWORD}\r"
            expect eof
            }
EOD
}

function get_latest_db_dump_aws {
    FILENAME=${1:-latest.sql.gz}
    AWSID=$(get_aws_cli)
    echo_green "Downloading database dump from AWS..."
    docker run --rm -it -v "$PWD/$DIR_WORK/mysql-init-script/:/mysql-init-script/" \
         -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
         -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
         -e AWS_DEFAULT_REGION=$AWS_REGION \
         $AWSID \
             aws s3 cp s3://$BUCKET/$FILENAME /mysql-init-script/latest.sql.gz
}

function get_latest_db_dump {
    if [[ ! -f $DIR_WORK/mysql-init-script/latest.sql.gz ]]; then
        if [[ ! -d $DIR_WORK/mysql-init-script/ ]]; then
            mkdir $DIR_WORK/mysql-init-script/
        fi

        if [[ $PANTHEON_SITE_NAME ]]; then
            get_latest_db_dump_pantheon
        elif [[ $GENERIC_SSH && $REMOTE_MYSQL ]]; then
            get_latest_db_dump_generic_ssh
        elif [[ $WPENGINE_SFTP ]]; then
            get_latest_db_dump_wpengine
        elif [[ $BUCKET ]]; then
            get_latest_db_dump_aws $1
        fi
    fi
}

function upload_dump {
    BUCKET=$1
    FILENAME=$2
    AWSCLI=$(get_aws_cli)
    echo_green "Uploading $FILENAME to AWS..."

    docker run --rm -it -v "$PWD/$DIR_WORK/backup/:/backup/" \
             -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
             -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
             -e AWS_DEFAULT_REGION=$AWS_REGION \
             $AWSCLI \
                 aws s3 cp /backup/$FILENAME s3://$BUCKET/$FILENAME

    docker run --rm -it -v "$PWD/$DIR_WORK/backup/:/backup/" \
             -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
             -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
             -e AWS_DEFAULT_REGION=$AWS_REGION \
             $AWSCLI \
                 aws s3 cp /backup/$FILENAME s3://$BUCKET/latest.sql.gz
}

function gitcmd {
    if [[ $REPOSITORY_KEY != "" ]]; then
        GIT=$(get_git_cli "$REPOSITORY_KEY")
        docker run -ti --rm -v $PWD/$DIR_WORK:/git -e GIT_SSH_COMMAND='ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i /id_rsa' $GIT "$@"
    else
        git "$@"
    fi
}

function extract_remote_files {
    DIR=$1
    STRIP=${2:0}
    if [[ -f $DIR_WORK/remote-files/latest.tgz ]] && [[ $DIR ]]; then
        [[ ! -d $DIR_WEB/$DIR ]] && mkdir -p $DIR_WEB/$DIR
        echo_green "Unpacking files..."
        tar xf $DIR_WORK/remote-files/latest.tgz -C $DIR_WEB/$DIR $( [[ $STRIP -gt 0 ]] && echo "--strip-components=$STRIP" ) 
    fi
}

function display_usage {
    echo
    echo "Usage:"
    echo "    $0 ( list | prepare | down | up | status | run | su-run | exec | git | dump-database | sync-database | sync-files | upload | clean | realclean )"
    echo
    echo "Global variables can be set in a file "$DIR_UNITS"/config.global"
    echo "Sample file content:"
    echo "    MYSQL_PORT_MAP=3316:3306"
    echo
    echo
    exit 1;
} >&3


function init_apache_image {
    APACHE_IMAGE=${APACHE_IMAGE:-php:7.2-apache}

    # username:password@hostname:port
    IFS=@ read -r USERNAMEPASSWORD REGISTRYIMAGE <<< "${APACHE_IMAGE}"
    IFS=: read -r USERNAME PASSWORD <<< "${USERNAMEPASSWORD}"
    IFS=/ read -r SOURCE_IMAGE TARGET_IMAGE_TAG <<< "${REGISTRYIMAGE}"
    IFS=: read -r TARGET_IMAGE TAG <<< "${TARGET_IMAGE_TAG}"

    AWS_REGION_IMAGE=$(sed 's/.*\.\(.*\)\..*/\1/' <<< `expr "$SOURCE_IMAGE" : '.*\(\..*\.amazonaws\)'`)

    if [[ ! -z ${USERNAME} ]]; then
        echo_green "Docker login to registry..."

        if [[ -z ${AWS_REGION_IMAGE} ]]; then
            echo $PASSWORD | docker login --username $USERNAME --password-stdin https://$REGISTRYIMAGE
        else
            AWSID=$(get_aws_cli)

            docker run --rm -it \
                -e AWS_ACCESS_KEY_ID=$USERNAME \
                -e AWS_SECRET_ACCESS_KEY=$PASSWORD \
                -e AWS_DEFAULT_REGION=$AWS_REGION_IMAGE \
                $AWSID \
                    aws ecr get-login-password | docker login --username AWS --password-stdin $SOURCE_IMAGE
        fi

        APACHE_IMAGE=$REGISTRYIMAGE
    fi
}

function init_php_fpm_image {
    # username:password@hostname:port
    IFS=@ read -r USERNAMEPASSWORD REGISTRYIMAGE <<< "${PHP_FPM_IMAGE}"
    IFS=: read -r USERNAME PASSWORD <<< "${USERNAMEPASSWORD}"
    IFS=/ read -r SOURCE_IMAGE TARGET_IMAGE_TAG <<< "${REGISTRYIMAGE}"
    IFS=: read -r TARGET_IMAGE TAG <<< "${TARGET_IMAGE_TAG}"
    IFS=- read -r PHP_VERSION APP <<< "${TAG}"

    AWS_REGION_IMAGE=$(sed 's/.*\.\(.*\)\..*/\1/' <<< `expr "$SOURCE_IMAGE" : '.*\(\..*\.amazonaws\)'`)

    if [[ ! -z ${USERNAME} ]]; then
        echo_green "Docker login to registry..."

        if [[ -z ${AWS_REGION_IMAGE} ]]; then
            echo $PASSWORD | docker login --username $USERNAME --password-stdin https://$REGISTRYIMAGE
        else
            AWSID=$(get_aws_cli)
            docker run --rm -it \
                -e AWS_ACCESS_KEY_ID=$USERNAME \
                -e AWS_SECRET_ACCESS_KEY=$PASSWORD \
                -e AWS_DEFAULT_REGION=$AWS_REGION_IMAGE \
                $AWSID \
                    aws ecr get-login-password | docker login --username AWS --password-stdin $SOURCE_IMAGE
        fi

        PHP_FPM_IMAGE=$REGISTRYIMAGE
    fi
}

function init_node_image {
    # username:password@hostname:port

    USERNAMEPASSWORD=""; REGISTRYIMAGE="${NODE_IMAGE}"
    if [[ "$NODE_IMAGE" == *@* ]]; then
        IFS=@ read -r USERNAMEPASSWORD REGISTRYIMAGE <<< "${NODE_IMAGE}"
    fi

    IFS=: read -r USERNAME PASSWORD <<< "${USERNAMEPASSWORD}"
    IFS=/ read -r SOURCE_IMAGE TARGET_IMAGE_TAG <<< "${REGISTRYIMAGE}"
    IFS=: read -r TARGET_IMAGE TAG <<< "${TARGET_IMAGE_TAG}"

    AWS_REGION_IMAGE=$(sed 's/.*\.\(.*\)\..*/\1/' <<< `expr "$SOURCE_IMAGE" : '.*\(\..*\.amazonaws\)'`)

    if [[ ! -z ${USERNAME} ]]; then
        echo_green "Docker login to registry..."

        if [[ -z ${AWS_REGION_IMAGE} ]]; then
            echo $PASSWORD | docker login --username $USERNAME --password-stdin https://$REGISTRYIMAGE
        else
            AWSID=$(get_aws_cli)

            docker run --rm -it \
                -e AWS_ACCESS_KEY_ID=$USERNAME \
                -e AWS_SECRET_ACCESS_KEY=$PASSWORD \
                -e AWS_DEFAULT_REGION=$AWS_REGION_IMAGE \
                $AWSID \
                    aws ecr get-login-password | docker login --username AWS --password-stdin $SOURCE_IMAGE
        fi

        NODE_IMAGE=$REGISTRYIMAGE
    fi
}

function list_projects {
    projects_update

    if [[ -d "$DIR_PROJECT" && -h "$DIR_PROJECT" ]]; then SELECTED_PROJECT=$(ls -l $DIR_PROJECT | sed 's=.*/=='); fi

    local FILES_PROJECTS=$(find $DIR_PROJECTS -type f -name "deploy-config.md" -or -name "config" -not -path "*.git/*")

    if [[ ! -z $FILES_PROJECTS ]]; then echo_blue "\nList of projects\n"; fi

    i=1
    for DIR in "$DIR_PROJECTS"/*
    do
        if [ -e "$DIR/deploy-config.md" ] || [ -e "$DIR/config" ]; then
            DIRNAME=$(echo $DIR | sed 's=.*/==')
            if [[ $DIRNAME != $SELECTED_PROJECT ]]; then echo $i.' '$DIRNAME
                                                    else echo_green $i.' '$DIRNAME'        <-- selected project'
            fi
            (( i++ ))
        fi
    done
    echo

    if [[ ! -z $FILES_PROJECTS ]]; then
        echo_blue "Make a choice and run "
        echo "     ./deploy.sh -v prepare NAME_PROJECT"
        echo "or"
        echo "     ./deploy.sh -v prepare NUMBER_PROJECT"
        echo
    else echo_red "There are no configuration files available. Please create a configuration file in the root directory or contact support.\n"
    fi
} >&3

function realclean {
    git ls-files -o --directory | grep -v '^config$' | grep -v 'config.global$' | xargs rm -rf
}

function select_project {
    projects_update

    i=1
    for DIR in "$DIR_PROJECTS"/*
    do
        if [ -e "$DIR/deploy-config.md" ] || [ -e "$DIR/config" ]; then
            DIRNAME=$(echo $DIR | sed 's=.*/==')
            if [[ $2 == $i || $2 == $DIRNAME ]]; then break; fi;
            (( i++ ))
        fi
    done

    # If the project's config was changed
    if [[ -d "$DIR_PROJECT" && -h "$DIR_PROJECT" ]]; then
        SELECTED_PROJECT=$(ls -l $DIR_PROJECT | sed 's=.*/==')
        if [ ! $SELECTED_PROJECT == $DIRNAME ]; then
            echo_red "\n!!! WARNING !!!\nAll data from the previous project "$SELECTED_PROJECT" will be deleted!\n"
            echo_red "To abort the process, press CTRL-C...\n"
            for ((i=15;i>0;i--)) do echo_red $i" seconds left..."; sleep 1; done
            if [ ! $DIRNAME == "MyConfig" ]; then rm -f ./config; fi
            realclean
            projects_update
        fi
    fi
    ###

    project_update $DIR

    if [[ -f $DIR/config ]]; then
        rm -rf $DIR_PROJECT
        ln -s ./.$DIR $DIR_PROJECT
    else echo_red "The selected project does not have a configuration file. Please contact support"; exit 1
    fi

} >&3

function ssl_certificate_check {
    echo_green "Checking the expiration of SSL certificates..."
    if openssl x509 -checkend 0 -noout -in "$DIR_SSL/fullchain.pem" > /dev/null 2>&1; then
        echo_green "SSL certificate has not expired"
    else
        echo_red "The certificate has expired"
        ssl_certificate_pull

        if openssl x509 -checkend 0 -noout -in "$DIR_SSL/fullchain.pem" > /dev/null 2>&1; then
            echo_green "SSL certificate has been updated"
        else
            echo_red "SSL certificate has not been updated. Please contact support"; exit 1
        fi
    fi
}

function ssl_certificate_pull {
    echo_green "SSL certificates downloading..."
    mkdir -p $DIR_SSL
    HTTP_RESPONSE=$(cd $DIR_SSL \
        && curl -s -u $SSL_CREDENTIALS -w "%{http_code}" \
        -O $SSL_URL/cert.pem \
        -O $SSL_URL/chain.pem \
        -O $SSL_URL/fullchain.pem \
        -O $SSL_URL/privkey.pem)
    [[ $HTTP_RESPONSE != "200200200200" ]] && echo_red "SSL certificates download failed"
}

function environment_setup {
    if [[ ! -d "$DIR_PROJECT" || ! -h "$DIR_PROJECT" ]]; then echo >&3; echo_red "No config found !!!" >&3; list_projects; exit 1
        else
            SELECTED_PROJECT=$(ls -l $DIR_PROJECT | sed 's=.*/==')
            if [[ ! -f $DIR_PROJECT/config ]] ; then select_project prepare $SELECTED_PROJECT; fi
    fi


    source $DIR_PROJECT/config

    # config.global contains variables that overlap variables from config file
    if [[ -f $DIR_UNITS/config.global ]]; then export $(grep -v '#.*' $DIR_UNITS'/config.global' | xargs); fi


    [[ -z "${WORDPRESS_TABLE_PREFIX}" ]] && WORDPRESS_TABLE_PREFIX=""
    [[ -z "${PHP_SHORT_OPEN_TAG}" ]] && PHP_SHORT_OPEN_TAG="Off"

    # For support Apple m1
    if [[ $(uname -m) == "arm64" ]]; then
        export DOCKER_DEFAULT_PLATFORM=linux/amd64
    fi

    # create workspace in user's homedir
    if [[ ! -d $DIR_WORKSPACE ]]; then mkdir -p $DIR_WORKSPACE; fi
    if [[ -d $DIR_UNITS/tools ]]; then
        cp -f $DIR_UNITS/tools/* $DIR_WORKSPACE/
        for TOOL in $DIR_WORKSPACE/*; do
            if [[ -f $TOOL ]]; then
                sed -r -e "s!PATH_DEPLOY=.*!PATH_DEPLOY=\"$PWD\"!" $TOOL > ./tmp; cat ./tmp > $TOOL; rm -f ./tmp;
            fi
        done
    fi

    if [[ ! -d "$DIR_WORKSPACE/vscode-server" ]]; then
        cp -rf $DIR_UNITS/vscode-server $DIR_WORKSPACE/
    fi


    # Replacing a dot with a dash in PROJECT
    PROJECT=$(echo $PROJECT | sed 's!\.!\-!g')

    MYSQL_CONTAINER="$PROJECT-mysql"
    MYSQL_IMAGE=$MYSQL_CONTAINER
    MYSQL_DOCKERFILE=$DIR_DOCKERFILES"/"${MYSQL_DOCKERFILE:-Dockerfile.app.mysql}
    MYSQL_BASE_IMAGE=${MYSQL_BASE_IMAGE:-mysql:5.6}
    MYSQL_INNODB_LOG_FILE_SIZE=${MYSQL_INNODB_LOG_FILE_SIZE:-"16M"}

    APACHE_CONTAINER="$PROJECT-apache"
    PHP_FPM_CONTAINER="$PROJECT-php-fpm"
    NODE_CONTAINER="$PROJECT-node"
    REDIS_CONTAINER="$PROJECT-redis"
    PHPMYADMIN_CONTAINER="$PROJECT-phpmyadmin"

    APACHE_DOCKERFILE=($DIR_DOCKERFILES"/Dockerfile.app.apache")
    PHP_FPM_DOCKERFILE=($DIR_DOCKERFILES"/Dockerfile.app.php-fpm")
    NODE_DOCKERFILE=($DIR_DOCKERFILES"/Dockerfile.app.node")
    REDIS_DOCKERFILE=($DIR_DOCKERFILES"/Dockerfile.app.redis")
    PHPMYADMIN_DOCKERFILE=($DIR_DOCKERFILES"/Dockerfile.app.phpmyadmin")

    APP_DOCKERFILES=""
    APP_TYPE=${APP_TYPE:-empty}


    VERS_COMPOSER=${COMPOSER:-1.10.16}
    SELFUPDATE=${UPDATE:-"on"}


    AWS_FILENAME_DB=${AWS_FILENAME_DB:-latest.sql.gz}
    AWS_FILENAME_FILES=${AWS_FILENAME_FILES:-files.tgz}

    if [[ -e "${DIR_DOCKERFILES}/Dockerfile.${APP_TYPE}" ]]; then
        APP_DOCKERFILES+=("${DIR_DOCKERFILES}/Dockerfile.${APP_TYPE}")
    fi

    WEB_DOCUMENT_ROOT=/var/www/html/${WEB_ROOT%/}

    if [[ $APACHE_IMAGE ]]; then DOCKER_COMPOSE_ARGS=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-apache.yml"); fi
    if [[ $PHP_FPM_IMAGE ]]; then DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-php-fpm.yml"); fi
    if [[ $NODE_IMAGE ]]; then DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-node.yml"); fi
    if [[ $REDIS_IMAGE ]]; then DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-redis.yml"); fi
    if [[ $PHPMYADMIN_IMAGE ]]; then DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-phpmyadmin.yml"); fi

    if [[ $MYSQL_DATABASE ]]; then
        DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-mysql.yml")

        if [[ $APACHE_IMAGE ]]; then DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-mysql-apache.yml"); fi
        if [[ $PHP_FPM_IMAGE ]]; then DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-mysql-php-fpm.yml"); fi

        if [[ $MYSQL_PORT_MAP ]]; then
            if [[ ! $MYSQL_PORT ]]; then
                IFS=: read -r MYSQL_EXTERNAL_PORT MYSQL_PORT <<< "$MYSQL_PORT_MAP"
            fi
            DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-mysql-ports.yml")
        fi
    fi

    MYSQL_PORT=${MYSQL_PORT:-3306}


    if [[ $APACHE_PORT_MAP ]]; then
        DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-apache-ports.yml")
    fi

    if [[ $APACHE_PORT_MAP_SSL ]]; then
        DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-apache-ssl-ports.yml")
    fi

    if [[ $NODE_PORT_MAP ]]; then
        if [[ ! $NODE_PORT ]]; then
            IFS=: read -r NODE_EXTERNAL_PORT NODE_PORT <<< "$NODE_PORT_MAP"
        fi
        DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-node-ports.yml")
    fi
    NODE_PORT=${NODE_PORT:-3000}

    if [[ $REDIS_PORT_MAP ]]; then
        DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-redis-ports.yml")
    fi

    if [[ $PHPMYADMIN_PORT_MAP ]]; then
        DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-phpmyadmin-ports.yml")
    fi

    if [[ $MTU_NETWORK ]]; then
        DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-network-mtu.yml")
    fi

    if [[ $APP_NETWORK ]]; then
        DOCKER_COMPOSE_ARGS+=("-f" "${DIR_DOCKERCOMPOSES}/docker-compose-app-network.yml")
    fi


    if [[ -e "${DIR_WORK}/docker-compose.${PROJECT}.yml" ]]; then
        DOCKER_COMPOSE_ARGS+=("-f" "${DIR_WORK}/docker-compose.${PROJECT}.yml")
    fi
}

function InitFolderAndFiles {
    if [[ ! -d $DIR_WEB/.git ]]; then echo_red "Content in your webroot is not tracked by git"; fi
    if [[ ! -d $DIR_WORK/data/db ]]; then mkdir -p $DIR_WORK/data/db/; fi
    if [[ ! -d $DIR_WORK/log/mysql ]]; then mkdir -p $DIR_WORK/log/mysql; fi
    if [[ ! -d $DIR_WORK/log/apache2 ]]; then mkdir -p $DIR_WORK/log/apache2; fi
    if [[ ! -d $DIR_WORK/log/php ]]; then mkdir -p $DIR_WORK/log/php; fi

    # error.log might be created as directory if not exists and mounted by docker-compose
    if [[ ! -f $DIR_WORK/log/php/php-fpm.log ]]; then
        rm -rf $DIR_WORK/log/php/php-fpm.log
        touch $DIR_WORK/log/php/php-fpm.log
    fi

    # error.log might be created as directory if not exists and mounted by docker-compose
    if [[ ! -f $DIR_WORK/log/php/fpm-php.www.log ]]; then
        rm -rf $DIR_WORK/log/php/fpm-php.www.log
        touch $DIR_WORK/log/php/fpm-php.www.log
    fi

    # error.log might be created as directory if not exists and mounted by docker-compose
    if [[ ! -f $DIR_WORK/log/apache2/error.log ]]; then
        rm -rf $DIR_WORK/log/apache2/error.log
        touch $DIR_WORK/log/apache2/error.log
    fi

    # access.log might be created as directory if not exists and mounted by docker-compose
    if [[ ! -f $DIR_WORK/log/apache2/access.log ]]; then
        rm -rf $DIR_WORK/log/apache2/access.log
        touch $DIR_WORK/log/apache2/access.log
    fi

    # error.log might be created as directory if not exists and mounted by docker-compose
    if [[ ! -f $DIR_WORK/log/mysql/error.log ]]; then
        rm -rf $DIR_WORK/log/mysql/error.log
        touch $DIR_WORK/log/mysql/error.log
    fi
}


##=----                                                                                             ----=##
#                                         - - =   MAIN CODE   = - -                                       #
##=----                                                                                             ----=##


set -a

USERID=$(id -u)
GROUPID=$(id -g)


if [[ $USERID == "0" ]]; then
    echo_red "Running as root is not supported. Please run the following command to add user to the docker group:"
    echo_red "    \$ sudo usermod -aG docker \$USER"
    exit 1;
fi

if [[ ! -f ./config && -d $DIR_PROJECTS/MyConfig ]]; then rm -rf $DIR_PROJECTS/MyConfig; rm -rf $DIR_PROJECT; fi

case $1 in
    up | down | status | run | su-run | exec | dump-database | sync-database | dump-database | sync-files | upload)
        environment_setup
        ;;

    prepare)
        if [[ -n $2 ]]; then select_project "$@"
        else
            if [[ -f ./config ]]; then select_project $1 "MyConfig"
            else
                projects_update
                project_update $DIR_PROJECT
            fi
        fi

        environment_setup
        ;;

    list)
        list_projects
        exit 0
        ;;
esac



case $1 in
    prepare)
        progress 5 "Initialize $SELECTED_PROJECT"
        self_update "$@"

        InitFolderAndFiles
        ssl_certificate_pull
        
        if [[ $(declare -F preinstall) ]]; then
            echo_green "running preinstall function";
            preinstall

            if [[ -e "${DIR_WORK}/Dockerfile.${PROJECT}" ]]; then
                APP_DOCKERFILES+=("${DIR_WORK}/Dockerfile.${PROJECT}")
            fi
        fi

        
        if [[ $MYSQL_DATABASE ]] && [[ $MYSQL_DOCKERFILE ]]; then
            progress 10 "Docker pull MySQL"
            printf "\n\e[1;34m"
            docker pull ${MYSQL_BASE_IMAGE}
            printf "\n\e[0m"
            
            progress 15 "Docker build MySQL"
            docker --log-level "error" build \
                --build-arg MYSQL_INNODB_LOG_FILE_SIZE=$MYSQL_INNODB_LOG_FILE_SIZE \
                --build-arg MYSQL_BASE_IMAGE=$MYSQL_BASE_IMAGE \
                --build-arg USERID=$USERID \
                --build-arg GROUPID=$GROUPID \
                -f $MYSQL_DOCKERFILE \
                -t $MYSQL_IMAGE . || exit 1
            printf "\n"
        fi

        if [[ $APACHE_IMAGE ]]; then
            init_apache_image

            progress 20 "Docker pull Apache"
            printf "\n\e[1;34m"
            docker pull ${APACHE_IMAGE}
            printf "\n\e[0m"

            APACHE_CONFIG=${DIR_APACHE_CONFIGS}/apache-default.conf
            if [[ $PHP_FPM_IMAGE ]]; then APACHE_CONFIG=${DIR_APACHE_CONFIGS}/apache-fpm.conf; fi
            if [[ $NODE_IMAGE ]]; then APACHE_CONFIG=${DIR_APACHE_CONFIGS}/apache-node.conf; fi

            progress 25 "Docker build Apache"
            cat $APACHE_DOCKERFILE | docker --log-level "error" build \
                --build-arg APACHE_IMAGE=$APACHE_IMAGE \
                --build-arg USERID=$USERID \
                --build-arg GROUPID=$GROUPID \
                --build-arg PROJECT=$PROJECT \
                --build-arg WEB_DOCUMENT_ROOT=$WEB_DOCUMENT_ROOT \
                --build-arg APACHE_CONFIG=$APACHE_CONFIG \
                --build-arg NODE_PORT=$NODE_PORT \
                -f - \
                -t $APACHE_CONTAINER . || exit 1
            printf "\n"
        fi

        if [[ $PHP_FPM_IMAGE ]]; then
            init_php_fpm_image

            progress 30 "Docker pull PHP-FPM"
            printf "\n\e[1;34m"
            docker pull ${PHP_FPM_IMAGE}
            printf "\n\e[0m"

            progress 35 "Docker build PHP-FPM"
            APP_DOCKERFILES+=${PHP_FPM_DOCKERFILE}
            cat ${APP_DOCKERFILES[@]} | docker --log-level "error" build \
                --build-arg PHP_FPM_IMAGE=$PHP_FPM_IMAGE \
                --build-arg USERID=$USERID \
                --build-arg GROUPID=$GROUPID \
                --build-arg PHP_VERSION=$PHP_VERSION \
                --build-arg APP_TYPE=$APP_TYPE \
                --build-arg WEB_DOCUMENT_ROOT=$WEB_DOCUMENT_ROOT \
                --build-arg PHP_SHORT_OPEN_TAG=$PHP_SHORT_OPEN_TAG \
                --build-arg VERS_COMPOSER=$VERS_COMPOSER \
                --build-arg MAILGUN_USER=$MAILGUN_USER \
                --build-arg MAILGUN_PASSWORD=$MAILGUN_PASSWORD \
                --build-arg DIR_UNITS=$DIR_UNITS \
                --build-arg DIR_WORKSPACE=$DIR_WORKSPACE \
                -f - \
                -t $PHP_FPM_CONTAINER . || exit 1
            printf "\n"       
        fi

        if [[ $NODE_IMAGE ]]; then
            init_node_image

            progress 40 "Docker pull Node"
            printf "\n\e[1;34m"
            docker pull ${NODE_IMAGE}
            printf "\n\e[0m"

            progress 45 "Docker build Node"
            APP_DOCKERFILES+=${NODE_DOCKERFILE}
            cat ${APP_DOCKERFILES[@]} | docker --log-level "error" build \
                --build-arg NODE_IMAGE=$NODE_IMAGE \
                --build-arg USERID=$USERID \
                --build-arg GROUPID=$GROUPID \
                --build-arg APP_TYPE=$APP_TYPE \
                --build-arg DIR_SCRIPTS=$DIR_SCRIPTS \
                -f - \
                -t $NODE_CONTAINER . || exit 1
            printf "\n"       
        fi


        if [[ $REDIS_IMAGE ]]; then
            progress 46 "Docker pull Redis"
            printf "\n\e[1;34m"
            docker pull ${REDIS_IMAGE}
            printf "\n\e[0m"

            progress 48 "Docker build Redis"
            cat ${REDIS_DOCKERFILE} | docker --log-level "error" build \
                --build-arg REDIS_IMAGE=$REDIS_IMAGE \
                -f - \
                -t $REDIS_CONTAINER . || exit 1
            printf "\n"       
        fi

        if [[ $PHPMYADMIN_IMAGE ]]; then
            progress 46 "Docker pull phpMyAdmin"
            printf "\n\e[1;34m"
            docker pull ${PHPMYADMIN_IMAGE}
            printf "\n\e[0m"

            progress 48 "Docker build phpMyAdmin"
            cat ${PHPMYADMIN_DOCKERFILE} | docker --log-level "error" build \
                --build-arg PHPMYADMIN_IMAGE=$PHPMYADMIN_IMAGE \
                -f - \
                -t $PHPMYADMIN_CONTAINER . || exit 1
            printf "\n"       
        fi


        progress 50 "Get latest DB Dump"
        get_latest_db_dump $AWS_FILENAME_DB

        progress 60 "Get latest files from GitHub repository"
        if [[ $REPOSITORY ]] &&[[ ! -d $DIR_WEB/.git ]]; then
            gitcmd clone --recurse-submodules $REPOSITORY $DIR_WEB/
            (cd $DIR_WEB/ && gitcmd submodule update --init --recursive)
        fi

        progress 70 "Get latest upload files"
        SYNC_ERROR=1
        if [[ $PANTHEON_SITE_NAME ]] && [[ $FILES_DIR ]]; then
            get_latest_files_from_pantheon
            SYNC_ERROR=0
        fi

        if [[ $SYNC_ERROR != 0 ]] && [[ $RSYNC_DIR ]] && [[ $FILES_DIR ]] && [[ $GENERIC_SSH ]]; then
            get_latest_files_from_ssh
            if [[ $? != 0 ]]; then SYNC_ERROR=1
                              else SYNC_ERROR=0
            fi
        fi

        if [[ $SYNC_ERROR != 0 ]] && [[ $FILES_DIR ]]; then
            get_latest_files_from_aws $AWS_FILENAME_FILES
        fi


        if [[ $(declare -F postinstall) ]]; then
            echo_green "Running postinstall function"

            if [[ $PHP_FPM_IMAGE ]]; then
                docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} -f ${DIR_DOCKERCOMPOSES}/docker-compose-app-php-fpm-user.yml \
                    run --no-deps --rm php-fpm \
                        bash -c "source /tmp/config && HOME=/tmp && cd /var/www/html && postinstall"
            else
                if [[ $APACHE_IMAGE ]]; then
                    docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} -f ${DIR_DOCKERCOMPOSES}/docker-compose-app-apache-user.yml \
                        run --no-deps --rm apache \
                            bash -c "source /tmp/config && HOME=/tmp && cd /var/www/html && postinstall"
                fi
            fi
        fi

        progress 80 "Extract files"
        extract_remote_files $FILES_DIR $( [[ $PANTHEON_SITE_NAME ]] && echo 1 )

        progress 100 "Done"
        ;;
    down)
        progress 10 "Shutting down"
        docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} $@
        progress 100 "Done"
        ;;
    up)
        [[ $2 == "-d" ]] || progress 20 "Self update"
        self_update "$@"

        [[ $2 == "-d" ]] || progress 40 "Setting up apache/mysql logs.."
        InitFolderAndFiles

        [[ $2 == "-d" ]] || progress 90 "Wait 2-3 min. Exit: ctrl+c"
        [[ $2 == "-d" ]] || progress 95 "\n"

        ssl_certificate_check

        docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} $@
        ;;
    status)
        docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} ps >&3
        ;;
    run)
        docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} run --no-deps --rm php-fpm su mapped -c "cd /var/www/html; HOME=/tmp; ${*:2}"
        ;;
    su-run)
        docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} run --no-deps --rm php-fpm "${@:2}"
        ;;	
    exec)
        docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} exec php-fpm su mapped -c "cd /var/www/html; HOME=/tmp; ${*:2}"
        ;;

    dump-database)
        if [[ $(docker ps -f id=$(docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} ps -q mysql) -q) != ""  ]]; then
            docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} exec -T mysql mysqldump -uroot $MYSQL_DATABASE "${@:2}"
        else
            echo_red "MYSQL container is not running"
            exit 1
        fi
        ;;
    sync-database)
        AWS_FILENAME_DB=${2:-${AWS_FILENAME_DB:-latest.sql.gz}}
        rm -rf $DIR_WORK/data/
        rm -rf $DIR_WORK/mysql-init-script/
        get_latest_db_dump $AWS_FILENAME_DB
        ;;
    sync-files)
        SYNC_ERROR=1
        if [[ $PANTHEON_SITE_NAME ]] && [[ $FILES_DIR ]]; then
            rm -rf $DIR_WORK/remote-files/
            get_latest_files_from_pantheon
            extract_remote_files $FILES_DIR 1
            SYNC_ERROR=0
        fi

        if [[ $SYNC_ERROR != 0 ]] && [[ $RSYNC_DIR ]] && [[ $FILES_DIR ]] && [[ $GENERIC_SSH ]]; then
            get_latest_files_from_ssh
            if [[ $? != 0 ]]; then SYNC_ERROR=1
                              else SYNC_ERROR=0
            fi
        fi

        if [[ $SYNC_ERROR != 0 ]] && [[ $FILES_DIR ]]; then
            AWS_FILENAME_FILES=${2:-${AWS_FILENAME_FILES:-files.tgz}}
            rm -rf $DIR_WORK/remote-files/
            get_latest_files_from_aws $AWS_FILENAME_FILES
            extract_remote_files $FILES_DIR
        fi
        
        progress 100 "Done"
        
        ;;
    upload)
        if [[ ! -d $DIR_WORK/backup ]]; then
            mkdir $DIR_WORK/backup
        fi 
        FILENAME=$MYSQL_CONTAINER-$(date +%Y-%m-%d.%H:%M:%S).sql.gz
        if [[ $(docker ps -f id=$(docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@] --project-directory ${PWD}} ps -q mysql) -q) != ""  ]]; then
            docker compose -p $PROJECT ${DOCKER_COMPOSE_ARGS[@]} --project-directory ${PWD} exec -T mysql mysqldump -uroot $MYSQL_DATABASE | gzip - > $DIR_WORK/backup/$FILENAME
        else
            echo_red "MYSQL container is not running"
            exit 1
        fi
        upload_dump $BUCKET $FILENAME
        ;;

    git)
        gitcmd -C $DIR_WEB/ ${*:2} >&3
        ;;

    clean)
        git ls-files -o --directory | grep -v ${DIR_WEB/.\//} | grep -v ${DIR_WORK/.\//}'/config' | xargs rm -rf
        ;;

    realclean)
        realclean
        ;;
    log)
        tail -q -f $DIR_WORK/log/apache2/error.log -f $DIR_WORK/log/apache2/access.log -f $DIR_WORK/log/mysql/error.log >&3
        ;;
    *)
        display_usage
        ;;

esac