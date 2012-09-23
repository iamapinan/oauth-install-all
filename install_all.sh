#!/bin/sh

# Make sure this directory exists and is owned by the user running the script

# Fedora, CentOS, RHEL
#INSTALL_DIR="/var/www/html/oauth"

# Debian, Ubuntu
#INSTALL_DIR="/var/www/oauth"

# Mac OS X
INSTALL_DIR="/Library/WebServer/Documents/oauth"

# Set the base URL under which this software will be available through a 
# web server, can be http://localhost/oauth or some PageKite host, or an 
# actual host!

#BASE_URL="https://fkooman.pagekite.me/oauth"
BASE_URL="http://localhost/oauth"

SIMPLESAMLPHP_VERSION=1.9.2

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
#                                                                             #
###############################################################################

LAUNCH_DIR=`pwd`

# remove the existing installation
rm -rf ${INSTALL_DIR}/*

#if [ ! -f ${INSTALL_DIR} ]
#then
#    echo "install dir ${INSTALL_DIR} does not exist";
#    exit 1
#fi

mkdir -p ${INSTALL_DIR}/downloads
mkdir -p ${INSTALL_DIR}/apache

# the index page
cp ${LAUNCH_DIR}/res/index.html ${INSTALL_DIR}/index.html

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

# update the BASE_URL in the patch and apply the simpleSAMLphp configuration 
# patch to configure an IdP and SP
cat ${LAUNCH_DIR}/config/simpleSAMLphp.diff \
    | sed "s|{BASE_URL}|${BASE_URL}|g" | patch -p1

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

# Done
echo "**********************************************************************"
echo "* INSTALLATION DONE                                                  *"
echo "**********************************************************************"
echo
echo Please visit ${BASE_URL}.
echo
