#!/bin/bash

if [ -f "versions.sh" ]
then
    echo "**** Using custom 'versions.sh'..."
    source ./versions.sh
else
    echo "**** Using default 'versions.sh.default'..."
    source ./versions.sh.default
fi

# we need Bower in path and executable, too hard to install with this script...
if [ `which bower` ]
then
    echo "* Bower found, OK"
else

cat << EOF
    * Bower NOT found. Please make sure "bower" is available in your PATH.

    ---- Installation Instructions ----
    Make sure nodejs and npm are installed and working.
    On Fedora: 
    
        $ yum install npm

    On CentOS/RHEL: Add the "EPEL" repository and:
    
        $ yum install npm

    Then install Bower:

        $ npm install bower

    Create a symlink from node_modules/bower/bin/bower to a directory in your
    path. E.g.:

        $ ln -s ~/node_modules/bower/bin/bower ~/bin/bower

    That should be enough! On Ubuntu/Debian you need to install nodejs and npm
    manually or from a PPA as node on Ubuntu is too old and unavailable on 
    Debian. 

EOF
fi

# check command line parameters
if [ -z "$1" ]
then

cat << EOF
    Please specify the location to install to. 

    Examples:
    
    Fedora, CentOS, RHEL: /var/www/html/oauth
    Debian, Ubuntu: /var/www/oauth
    Mac OS X: /Library/WebServer/Documents/oauth

    **********************************************************************
    * WARNING: ALL FILES IN THE INSTALLATION DIRECTORY WILL BE ERASED!!! *
    **********************************************************************

EOF
exit 1
else
    INSTALL_DIR=$1
fi

if [ -z "$2" ]
then
cat << EOF
    Please also specify the URL at which this installation will be available.

    Examples:

    http://localhost/oauth
    https://www.example.edu/oauth
    https://my.server.example.org

EOF
exit 1
else
    BASE_URL=$2
    BASE_PATH=`echo ${BASE_URL} | sed "s|[^/]*\/\/[^/]*||g"`
    DOMAIN_NAME=`echo ${BASE_URL} | sed "s|[^/]*\/\/||g" | sed "s|:.*||g" | sed "s|\/.*||g"`
    DATE_TIME=`date`
fi

# for development purposes it can be useful to disable the SSL certificate 
# check for backchannel calls where accepting a self-signed certificate in
# the browser is not enough. SSL CHECK IS ENABLED BY DEFAULT AND *REALLY* MUST
# be used. UNDOCUMENTED ON PURPOSE! Seriously, DO NOT USE!
if [ -z "$3" ]
then
    ENABLE_CERTIFICATE_CHECK="true"
else
    if [ "disable_cert_check" == "$3" ]
    then
        ENABLE_CERTIFICATE_CHECK="false"
    else
        ENABLE_CERTIFICATE_CHECK="true"
    fi
fi

cat << EOF
###############################################################################
# This script installs the following components to have a fully functional    #
# OAuth installation with all the components to quickly evaluate the software #
#                                                                             #
# The following components will be installed:                                 #
#                                                                             #
# * php-simple-auth                                                           #
# * php-oauth                                                                 #
# * html-manage-applications                                                  #
# * html-manage-authorization                                                 #
# * html-view-grades                                                          #
# * php-grades-rs                                                             #
# * OAuth Demo App                                                            #
# * php-remoteStorage                                                         #
# * html-music-player                                                         #
###############################################################################
EOF

if [ ! -d "${INSTALL_DIR}" ]
then
    echo "install dir ${INSTALL_DIR} does not exist (yet) make sure you created it and have write permission to it!";
    exit 1
fi

LAUNCH_DIR=`pwd`

# remove the existing installation
echo "ARE YOU SURE YOU WANT TO ERASE ALL FILES FROM: '${INSTALL_DIR}/'?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

rm -rf ${INSTALL_DIR}/*

mkdir -p ${INSTALL_DIR}/apache
mkdir -p ${INSTALL_DIR}/downloads
mkdir -p ${INSTALL_DIR}/img

# the index page
cat ${LAUNCH_DIR}/res/index.html \
    | sed "s|{BASE_URL}|${BASE_URL}|g" \
    | sed "s|@example.org|@${DOMAIN_NAME}|g" \
    | sed "s|{DATE_TIME}|${DATE_TIME}|g" > ${INSTALL_DIR}/index.html

# copy the image resources
cp ${LAUNCH_DIR}/res/img/* ${INSTALL_DIR}/img/

(
cd ${INSTALL_DIR}/downloads
curl -O http://getcomposer.org/composer.phar
)

cat << EOF
#############################
# html-webapp-deps (SHARED) #
#############################
EOF
(
cd ${INSTALL_DIR}
mkdir -p html-webapp-deps/js
mkdir -p html-webapp-deps/bootstrap

# jQuery
curl -L -o html-webapp-deps/js/jquery.js http://code.jquery.com/jquery.min.js

# JSrender (JavaScript Template Rendering for jQuery)
curl -L -o html-webapp-deps/js/jsrender.js https://raw.github.com/BorisMoore/jsrender/master/jsrender.js

# JSO (JavaScript OAuth 2 client)
curl -L -o html-webapp-deps/js/jso.js https://raw.github.com/andreassolberg/jso/master/jso.js

# Bootstrap
curl -L -o html-webapp-deps/bootstrap.zip http://getbootstrap.com/2.3.2/assets/bootstrap.zip
(cd html-webapp-deps/ && unzip bootstrap.zip && rm bootstrap.zip)
)

cat << EOF
###################
# php-simple-auth #
###################
EOF
(
cd ${INSTALL_DIR}
git clone -b ${PHP_SIMPLE_AUTH_BRANCH} https://github.com/fkooman/php-simple-auth.git
cd php-simple-auth
cat config/users.json.example \
    | sed "s|@example.org|@${DOMAIN_NAME}|g" > config/users.json

php ${INSTALL_DIR}/downloads/composer.phar install
restorecon -R vendor

# Apache config
cat docs/apache.conf \
    | sed "s|/APPNAME|${BASE_PATH}/php-simple-auth|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-simple-auth|g" > ${INSTALL_DIR}/apache/oauth_php-simple-auth.conf
)

cat << EOF
#############
# php-oauth #
#############
EOF
(
cd ${INSTALL_DIR}
git clone -b ${PHP_OAUTH_BRANCH} https://github.com/fkooman/php-oauth.git
cd php-oauth

php ${INSTALL_DIR}/downloads/composer.phar install
restorecon -R vendor

sh docs/configure.sh
php docs/initOAuthDatabase.php

# config
cat config/oauth.ini.defaults \
    | sed "s|authenticationMechanism = \"DummyResourceOwner\"|;authenticationMechanism = \"DummyResourceOwner\"|g" \
    | sed "s|;authenticationMechanism = \"SimpleAuthResourceOwner\"|authenticationMechanism = \"SimpleAuthResourceOwner\"|g" \
    | sed "s|accessTokenExpiry = 3600|accessTokenExpiry = 28800|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-oauth|g" \
    | sed "s|enableApi = FALSE|enableApi = TRUE|g" \
    | sed "s|/var/www/html/php-simple-auth|${INSTALL_DIR}/php-simple-auth|g" > config/oauth.ini

# copy the entitlements file
cat config/simpleAuthEntitlement.json.example \
    | sed "s|@example.org|@${DOMAIN_NAME}|g" > config/simpleAuthEntitlement.json

# Apache config
cat docs/apache.conf \
    | sed "s|/APPNAME|${BASE_PATH}/php-oauth|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-oauth|g" > ${INSTALL_DIR}/apache/oauth_php-oauth.conf

# Register Clients
cat ${LAUNCH_DIR}/config/client_registrations.json \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > docs/myregistration.json
php docs/registerClients.php docs/myregistration.json
)

cat << EOF
############################
# html-manage-applications #
############################
EOF
(
cd ${INSTALL_DIR}
git clone -b ${HTML_MANAGE_APPLICATIONS_BRANCH} https://github.com/fkooman/html-manage-applications.git
cd html-manage-applications
ln -s ../html-webapp-deps ext

# configure
cat config/config.js.default \
    | sed "s|http://localhost|${BASE_URL}|g" > config/config.js
)

cat << EOF
##############################
# html-manage-authorizations #
##############################
EOF
(
cd ${INSTALL_DIR}
git clone -b ${HTML_MANAGE_AUTHORIZATIONS_BRANCH} https://github.com/fkooman/html-manage-authorizations.git
cd html-manage-authorizations
# install dependencies using Bower
bower install

# configure
cat config/config.js.default \
    | sed "s|http://localhost|${BASE_URL}|g" > config/config.js
)

cat << EOF
####################
# html-view-grades #
####################
EOF
(
cd ${INSTALL_DIR}
git clone -b ${HTML_VIEW_GRADES_BRANCH} https://github.com/fkooman/html-view-grades.git
cd html-view-grades
ln -s ../html-webapp-deps ext

# configure
cat config/config.js.default \
    | sed "s|http://localhost|${BASE_URL}|g" > config/config.js
)

cat << EOF
#################
# php-grades-rs #
#################
EOF
(
cd ${INSTALL_DIR}
git clone -b ${PHP_GRADES_RS_BRANCH} https://github.com/fkooman/php-grades-rs.git
cd php-grades-rs

php ${INSTALL_DIR}/downloads/composer.phar install
restorecon -R vendor

sh docs/configure.sh

cat data/grades.json.example \
    | sed "s|@example.org|@${DOMAIN_NAME}|g" > data/grades.json

cat config/rs.ini \
    | sed "s|http://localhost/php-oauth/introspect.php|${BASE_URL}/php-oauth/introspect.php|g" > config/tmp_rs.ini
mv config/tmp_rs.ini config/rs.ini

# check for disabling SSL cert check
if [ "${ENABLE_CERTIFICATE_CHECK}" == "false" ]
then
    cat config/rs.ini \
        | sed "s|;disableCertCheck = 1|disableCertCheck = 1|g" > config/tmp_rs.ini
    mv config/tmp_rs.ini config/rs.ini 
fi

# Apache config
cat docs/apache.conf \
    | sed "s|/APPNAME|${BASE_PATH}/php-grades-rs|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-grades-rs|g" > ${INSTALL_DIR}/apache/oauth_php-grades-rs.conf
)

cat << EOF
##################
# OAuth Demo App #
##################
EOF
(
mkdir -p ${INSTALL_DIR}/demo-oauth-app
cd ${INSTALL_DIR}/demo-oauth-app
cat ${LAUNCH_DIR}/res/oauth/index.php \
    | sed "s|{INSTALL_DIR}|${INSTALL_DIR}|g" \
    | sed "s|{ENABLE_CERTIFICATE_CHECK}|${ENABLE_CERTIFICATE_CHECK}|g" \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > ${INSTALL_DIR}/demo-oauth-app/index.php
cat ${LAUNCH_DIR}/res/oauth/callback.php \
    | sed "s|{INSTALL_DIR}|${INSTALL_DIR}|g" \
    | sed "s|{ENABLE_CERTIFICATE_CHECK}|${ENABLE_CERTIFICATE_CHECK}|g" \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > ${INSTALL_DIR}/demo-oauth-app/callback.php
cp ${LAUNCH_DIR}/res/oauth/composer.json ${INSTALL_DIR}/demo-oauth-app/composer.json

php ${INSTALL_DIR}/downloads/composer.phar install
restorecon -R vendor

# initialize the SQlite database
mkdir data
sqlite3 data/client.sqlite < vendor/fkooman/php-oauth-client/schema/db.sql
chmod o+w data data/client.sqlite
chcon -R -t httpd_sys_rw_content_t data/
)

cat << EOF
#####################
# php-remoteStorage #
#####################
EOF
(
cd ${INSTALL_DIR}
git clone -b ${PHP_REMOTE_STORAGE_BRANCH} https://github.com/fkooman/php-remoteStorage.git
cd php-remoteStorage

php ${INSTALL_DIR}/downloads/composer.phar install
restorecon -R vendor

sh docs/configure.sh

cat config/remoteStorage.ini \
    | sed "s|http://localhost/php-oauth/introspect.php|${BASE_URL}/php-oauth/introspect.php|g" > config/tmp_remoteStorage.ini
mv config/tmp_remoteStorage.ini config/remoteStorage.ini

# check for disabling SSL cert check
if [ "${ENABLE_CERTIFICATE_CHECK}" == "false" ]
then
    cat config/remoteStorage.ini \
        | sed "s|;disableCertCheck = 1|disableCertCheck = 1|g" > config/tmp_remoteStorage.ini
    mv config/tmp_remoteStorage.ini config/remoteStorage.ini 
fi

cat docs/apache.conf \
    | sed "s|/APPNAME|${BASE_PATH}/php-remoteStorage|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-remoteStorage|g" > ${INSTALL_DIR}/apache/oauth_php-remoteStorage.conf
)

cat << EOF
#####################
# html-music-player #
#####################
EOF
(
cd ${INSTALL_DIR}
git clone -b ${HTML_MUSIC_PLAYER_BRANCH} https://github.com/fkooman/html-music-player.git
cd html-music-player
ln -s ../html-webapp-deps ext

# configure
cat config/config.js.default \
    | sed "s|http://localhost|${BASE_URL}|g" > config/config.js
)

cat << EOF
#############
# Webfinger #
#############
EOF
(
cd ${INSTALL_DIR}
mkdir webfinger/
cat ${LAUNCH_DIR}/res/webfinger.php \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > webfinger/index.php

cat ${LAUNCH_DIR}/res/webfinger-apache.conf \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/webfinger|g" > ${INSTALL_DIR}/apache/oauth_webfinger.conf
)

# Done
echo "**********************************************************************"
echo "* INSTALLATION DONE                                                  *"
echo "**********************************************************************"
echo
echo Please visit ${BASE_URL}.
echo
