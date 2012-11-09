#!/bin/bash

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
fi

SIMPLESAMLPHP_VERSION=1.10.0

cat << EOF
###############################################################################
# This script installs the following components to have a fully functional    #
# OAuth installation with all the components to quickly evaluate the software #
#                                                                             #
# The following components will be installed:                                 #
#                                                                             #
# * simpleSAMLphp                                                             #
# * php-rest-service                                                          #
# * php-lib-remote-rs                                                         #
# * php-oauth                                                                 #
# * html-manage-applications                                                  #
# * html-manage-authorization                                                 #
# * html-view-grades                                                          #
# * php-oauth-grades-rs                                                       #
# * php-oauth-demo-client                                                     #
# * php-oauth-client                                                          #
# * php-oauth-example-rs                                                      #
# * php-voot-proxy                                                            #
# * php-voot-provider                                                         #
# * html-voot-client                                                          #
# * voot-specification                                                        #
# * saml_info                                                                 #
###############################################################################
EOF

if [ ! -d "${INSTALL_DIR}" ]
then
    echo "install dir ${INSTALL_DIR} does not exist (yet) make sure you created it and have write permission to it!";
    exit 1
fi

LAUNCH_DIR=`pwd`

# some simpleSAMLphp variables
SSP_ADMIN_PASSWORD=`tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd bs=8 count=1 2>/dev/null;echo`
SSP_SECRET_SALT=`tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd bs=32 count=1 2>/dev/null;echo`

# remove the existing installation
echo "ARE YOU SURE YOU WANT TO ERASE ALL FILES FROM: '${INSTALL_DIR}/'?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

rm -rf ${INSTALL_DIR}/*

mkdir -p ${INSTALL_DIR}/downloads
mkdir -p ${INSTALL_DIR}/apache

# the index page
cat ${LAUNCH_DIR}/res/index.html \
    | sed "s|{BASE_URL}|${BASE_URL}|g" \
    | sed "s|{ADMIN_PASSWORD}|${SSP_ADMIN_PASSWORD}|g" > ${INSTALL_DIR}/index.html

cat << EOF
#################
# simpleSAMLphp #
#################
EOF
(
cd ${INSTALL_DIR}/downloads
curl -O https://simplesamlphp.googlecode.com/files/simplesamlphp-${SIMPLESAMLPHP_VERSION}.tar.gz
cd ${INSTALL_DIR}
tar -xzf downloads/simplesamlphp-${SIMPLESAMLPHP_VERSION}.tar.gz
mv simplesamlphp-${SIMPLESAMLPHP_VERSION} ssp
cd ${INSTALL_DIR}/ssp

# generate IdP certificate
openssl req -subj '/O=Snake Oil, CN=Demo Identity Provider/' -newkey rsa:2048 -new -x509 -days 3652 -nodes -out cert/idp.crt -keyout cert/idp.pem

# figure out the fingerprint of the certificate
CERT_FINGERPRINT=`openssl x509 -inform PEM -in cert/idp.crt -noout -fingerprint | cut -d '=' -f 2 | sed "s|:||g" | tr '[A-F]' '[a-f]'`

# update the BASE_URL in the patch and apply the simpleSAMLphp configuration 
# patch to configure an IdP and SP
cat ${LAUNCH_DIR}/config/simpleSAMLphp.diff \
    | sed "s|{BASE_URL}|${BASE_URL}|g" \
    | sed "s|{ADMIN_PASSWORD}|${SSP_ADMIN_PASSWORD}|g" \
    | sed "s|{SECRET_SALT}|${SSP_SECRET_SALT}|g" \
    | sed "s|{CERT_FINGERPRINT}|${CERT_FINGERPRINT}|g" | patch -p1

# enable the example-userpass module
touch modules/exampleauth/enable

# Apache config
echo "Alias ${BASE_PATH}/ssp ${INSTALL_DIR}/ssp/www" > ${INSTALL_DIR}/apache/oauth_ssp.conf
)

cat << EOF
#####################################
# php-rest-service (SHARED LIBRARY) #
#####################################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-rest-service.git
)
cat << EOF
######################################
# php-lib-remote-rs (SHARED LIBRARY) #
######################################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-lib-remote-rs.git
)

cat << EOF
#############
# php-oauth #
#############
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-oauth.git
cd php-oauth

mkdir extlib
ln -s ../../php-rest-service extlib/

sh docs/configure.sh
php docs/initOAuthDatabase.php

# config
cat config/oauth.ini.defaults \
    | sed "s|authenticationMechanism = \"DummyResourceOwner\"|;authenticationMechanism = \"DummyResourceOwner\"|g" \
    | sed "s|;authenticationMechanism = \"SspResourceOwner\"|authenticationMechanism = \"SspResourceOwner\"|g" \
    | sed "s|allowResourceOwnerScopeFiltering = FALSE|allowResourceOwnerScopeFiltering = TRUE|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-oauth|g" \
    | sed "s|enableApi = FALSE|enableApi = TRUE|g" \
    | sed "s|/var/simplesamlphp|${INSTALL_DIR}/ssp|g" > config/oauth.ini

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
git clone https://github.com/fkooman/html-manage-applications.git
cd html-manage-applications
sh docs/install_dependencies.sh

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
git clone https://github.com/fkooman/html-manage-authorizations.git
cd html-manage-authorizations
sh docs/install_dependencies.sh

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
git clone https://github.com/fkooman/html-view-grades.git
cd html-view-grades
sh docs/install_dependencies.sh

# configure
cat config/config.js.default \
    | sed "s|http://localhost|${BASE_URL}|g" > config/config.js
)

cat << EOF
#########################
# php-oauth-demo-client #
#########################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-oauth-demo-client.git
cd php-oauth-demo-client

mkdir extlib
ln -s ../../php-rest-service extlib/

cat ${LAUNCH_DIR}/config/debug_configuration.json \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > config.json
)

cat << EOF
####################
# php-oauth-client #
####################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-oauth-client.git
cd php-oauth-client
sh docs/configure.sh

cat config/client.ini \
    | sed "s|http://localhost/|${BASE_URL}/|g" > config/tmp_client.ini
mv config/tmp_client.ini config/client.ini

cat index.php \
    | sed "s|http://localhost/|${BASE_URL}/|g" > tmp_index.php
mv tmp_index.php index.php
)

cat << EOF
########################
# php-oauth-example-rs #
########################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-oauth-example-rs.git
cd php-oauth-example-rs

mkdir extlib
ln -s ../../php-lib-remote-rs extlib/

sh docs/configure.sh

cat config/rs.ini \
    | sed "s|http://localhost/php-oauth/tokeninfo.php|${BASE_URL}/php-oauth/tokeninfo.php|g" > config/tmp_rs.ini
mv config/tmp_rs.ini config/rs.ini
)

cat << EOF
#######################
# php-oauth-grades-rs #
#######################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-oauth-grades-rs.git
cd php-oauth-grades-rs

mkdir extlib
ln -s ../../php-rest-service extlib/
ln -s ../../php-lib-remote-rs extlib/

sh docs/configure.sh

cat config/rs.ini \
    | sed "s|http://localhost/php-oauth/tokeninfo.php|${BASE_URL}/php-oauth/tokeninfo.php|g" > config/tmp_rs.ini
mv config/tmp_rs.ini config/rs.ini

# Apache config
cat docs/apache.conf \
    | sed "s|/APPNAME|${BASE_PATH}/php-oauth-grades-rs|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-oauth-grades-rs|g" > ${INSTALL_DIR}/apache/oauth_php-oauth-grades-rs.conf
)

cat << EOF
#####################
# php-voot-provider #
#####################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-voot-provider.git
cd php-voot-provider

mkdir extlib
ln -s ../../php-rest-service extlib/

sh docs/configure.sh
php docs/initVootDatabase.php
cat docs/apache.conf \
    | sed "s|/APPNAME|${BASE_PATH}/php-voot-provider|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-voot-provider|g" > ${INSTALL_DIR}/apache/oauth_php-voot-provider.conf
)

cat << EOF
##################
# php-voot-proxy #
##################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-voot-proxy.git
cd php-voot-proxy

mkdir extlib
ln -s ../../php-rest-service extlib/
ln -s ../../php-lib-remote-rs extlib/

sh docs/configure.sh

cat config/proxy.ini \
    | sed "s|http://localhost/php-oauth/tokeninfo.php|${BASE_URL}/php-oauth/tokeninfo.php|g" > config/tmp_proxy.ini
mv config/tmp_proxy.ini config/proxy.ini

php docs/initProxyDatabase.php
cat docs/apache.conf \
    | sed "s|/APPNAME|${BASE_PATH}/php-voot-proxy|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-voot-proxy|g" > ${INSTALL_DIR}/apache/oauth_php-voot-proxy.conf

# Register Providers
cat ${LAUNCH_DIR}/config/provider_registrations.json \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > docs/myregistration.json
php docs/registerProviders.php docs/myregistration.json
)

cat << EOF
####################
# html-voot-client #
####################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/html-voot-client.git
cd html-voot-client
sh docs/install_dependencies.sh

# configure
cat config/config.js.default \
    | sed "s|http://localhost|${BASE_URL}|g" > config/config.js
)

cat << EOF
######################
# voot-specification #
######################
EOF
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/voot-specification.git
)

cat << EOF
###################################
# SAML attribute list application #
###################################
EOF
(
mkdir -p ${INSTALL_DIR}/saml
cd ${INSTALL_DIR}/saml
cat ${LAUNCH_DIR}/res/saml.php \
    | sed "s|{INSTALL_DIR}|${INSTALL_DIR}|g" > ${INSTALL_DIR}/saml/index.php
)

# Done
echo "**********************************************************************"
echo "* INSTALLATION DONE                                                  *"
echo "**********************************************************************"
echo
echo Please visit ${BASE_URL}.
echo
