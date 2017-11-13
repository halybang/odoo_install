#!/bin/bash
################################################################################
# Script for installing Odoo V10 on Ubuntu 16.04, 15.04, 14.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 14.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################
 
##fixed parameters
#odoo
OE_USER="odoo"
OE_BASE="10"
OE_HOME="/opt/$OE_USER"
OE_HOME_EXT="$OE_HOME/$OE_BASE/${OE_USER}-server"
OE_ADDONS_PATH="$OE_HOME_EXT/addons,$OE_HOME/$OE_BASE/custom/addons"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
OE_POLL_PORT="8072"
#Choose the Odoo version which you want to install. For example: 10.0, 9.0, 8.0, 7.0 or saas-6. When using 'trunk' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 10.0
OE_VERSION="10.0"
# Set this to True if you want to install Odoo 10 Enterprise!
IS_ENTERPRISE="False"
#set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server-${OE_BASE}"

#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"

UBUNTU_FIX_LOCAL="False"

##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to 
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
WKHTMLTOX_X32=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-i386.deb

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
apt-get update
apt-get upgrade -y

#--------------------------------------------------
# Ubuntu-fix locale Server
#--------------------------------------------------
if [ $UBUNTU_FIX_LOCAL = "True" ]; then
    echo -e "\n---- Ubuntu Fix Locales ----"	
    apt-get install gdebi-core locales -y
    dpkg-reconfigure locales
    locale-gen C.UTF-8
    /usr/sbin/update-locale LANG=C.UTF-8
    echo -e "\n---- Set locales ----"
    echo 'LC_ALL=C.UTF-8' >> /etc/environment
fi

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
apt-get install postgresql -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n---- Install tool packages ----"
apt-get install wget git python-pip gdebi-core -y
	
echo -e "\n---- Install python packages ----"
apt-get install python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y python-suds
	
echo -e "\n---- Install python libraries ----"
pip install gdata psycogreen ofxparse XlsxWriter oauthlib pysftp xlrd

echo -e "\n--- Install other required packages"
apt-get install node-clean-css -y
apt-get install node-less -y
apt-get install python-gevent -y

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 10 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  wget $_url
  gdebi --n `basename $_url`
  ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
  #apt-get install wkhtmltopdf -y
fi
	
echo -e "\n---- Create ODOO system user ----"
adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
mkdir -p /var/log/$OE_USER/$OE_BASE
mkdir -p /var/lib/$OE_USER/$OE_BASE
mkdir -p /var/lib/$OE_USER/$OE_BASE/.local/share/Odoo
chown -R $OE_USER:$OE_USER /var/log/$OE_USER
chown -R $OE_USER:$OE_USER /var/lib/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
git clone --depth 1 --branch $OE_VERSION https://www.github.com/halybang/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
    ln -s /usr/bin/nodejs /usr/bin/node
    mkdir -p $OE_HOME/$OE_BASE/enterprise
    mkdir -p $OE_HOME/$OE_BASE/enterprise/addons

    echo -e "\n---- Adding Enterprise code under $OE_HOME/$OE_BASE/enterprise/addons ----"
    git clone --depth 1 --branch 10.0 https://www.github.com/odoo/enterprise "$OE_HOME/$OE_BASE/enterprise/addons"

    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo apt-get install nodejs npm
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
    OE_ADDONS_PATH="$OE_HOME/$OE_BASE/enterprise/addons,$OE_ADDONS_PATH"
fi

echo -e "\n---- Create custom module directory ----"
mkdir -p $OE_HOME/$OE_BASE/custom
mkdir -p $OE_HOME/$OE_BASE/custom/addons

echo -e "\n---- Setting permissions on home folder ----"
chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"
#sudo cp $OE_HOME_EXT/debian/odoo.conf /etc/${OE_CONFIG}.conf
#sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
#sudo chmod 640 /etc/${OE_CONFIG}.conf

#echo -e "* Change server config file"
#sudo sed -i s/"db_user = .*"/"db_user = $OE_USER"/g /etc/${OE_CONFIG}.conf
#sudo sed -i s/"; admin_passwd.*"/"admin_passwd = $OE_SUPERADMIN"/g /etc/${OE_CONFIG}.conf
#sudo su root -c "echo '[options]' >> /etc/${OE_CONFIG}.conf"
#sudo su root -c "echo 'logfile = /var/log/$OE_USER/$OE_CONFIG$1.log' >> /etc/${OE_CONFIG}.conf"
#if [  $IS_ENTERPRISE = "True" ]; then
#    sudo su root -c "echo 'addons_path=$OE_HOME/enterprise/addons,$OE_HOME_EXT/addons' >> /etc/${OE_CONFIG}.conf"
#else
#    sudo su root -c "echo 'addons_path=$OE_HOME_EXT/addons,$OE_HOME/custom/addons' >> /etc/${OE_CONFIG}.conf"
#fi

cat <<EOF > /etc/${OE_CONFIG}.conf
[options]
addons_path = $OE_ADDONS_PATH
admin_passwd =  $OE_SUPERADMIN
csv_internal_sep = ,
data_dir = /var/lib/$OE_USER/$OE_BASE/.local/share/Odoo
db_host = False
db_maxconn = 64
db_name = False
db_password = False
db_port = False
db_template = template1
db_user = $OE_USER
dbfilter = ^%d$
debug_mode = False
demo = {}
email_from = False
geoip_database = /usr/share/GeoIP/GeoLiteCity.dat
import_partial =
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 60
limit_time_real = 120
list_db = True
log_db = False
log_db_level = warning
log_handler = :INFO
log_level = info
logfile = /var/log/$OE_USER/$OE_BASE/$OE_CONFIG.log
logrotate = True
longpolling_port = $OE_POLL_PORT
max_cron_threads = 1
osv_memory_age_limit = 1.0
osv_memory_count_limit = False
pg_path = None
pidfile = None
proxy_mode = True
reportgz = False
server_wide_modules = None
smtp_password = False
smtp_port = 25
smtp_server = localhost
smtp_ssl = False
smtp_user = False
syslog = False
test_commit = False
test_enable = False
test_file = False
test_report_directory = False
translate_modules = ['all']
unaccent = False
without_demo = False
workers = 2
xmlrpc = True
xmlrpc_interface = 127.0.0.1
xmlrpc_port = $OE_PORT
EOF

chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Create startup file"
echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh
echo 'sudo -u $OE_USER $OE_HOME_EXT/openerp-server --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh
chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create init file"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: ${OE_CONFIG}
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/bin:/sbin:/usr/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG

# Specify the user name (Default: odoo).
USER=$OE_USER

# Specify an alternate config file (Default: /etc/openerp-server.conf).
CONFIGFILE="/etc/${OE_CONFIG}.conf"

# pidfile
PIDFILE=/var/run/\${NAME}.pid

# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}

case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;

restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;

esac
exit 0
EOF

echo -e "* Security Init File"
mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
chmod 755 /etc/init.d/$OE_CONFIG
chown root: /etc/init.d/$OE_CONFIG

echo -e "* Start ODOO on Startup"
update-rc.d $OE_CONFIG defaults

echo -e "* Starting Odoo Service"
/etc/init.d/$OE_CONFIG start
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT Poll: ${OE_POLL_PORT}"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_HOME/$OE_BASE"
echo "Addons folder: $OE_HOME_EXT/addons/ $OE_ADDONS_PATH"
echo "Start Odoo service: sudo service $OE_CONFIG start"
echo "Stop Odoo service: sudo service $OE_CONFIG stop"
echo "Restart Odoo service: sudo service $OE_CONFIG restart"
echo "-----------------------------------------------------------"

