#!/bin/bash
# Author: Daniel Gordi (danitfk)
# Date: 14/Nov/2018

### VARIABLES ####
# BITBUCKET Installation variables (must change by user)
BITBUCKET_USER="bitbucket"
BITBUCKET_HOME="/opt/bitbucket"
BITBUCKET_DISPLAY_NAME="Your Bitbucket"
BITBUCKET_BASE_URL="bitbucket.gordi.ir"
BITBUCKET_LICENSE=""
BITBUCKET_SYSADMIN_USER="superuser"
BITBUCKET_SYSADMIN_PASSWORD="logmein2018@@"
BITBUCKET_SYSADMIN_DISPLAY_NAME="Bitbucket Superuser"
BITBUCKET_SYSADMIN_EMAIL_ADDRESS="superuser@mydomain.tld"
BITBUCKET_DATABASE_NAME="bitbucket"
BITBUCKET_DATABASE_USERNAME="bitbucketusernameDB2018"
BITBUCKET_DATABASE_PASSWORD="bitbucketpasswordDB2018"
BITBUCKET_PLUGIN_MIRRORING_UPSTREAM="https://bitbucket.gordi.ir"
BITBUCKET_SSL_CERTIFICATE_PASS="myrandomSSLpass"
# Bitbucket archive URL
BITBUCKET_URL="https://downloads.atlassian.com/software/stash/downloads/atlassian-bitbucket-5.15.1.tar.gz"
BITBUCKET_MYSQL_DIRVER_REPO="https://dev.mysql.com/get/Downloads/Connector-J/"
BITBUCKET_MYSQL_DRIVER_NAME="mysql-connector-java-8.0.13.tar.gz"
# JDK 8 tar.gz Archive
JAVA_REPOSITORY="https://ftp.weheartwebsites.de/linux/java/jdk/"
JAVA_FILENAME="jdk-8u192-linux-x64.tar.gz"
###################

function system_health_check {
# Check sudo access or root user
if [ "$(whoami)" != "root" ]; then
        echo "ERROR! "
	echo "You have to run this script by root user or sudo command"
        exit 1
fi
# Check network connectivity
if ping -q -c 1 -W 1 google.com >/dev/null; then
  echo "The Internet connectivity and system DNS is OK."
else
  echo "ERROR!! -> There is some problem in Internet connectivity or system DNS."
  exit 1
fi
SYSTEM_IP=`ifconfig | grep inet | awk {'print $2'} | cut -d":" -f2 | grep -Ev "127.0.0.1|:"`
printf "Your Public IP address is $SYSTEM_IP? (y/n) "
read answer
if [[ "$answer" == "y" ]] 
then
	DOMAIN_IP=`dig $BITBUCKET_BASE_URL +short @8.8.8.8`
	if [[ "$DOMAIN_IP" == "$SYSTEM_IP" ]]
	then
		echo "System IP and Domain got matched."
	else
		echo "System IP and Domain not matched."
		exit 1
	fi
	
else
	printf "Please Enter your correct Public IP of Server. (Must match with domain)"
	read answer
	DOMAIN_IP=`dig $BITBUCKET_BASE_URL +short @8.8.8.8`
	if [[ "$DOMAIN_IP" == "$answer" ]]
	then
		echo "System IP and Domain got matched."
	else
		echo "System IP and Domain not matched."
		exit 1
	fi
	
fi

}
### Install Oracle Java 8
function java_install {
cd /opt/
rm -rf $JAVA_FILENAME java `ls -lf1 | grep jdk`
wget -q `echo "$JAVA_REPOSITORY""$JAVA_FILENAME"`
tar -xf $JAVA_FILENAME && rm -f $JAVA_FILENAME
ln -s `ls -lf1 | grep jdk` java
update-alternatives --install /usr/bin/java java /opt/java/bin/java 1
update-alternatives --install /usr/bin/javac javac /opt/java/bin/javac 1
update-alternatives --install /usr/bin/javadoc javadoc /opt/java/bin/javadoc 1
update-alternatives --install /usr/bin/jarsigner jarsigner /opt/java/bin/jarsigner 1
update-alternatives --install /usr/bin/keytool keytool /opt/java/bin/keytool 1
export JAVA_HOME="/opt/java/"
echo 'JAVA_HOME="/opt/java/" >> /etc/environment"'
}
### Install System requirements with package manager and download sources
function requirements_install {
apt-get update
apt-get install -qy wget
wget -q http://ftp.au.debian.org/debian/pool/main/n/netselect/netselect_0.3.ds1-26_amd64.deb
dpkg -i netselect_0.3.ds1-26_amd64.deb
rm -f netselect_0.3.ds1-26_amd64.deb
FAST_APT=`sudo netselect -s 20 -t 40 $(wget -qO - mirrors.ubuntu.com/mirrors.txt) | tail -n1 | grep -o http.*`
if [[ $FAST_APT == "" ]];
then
	echo "Cannot find fastest mirror of apt."
	echo "Continue with default mirror"
else
	ORIG_APT=`cat /etc/apt/sources.list | grep deb | awk {'print $2'} | uniq | head -n1`
	sed -i "s|$ORIG_APT|$FAST_APT|g" /etc/apt/sources.list
	apt-get update
fi
apt-get install -qy git postfix mysql-server nano curl software-properties-common locales
cd /usr/local/src
wget -qO "bitbucket.tar.gz" "$BITBUCKET_URL"
tar -xf bitbucket.tar.gz
BITBUCKET_DIR_NAME=`ls -f1 | grep atlassian-bitbucket`
cp -r $BITBUCKET_DIR_NAME $BITBUCKET_HOME
rm -rf $BITBUCKET_DIR_NAME
locale-gen "en_US.UTF-8"
update-locale LC_ALL="en_US.UTF-8"
export LC_ALL=en_US.UTF-8
export BITBUCKET_HOME=$BITBUCKET_HOME
}

### Install MySQL Driver into bitbucket
function mysql_driver_install {
cd /tmp/
wget -qO "$BITBUCKET_MYSQL_DRIVER_NAME" `echo "$BITBUCKET_MYSQL_DIRVER_REPO""$BITBUCKET_MYSQL_DRIVER_NAME"`
tar -xf "$BITBUCKET_MYSQL_DRIVER_NAME"
cd `echo "$BITBUCKET_MYSQL_DRIVER_NAME" | sed 's/.tar.gz//g'`
cp `echo "$BITBUCKET_MYSQL_DRIVER_NAME" | sed 's/.tar.gz/.jar/g'` $BITBUCKET_HOME/lib/`echo "$BITBUCKET_MYSQL_DRIVER_NAME" | sed 's/.tar.gz/.jar/g'`
echo "$(tput setaf 2)MySQL Driver Installed successfully. $(tput sgr 0)"
}

### Create bitbucket user and home directory
function user_permissions {
useradd $BITBUCKET_USER
usermod -s /bin/nologin $BITBUCKET_USER
usermod -d $BITBUCKET_HOME $BITBUCKET_USER
chown -R $BITBUCKET_USER:$BITBUCKET_USER $BITBUCKET_HOME
usermod -a -G sudo $BITBUCKET_USER

}


### Configure MySQL Database
function mysql_configure {
systemctl enable mysql > /dev/null 2>&1
systemctl start mysql > /dev/null 2>&1
echo "create database $BITBUCKET_DATABASE_NAME CHARACTER SET utf8 COLLATE utf8_bin;" | mysql -u'root'
echo "grant all on $BITBUCKET_DATABASE_NAME.* to \"$BITBUCKET_DATABASE_USERNAME\"@localhost identified by \"$BITBUCKET_DATABASE_PASSWORD\";" | mysql -u'root'
echo "FLUSH PRIVILEGES;" | mysql -u'root'
}

### Install Let's Encrypt and Issue SSL certificate
function install_letsencrypt { 
add-apt-repository ppa:certbot/certbot -y > /dev/null 2>&1
apt-get update
apt-get install -qy certbot
certbot certonly --standalone --preferred-challenges http --agree-tos --email $BITBUCKET_SYSADMIN_EMAIL_ADDRESS -d $BITBUCKET_BASE_URL --non-interactive
SSL_DIRECTORY=`echo "/etc/letsencrypt/live/$BITBUCKET_BASE_URL/"`
SSL_CERT_FILE=`echo "$SSL_DIRECTORY""cert.pem"`
SSL_KEY_FILE=`echo "$SSL_DIRECTORY""privkey.pem"`
SSL_CHAIN_FILE=`echo "$SSL_DIRECTORY""chain.pem"`
SSL_FULLCHAIN_FILE=`echo "$SSL_DIRECTORY""fullchain.pem"`
# Create Java keystore from Let's encrypt
cd $SSL_DIRECTORY
openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out pkcs.p12 -name $BITBUCKET_BASE_URL -passin pass:$BITBUCKET_SSL_CERTIFICATE_PASS -passout pass:$BITBUCKET_SSL_CERTIFICATE_PASS > /dev/null 2>&1
keytool -importkeystore -deststorepass $BITBUCKET_SSL_CERTIFICATE_PASS -destkeypass  $BITBUCKET_SSL_CERTIFICATE_PASS  -destkeystore $BITBUCKET_BASE_URL.jks -srckeystore pkcs.p12 -srcstoretype PKCS12 -srcstorepass $BITBUCKET_SSL_CERTIFICATE_PASS -alias $BITBUCKET_BASE_URL > /dev/null 2>&1
SSL_JKS_FILE=`echo "$SSL_DIRECTORY""$BITBUCKET_BASE_URL"".jks"`

}
function generate_properties {

cat > $BITBUCKET_HOME/bitbucket.properties  << EOL
BITBUCKET_DATABASE_USERNAME="bitbucketusernameDB2018"
BITBUCKET_DATABASE_PASSWORD="bitbucketpasswordDB2018"
BITBUCKET_PLUGIN_MIRRORING_UPSTREAM="https://bitbucket.gordi.ir"
setup.displayName=$BITBUCKET_DISPLAY_NAME
setup.baseUrl=$BITBUCKET_BASE_URL
setup.license=$BITBUCKET_LICENSE
setup.sysadmin.username=$BITBUCKET_SYSADMIN_USER
setup.sysadmin.password=$BITBUCKET_SYSADMIN_PASSWORD
setup.sysadmin.displayName=$BITBUCKET_DATABASE_NAME="bitbucket"
setup.sysadmin.emailAddress=$BITBUCKET_SYSADMIN_EMAIL_ADDRESS
jdbc.driver=org.postgresql.Driver
jdbc.url=jdbc:postgresql://localhost:3306/$BITBUCKET_DATABASE_NAME
jdbc.user=$BITBUCKET_DATABASE_USERNAME
jdbc.password=$BITBUCKET_DATABASE_PASSWORD
plugin.mirroring.upstream.url=$BITBUCKET_PLUGIN_MIRRORING_UPSTREAM
server.port=8443
server.ssl.enabled=true
server.ssl.key-store=$SSL_JKS_FILE
server.ssl.key-store-password=$BITBUCKET_SSL_CERTIFICATE_PASS
server.ssl.key-password=$BITBUCKET_SSL_CERTIFICATE_PASS
EOL

}

function start_bitbucket {
echo "Start bitbucket"
}
# Flow:
# 0) Run System Health check
# 1) Install requirements, services and source
# 2) Install Java JDK 8 
# 3) Create user and set permissions
# 4) Install MySQL Driver connector in Bitbucket
# 5) Configure MySQL Database 
# 6) Install Let's Encrypt and Issue certificate
# 7) Generate bitbucket.properties
# 8) Start bitbucket service



# non-interactive apt
export DEBIAN_FRONTEND=noninteractive
echo "0) System health check running (Internet Connectivity, DNS, Hostname, Resolve Domain)..." && system_health_check && echo "$(tput setaf 2)0) Everything is alright.. $(tput sgr 0)"
echo "1) Installing system requirements and download sources..." && requirements_install $(tput setaf 3) > /dev/null && echo "$(tput setaf 2)1) System Requirements installed successfully. $(tput sgr 0)"
echo "2) Installing Oracle Java JDK 8 ..." &&  tput setaf 3 && java_install > /dev/null && echo "$(tput setaf 2)2) Oracle Java JDK 8 installed successfully. $(tput sgr 0)"
echo "3) Create bitbucket user and set permissions..." &&   tput setaf 3 && user_permissions > /dev/null && echo "$(tput setaf 2)3) Bitbucket user created successfully. $(tput sgr 0)"
echo "4) Install MySQL Driver into Bitbucket..." && tput setaf 3 && mysql_driver_install > /dev/null && echo "$(tput setaf 2)4) MySQL Driver Installed successfully. $(tput sgr 0)"
echo "5) Configure MySQL Database..." &&  tput setaf 3 && mysql_configure > /dev/null && echo "$(tput setaf 2)5) MySQL Database configured successfully. $(tput sgr 0)"
echo "6) Install Let's Encrypt and Issue SSL..." &&  tput setaf 3 && install_letsencrypt > /dev/null && echo "$(tput setaf 2)6) Let's Encrypt install and SSL certificate issued successfully. $(tput sgr 0)"
echo "7) Generate Bitbucket system properties file..." &&  tput setaf 3 && generate_properties > /dev/null && echo "$(tput setaf 2)7) BitBucket properties file generated successfully. $(tput sgr 0)"
echo "8) Start bitbucket service..." &&  tput setaf 3 && start_bitbucket > /dev/null && echo "$(tput setaf 2)8) Bitbucket started successfully and you can access to the server with these details:" ;echo "URL: https://$BITBUCKET_BASE_URL:8443" ; echo "Username: $BITBUCKET_SYSADMIN_USER" ; echo "Password: $BITBUCKET_SYSADMIN_PASSWORD $(tput sgr 0)"

