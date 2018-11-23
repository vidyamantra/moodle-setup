#!/bin/bash

# System Upgrade
yum -y -q upgrade

# Disable SELinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Add Nginx Repo
echo -e "[nginx]\nname=nginx repo\nbaseurl=http://nginx.org/packages/centos/7/\$basearch/\ngpgcheck=0 \nenabled=1" > /etc/yum.repos.d/nginx.repo

# Add various other repos
yum install -y -q https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm https://centos7.iuscommunity.org/ius-release.rpm http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm

# Install various components
yum install -y -q vim-enhanced wget rsync nginx php71u-mcrypt php71u-tidy php71u-intl php71u-gd php71u-cli php71u-opcache php71u-common php71u-xmlrpc php71u-ldap php71u-mbstring php71u-process php71u-mysqlnd php71u-soap php71u-pdo php71u-json php71u-xml php71u-fpm php71u-bcmath Percona-Server-server-56 aspell graphviz ghostscript

# MySQL Config
>/etc/my.cnf cat << EOF
[client]
default-character-set = utf8mb4

[mysqld]
innodb_buffer_pool_size = 128M
join_buffer_size = 128M
sort_buffer_size = 2M
read_rnd_buffer_size = 2M
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
innodb_file_format = Barracuda
innodb_file_per_table = 1
innodb_large_prefix
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
skip-character-set-client-handshake

# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

# Recommended in standard MySQL setup
sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

[mysql]
default-character-set = utf8mb4
EOF

# Moodle Config in nginx
>/etc/nginx/conf.d/moodle.conf cat << EOF
server {
    listen      80 default_server;

    server_name  "";
    root   /var/www/moodle/html;
    index  index.php index.html index.htm;

    location ~ \.php\$ {
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }

    location ~ ^(?P<script_name>.+\.php)(?P<path_info>/.+)$ {
        fastcgi_pass  127.0.0.1:9000;
        fastcgi_index  index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$script_name;
        fastcgi_param PATH_INFO \$path_info;
        fastcgi_param PATH_TRANSLATED \$document_root\$path_info;
    }
}
EOF

# Configure Moodle code
mkdir -p /var/www/moodle/html
mkdir -p /var/www/moodle/moodledata
wget -O /tmp/moodle.tgz https://download.moodle.org/download.php/direct/stable35/moodle-latest-35.tgz
tar -xzf /tmp/moodle.tgz --strip-components=1 -C /var/www/moodle/html/
chown -R php-fpm.nginx /var/www/moodle/html
chown -R php-fpm.nginx /var/www/moodle/moodledata

# Moodle Config
>/var/www/moodle/html/config.php cat << EOF
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mysqli';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = 'moodle';
\$CFG->dbuser    = 'root'; //UNSECURE
\$CFG->dbpass    = ''; //UNSECURE
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot = 'http://'.\$_SERVER['HTTP_HOST'];  //NOT RECOMMENDED, use static value
\$CFG->dataroot  = '/var/www/moodle/moodledata';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 0777;

// Enable debugging
@error_reporting(E_ALL | E_STRICT);   // NOT FOR PRODUCTION SERVERS!
@ini_set('display_errors', '1');         // NOT FOR PRODUCTION SERVERS!
\$CFG->debug = (E_ALL | E_STRICT);   // === DEBUG_DEVELOPER - NOT FOR PRODUCTION SERVERS!
\$CFG->debugdisplay = 1;              // NOT FOR PRODUCTION SERVERS!

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF

# php
sed -i 's/max_execution_time =.*/max_execution_time=300/' /etc/php.ini
sed -i 's/max_input_time =.*/max_input_time=600/' /etc/php.ini
sed -i 's/memory_limit =.*/memory_limit=2048M/' /etc/php.ini
sed -i 's/post_max_size =.*/post_max_size=512M/' /etc/php.ini
sed -i 's/upload_max_filesize =.*/upload_max_filesize=512M/' /etc/php.ini

# opcache
mkdir -p /var/www/.opcache
sed -i 's/;opcache.file_cache=.*/opcache.file_cache=\/var\/www\/.opcache/' /etc/php.d/10-opcache.ini
sed -i 's/opcache.memory_consumption=.*/opcache.memory_consumption=512/' /etc/php.d/10-opcache.ini
sed -i 's/opcache.max_accelerated_files=.*/opcache.max_accelerated_files=12000/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.revalidate_freq=.*/opcache.revalidate_freq=60/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.use_cwd=.*/opcache.use_cwd=1/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.validate_timestamps=.*/opcache.validate_timestamps=1/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.save_comments=.*/opcache.save_comments=1/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.enable_file_override=.*/opcache.enable_file_override=0/' /etc/php.d/10-opcache.ini

# Add to startup
systemctl enable nginx
systemctl enable php-fpm
systemctl enable mysql

# Start services
systemctl start nginx
systemctl start php-fpm
systemctl start mysql

# Create Database
mysql -uroot -e "create database 'moodle'"
