#!/bin/bash

set -e
set -u
set -o pipefail


###
### Globals
###

# The following global variables are available by our Dockerfile itself:
#   MY_USER
#   MY_GROUP
#   MY_UID
#   MY_GID

# Path to scripts to source
CONFIG_DIR="/docker-entrypoint.d"


###
### Source libs
###
init="$( find "${CONFIG_DIR}" -name '*.sh' -type f | sort -u )"
for f in ${init}; do
	# shellcheck disable=SC1090
	. "${f}"
done

#############################################################
## Entry Point
#############################################################

###
### Set Debug level
###
[ "$DEBUG" = "true" ] && set -x
DEBUG_LEVEL="$( env_get "DEBUG_ENTRYPOINT" "0" )"
log "info" "Debug level: ${DEBUG_LEVEL}" "${DEBUG_LEVEL}"


###
### Change uid/gid
###
set_uid "NEW_UID" "${MY_USER}" "${DOCROOT}" "${DEBUG_LEVEL}"
set_gid "NEW_GID" "${MY_GROUP}" "${DOCROOT}" "${DEBUG_LEVEL}"


###
### Enable PHP extensions
###
PHP_EXT_DIR=/usr/local/etc/php/conf.d
PHP_EXT_COM_ON=docker-php-ext-enable

[ -d ${PHP_EXT_DIR} ] && rm -f ${PHP_EXT_DIR}/docker-php-ext-*.ini

if [ -x "$(command -v ${PHP_EXT_COM_ON})" ] && [ ! -z "${PHP_EXTENSIONS}" ]; then
  ${PHP_EXT_COM_ON} "${PHP_EXTENSIONS}"
fi


###
### Set host.docker.internal if not available
###
HOST_NAME="host.docker.internal"
HOST_IP=$(php -r "putenv('RES_OPTIONS=retrans:1 retry:1 timeout:1 attempts:1'); echo gethostbyname('$HOST_NAME');")
if [[ "$HOST_IP" == "$HOST_NAME" ]]; then
  HOST_IP=$(/sbin/ip route|awk '/default/ { print $3 }')
  printf "\n%s %s\n" "$HOST_IP" "$HOST_NAME" >> /etc/hosts
fi


###
### Startup
###
log "info" "Starting $( php-fpm -v 2>&1 | head -1 )" "${DEBUG_LEVEL}"
exec "$@"
