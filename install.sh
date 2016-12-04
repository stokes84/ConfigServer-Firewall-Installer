#!/bin/bash

# Clear Screen
tput clear

# Hide Cursor
tput civis
trap 'tput cnorm' EXIT

# Set some styles
bold=$(tput bold)
alert=$(tput setaf 1)
info=$(tput setaf 3)
normal=$(tput sgr0)
red=$(tput setaf 1; tput bold)
green=$(tput setaf 2; tput bold)

script_dir="$( cd "$( dirname "$0" )" && pwd )"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#\tThis script must be run as root." 1>&2
    exit 1
fi

# Progress spinner function
function _spinner() {
    # 		$1 start/stop
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="SUCCESS"
    local on_fail="FAIL"

    case $1 in
        start)
            # Calculate the column where spinner and status msg will be displayed
            let column=$(tput cols)-${#2}
            # Display message and position the cursor in $column column
            printf "${2}"
            printf "%${column}s"

            # Start spinner
            i=1
            sp='\|/-'
            delay=0.15

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                # Spinner isn't running
                exit 1
            fi

            kill $3 > /dev/null 2>&1

            # inform the user uppon success or failure
            if [[ $2 -eq 0 ]]; then
                printf "\b[${green}${on_success}${normal}]\n"
                sleep 1
            else
                printf "\b[${red}${on_fail}${normal}]\n\n"
		eval printf %.0s- '{1..'"${COLUMNS:-$(tput cols)}"\}; echo
		error_title="${bold}Check Error Log${normal}"
		printf "%*s\n" $(((${#error_title}+$(tput cols))/2)) "$error_title"
		eval printf %.0s- '{1..'"${COLUMNS:-$(tput cols)}"\}; echo
		tail -2 install.log
		printf "\n"
		exit 1
            fi
            ;;
        *)
            # Invalid argument
            exit 1
            ;;
    esac
}

function start_spinner {
    # $1 : Msg to display
    _spinner "start" "${1}" &
    # Set global spinner pid
    _sp_pid=$!
    disown
}

function stop_spinner {
    # $1 : Command exit status
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}

# Remove previous install log
if [[ -f "install.log" ]]; then
	rm -f install.log
fi

start_spinner "${bold}Installing Dependencies${normal}"

{

# Install the CSF dependencies
if [ -f /etc/redhat-release ]; then
	yum -y update && yum -y install sed openssl perl-Time-HiRes perl-libwww-perl perl-GDGraph perl-IO-Socket-SSL.noarch perl-Net-SSLeay perl-Net-LibIDN perl-IO-Socket-INET6 perl-Socket6 net-tools rsyslog
else
	apt-get -y update && apt-get -y install apache2 sed openssl libio-socket-ssl-perl libcrypt-ssleay-perl libnet-libidn-perl libio-socket-inet6-perl libsocket6-perl
fi
} &> install.log

stop_spinner $?

start_spinner "${bold}Installing Latest Version of CSF${normal}"

{
# Make a temp dir to toss install files in	
mkdir -p /tmp/csf_install

# Grab the latest version of CSF for FREE!!! ...let's decompress and install it too
wget -q -O /tmp/csf_install/csf.tgz https://download.configserver.com/csf.tgz
tar -xf /tmp/csf_install/csf.tgz -C /tmp/csf_install
cd /tmp/csf_install/csf && sh install.sh
} &> install.log

stop_spinner $?

start_spinner "${bold}Configuring CSF${normal}"

{

# Extra security stuffs because we don't like warning messages, view readme @ http://configserver.com/free/csf/readme.txt
sed -i -e 's|RESTRICT_SYSLOG = "0"|RESTRICT_SYSLOG = "3"|g' /etc/csf/csf.conf

# We'll just flip this switch off, we don't wanna test give us security now!
sed -i -e 's|TESTING = "1"|TESTING = "0"|g' /etc/csf/csf.conf

# Turn that UI on
sed -i -e 's|UI = "0"|UI = "1"|g' /etc/csf/csf.conf
} &> install.log

stop_spinner $?

# Do we want to harden access to the CSF UI based on IP?
# printf "\n${alert}${bold}Attention:${normal} Highly recommended that you restrict IP access to the UI";
# printf "\n${info}${bold}Note:${normal} This restricts access based on client IP not server IP";
# printf "\n${info}${bold}Note:${normal} If you're behind a dynamic IP then you may want to decline\n";
tput sc; tput cnorm
read -e -p "Do you wish to enable UI IP access restrictions? (y/n)" yn
tput civis
case $yn in
[Yy]* )
	# Just in case you want to switch the option from the installer
	sed -i -e 's|UI_ALLOW = "0"|UI_ALLOW = "1"|g' /etc/csf/csf.conf
	tput rc; tput el
	printf "UI IP Restriction: [ ${green}ON${normal} ]\n"
	# Giz me your IP address!... the one you're on now because it's the only one that will have access to the CSF UI
	# printf "\n${alert}${bold}Attention:${normal} This is the only IP allowed access to the CSF UI"
	# printf "\n${info}${bold}Note:${normal} You can add/remove IP's @ /etc/csf/ui/ui.allow\n"
	tput cnorm
	read -e -p "CSF UI Allowed Access IP: " -i "${SSH_CLIENT%% *}" csfIP
	tput civis
	echo ${csfIP} >> /etc/csf/ui/ui.allow
	;;
[Nn]* ) 
	tput rc; tput el
	printf "UI IP Restriction: [ ${red}OFF${normal} ]\n"
	sed -i -e 's|UI_ALLOW = "1"|UI_ALLOW = "0"|g' /etc/csf/csf.conf
	;;
esac

# Giz me your UI username!
# Also this cannot be "username" or CSF will complain
# printf "\n${info}${bold}Note:${normal} You can edit this username @ /etc/csf/csf.conf\n"
tput cnorm
read -e -p "CSF UI Login Username: " csfUser
tput civis
sed -i -e '/UI_USER/s/"\([^"]*\)"/"'${csfUser}'"/' /etc/csf/csf.conf

# Giz me your UI password!
# You'll want this one strong although CSF has built in brute force detection (4 attempts)
# Also this cannot be "password" or CSF will complain
# printf "\n${info}${bold}Note:${normal} You can edit this password @ /etc/csf/csf.conf\n"
while true
do
	tput sc; tput cnorm
	read -es -p "Password: " password
	tput rc; tput el
	read -es -p "Password (again): " csfPass
	tput rc; tput el; tput civis
	[ "$password" = "$csfPass" ] && break
	printf "Passwords do not match, try again"
	sleep 1
	tput rc; tput el
done
# read -e -p "CSF UI Login Password: " csfPass
sed -i -e '/UI_PASS/s/"\([^"]*\)"/"'${csfPass}'"/' /etc/csf/csf.conf
tput rc; tput el
printf "CSF UI Password: [ ${green}OK${normal} ]\n"

# Wanna get some emails from CSF?
# printf "\n${info}${bold}Note:${normal} Leave this blank to disable firewall activity alerts"
# printf "\n${info}${bold}Note:${normal} You can edit this email @ /etc/csf/csf.conf\n"
tput cnorm
read -e -p "CSF Alert Email: " csfEmail
tput civis
sed -i -e '/LF_ALERT_TO/s/"\([^"]*\)"/"'${csfEmail}'"/' /etc/csf/csf.conf

# Let's setup a port to push the UI through
# printf "\n${info}${bold}Note:${normal} Should be >1023 and an unused port"
# printf "\n${info}${bold}Note:${normal} You can edit this port @ /etc/csf/csf.conf\n"
tput cnorm
read -e -p "CSF UI Port: " csfPort
tput civis
sed -i -e '/UI_PORT/s/"\([^"]*\)"/"'${csfPort}'"/' /etc/csf/csf.conf
sed -i -e 's|TCP_IN = "20,21,22,25,53,80,110,143,443,465,587,993,995"|TCP_IN = "20,21,22,25,53,80,110,143,443,465,587,993,995,'${csfPort}'"|g' /etc/csf/csf.conf

start_spinner "${bold}Removing Installation Files & APF+BFD${normal}"

{
# Just in case you were using APF+BFD we'll try to remove it if it exists
sh /etc/csf/remove_apf_bfd.sh

# Remove the temp install dir
rm -rf /tmp/csf_install
} &> install.log

stop_spinner $?

# Install SSL if you say we need to (we need it for UI access)
# printf "\n${alert}${bold}Attention:${normal} SSL is ${bold}required${normal} for connecting to the CSF UI\n";
tput sc; tput cnorm
read -e -p "Do you need SSL installed and configured (required for UI)? (y/n)" yn
case $yn in
[Yy]* ) 
	tput rc; tput el
	read -e -p "FQDN: " domain
	tput rc; tput el
	read -e -p "Email: " email
	tput rc; tput el
	read -e -p "SSL 2-Digit Country Code: " country
	tput rc; tput el
	read -e -p "SSL State: " state
	tput rc; tput el
	read -e -p "SSL City: " city
	tput rc; tput el
	read -e -p "SSL Organization: " organization
	tput rc; tput el; tput civis
	
	start_spinner "${bold}Installing OpenSSL & Configuring${normal}"

	{
	# echo "Installing and configuring SSL for CSF UI access..."
	if [ -f /etc/redhat-release ]; then
		yum -y install mod_ssl
		cd /etc/csf/ui
		openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=${country}/ST=${state}/L=${city}/O=${organization}/CN=${domain}" -keyout server.key -out server.crt
		chmod 400 server.*
		cp server.key /etc/pki/tls/certs/server.key
		cp server.crt /etc/pki/tls/certs/server.crt
		sed -i -e 's|SSLCertificateFile /etc/pki/tls/certs/localhost.crt|SSLCertificateFile /etc/pki/tls/certs/server.crt|g' /etc/httpd/conf.d/ssl.conf
		sed -i -e 's|SSLCertificateKeyFile /etc/pki/tls/private/localhost.key|SSLCertificateKeyFile /etc/pki/tls/certs/server.key|g' /etc/httpd/conf.d/ssl.conf
	else
		cd /etc/csf/ui
		openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=${country}/ST=${state}/L=${city}/O=${organization}/CN=${domain}" -keyout server.key -out server.crt
		chmod 400 server.*
		mkdir /etc/apache2/ssl/
		a2enmod ssl
		cp server.key /etc/apache2/ssl/server.key
		cp server.crt /etc/apache2/ssl/server.crt
		ln -s /etc/apache2/mods-available/ssl.load /etc/apache2/mods-enabled/ssl.load
		ln -s /etc/apache2/mods-available/ssl.conf /etc/apache2/mods-enabled/ssl.conf
		# printf "\n${info}${bold}Note:${normal} You can edit this file @ /etc/apache2/sites-available/domain.com.conf\n"
		# read -e -p "Your FQDN: " -i "your-domain.com" domain
		# read -e -p "Your Email: " -i "you@your-domain.com" email
		echo "
		<virtualhost *:443>
		ServerName ${domain}
		ServerAlias *.${domain}
		ServerAdmin ${email}
		DocumentRoot "/var/www/html"
		ErrorLog ${APACHE_LOG_DIR}/error.log
		CustomLog ${APACHE_LOG_DIR}/access.log combined
		SSLEngine on
		SSLProtocol SSLv3
		SSLCertificateFile /etc/apache2/ssl/server.crt
		SSLCertificateKeyFile /etc/apache2/ssl/server.key
		</virtualhost>" >> /etc/apache2/sites-available/${domain}.conf
		cd 
	fi
	} &> ${script_dir}/install.log
	
	stop_spinner $?
	;;
[Nn]* ) 
	# printf "\n${alert}${bold}Attention:${normal} Make sure you copy your key and cert files to /etc/csf/ui\n";
	tput rc; tput el; tput civis
	printf "SSL Installation: [ ${red}NO ]\n"
	;;
esac

start_spinner "${bold}Starting CSF+LFD${normal}"

{
# Restart firewall and Apache
if [ -f /etc/redhat-release ]; then
	service httpd stop && service httpd start && csf -r && lfd -r
else
	service apache2 stop && service apache2 start && csf -r && lfd -r
fi
} &> install.log

stop_spinner $?

printf "\n"

# Let's run a quick test make sure we don't have any fatal errors
perl /usr/local/csf/bin/csftest.pl

# Restor cursor
tput cnorm


