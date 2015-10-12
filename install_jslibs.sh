#!/bin/bash


mkdir -p /data/wwwlibs
cd /data/wwwlibs
wget http://cdn.sencha.com/ext/gpl/ext-3.4.1.1-gpl.zip
unzip -o -q ext-3.4.1.1-gpl.zip
wget http://cdn.sencha.com/ext/gpl/ext-4.2.1-gpl.zip
unzip -o -q ext-4.2.1-gpl.zip

svn co svn://bnhelp.cz/hslayers/branches/hslayers-3.5
cd hslayers-3.5/tools
python build.py -rpica

cd /data/wwwlibs
git clone http://git.ccss.cz/hsrs/hslayers-ng.git
ln -s /usr/bin/nodejs /usr/bin/node
cat >/root/.bowerrc <<"EOF"
{"interactive": false}
EOF
cd hslayers-ng
npm install --unsafe-perm

cd /data/wwwlibs
wget http://packages.sdi4apps.eu/hsproxy-20151012.tar.xz
wget http://packages.sdi4apps.eu/proxy4ows-20151012.tar.xz
wget http://packages.sdi4apps.eu/proj4js-20151012.tar.xz
tar xJf hsproxy-20151012.tar.xz
tar xJf proxy4ows-20151012.tar.xz
tar xJf proj4js-20151012.tar.xz
