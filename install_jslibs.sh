#!/bin/bash


mkdir -p /data/wwwlibs
cd /data/wwwlibs
wget --quiet http://cdn.sencha.com/ext/gpl/ext-3.4.1.1-gpl.zip
wget --quiet http://cdn.sencha.com/ext/gpl/ext-4.2.1-gpl.zip
wget --quiet http://packages.sdi4apps.eu/hsproxy-20151012.tar.xz
wget --quiet http://packages.sdi4apps.eu/proxy4ows-20151012.tar.xz
wget --quiet http://packages.sdi4apps.eu/proj4js-20151012.tar.xz
unzip -o -q ext-3.4.1.1-gpl.zip
unzip -o -q ext-4.2.1-gpl.zip
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
   Alias /wwwlibs /data/www/wwwlibs

   <Directory /data/www>
       Options +FollowSymLinks +MultiViews
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

   ProxyRequests Off

   ProxyPass / ajp://127.0.0.1:8009/
   ProxyPassReverse / ajp://127.0.0.1:8009/
   #ProxyPassReverseCookieDomain localhost foodie.wirelessinfo.cz
   SSLOptions +ExportCertData

   <Proxy *>
       AddDefaultCharset off
       Require all granted
       SetOutputFilter DEFLATE
   </Proxy>

   ProxyVia On

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
