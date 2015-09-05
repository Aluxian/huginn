#!/bin/bash

# update
apt-get update -y
apt-get upgrade -y

# install deps
apt-get install -y runit build-essential git zlib1g-dev libyaml-dev \
  libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev \
  curl openssh-server checkinstall libxml2-dev libxslt-dev \
  libcurl4-openssl-dev libicu-dev logrotate python-docutils \
  pkg-config cmake nodejs graphviz

# build and install ruby
apt-get remove -y ruby1.8 ruby1.9
mkdir /tmp/ruby
cd /tmp/ruby
curl -L --progress http://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.3.tar.bz2 | tar xj
cd ruby-2.2.3
./configure --disable-install-rdoc
make "-j`nproc`"
make install

# install bundler and foreman
gem install bundler foreman --no-ri --no-rdoc

# create a user for huginn
adduser --disabled-login --gecos 'Huginn' huginn

# install mysql
apt-get install -y mysql-server mysql-client libmysqlclient-dev
mysql_secure_installation
mysql -u root -p

#CREATE USER 'huginn'@'localhost' IDENTIFIED BY '$password';
#SET storage_engine=INNODB;
#GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, LOCK TABLES ON `huginn_production`.* TO 'huginn'@'localhost';

sudo -u huginn -H mysql -u huginn -p -D huginn_production

# clone huginn
sudo -u huginn -H ssh-keygen
cd /home/huginn
sudo -u huginn -H git clone git@github.com:Aluxian/huginn.git -b master huginn
cd /home/huginn/huginn

# copy the example config
sudo -u huginn -H cp .env.example .env
sudo -u huginn -H cp config/unicorn.rb.example config/unicorn.rb

# create dirs
sudo -u huginn mkdir -p log tmp/pids tmp/sockets

# ensure permissions
sudo chown -R huginn log/ tmp/
sudo chmod -R u+rwX,go-w log/ tmp/
sudo -u huginn -H chmod o-rwx .env

# install gems
sudo -u huginn -H bundle install --deployment --without development test

# install new relic monitoring
echo deb http://apt.newrelic.com/debian/ newrelic non-free >> /etc/apt/sources.list.d/newrelic.list
wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add -
apt-get update
apt-get install newrelic-sysmond
nrsysmond-config --set license_key=
/etc/init.d/newrelic-sysmond start

# firewall
yes | ufw enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow www
ufw reload
