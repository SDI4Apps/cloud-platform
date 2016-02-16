#!/bin/bash


mkdir -p /data/wwwlibs
cd /data/wwwlibs
wget --quiet http://cdn.sencha.com/ext/gpl/ext-3.4.1.1-gpl.zip
wget --quiet http://cdn.sencha.com/ext/gpl/ext-4.2.1-gpl.zip
wget --quiet http://packages.sdi4apps.eu/hsproxy-20151012.tar.xz
wget --quiet http://packages.sdi4apps.eu/proxy4ows-20151012.tar.xz
wget --quiet http://packages.sdi4apps.eu/proj4js-20151012.tar.xz
wget --quiet https://github.com/jezekjan/webglayer/releases/download/v1.0.1/webglayer-1.0.1.zip
unzip -o -q ext-3.4.1.1-gpl.zip
unzip -o -q ext-4.2.1-gpl.zip
unzip -o -q webglayer-1.0.1.zip
tar xJf hsproxy-20151012.tar.xz
tar xJf proxy4ows-20151012.tar.xz
tar xJf proj4js-20151012.tar.xz

svn co --quiet svn://bnhelp.cz/hslayers/branches/hslayers-3.5
cd hslayers-3.5/tools
python build.py -rpica >/dev/null 2>&1

cd /data/wwwlibs
git clone --quiet http://git.ccss.cz/hsrs/hslayers-ng.git
ln -s /usr/bin/nodejs /usr/bin/node
cat >/root/.bowerrc <<"EOF"
{"interactive": false}
EOF
cd hslayers-ng
sed -i -e 's/bower --allow-root/bower --allow-root --silent/' package.json
npm config set loglevel warn
npm install --unsafe-perm

# prepare Apache
a2enmod ssl rewrite proxy_ajp proxy_http headers cgi python 
cat >/etc/apache2/sites-enabled/000-default.conf <<"EOF"
<VirtualHost *:80>
   ServerAdmin webmaster@localhost

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

   <Files "awstats.pl">
       AuthUserFile /etc/awstats/.htpasswd
       AuthName "Restricted Area For Customers"
       AuthType Basic
       require valid-user
   </Files>

   Alias /awstats /data/www/awstats
   Alias /awstats-icon/ /usr/share/awstats/icon/
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

   ProxyPass /awstats !
   ProxyPass /awstats-icon !
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
service apache2 restart

#Tomcat
su ubuntu tomcat7-instance-create /home/ubuntu/tomcat7
cat >/home/ubuntu/tomcat7/conf/server.xml <<"EOF"
<?xml version='1.0' encoding='utf-8'?>
<Server port="8006" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.core.JasperListener" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>
  <Service name="Catalina">
    <Connector port="8010" protocol="AJP/1.3" redirectPort="8443" 
      URIEncoding="UTF-8" address="127.0.0.1" useBodyEncodingForURI="true" tomcatAuthentication="false"/>
    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm" resourceName="UserDatabase"/>
      </Realm>
      <Host name="localhost"  appBase="webapps" unpackWARs="true" autoDeploy="true"></Host>
    </Engine>
  </Service>
</Server>
EOF
mkdir -p /usr/share/tomcat7/common/classes /usr/share/tomcat7/server/classes /usr/share/tomcat7/shared/classes
su ubuntu /home/ubuntu/tomcat7/bin/startup.sh

#Liferay DB
cd /home/ubuntu
cat >/home/ubuntu/setupdb.sql <<"EOF"
CREATE ROLE liferay NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN PASSWORD 'somepass';
EOF
wget 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferaydb.sql'
su postgres -c "psql -f /home/ubuntu/setupdb.sql"
su postgres -c "psql -f /home/ubuntu/liferaydb.sql"

#Liferay server
#wget -O liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip http://sourceforge.net/projects/lportal/files/Liferay%20Portal/6.2.5%20GA6/liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip/download
wget 'https://acrab.ics.muni.cz/~makub/sdi4apps/liferay-portal-6.2-ce-ga6.tar.xz'
tar xJf liferay-portal-6.2-ce-ga6.tar.xz
su - ubuntu -c "/home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/bin/startup.sh"


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
       - Oracle Java 7 and 8
       - Tomcat 7
       - MapServer
       - Liferay 6.2 GA6
       - HSProxy 
       - proxy4ows
       - JavaScript libraries
         - ExtJS 3.4.1
         - ExtJS 4.2.1
         - Proj4js
         - HSLayers 3.5
         - HSLayers NG
         - WebGLayer

EOF
