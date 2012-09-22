#!/bin/sh

# make sure this directory exists and is owned by the user running the script
#INSTALL_DIR="/var/www/html/oauth"
INSTALL_DIR="/Library/WebServer/Documents/oauth"

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
# * php-summerschool (sample OAuth resource server)                           #
# * simpleSAMLphp (both as a SAML identity and service provider)              #
# * php-oauth-demo-client (a client to debug OAuth servers)                   #
# * php-oauth-client (a client library)                                       #
#                                                                             #
# The following dependencies are required:                                    #
#                                                                             #
# * php (command line version)                                                #
# * git                                                                       #
# * ...                                                                       #
# * ...                                                                       #
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

# apply simpleSAMLphp configuration patch for both IdP and SP
patch -p1 < ${LAUNCH_DIR}/config/simpleSAMLphp.diff

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

cat docs/registration.json \
    | sed "s|http://localhost/html-manage-applications|http://localhost/oauth/apps|g" \
    | sed "s|http://localhost/html-manage-authorizations|http://localhost/oauth/auth|g" > docs/myregistration.json

php docs/registerClients.php docs/myregistration.json

# add some more clients
echo '[{"id":"debug_client","name":"OAuth Debug Client","description":"Debug Client","secret":"s3cr3t","redirect_uri":"http:\/\/localhost\/oauth\/debug\/index.php","type":"web_application","icon":null,"allowed_scope":"read","contact_email":null},{"id":"demo","name":"OAuth Client Library Demo","description":"Simple Client Library Demo App","secret":"foo","redirect_uri":"http:\/\/localhost\/oauth\/client\/index.php","type":"web_application","icon":null,"allowed_scope":"read","contact_email":null}]' > docs/additional.json

php docs/registerClients.php docs/additional.json

# AS config
cat config/oauth.ini.defaults \
    | sed "s|authenticationMechanism = \"DummyResourceOwner\"|;authenticationMechanism = \"DummyResourceOwner\"|g" \
    | sed "s|;authenticationMechanism = \"SspResourceOwner\"|authenticationMechanism = \"SspResourceOwner\"|g" \
    | sed "s|allowResourceOwnerScopeFiltering = FALSE|allowResourceOwnerScopeFiltering = TRUE|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/as|g" \
    | sed "s|enableApi = FALSE|enableApi = TRUE|g" \
    | sed "s|/var/simplesamlphp|${INSTALL_DIR}/ssp|g" > config/oauth.ini

# Apache config
cat docs/apache.conf \
    | sed "s|/APPNAME|/oauth/as|g" \
    | sed "s|/PATH/TO/APP|${INSTALL_DIR}/as|g" > ${INSTALL_DIR}/apache/oauth_as.conf
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
patch -p1 < ${LAUNCH_DIR}/config/html-manage-applications.diff
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
patch -p1 < ${LAUNCH_DIR}/config/html-manage-authorizations.diff
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

# Client config
cat config.json \
    | sed "s|http://localhost/php-oauth|http://localhost/oauth/as|g" \
    | sed "s|php-oauth-code-client|debug_client|g" > tmp_config.json
mv tmp_config.json config.json
)

####################
# php-oauth-client #
####################
(
mkdir -p ${INSTALL_DIR}/client
cd ${INSTALL_DIR}/client
git clone https://github.com/fkooman/php-oauth-client.git .
sh docs/configure.sh

# Client config
cat config/client.ini \
    | sed "s|http://localhost/php-oauth/|http://localhost/oauth/as/|g" \
    | sed "s|http://localhost/php-oauth-client/index.php|http://localhost/oauth/client/index.php|g" > config/tmp_client.ini
mv config/tmp_client.ini config/client.ini

cat index.php \
    | sed "s|http://localhost/php-oauth|http://localhost/oauth/as|g" > tmp_index.php
mv tmp_index.php index.php
)

# Done
echo "**********************************************************************"
echo "* INSTALLATION DONE                                                  *"
echo "*                                                                    *" 
echo "* Please visit http://localhost/oauth to see a list of all installed *"
echo "* services and what you can do with them.                            *"
echo "*                                                                    *"
echo "**********************************************************************"
