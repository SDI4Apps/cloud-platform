#!/bin/bash


mkdir -p /data/wwwlibs/jquery /data/www/py /data/www/php /data/www/cgi-bin /data/www/wwwlibs
cd /data/wwwlibs
wget --quiet http://cdn.sencha.com/ext/gpl/ext-3.4.1.1-gpl.zip
wget --quiet http://cdn.sencha.com/ext/gpl/ext-4.2.1-gpl.zip
wget --quiet http://packages.sdi4apps.eu/hsproxy.tar.xz
wget --quiet http://packages.sdi4apps.eu/proxy4ows.tar.xz
wget --quiet http://packages.sdi4apps.eu/proj4js.tar.xz
wget --quiet http://packages.sdi4apps.eu/css.tar.xz
wget --quiet http://packages.sdi4apps.eu/js.tar.xz
wget --quiet http://packages.sdi4apps.eu/statusmanager.tar.xz
wget --quiet http://packages.sdi4apps.eu/metadata.tar.xz
wget --quiet https://github.com/jezekjan/webglayer/releases/download/v1.0.1/webglayer-1.0.1.zip
#JS libs in /data/wwwlibs
unzip -o -q ext-3.4.1.1-gpl.zip
unzip -o -q ext-4.2.1-gpl.zip
tar xJf hsproxy.tar.xz
tar xJf proxy4ows.tar.xz
tar xJf proj4js.tar.xz
tar xJf statusmanager.tar.xz
cd /data/www
tar xJf /data/wwwlibs/css.tar.xz
tar xJf /data/wwwlibs/js.tar.xz
cd /data/wwwlibs/jquery
wget --quiet http://code.jquery.com/jquery-1.12.0.min.js

#HS Layers
cd /data/wwwlibs
svn co --quiet svn://bnhelp.cz/hslayers/branches/hslayers-3.5
cd hslayers-3.5/tools
python build.py -rpica >/dev/null 2>&1

#LayMan
cd /data/www/py
git clone --quiet https://github.com/CCSS-CZ/layman

#MICKA
cd /data/www/php
tar xJf /data/wwwlibs/metadata.tar.xz

#HS Layers NG
cd /data/wwwlibs
git clone --quiet https://github.com/hslayers/hslayers-ng.git
ln -s /usr/bin/nodejs /usr/bin/node
cat >/root/.bowerrc <<"EOF"
{"interactive": false}
EOF
cd hslayers-ng
sed -i -e 's/bower --allow-root/bower --allow-root --silent/' package.json
npm config set loglevel warn
npm install --unsafe-perm

# well known URLs
cd /data/www/wwwlibs
ln -s /data/wwwlibs/ext-3.4.1 ext
ln -s /data/wwwlibs/ext-4.2.1.883 ext4
ln -s /data/wwwlibs/hslayers-3.5/build hslayers
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


#get public hostname 
if [ -f /usr/bin/gcloud ] ; then
 EXT_IP=$(curl -Ls -m 5 http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
 HOSTNAME=`python -c "import socket; print socket.getfqdn(\"$EXT_IP\")"`
elif /usr/bin/ec2metadata --public-hostname 2>/dev/null ; then
 HOSTNAME=$(/usr/bin/ec2metadata --public-hostname)
else
 HOSTNAME=$(hostname -f)
fi

# prepare Apache
a2enmod ssl rewrite proxy_ajp proxy_http headers cgi python 
cat >/etc/apache2/sites-enabled/000-default.conf <<EOF
<VirtualHost *:80>
  ServerAdmin webmaster@$HOSTNAME
  RedirectPermanent / https://$HOSTNAME/
</VirtualHost>
<VirtualHost *:443>
   ServerAdmin webmaster@localhost

   SSLEngine on
   SSLCertificateFile /etc/apache2/ssl/cert.pem
   SSLCertificateKeyFile /etc/apache2/ssl/key.pem

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
   Alias /wwwlibs /data/wwwlibs

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
  <h1>SDI4Apps platform</h1>
 </body>
</html>
EOF

# this does not work on clouds :-(
#SSL cert from LetsEncrypt https://letsencrypt.readthedocs.org/en/latest/intro.html
#git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
#cd /opt/letsencrypt
#./letsencrypt-auto --apache --email test@liferay.com --agree-tos --no-redirect -d $HOSTNAME

#generate a self-signed certificate with current host name
mkdir -p /etc/apache2/ssl
openssl req -x509 -newkey rsa:2048 -keyout /etc/apache2/ssl/key.pem -out /etc/apache2/ssl/cert.pem -days 3650 -nodes -subj "/CN=$HOSTNAME"

service apache2 restart

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

#Liferay DB
cd /home/ubuntu
 # create db user
cat >/home/ubuntu/setupdb.sql <<"EOF"
CREATE ROLE liferay NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN PASSWORD 'somepass';
EOF
su postgres -c "psql -f /home/ubuntu/setupdb.sql"
 # import database for a brand new portal
wget 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferaydb.sql'
su postgres -c "psql -f /home/ubuntu/liferaydb.sql"
 # set correct hostname
cat >/home/ubuntu/setup_portal.sql <<EOF
update virtualhost set hostname='$HOSTNAME';
update account_ set name='SDI4Apps';
EOF
su postgres -c "psql -f /home/ubuntu/setup_portal.sql liferaydb"

#Liferay server
#wget -O liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip http://sourceforge.net/projects/lportal/files/Liferay%20Portal/6.2.5%20GA6/liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip/download
wget 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferay-portal-6.2-ce-ga6.tar.xz'
tar xJf liferay-portal-6.2-ce-ga6.tar.xz
su - ubuntu -c "/home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/bin/startup.sh"
#portlets
cat >/home/ubuntu/deploy_portlets.sh <<"EOF"
cd ~
git clone --quiet https://github.com/SDI4Apps/liferay
cd liferay
sed -i -e 's#app.server.tomcat.dir=${app.server.parent.dir}/tomcat-7.0.42#app.server.tomcat.dir=/home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62#' build.properties
cd portlets ; ant war ; ant war ; cd ..
cd hooks ; ant war ; cd ..
cd themes ; ant war ; cd ..
cd dist
cp * ~/liferay-portal-6.2-ce-ga6/deploy/
EOF
chmod a+x /home/ubuntu/deploy_portlets.sh
su - ubuntu -c "/home/ubuntu/deploy_portlets.sh"


cat >/etc/motd <<"EOF"
       This is the SDI4Apps platform
        ____  ____ ___ _  _     _
       / ___||  _ \_ _| || |   / \   _ __  _ __  ___
       \___ \| | | | || || |_ / _ \ |  _ \|  _ \/ __|
        ___) | |_| | ||__   _/ ___ \| |_) | |_) \__ \
       |____/|____/___|  |_|/_/   \_\  __/|  __/|___/
                                    |_|   |_|

       It provides the following software:
       - PostgreSQL 9.5
       - PostGIS 
       - Apache 2.4 + PHP 
       - Oracle Java 7
       - Tomcat 7
       - MapServer
       - Liferay 6.2 GA6
       - HSProxy 
       - proxy4ows
       - Statusmanager
       - LayMan
       - phpPgAdmin
       - JavaScript libraries
         - ExtJS 3.4.1
         - ExtJS 4.2.1
         - Proj4js
         - HSLayers 3.5
         - HSLayers NG
         - WebGLayer

EOF
