#!/bin/bash
#Author: Daniel Gordi (danitfk)
#Date: 14/Nov/2018

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

}
### Install Oracle Java 8
function java_install {
cd /opt/
wget `echo "$JAVA_REPOSITORY""$JAVA_FILENAME"`
tar -xf $JAVA_FILENAME && rm -f $JAVA_FILENAME
ln -s `echo $JAVA_FILENAME | sed 's/.tar.gz//g'` java
update-alternatives --install /usr/bin/java java /opt/java/bin/java 1
update-alternatives --install /usr/bin/javac javac /opt/java/bin/javac 1
update-alternatives --install /usr/bin/javadoc javadoc /opt/java/bin/javadoc 1
update-alternatives --install /usr/bin/jarsigner jarsigner /opt/java/bin/jarsigner 1
}
### Install System requirements with package manager and download sources
function requirements_install {
apt-get update
apt-get install -qy wget
wget http://ftp.au.debian.org/debian/pool/main/n/netselect/netselect_0.3.ds1-26_amd64.deb
dpkg -i netselect_0.3.ds1-26_amd64.deb
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
apt-get install -qy git postfix mysql-server nano curl
cd /usr/local/src
wget -O "bitbucket.tar.gz" "$BITBUCKET_URL"
tar -xf bitbucket.tar.gz
BITBUCKET_DIR_NAME=`ls -f1 | grep atlassian-bitbucket`
mv $BITBUCKET_DIR_NAME $BITBUCKET_HOME
}

### Install MySQL Driver into bitbucket
function mysql_driver_install {
cd /tmp/
wget -O "$BITBUCKET_MYSQL_DRIVER_NAME" `echo "$BITBUCKET_MYSQL_DIRVER_REPO""$BITBUCKET_MYSQL_DRIVER_NAME"`
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

function mysql_configure {
systemctl enable mysql-server
systemctl start mysql-server
echo "create database $BITBUCKET_DATABASE_NAME CHARACTER SET utf8 COLLATE utf8_bin;" | mysql -u'root'
echo "grant all on $BITBUCKET_DATABASE_NAME.* to \"$BITBUCKET_DATABASE_USERNAME\"@localhost identified by \"$BITBUCKET_DATABASE_PASSWORD\";" | mysql -u'root'
echo "FLUSH PRIVILEGES;" | mysql -u'root'
}

# Flow:
# 0) System Health check
# 1) Install requirements, services and source
# 2) Install Java JDK 8 
# 3) Create user and set permissions
# 4) Install MySQL Driver connector in Bitbucket
# 5) Configure MySQL Database 
# 6)
# 6)
# 6)



# non-interactive apt
export DEBIAN_FRONTEND=noninteractive
echo "0) System health check running (Internet Connectivity, DNS, Hostname, Resolve Domain)..." && requirements_install && echo "$(tput setaf 2)0) Everything is alright.. $(tput sgr 0)"
echo "1) Installing system requirements and download sources..." && requirements_install && echo "$(tput setaf 2)1) System Requirements installed successfully. $(tput sgr 0)"
echo "2) Installing Oracle Java JDK 8 ..." && java_install && echo "$(tput setaf 2)2) Oracle Java JDK 8 installed successfully. $(tput sgr 0)"
echo "3) Create bitbucket user and set permissions..." &&  user_permissions && echo "$(tput setaf 2)3) Bitbucket user created successfully. $(tput sgr 0)"
echo "4) Install MySQL Driver into Bitbucket..." &&  mysql_dirver_install && echo "$(tput setaf 2)4) MySQL Driver Installed successfully. $(tput sgr 0)"
echo "5) Configure MySQL Database..." &&  mysql_configure && echo "$(tput setaf 2)5) MySQL Database configured successfully. $(tput sgr 0)"


