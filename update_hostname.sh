#!/bin/bash
# update hostname in fullyinstalled SDI4Apps platform

#SSL cert from LetsEncrypt https://letsencrypt.readthedocs.org/en/latest/intro.html
cd /opt/letsencrypt
./letsencrypt-auto --apache --email test@liferay.com --agree-tos --no-redirect -d $(hostname -f)

service apache2 restart

#Liferay DB
cd /home/ubuntu
 # set correct hostname
cat >/home/ubuntu/setup_portal.sql <<EOF
update virtualhost set hostname='$(hostname -f)';
update account_ set name='SDI4Apps at $(hostname -f)';
EOF
su postgres -c "psql -f /home/ubuntu/setup_portal.sql liferaydb"

#Liferay server
su - ubuntu -c "/home/ubuntu/liferay-portal-6.2-ce-ga6/tomcat-7.0.62/bin/startup.sh"
