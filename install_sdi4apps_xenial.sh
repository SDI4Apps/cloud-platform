#!/bin/bash

#make sure services are started 
# see https://bugs.launchpad.net/cloud-init/+bug/1576692 and https://bugs.launchpad.net/ubuntu/+source/init-system-helpers/+bug/1575572
# should be fixed in init-system-helpers - 1.32ubuntu1
for SERVICE in ntp postgresql fail2ban ; do
  echo -n "state of service $SERVICE ... "
  if ! systemctl is-active $SERVICE ; then systemctl start $SERVICE ; fi
done

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
#echo -n "Downloading hsl_ng_bower.tar.xz ... " ; date
#wget --inet4-only  --quiet http://packages.sdi4apps.eu/hsl_ng_bower.tar.xz
#echo -n "Downloading hsl_ng_node.tar.xz ... " ; date
#wget --inet4-only  --quiet http://packages.sdi4apps.eu/hsl_ng_node.tar.xz
echo -n "Downloading ext-4.2.1-gpl.zip ... " ; date
wget --quiet http://cdn.sencha.com/ext/gpl/ext-4.2.1-gpl.zip
echo -n "Downloading ext4_sandbox_gray.tar.xz ... " ; date
wget --inet4-only  --quiet http://packages.sdi4apps.eu/ext4_sandbox_gray.tar.xz
echo -n "Downloading hsproxy.tar.xz ... " ; date
wget --inet4-only  --quiet http://packages.sdi4apps.eu/hsproxy.tar.xz
echo -n "Downloading proxy4ows.tar.xz ... " ; date
wget --inet4-only  --quiet http://packages.sdi4apps.eu/proxy4ows.tar.xz
echo -n "Downloading proj4js.tar.xz ... " ; date
wget --inet4-only  --quiet http://packages.sdi4apps.eu/proj4js.tar.xz
echo -n "Downloading css.tar.xz ... " ; date
wget --inet4-only  --quiet http://packages.sdi4apps.eu/css.tar.xz
echo -n "Downloading js.tar.xz ... " ; date
wget --inet4-only  --quiet http://packages.sdi4apps.eu/js.tar.xz
echo -n "Downloading webglayer-1.0.1.zip ... " ; date
wget --quiet https://github.com/jezekjan/webglayer/releases/download/v1.0.1/webglayer-1.0.1.zip
echo -n "Downloading geoserver-2.7.6-war.zip ... " ; date
wget --inet4-only  --quiet http://packages.sdi4apps.eu/geoserver-2.7.6-war.zip
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
wget --inet4-only  --quiet http://packages.sdi4apps.eu/metadata.tar.xz
cd /data/www/php
tar xJf /data/wwwlibs/metadata.tar.xz
cd /home/ubuntu
wget --inet4-only  --quiet http://packages.sdi4apps.eu/metadata.sql.xz
unxz metadata.sql.xz
su postgres -c "psql -f /home/ubuntu/metadata.sql micka"
rm metadata.sql
cat >/etc/cron.daily/update-micka-services <<"EOF"
#!/bin/sh

/usr/bin/php /data/www/php/metadata/include/harvest/alive.php hide=1 report=/data/www/php/metadata/reports/alive.html
EOF
chmod 755 /etc/cron.daily/update-micka-services

#Status manager
echo -n "Installing status manager ... " ; date
cd /data/wwwlibs
wget --inet4-only  --quiet http://packages.sdi4apps.eu/statusmanager.tar.xz
tar xJf statusmanager.tar.xz
cd /data/wwwlibs/statusmanager
#mv index.php-template index.php
mkdir tmp
mkdir permalink
# cat >statusmanager.ini <<"EOF"
# [logging]
# path="./log"
# debug=true

# [status]
# session_id="JSESSIONID"
# path="./users"
# namedPath="./users"

# [csw]
# url="http://localhost/php/metadata/csw/index.php"

# [permalink]
# path="./permalink"
# url="/php/statusmanager/permalink"

# [feedback]
# path="/data/wwwlibs/statusmanager/tmp"
# url="/php/statusmanager/tmp/"
# EOF
#patch -b res/HsAuth.php -i - <<"EOF"
#--- res/HsAuth.php      2016-03-07 15:53:03.000000000 +0100
#+++ res/HsAuth.php.new  2016-03-16 16:49:17.081323503 +0100
#@@ -1,5 +1,5 @@
# <?php
#-define("LIFERAY_VALIDATE_URL", "http://liferay.local/g4i-portlet/service");
#+define("LIFERAY_VALIDATE_URL", "http://localhost/sso-portlet/service");
# define("CSW_LOG", __DIR__ . "/../log/");
# define("ADMINISTRATOR", "Administrator");
#EOF
cd /data/wwwlibs/statusmanager/data
sqlite3 data.sqlite <data.sql
chown www-data:www-data /data/wwwlibs/statusmanager -R


#HS Layers NG
echo -n "Installing Layers NG ... " ; date
cd /data/wwwlibs
ln -s /usr/bin/nodejs /usr/bin/node
git clone --quiet https://github.com/hslayers/hslayers-ng.git
cd hslayers-ng
git reset --hard 2aac3feb3f8acff47426da41f3879c44672396ad
#tar xJf /data/wwwlibs/hsl_ng_bower.tar.xz
#tar xJf /data/wwwlibs/hsl_ng_node.tar.xz
cat >/root/.bowerrc <<"EOF"
{"interactive": false}
EOF
sed -i -e 's/bower --allow-root/bower --allow-root --silent/' package.json
npm install -g npm@next
npm config set loglevel warn
npm install --unsafe-perm
git rev-parse HEAD^ > gitsha.js

#proxy4ows
echo -n "Installing proxy4ows ... " ; date
cd /data/wwwlibs/proxy4ows
mv proxy4ows.cgi-template proxy4ows.cgi
cat >config.cfg <<"EOF"
[Proxy4OWS]
cachedir=/tmp/
logging=DEBUG
owslib=/home/jachym/usr/src/owslib/OWSLib/

[MapServer]
name=proxy4ows
tempdir=/tmp/
errorfile=stderr
imagepath=/data/www/php/tmp/
onlineresource=http://localhost/cgi-bin/proxy4ows.cgi
#onlineresource=http://cloud255-170.cerit-sc.cz/cgi-bin/proxy4ows.cgi
srs=EPSG:4326 EPSG:102067 EPSG:900913 EPSG:3035 EPSG:3857 EPSG:900913
EOF
mkdir /data/www/php/tmp
chown www-data:www-data /data/www/php/tmp
chmod 755 /data/www/php/tmp

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
#set hsproxy
chown www-data:www-data /data/wwwlibs/hsproxy/lib/hsproxy.py
chmod 555 /data/wwwlibs/hsproxy/lib/hsproxy.py

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

#change PHP config (made by "diff -NarU 1 php.ini.orig php.ini")
patch -b /etc/php/7.0/apache2/php.ini -i - <<"EOF"
--- php.ini.orig	2016-05-11 09:29:45.706846654 +0200
+++ php.ini	2016-05-11 09:37:23.018971340 +0200
@@ -201,3 +201,3 @@
 ; http://php.net/short-open-tag
-short_open_tag = Off
+short_open_tag = On
 
@@ -384,3 +384,3 @@
 ; How many GET/POST/COOKIE input variables may be accepted
-; max_input_vars = 1000
+max_input_vars = 5000
 
@@ -444,3 +444,3 @@
 ; http://php.net/error-reporting
-error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
+error_reporting = E_ALL & ~E_NOTICE & ~E_DEPRECATED & ~E_STRICT
 
@@ -461,3 +461,3 @@
 ; http://php.net/display-errors
-display_errors = Off
+display_errors = On
 
@@ -472,3 +472,3 @@
 ; http://php.net/display-startup-errors
-display_startup_errors = Off
+display_startup_errors = On
 
@@ -655,3 +655,3 @@
 ; http://php.net/post-max-size
-post_max_size = 8M
+post_max_size = 128M
 
@@ -797,3 +797,3 @@
 ; http://php.net/upload-max-filesize
-upload_max_filesize = 2M
+upload_max_filesize = 100M
 
@@ -911,3 +911,3 @@
 ; http://php.net/date.timezone
-;date.timezone =
+date.timezone = Europe/Prague
 
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

echo -n "Installing Liferay ..." ; date
LIFERAY_SETUP=geo


cd /home/ubuntu
case "$LIFERAY_SETUP"  in 
 notinstalled)
     # only download
     wget --quiet -O liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip http://sourceforge.net/projects/lportal/files/Liferay%20Portal/6.2.5%20GA6/liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip/download
     ;;
 notconfigured)
     # download installed and packed Liferay
     wget --inet4-only  --quiet 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferay-portal-6.2-ce-ga6.tar.xz'
     tar xJf liferay-portal-6.2-ce-ga6.tar.xz
     rm liferay-portal-6.2-ce-ga6.tar.xz
     # import database for a brand new portal
     wget --inet4-only  --quiet 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferaydb.sql'
     su postgres -c "psql -f /home/ubuntu/liferaydb.sql"
     rm liferaydb.sql
     # add GeoServer
     unzip /data/wwwlibs/geoserver-2.7.6-war.zip geoserver.war -d /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/
     chown ubuntu:ubuntu /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/geoserver.war
     ;;
 geo)
     #configured to display a map
     echo -n "Downloading Liferay ... " ; date
     wget --inet4-only  --quiet 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferay-portal-sdi4apps.tar.xz'
     echo -n "Extracting Liferay ... " ; date
     tar xJf liferay-portal-sdi4apps.tar.xz
     rm liferay-portal-sdi4apps.tar.xz
     # import database for a brand new portal
     echo -n "Downloading Liferay database ... " ; date
     wget --inet4-only  --quiet 'http://packages.sdi4apps.eu/liferaydb.sql.xz'
     unxz liferaydb.sql.xz
     echo -n "Importing Liferay database ... " ; date
     su postgres -c "psql -f /home/ubuntu/liferaydb.sql liferaydb"
     #rm liferaydb.sql
     ;;
esac

#update geo portlets
if [[ $LIFERAY_SETUP = geo || $LIFERAY_SETUP = notconfigured ]] ; then 
     cd /home/ubuntu
     wget --inet4-only  --quiet 'http://packages.sdi4apps.eu/portlets.tar.xz' 
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
echo -n "Restarting Apache ... " ; date
service apache2 restart

#this is an awfull and dangerous hack ! Change it later.
# enabling Apache user to write to the geoserver directory
echo -n "Enabling www-data to write to Geoserver ... " ; date
while [ ! -d /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/geoserver/data ] ; do 
 echo -n "waiting for deployment of geoserver ..." ; date
 sleep 5 
done
cd /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/geoserver/data
find -type d -exec setfacl -m u:www-data:rwx -m g:www-data:rwx -d -m u:www-data:rwx -d -m g:www-data:rwx {} \;
find -type f -exec setfacl -m u:www-data:rwx -m g:www-data:rwx {} \;

#Install SensLog
echo -n "Installing SensLog ... " ; date
cd /home/ubuntu
echo -n "Downloading SensLog.sql.xz ... " ; date
wget --inet4-only  --quiet 'http://packages.sdi4apps.eu/SensLog.sql.xz'
echo -n "Extracting SensLog.sql.xz ... " ; date
tar xJf SensLog.sql.xz
echo -n "Importing SensLog.sql ... " ; date
su postgres -c "psql -f /home/ubuntu/SensLog.sql"
rm SensLog.sql.xz
rm SensLog.sql
echo -n "Downloading SensLog.tar.xz ... " ; date
wget --inet4-only  --quiet 'http://packages.sdi4apps.eu/SensLog.tar.xz'
cd /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/
echo -n "Extracting SensLog.tar.xz ... " ; date
tar xJf /home/ubuntu/SensLog.tar.xz
chown ubuntu:ubuntu /home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/webapps/SensLog.war
cd /home/ubuntu
rm SensLog.tar.xz


#Virtuoso
echo -n "Installing Virtuoso ... " ; date
echo virtuoso-opensource-7 virtuoso-opensource-7/dba-password password 'dba' |  /usr/bin/debconf-set-selections
echo virtuoso-opensource-7 virtuoso-opensource-7/dba-password-again password 'dba' |  /usr/bin/debconf-set-selections
echo "deb http://packages.comsode.eu/debian jessie main" >/etc/apt/sources.list.d/odn.list
wget --quiet -O - http://packages.comsode.eu/key/odn.gpg.key | apt-key add -
apt-get update
apt-get install -y virtuoso-opensource
#workaround for systemd problem with installing services during boot
for SERVICE in virtuoso-opensource-7 ; do
  echo -n "state of service $SERVICE ... "
  if ! systemctl is-active $SERVICE ; then systemctl start $SERVICE ; fi
done
cd /tmp
#load some data into Virtuoso
echo -n "Downloading virtuoso_data.tar.xz ... " ; date
wget --inet4-only  --quiet http://packages.sdi4apps.eu/virtuoso_data.tar.xz
echo -n "Extracting virtuoso_data.tar.xz ... " ; date
tar xJf virtuoso_data.tar.xz
echo -n "Importing virtuoso_data.tar.xz ... " ; date
cd /tmp/rdf
isql-vt 1111 dba dba exec="ld_dir ('/tmp/rdf', 'Zemgale_S4a.rdf', 'http://www.sdi4apps.eu/poi.rdf');"
isql-vt 1111 dba dba exec="rdf_loader_run(log_enable=>3);"
isql-vt 1111 dba dba exec="ld_dir ('/tmp/rdf', 'LV.rdf', 'http://www.sdi4apps.eu/poi.rdf');"
isql-vt 1111 dba dba exec="rdf_loader_run(log_enable=>3);"
isql-vt 1111 dba dba exec="ld_dir ('/tmp/rdf', 'LV_OSM.rdf', 'http://www.sdi4apps.eu/poi.rdf');"
isql-vt 1111 dba dba exec="rdf_loader_run(log_enable=>3);"

#(re)start postfix
/etc/init.d/postfix restart

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
       - Apache 2.4 + PHP 7.0
       - Geoserver 2.7.6
       - HSProxy 
       - LayMan
       - Liferay 6.2 GA6
       - MapServer 7.0
       - MICKA
       - Oracle Java 7
       - pgRouting
       - phpPgAdmin
       - PostgreSQL 9.6
       - PostGIS 
       - Proxy4ows
       - SensLog
       - Statusmanager
       - Tomcat 7
       - Virtuoso 7.2
       - JavaScript libraries
         - ExtJS 4.2.1
         - jQuery 1.12.0
         - Proj4js
         - HSLayers NG
         - WebGLayer

EOF
echo -n "SDI4Apps platform installed ... " ; date
