ARG APP_BASE_IMAGE
FROM $APP_BASE_IMAGE

# APP_BASE_IMAGE must be declared again after FROM
ARG APP_BASE_IMAGE

ENV DEBIAN_FRONTEND noninteractive

# --- fixing user permissions

ARG USERID
ARG GROUPID


RUN userdel node

RUN bash -c 'if [[ $(getent group $GROUPID | cut -d: -f1) == "" ]]; then groupadd -g $GROUPID node; else groupmod --new-name node $(getent group $GROUPID | cut -d: -f1); fi'
RUN bash -c 'if [[ $(id -u mysql 2>/dev/null) == "" ]]; then useradd -r -g node -u $USERID node; else usermod -u $USERID node; fi'


#RUN groupadd -g $GROUPID mapped || groupmod -n mapped $(getent group $GROUPID | cut -d: -f1)
#RUN useradd \
#      --uid $USERID \
#      --gid $GROUPID \
#      --home-dir /var/www/html/ \
#      mapped

# -- end fixing user permissions

# --- app-type related code

ARG APP_TYPE
COPY scripts/${APP_TYPE}/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

# -- end app-type related code

USER node

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["yarn", "start"]
