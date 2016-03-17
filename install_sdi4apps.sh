#!/bin/bash

echo -n "Preparing SQL databases ... " ; date
cd /home/ubuntu
# create db user
cat >/home/ubuntu/setupdb.sql <<"EOF"
CREATE ROLE liferay NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN PASSWORD 'somepass';
CREATE DATABASE liferaydb;
ALTER DATABASE liferaydb OWNER TO liferay;
CREATE DATABASE layman;
ALTER DATABASE layman OWNER TO liferay;
CREATE DATABASE micka;
ALTER DATABASE micka OWNER TO liferay;
EOF
su postgres -c "psql -f /home/ubuntu/setupdb.sql"

echo -n "Downloading SDI4Apps libraries ... " ; date
mkdir -p /data/wwwlibs/jquery /data/www/py /data/www/php /data/www/cgi-bin /data/www/wwwlibs
cd /data/wwwlibs
wget --quiet http://packages.sdi4apps.eu/hsl_ng_bower.tar.xz
wget --quiet http://packages.sdi4apps.eu/hsl_ng_node.tar.xz
wget --quiet http://cdn.sencha.com/ext/gpl/ext-4.2.1-gpl.zip
wget --quiet http://packages.sdi4apps.eu/ext4_sandbox_gray.tar.xz
wget --quiet http://packages.sdi4apps.eu/hsproxy.tar.xz
wget --quiet http://packages.sdi4apps.eu/proxy4ows.tar.xz
wget --quiet http://packages.sdi4apps.eu/proj4js.tar.xz
wget --quiet http://packages.sdi4apps.eu/css.tar.xz
wget --quiet http://packages.sdi4apps.eu/js.tar.xz
wget --quiet https://github.com/jezekjan/webglayer/releases/download/v1.0.1/webglayer-1.0.1.zip
wget --quiet http://downloads.sourceforge.net/project/geoserver/GeoServer/2.8.2/geoserver-2.8.2-war.zip
echo -n "Extracting SDI4Apps libraries ... " ; date
#JS libs in /data/wwwlibs
unzip -o -q ext-4.2.1-gpl.zip
tar xJf hsproxy.tar.xz
tar xJf proxy4ows.tar.xz
tar xJf proj4js.tar.xz
cd /data/www
tar xJf /data/wwwlibs/css.tar.xz
tar xJf /data/wwwlibs/js.tar.xz
cd /data/wwwlibs/jquery
wget --quiet http://code.jquery.com/jquery-1.12.0.min.js
cd /data/wwwlibs/ext-4.2.1.883/resources
tar xJf /data/wwwlibs/ext4_sandbox_gray.tar.xz

#LayMan
echo -n "Installing Layman ... " ; date
cd /data/www/py
git clone --quiet https://github.com/CCSS-CZ/layman
cat >>/data/www/py/layman/server/laypad/laypad.sql <<"EOF"
GRANT ALL ON DATABASE layman TO liferay;
GRANT ALL ON SCHEMA layman TO liferay;
GRANT ALL ON ALL TABLES IN SCHEMA layman TO liferay;
EOF
su postgres -c "psql -f /data/www/py/layman/server/laypad/laypad.sql layman"
cd /data/www/py/layman/server
mv layman.cgi-template layman.cgi
mv layman.py-template layman.py
chmod a+x layman.cgi layman.py
cat >layman.cfg <<"EOF"
[Authorization]
service=Liferay
url=http://localhost/sso-portlet/service/sso/validate/
allroles=http://localhost/sso-portlet/service/list/roles/en
ignoreroles=administrator,guest,lmadmin,organization administrator,organization owner,organization user,owner,power user,site administrator,site member,site owner,user,mickaadmin,mickawrite,poi,user_role

[FileMan]
homedir=/data/www/py/layman/data/

[LayEd]
# restrictBy:
# owner - only my own data and layers are available for reading and writing (plan4business)
# groups - all the data and layers of all the groups I am member of are available for reading and writing (pprd)
# this is provisional configuration before this depends on the user's membership in LR groups (lmWriteOwn, lmReadGroup etc.) 
restrictBy=owner

[DbMan]
dbname=layman
dbuser=liferay
dbhost=localhost
dbpass=somepass
dbport=5432
exposepk=true

[GeoServer]
url=http://localhost/geoserver/rest
user=admin
password=geoserver
gsdir=/home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/geoserver/
datadir=/home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/geoserver/data/
userpwd=crypt1:2DFyNWnqJIfUL0j8bGMUeA==
#workspace=

[Gdal]
gdal_data=/usr/share/gdal/1.10/

[CKAN]
CkanApiUrl=http://localhost/api/3
ResourceFormat=shp,kml,json

[PROJ]
ProjEPSG=/usr/share/proj/epsg
EOF

#MICKA
echo -n "Installing MICKA ... " ; date
cd /data/wwwlibs/
wget --quiet http://packages.sdi4apps.eu/metadata.tar.xz
cd /data/www/php
tar xJf /data/wwwlibs/metadata.tar.xz
cd /home/ubuntu
wget --quiet http://packages.sdi4apps.eu/metadata.sql.xz
unxz metadata.sql.xz
su postgres -c "psql -f /home/ubuntu/metadata.sql micka"
rm metadata.sql

#Status manager
echo -n "Installing status manager ... " ; date
cd /data/wwwlibs
wget --quiet http://packages.sdi4apps.eu/statusmanager.tar.xz
tar xJf statusmanager.tar.xz
cd /data/wwwlibs/statusmanager
mv index.php-template index.php
cat >statusmanager.ini <<"EOF"
[logging]
path="./log"
debug=true

[status]
session_id="JSESSIONID"
path="./users"
namedPath="./users"

[csw]
url="http://localhost/php/metadata/csw/index.php"

[permalink]
path="./permalink"
url="/php/statusmanager/permalink"

[feedback]
path="/data/wwwlibs/statusmanager/tmp"
url="/php/statusmanager/tmp/"
EOF
patch -b res/HsAuth.php -i - <<"EOF"
--- res/HsAuth.php      2016-03-07 15:53:03.000000000 +0100
+++ res/HsAuth.php.new  2016-03-16 16:49:17.081323503 +0100
@@ -1,5 +1,5 @@
 <?php
-define("LIFERAY_VALIDATE_URL", "http://liferay.local/g4i-portlet/service");
+define("LIFERAY_VALIDATE_URL", "http://localhost/sso-portlet/service");
 define("CSW_LOG", __DIR__ . "/../log/");
 define("ADMINISTRATOR", "Administrator");
EOF
cd /data/wwwlibs/statusmanager/data
sqlite3 data.sqlite <data.sql
chown www-data:www-data data.sqlite


#HS Layers NG
echo -n "Installing Layers NG ... " ; date
cd /data/wwwlibs
ln -s /usr/bin/nodejs /usr/bin/node
git clone --quiet https://github.com/hslayers/hslayers-ng.git
cd hslayers-ng
tar xJf /data/wwwlibs/hsl_ng_bower.tar.xz
tar xJf /data/wwwlibs/hsl_ng_node.tar.xz
cat >/root/.bowerrc <<"EOF"
{"interactive": false}
EOF
sed -i -e 's/bower --allow-root/bower --allow-root --silent/' package.json
npm config set loglevel warn
npm install --unsafe-perm

# well known URLs
echo -n "Setting symbolic links in /data/www/wwwlibs ... " ; date
cd /data/www/wwwlibs
ln -s /data/wwwlibs/ext-4.2.1.883 ext4
ln -s /data/wwwlibs/hslayers-ng hslayers-ng
ln -s /data/wwwlibs/hsproxy hsproxy
ln -s /data/wwwlibs/jquery jquery
ln -s /data/wwwlibs/proj4js proj4js
ln -s /data/wwwlibs/proxy4ows proxy4ows
ln -s /data/wwwlibs/statusmanager statusmanager
cd /data/www/cgi-bin
ln -s ../wwwlibs/hsproxy/lib/hsproxy.py hsproxy.cgi
ln -s ../py/layman/server/layman.py layman
ln -s /usr/lib/cgi-bin/mapserv mapserv
ln -s ../wwwlibs/proxy4ows/proxy4ows.cgi proxy4ows.cgi
cd /data/www/php
ln -s /usr/share/phppgadmin pma #phpPgAdmin

#set ownership - dangerous, change later !
cd /data/www
chown -R www-data:www-data .

#get public hostname 
echo -n "Getting public hostname ... " ; date
if [ -f /usr/bin/gcloud ] ; then
 EXT_IP=$(curl -Ls -m 5 http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
 HOSTNAME=`python -c "import socket; print socket.getfqdn(\"$EXT_IP\")"`
elif /usr/bin/ec2metadata --public-hostname 2>/dev/null ; then
 HOSTNAME=$(/usr/bin/ec2metadata --public-hostname)
else
 HOSTNAME=$(hostname -f)
fi

# prepare Apache
echo -n "Configuring Apache ... " ; date
a2enmod ssl rewrite proxy_ajp proxy_http headers cgi python 
cat >/etc/apache2/sites-enabled/000-default.conf <<EOF
<VirtualHost *:80>
  ServerAdmin webmaster@$HOSTNAME
#  RedirectPermanent / https://$HOSTNAME/
#</VirtualHost>
#<VirtualHost *:443>
#   ServerAdmin webmaster@localhost
#
#   SSLEngine on
#   SSLCertificateFile /etc/apache2/ssl/cert.pem
#   SSLCertificateKeyFile /etc/apache2/ssl/key.pem

   ScriptAlias /cgi-bin/ /data/www/cgi-bin/
   <Directory "/data/www/cgi-bin">
       AllowOverride None
       Options +ExecCGI -MultiViews +FollowSymlinks
       AddHandler cgi-script .py
       Require all granted
   </Directory>

   RewriteEngine On
   RewriteCond %{HTTPS} off
   RewriteRule ^/cas-server https://%{HTTP_HOST}%{REQUEST_URI}
   RewriteCond %{HTTP:Authorization} ^(.*)
   RewriteRule .* - [e=HTTP_AUTHORIZATION:%1]

   Alias /css /data/www/css
   Alias /js /data/www/js
   Alias /maps /data/www/maps
   Alias /php /data/www/php
   Alias /wwwlibs /data/www/wwwlibs

   <Directory /data/www>
       Options +FollowSymLinks +MultiViews
       AllowOverride All
       Require all granted
       SetOutputFilter DEFLATE
   </Directory>

  <Directory /data/wwwlibs>
       Options +Indexes +FollowSymLinks +MultiViews
       AllowOverride All
       Require all granted
       SetOutputFilter DEFLATE
   </Directory>

   <Location /php/hsmap>
       FileETag None
       <ifModule mod_headers.c>
           Header unset ETag
           Header set Cache-Control "max-age=0, no-cache, no-store, must-revalidate"
           Header set Pragma "no-cache"
           Header set Expires "Wed, 11 Jan 1984 05:00:00 GMT"
       </ifModule>
   </Location>

   ProxyPass /wwwlibs !
   ProxyPass /php !
   ProxyPass /js !
   ProxyPass /maps !
   ProxyPass /css !
   ProxyPass /cgi-bin !
   ProxyPass /icons !
   ProxyPass /sparql http://localhost:8890/sparql
   ProxyPass / ajp://127.0.0.1:8011/
   <Proxy *>
       AddDefaultCharset off
       Require all granted
       SetOutputFilter DEFLATE
   </Proxy>

   ErrorLog /var/log/apache2/error.log
   CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF
cat >/var/www/html/index.html <<"EOF"
<html>
 <head>
  <title>SDI4Apps platform</title>
 </head>
 <body>
  <h1>SDI4Apps platform is being installed, please wait ...</h1>
 </body>
</html>
EOF

#generate a self-signed certificate with current host name
mkdir -p /etc/apache2/ssl
openssl req -x509 -newkey rsa:2048 -keyout /etc/apache2/ssl/key.pem -out /etc/apache2/ssl/cert.pem -days 3650 -nodes -subj "/CN=$HOSTNAME"

#change PHP config
patch -b /etc/php5/apache2/php.ini -i - <<"EOF"
--- php.ini.bck 2016-03-15 15:26:35.997545043 +0100
+++ php.ini 2016-03-16 10:29:26.045730192 +0100
@@ -209,7 +209,7 @@
 ; Development Value: Off
 ; Production Value: Off
 ; http://php.net/short-open-tag
-short_open_tag = Off
+short_open_tag = On

 ; Allow ASP-style <% %> tags.
 ; http://php.net/asp-tags
@@ -373,7 +373,7 @@
 ; threat in any way, but it makes it possible to determine whether you use PHP
 ; on your server or not.
 ; http://php.net/expose-php
-expose_php = On
+expose_php = Off

 ;;;;;;;;;;;;;;;;;;;
 ; Resource Limits ;
@@ -399,7 +399,7 @@
 ;max_input_nesting_level = 64

 ; How many GET/POST/COOKIE input variables may be accepted
-; max_input_vars = 1000
+max_input_vars = 5000

 ; Maximum amount of memory a script may consume (128MB)
 ; http://php.net/memory-limit
@@ -459,7 +459,7 @@
 ; Development Value: E_ALL
 ; Production Value: E_ALL & ~E_DEPRECATED & ~E_STRICT
 ; http://php.net/error-reporting
-error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
+error_reporting = E_ALL & ~E_NOTICE & ~E_DEPRECATED & ~E_STRICT

 ; This directive controls whether or not and where PHP will output errors,
 ; notices and warnings too. Error output is very useful during development, but
@@ -476,7 +476,7 @@
 ; Development Value: On
 ; Production Value: Off
 ; http://php.net/display-errors
-display_errors = Off
+display_errors = On

 ; The display of errors which occur during PHP's startup sequence are handled
 ; separately from display_errors. PHP's default behavior is to suppress those
@@ -487,7 +487,7 @@
 ; Development Value: On
 ; Production Value: Off
 ; http://php.net/display-startup-errors
-display_startup_errors = Off
+display_startup_errors = On

 ; Besides displaying errors, PHP can also log errors to locations such as a
 ; server-specific log, STDERR, or a location specified by the error_log
@@ -670,7 +670,7 @@
 ; Its value may be 0 to disable the limit. It is ignored if POST data reading
 ; is disabled through enable_post_data_reading.
 ; http://php.net/post-max-size
-post_max_size = 8M
+post_max_size = 128M

 ; Automatically add files before PHP document.
 ; http://php.net/auto-prepend-file
@@ -690,13 +690,13 @@

 ; PHP's default character set is set to empty.
 ; http://php.net/default-charset
-;default_charset = "UTF-8"
+default_charset = "UTF-8"

 ; Always populate the $HTTP_RAW_POST_DATA variable. PHP's default behavior is
 ; to disable this feature. If post reading is disabled through
 ; enable_post_data_reading, $HTTP_RAW_POST_DATA is *NOT* populated.
 ; http://php.net/always-populate-raw-post-data
-;always_populate_raw_post_data = On
+; always_populate_raw_post_data = 1

 ;;;;;;;;;;;;;;;;;;;;;;;;;
 ; Paths and Directories ;
@@ -802,7 +802,7 @@

 ; Maximum allowed size for uploaded files.
 ; http://php.net/upload-max-filesize
-upload_max_filesize = 2M
+upload_max_filesize = 100M

 ; Maximum number of files that can be uploaded via a single request
 max_file_uploads = 20
@@ -876,7 +876,7 @@
 [Date]
 ; Defines the default timezone used by the date functions
 ; http://php.net/date.timezone
-;date.timezone =
+date.timezone = Europe/Prague

 ; http://php.net/date.default-latitude
 ;date.default_latitude = 31.766
EOF

#Tomcat
#su ubuntu tomcat7-instance-create /home/ubuntu/tomcat7
#cat >/home/ubuntu/tomcat7/conf/server.xml <<"EOF"
#<?xml version='1.0' encoding='utf-8'?>
#<Server port="8006" shutdown="SHUTDOWN">
#  <Listener className="org.apache.catalina.core.JasperListener" />
#  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
#  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
#  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
#  <GlobalNamingResources>
#    <Resource name="UserDatabase" auth="Container"
#              type="org.apache.catalina.UserDatabase"
#              description="User database that can be updated and saved"
#              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
#              pathname="conf/tomcat-users.xml" />
#  </GlobalNamingResources>
#  <Service name="Catalina">
#    <Connector port="8010" protocol="AJP/1.3" redirectPort="8443" 
#      URIEncoding="UTF-8" address="127.0.0.1" useBodyEncodingForURI="true" tomcatAuthentication="false"/>
#    <Engine name="Catalina" defaultHost="localhost">
#      <Realm className="org.apache.catalina.realm.LockOutRealm">
#        <Realm className="org.apache.catalina.realm.UserDatabaseRealm" resourceName="UserDatabase"/>
#      </Realm>
#      <Host name="localhost"  appBase="webapps" unpackWARs="true" autoDeploy="true"></Host>
#    </Engine>
#  </Service>
#</Server>
#EOF
#mkdir -p /usr/share/tomcat7/common/classes /usr/share/tomcat7/server/classes /usr/share/tomcat7/shared/classes
#su ubuntu /home/ubuntu/tomcat7/bin/startup.sh



#Liferay server - options are:
# notinstalled - only downloaded, no set up, no database
# notconfigured - installed, with database, with geo portlets, not set up
# geo - installed, with portlets, set up to display a map

LIFERAY_SETUP=geo


cd /home/ubuntu
case "$LIFERAY_SETUP"  in 
 notinstalled)
     # only download
     wget --quiet -O liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip http://sourceforge.net/projects/lportal/files/Liferay%20Portal/6.2.5%20GA6/liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip/download
     ;;
 notconfigured)
     # download installed and packed Liferay
     wget --quiet 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferay-portal-6.2-ce-ga6.tar.xz'
     tar xJf liferay-portal-6.2-ce-ga6.tar.xz
     rm liferay-portal-6.2-ce-ga6.tar.xz
     # import database for a brand new portal
     wget --quiet 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferaydb.sql'
     su postgres -c "psql -f /home/ubuntu/liferaydb.sql"
     rm liferaydb.sql
     # add GeoServer
     unzip /data/wwwlibs/geoserver-2.8.2-war.zip geoserver.war -d /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/
     chown ubuntu:ubuntu /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/geoserver.war
     ;;
 geo)
     #configured to display a map
     echo -n "Downloading Liferay ... " ; date
     wget --quiet 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferay-portal-sdi4apps.tar.xz'
     echo -n "Extracting Liferay ... " ; date
     tar xJf liferay-portal-sdi4apps.tar.xz
     rm liferay-portal-sdi4apps.tar.xz
     # import database for a brand new portal
     echo -n "Downloading Liferay database ... " ; date
     wget --quiet 'http://packages.sdi4apps.eu/liferaydb.sql.xz'
     unxz liferaydb.sql.xz
     echo -n "Importing Liferay database ... " ; date
     su postgres -c "psql -f /home/ubuntu/liferaydb.sql liferaydb"
     #rm liferaydb.sql
     ;;
esac

#update geo portlets
if [[ $LIFERAY_SETUP = geo || $LIFERAY_SETUP = notconfigured ]] ; then 
     cd /home/ubuntu
     wget --quiet 'http://packages.sdi4apps.eu/portlets.tar.xz' 
     cat >/home/ubuntu/deploy_portlets.sh <<"EOF"
cd ~/liferay-portal-6.2-ce-ga6/deploy/
tar xJf /home/ubuntu/portlets.tar.xz
EOF
     chmod a+x /home/ubuntu/deploy_portlets.sh
     su - ubuntu -c "/home/ubuntu/deploy_portlets.sh"
     rm portlets.tar.xz
fi

# set correct hostname for Liferay - needed for correct generated URLs
echo -n "Setting Liferay hostname ..." ; date
cat >/home/ubuntu/setup_portal.sql <<EOF
update virtualhost set hostname='$HOSTNAME';
update account_ set name='SDI4Apps';
EOF
su postgres -c "psql -f /home/ubuntu/setup_portal.sql liferaydb"
#rm /home/ubuntu/setup_portal.sql


# add Liferay as a service started after boot and start it
echo -n "Configuring Liferay as service ... " ; date
cat >/etc/init.d/liferay <<"EOF"
#!/bin/sh
#
# /etc/init.d/liferay -- startup script for the Liferay portal
#
### BEGIN INIT INFO
# Provides:          liferay
# Required-Start:    $local_fs $remote_fs $network
# Required-Stop:     $local_fs $remote_fs $network
# Should-Start:      $named
# Should-Stop:       $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start Liferay
# Description:       Start the Liferay portal under the ubuntu user.
### END INIT INFO

PATH=/bin:/usr/bin:/sbin:/usr/sbin
NAME=liferay
DESC="Liferay portal"

if [ `id -u` -ne 0 ]; then
        echo "You need root privileges to run this script"
        exit 1
fi

. /lib/lsb/init-functions

if [ -r /etc/default/rcS ]; then
        . /etc/default/rcS
fi

case "$1" in
  start)
        log_daemon_msg "Starting $DESC" "$NAME"
        su - ubuntu -c "/home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/bin/startup.sh"
        ;;
  stop)
        log_daemon_msg "Stopping $DESC" "$NAME"
        su - ubuntu -c "/home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/bin/shutdown.sh"
        ;;
  *)
        log_success_msg "Usage: $0 {start|stop}"
        exit 1
        ;;
esac

exit 0
EOF
chmod a+x /etc/init.d/liferay
update-rc.d liferay defaults
service liferay start

#restart Apache to activate forwarding to Liferay
service apache2 restart

#this is an awfull and dangerous hack ! Change it later.
# enabling Apache user to write to the geoserver directory
while [ ! -d /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/geoserver/data ] ; do 
 echo -n "waiting for deployment of geoserver ..." ; date
 sleep 5 
done
cd /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/geoserver/data
find -type d -exec setfacl -m u:www-data:rwx -m g:www-data:rwx -d -m u:www-data:rwx -d -m g:www-data:rwx {} \;
find -type f -exec setfacl -m u:www-data:rwx -m g:www-data:rwx {} \;

#Virtuoso
cd /tmp
wget --quiet http://packages.sdi4apps.eu/virtuoso_deb.tar.xz
tar xJf virtuoso_deb.tar.xz
cd virtuoso_deb/
apt-get install -y unixodbc libmono-corlib2.0-cil libmono-system-data2.0-cil libmono-system2.0-cil
echo virtuoso-opensource-7 virtuoso-opensource-7/dba-password password 'somepass' |  /usr/bin/debconf-set-selections
echo virtuoso-opensource-7 virtuoso-opensource-7/dba-password-again password 'somepass' |  /usr/bin/debconf-set-selections
dpkg -i *.deb
cd /tmp
wget --quiet http://packages.sdi4apps.eu/virtuoso_data.tar.xz
tar xJf virtuoso_data.tar.xz
cd /tmp/rdf
isql-vt 1111 dba somepass exec="ld_dir ('/tmp/rdf', 'Zemgale_S4a.rdf', 'http://www.sdi4apps.eu/poi.rdf');"
isql-vt 1111 dba somepass exec="rdf_loader_run(log_enable=>3);"
isql-vt 1111 dba somepass exec="ld_dir ('/tmp/rdf', 'LV.rdf', 'http://www.sdi4apps.eu/poi.rdf');"
isql-vt 1111 dba somepass exec="rdf_loader_run(log_enable=>3);"
isql-vt 1111 dba somepass exec="ld_dir ('/tmp/rdf', 'LV_OSM.rdf', 'http://www.sdi4apps.eu/poi.rdf');"
isql-vt 1111 dba somepass exec="rdf_loader_run(log_enable=>3);"



#done, change the Message-Of-The-Day to show it
cat >/etc/motd <<"EOF"
       This is the SDI4Apps platform
        ____  ____ ___ _  _     _
       / ___||  _ \_ _| || |   / \   _ __  _ __  ___
       \___ \| | | | || || |_ / _ \ |  _ \|  _ \/ __|
        ___) | |_| | ||__   _/ ___ \| |_) | |_) \__ \
       |____/|____/___|  |_|/_/   \_\  __/|  __/|___/
                                    |_|   |_|

       It provides the following software:
       - Apache 2.4 + PHP 
       - Geoserver 2.8.2
       - HSProxy 
       - LayMan
       - Liferay 6.2 GA6
       - MapServer 6.4.2
       - MICKA
       - Oracle Java 7
       - pgRouting
       - phpPgAdmin
       - PostgreSQL 9.5
       - PostGIS 
       - Proxy4ows
       - Statusmanager
       - Tomcat 7
       - JavaScript libraries
         - ExtJS 4.2.1
         - jQuery 1.12.0
         - Proj4js
         - HSLayers NG
         - WebGLayer

EOF
echo -n "SDI4Apps platform installed ... " ; date
