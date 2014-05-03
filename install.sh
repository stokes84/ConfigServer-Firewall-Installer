#!/bin/bash

# Set some styles
bold=`tput bold`
alert=`tput setaf 1`
info=`tput setaf 3`
normal=`tput sgr0`

# Make a temp dir to toss install files in	
mkdir -p /tmp/csf_install

# Grab the latest version of CSF for FREE!!! ...let's decompress and install it too
wget -q -O /tmp/csf_install/csf.tgz http://www.configserver.com/free/csf.tgz
tar -xf /tmp/csf_install/csf.tgz -C /tmp/csf_install
cd /tmp/csf_install/csf && sh install.sh

# Install the CSF dependencies
if [ -f /etc/redhat-release ]; then
	yum -y install sed openssl perl-Time-HiRes perl-libwww-perl perl-GDGraph perl-IO-Socket-SSL.noarch perl-Net-SSLeay perl-Net-LibIDN perl-IO-Socket-INET6 perl-Socket6
else
	apt-get -y install sed openssl libio-socket-ssl-perl libcrypt-ssleay-perl libnet-libidn-perl libio-socket-inet6-perl libsocket6-perl
fi

# Extra security stuffs because we don't like warning messages, view readme @ http://configserver.com/free/csf/readme.txt
sed -i -e 's|RESTRICT_SYSLOG = "0"|RESTRICT_SYSLOG = "3"|g' /etc/csf/csf.conf

# We'll just flip this switch off, we don't wanna test give us security now!
sed -i -e 's|TESTING = "1"|TESTING = "0"|g' /etc/csf/csf.conf

# Turn that GUI on
sed -i -e 's|UI = "0"|UI = "1"|g' /etc/csf/csf.conf

# Do we want to harden access to the CSF GUI based on IP?
printf "\n${alert}${bold}Attention:${normal} Highly recommended that you restrict IP access to the GUI";
printf "\n${info}${bold}Note:${normal} This restricts access based on client IP not server IP";
printf "\n${info}${bold}Note:${normal} If you're behind a dynamic IP then you may want to decline\n";
read -e -p "Do you wish to enable IP access restrictions? (y/n)" yn
case $yn in
[Yy]* )
	# Just in case you want to switch the option from the installer
	sed -i -e 's|UI_ALLOW = "0"|UI_ALLOW = "1"|g' /etc/csf/csf.conf
	# Giz me your IP address!... the one you're on now because it's the only one that will have access to the CSF GUI
	printf "\n${alert}${bold}Attention:${normal} This is the only IP allowed access to the CSF GUI"
	printf "\n${info}${bold}Note:${normal} You can add/remove IP's @ /etc/csf/ui/ui.allow\n"
	read -e -p "CSF GUI Allowed Access IP: " -i "${SSH_CLIENT%% *}" csfIP
	echo ${csfIP} >> /etc/csf/ui/ui.allow
	;;
[Nn]* ) 
	sed -i -e 's|UI_ALLOW = "1"|UI_ALLOW = "0"|g' /etc/csf/csf.conf
	;;
esac

if [ -f /etc/redhat-release ]; then
	# Telling CSF to ignore commonly flagged ZPanel processes (CentOS)
	sed -i '$a\exe:/usr/libexec/postfix/pickup' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/libexec/postfix/smtpd' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/libexec/postfix/qmgr' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/libexec/mysqld' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/sbin/httpd' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/libexec/dovecot/anvil' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/libexec/dovecot/auth' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/libexec/dovecot/pop3-login' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/libexec/dovecot/imap-login' /etc/csf/csf.pignore
else
	# Telling CSF to ignore commonly flagged ZPanel processes (Ubuntu)
	sed -i '$a\exe:/usr/lib/postfix/pickup' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/lib/postfix/smtpd' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/lib/postfix/qmgr' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/sbin/mysqld' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/lib/apache2/mpm-prefork/apache2' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/lib/dovecot/anvil' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/lib/dovecot/auth' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/lib/dovecot/pop3-login' /etc/csf/csf.pignore
	sed -i '$a\exe:/usr/lib/dovecot/imap-login' /etc/csf/csf.pignore
fi

# Giz me your GUI username!
# Also this cannot be "username" or CSF will complain
printf "\n${info}${bold}Note:${normal} You can edit this username @ /etc/csf/csf.conf\n"
read -e -p "CSF GUI Login Username: " csfUser
sed -i -e "s|UI_USER = \"username\"|UI_USER = \"${csfUser}\"|g" /etc/csf/csf.conf

# Giz me your GUI password!
# You'll want this one strong although CSF has built in brute force detection (4 attempts)
# Also this cannot be "password" or CSF will complain
printf "\n${info}${bold}Note:${normal} You can edit this password @ /etc/csf/csf.conf\n"
read -e -p "CSF GUI Login Password: " csfPass
sed -i -e "s|UI_PASS = \"password\"|UI_PASS = \"${csfPass}\"|g" /etc/csf/csf.conf

# Let's setup a port to push the GUI through
printf "\n${info}${bold}Note:${normal} Leave this blank to disable firewall activity alerts"
printf "\n${info}${bold}Note:${normal} You can edit this email @ /etc/csf/csf.conf\n"
read -e -p "CSF Alert Email: " csfEmail
sed -i -e "s|LF_ALERT_TO = \"\"|LF_ALERT_TO = \"${csfEmail}\"|g" /etc/csf/csf.conf

# Wanna get some emails from CSF?
printf "\n${info}${bold}Note:${normal} Should be >1023 and an unused port"
printf "\n${info}${bold}Note:${normal} You can edit this port @ /etc/csf/csf.conf\n"
read -e -p "CSF GUI Port: " csfPort
sed -i -e "s|UI_PORT = \"6666\"|UI_PORT = \"${csfPort}\"|g" /etc/csf/csf.conf

# Just in case you were using APF+BFD we'll try to remove it if it exists
sh /etc/csf/remove_apf_bfd.sh

# Remove the temp install dir
rm -rf /tmp/csf_install

# Install SSL if you say we need to (we need it for GUI access)
printf "\n${alert}${bold}Attention:${normal} SSL is ${bold}required${normal} for connecting to the CSF GUI\n";
read -e -p "Do you need SSL installed and configured? (y/n)" yn
case $yn in
[Yy]* ) 
	echo "Installing and configuring SSL for CSF GUI access..."
	if [ -f /etc/redhat-release ]; then
		yum -y install mod_ssl
	fi
	cd /etc/csf/ui
	openssl genrsa -out server.key 2048
	openssl req -key server.key -new -out server.csr
	openssl x509 -in server.csr -out server.crt -req -signkey server.key -days 3650
	chmod 400 server.*
	sed -i -e 's|SSLCertificateFile /etc/pki/tls/certs/localhost.crt|SSLCertificateFile /etc/csf/ui/server.crt|g' /etc/httpd/conf.d/ssl.conf
	sed -i -e 's|SSLCertificateKeyFile /etc/pki/tls/private/localhost.key|SSLCertificateKeyFile /etc/csf/ui/server.key|g' /etc/httpd/conf.d/ssl.conf
	;;
[Nn]* ) 
	printf "\n${alert}${bold}Attention:${normal} Make sure you copy your key and cert files to /etc/csf/ui\n";
	read -p "Press ${bold}[Enter]${normal} to complete installation..."
	;;
esac

# Restart firewall and Apache
csf -r && service lfd restart && service httpd restart

# Let's run a quick test make sure we don't have any fatal errors
perl /usr/local/csf/bin/csftest.pl


