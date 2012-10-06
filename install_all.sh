#!/bin/sh

if [ -z "$1" ]
then

cat << EOF
    Please specify the location to install to. 

    Examples:
    
    Fedora, CentOS, RHEL: /var/www/html/oauth
    Debian, Ubuntu: /var/www/oauth
    Mac OS X: /Library/WebServer/Documents/oauth
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
EOF
exit 1
else
    BASE_URL=$2
fi

SIMPLESAMLPHP_VERSION=1.10.0

###############################################################################
# This script installs the following components to have a fully functional    #
# OAuth installation with all the components to quickly evaluate the software #
#                                                                             #
# The following components will be installed:                                 #
#                                                                             #
# * php-oauth (the OAuth authorization server)                                #
# * html-manage-applications (management interface for the OAuth AS for       #
#   administrators)                                                           #
# * html-manage-authorization (manage OAuth client consent, for end users)    #
# * php-oauth-grades-rs (sample OAuth resource server)                        #
# * simpleSAMLphp (both as a SAML identity and service provider)              #
# * php-oauth-demo-client (a client to debug OAuth servers)                   #
# * php-oauth-client (a client library)                                       #
# * php-oauth-example-rs (a resource server library and example)              #
###############################################################################

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
rm -rf ${INSTALL_DIR}/*

mkdir -p ${INSTALL_DIR}/downloads
mkdir -p ${INSTALL_DIR}/apache

# the index page
cat ${LAUNCH_DIR}/res/index.html \
    | sed "s|{ADMIN_PASSWORD}|${SSP_ADMIN_PASSWORD}|g" > ${INSTALL_DIR}/index.html

#################
# simpleSAMLphp #
#################
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
echo "Alias /oauth/ssp ${INSTALL_DIR}/ssp/www" > ${INSTALL_DIR}/apache/oauth_ssp.conf
)

#############
# php-oauth #
#############
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-oauth.git
cd php-oauth
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
    | sed "s|/APPNAME|/oauth/php-oauth|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-oauth|g" > ${INSTALL_DIR}/apache/oauth_php-oauth.conf

# Register Clients
cat ${LAUNCH_DIR}/config/client_registrations.json \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > docs/myregistration.json
php docs/registerClients.php docs/myregistration.json
)

############################
# html-manage-applications #
############################
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/html-manage-applications.git
cd html-manage-applications
sh docs/install_dependencies.sh

# configure
cat ${LAUNCH_DIR}/config/html-manage-applications.diff \
    | sed "s|{BASE_URL}|${BASE_URL}|g" | patch -p1
)

##############################
# html-manage-authorizations #
##############################
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/html-manage-authorizations.git
cd html-manage-authorizations
sh docs/install_dependencies.sh

# configure
cat ${LAUNCH_DIR}/config/html-manage-authorizations.diff \
    | sed "s|{BASE_URL}|${BASE_URL}|g" | patch -p1
)

####################
# html-view-grades #
####################
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/html-view-grades.git
cd html-view-grades
sh docs/install_dependencies.sh

# configure
cat ${LAUNCH_DIR}/config/html-view-grades.diff \
    | sed "s|{BASE_URL}|${BASE_URL}|g" | patch -p1
)

#########################
# php-oauth-demo-client #
#########################
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-oauth-demo-client.git
cd php-oauth-demo-client

# use libs from php-oauth
ln -s ${INSTALL_DIR}/php-oauth/lib lib

cat ${LAUNCH_DIR}/config/debug_configuration.json \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > config.json
)

####################
# php-oauth-client #
####################
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

#######################
# php-oauth-grades-rs #
#######################
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-oauth-grades-rs.git
cd php-oauth-grades-rs
sh docs/configure.sh

cat config/rs.ini \
    | sed "s|/var/www/html/|${INSTALL_DIR}/|g" > config/tmp_rs.ini
mv config/tmp_rs.ini config/rs.ini

# Apache config
cat docs/apache.conf \
    | sed "s|/APPNAME|/oauth/php-oauth-grades-rs|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/php-oauth-grades-rs|g" > ${INSTALL_DIR}/apache/oauth_php-oauth-grades-rs.conf
)

########################
# php-oauth-example-rs #
########################
(
cd ${INSTALL_DIR}
git clone https://github.com/fkooman/php-oauth-example-rs.git
cd php-oauth-example-rs
sh docs/configure.sh

cat config/rs.ini \
    | sed "s|http://localhost/|${BASE_URL}/|g" > config/tmp_rs.ini
mv config/tmp_rs.ini config/rs.ini
)

###################################
# SAML attribute list application #
###################################
(
mkdir -p ${INSTALL_DIR}/saml_info
cd ${INSTALL_DIR}/saml_info
cat ${LAUNCH_DIR}/res/saml_info.php \
    | sed "s|{INSTALL_DIR}|${INSTALL_DIR}|g" > ${INSTALL_DIR}/saml_info/index.php
)

# Done
echo "**********************************************************************"
echo "* INSTALLATION DONE                                                  *"
echo "**********************************************************************"
echo
echo Please visit ${BASE_URL}.
echo
