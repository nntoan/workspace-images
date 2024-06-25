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
### Setup crontab
###
if [ ! -z "${CRONTAB}" ]; then
    echo "${CRONTAB}" > /etc/cron.d/magento && touch /var/log/cron.log
fi


###
### Enable PHP extensions
###
PHP_EXT_DIR=/usr/local/etc/php/conf.d
PHP_EXT_COM_ON=docker-php-ext-enable

[ -d ${PHP_EXT_DIR} ] && rm -f ${PHP_EXT_DIR}/docker-php-ext-*.ini

if [ -x "$(command -v ${PHP_EXT_COM_ON})" ] && [ ! -z "${PHP_EXTENSIONS}" ]; then
  ${PHP_EXT_COM_ON} ${PHP_EXTENSIONS}
fi


###
### Clear composer cache if needed
###
[ "$COMPOSER_CLEAR_CACHE" = "true" ] && \
    composer clearcache


###
### Configure composer
###
[ ! -z "${COMPOSER_VERSION}" ] && \
    composer self-update $COMPOSER_VERSION

[ ! -z "${COMPOSER_GITHUB_TOKEN}" ] && \
    composer config --global github-oauth.github.com $COMPOSER_GITHUB_TOKEN

[ ! -z "${COMPOSER_MAGENTO_USERNAME}" ] && \
    composer config --global http-basic.repo.magento.com \
        $COMPOSER_MAGENTO_USERNAME $COMPOSER_MAGENTO_PASSWORD


###
### Startup
###
exec "$@"
