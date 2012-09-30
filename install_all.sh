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
mkdir -p ${INSTALL_DIR}/as
cd ${INSTALL_DIR}/as
git clone https://github.com/fkooman/php-oauth.git .
sh docs/configure.sh
php docs/initOAuthDatabase.php

# AS config
cat config/oauth.ini.defaults \
    | sed "s|authenticationMechanism = \"DummyResourceOwner\"|;authenticationMechanism = \"DummyResourceOwner\"|g" \
    | sed "s|;authenticationMechanism = \"SspResourceOwner\"|authenticationMechanism = \"SspResourceOwner\"|g" \
    | sed "s|allowResourceOwnerScopeFiltering = FALSE|allowResourceOwnerScopeFiltering = TRUE|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/as|g" \
    | sed "s|enableApi = FALSE|enableApi = TRUE|g" \
    | sed "s|/var/simplesamlphp|${INSTALL_DIR}/ssp|g" > config/oauth.ini

# add entitlement for "grades" demo resource server
echo "entitlementValueMapping[\"administration\"] = \"urn:vnd:grades:administration\"" >> config/oauth.ini

# Apache config
cat docs/apache.conf \
    | sed "s|/APPNAME|/oauth/as|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/as|g" > ${INSTALL_DIR}/apache/oauth_as.conf

# Register Clients
cat ${LAUNCH_DIR}/config/client_registrations.json \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > docs/myregistration.json
php docs/registerClients.php docs/myregistration.json
)

############################
# html-manage-applications #
############################
(
mkdir -p ${INSTALL_DIR}/apps
cd ${INSTALL_DIR}/apps
git clone https://github.com/fkooman/html-manage-applications.git .
sh docs/install_dependencies.sh

# configure
cat ${LAUNCH_DIR}/config/html-manage-applications.diff \
    | sed "s|{BASE_URL}|${BASE_URL}|g" | patch -p1
)

##############################
# html-manage-authorizations #
##############################
(
mkdir -p ${INSTALL_DIR}/auth
cd ${INSTALL_DIR}/auth
git clone https://github.com/fkooman/html-manage-authorizations.git .
sh docs/install_dependencies.sh

# configure
cat ${LAUNCH_DIR}/config/html-manage-authorizations.diff \
    | sed "s|{BASE_URL}|${BASE_URL}|g" | patch -p1
)

#########################
# php-oauth-demo-client #
#########################
(
mkdir -p ${INSTALL_DIR}/debug
cd ${INSTALL_DIR}/debug
git clone https://github.com/fkooman/php-oauth-demo-client.git .

# use libs from php-oauth
ln -s ${INSTALL_DIR}/as/lib lib

cat ${LAUNCH_DIR}/config/debug_configuration.json \
    | sed "s|{BASE_URL}|${BASE_URL}|g" > config.json
)

####################
# php-oauth-client #
####################
(
mkdir -p ${INSTALL_DIR}/client
cd ${INSTALL_DIR}/client
git clone https://github.com/fkooman/php-oauth-client.git .
sh docs/configure.sh

cat config/client.ini \
    | sed "s|http://localhost/php-oauth/|${BASE_URL}/as/|g" \
    | sed "s|http://localhost/php-oauth-client/index.php|${BASE_URL}/client/index.php|g" > config/tmp_client.ini
mv config/tmp_client.ini config/client.ini

cat index.php \
    | sed "s|http://localhost/php-oauth|${BASE_URL}/as|g" > tmp_index.php
mv tmp_index.php index.php
)

#######################
# php-oauth-grades-rs #
#######################
(
mkdir -p ${INSTALL_DIR}/grades
cd ${INSTALL_DIR}/grades
git clone https://github.com/fkooman/php-oauth-grades-rs.git .
sh docs/configure.sh

cat config/rs.ini \
    | sed "s|/var/www/html/php-oauth|${INSTALL_DIR}/as|g" > config/tmp_rs.ini
mv config/tmp_rs.ini config/rs.ini

# Apache config
cat docs/apache.conf \
    | sed "s|/APPNAME|/oauth/grades|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/grades|g" > ${INSTALL_DIR}/apache/oauth_grades.conf
)

########################
# php-oauth-example-rs #
########################
(
mkdir -p ${INSTALL_DIR}/rs
cd ${INSTALL_DIR}/rs
git clone https://github.com/fkooman/php-oauth-example-rs.git .
sh docs/configure.sh

cat config/rs.ini \
    | sed "s|http://localhost/php-oauth/token.php|${BASE_URL}/as/token.php|g" > config/tmp_rs.ini
mv config/tmp_rs.ini config/rs.ini
)

# Done
echo "**********************************************************************"
echo "* INSTALLATION DONE                                                  *"
echo "**********************************************************************"
echo
echo Please visit ${BASE_URL}.
echo
