# Introduction
This project installs all components for running an OAuth service for
evaluating, testing and development.

It consist of an authorization server, a resource server and test clients. For
authentication the simpleSAMLphp framework is used as a SAML identity provider
and service provider. That way, the full stack is controlled and there are 
no outside dependencies anymore which is perfect for development purposes and
running it for instance in a virtual machine.

You can run this script on but Linux and Mac OS X systems.

# Configuration
There are some things you can configure in the script. One is the path to 
which to install the software. Some stuff is hardcoded, like the web directory
under which the software will be available, which is `http://localhost/oauth/`.

The directory for installation can be specified by modifying the `INSTALL_DIR`
parameter in the `install_all.sh` script. Here are some examples of what this
path should be on various operating systems:

* Linux (Fedora/CentOS/RHEL): `/var/www/html/oauth`
* Linux (Debian/Ubuntu): `/var/www/oauth`
* Mac OS X: `/Library/WebServer/Documents/oauth`

The script does not need root permissions, however, as the installation 
directory as suggested above are inside system paths you do need root permissions
to create this directory. Assuming your user account name is `fkooman` you can
run the following commands to create the directory and change the permissions:

On Fedora, CentOS and RHEL:

    $ su -c "mkdir /var/www/html/oauth"
    $ su -c "chown fkooman:fkooman /var/www/html/oauth"

On Ubuntu (Debian does not have `sudo`, use `su -c` like above with the Debian
path):

    $ sudo mkdir /var/www/oauth
    $ sudo chown fkooman:fkooman /var/www/oauth

On Mac OS X:

    $ sudo mkdir /Library/WebServer/Documents/oauth
    $ sudo chown fkooman:staff /Library/WebServer/Documents/oauth

Now you can run the script as a regular user. 

*NOTE*: the script will remove all files under the `INSTALL_DIR` location as
configured in `install_all.sh`. 

So assuming you are in the directory where you downloaded this project to, you
can simply run it:

    $ sh ./install_all.sh

If there are any warnings or errors about missing software you can just install
them and run the script again.

On a minimal Debian (base) install you need to install the following software, 
e.g. using `apt-get`:

    $ su -c "apt-get install git unzip php5-cli php5 php5-sqlite"

