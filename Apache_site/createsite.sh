#!/bin/bash

set -e

DOMAIN="mysite.site.com"
username=$(echo "$DOMAIN" | cut -d'.' -f1)
VHOST_DIR="/etc/apache2/vhosts"
APACHE_CONF="/etc/apache2/apache.conf"
PHP_VERSION="8.3"
PHP_CONF_DIR="/etc/php/$PHP_VERSION/fpm/pool.d"
SITE_PHP_CONF="$PHP_CONF_DIR/$DOMAIN.conf"
EFS_DNS_PATH="fs-0171b5ea225ca427f.efs.eu-central-1.amazonaws.com"
MOUNT_POINT="/srv/sites/$DOMAIN/public_html/wp-content"
FSTAB_ENTRY="$EFS_DNS_PATH:/ $MOUNT_POINT nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0"
INCLUDE_LINE="IncludeOptional $VHOST_DIR/*.conf"

install_packages() {
    sudo apt update
    sudo apt install -y apache2 mysql-client git software-properties-common
	sudo apt install apache2 php libapache2-mod-php
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update
    sudo apt install -y libapache2-mod-php$PHP_VERSION libapache2-mod-fcgid php$PHP_VERSION php$PHP_VERSION-{fpm,cli,mysql,xml,curl,mbstring,zip,intl,soap,bcmath,gd,imagick,opcache}
}

setup_user_dirs() {
    sudo useradd -m "$username" || echo "[INFO] User $username already exists"
    sudo mkdir -p /srv/sites/$DOMAIN/{public_html,logs}
    echo "This is a new site" | sudo tee /srv/sites/$DOMAIN/public_html/index.html > /dev/null
    sudo chown -R "$username":"$username" /srv/sites/$DOMAIN
}

configure_apache_vhost() {
    sudo mkdir -p "$VHOST_DIR"

    if ! grep -qF "$INCLUDE_LINE" "$APACHE_CONF"; then
        echo "$INCLUDE_LINE" | sudo tee -a "$APACHE_CONF" > /dev/null
    fi

    if [ ! -f "$VHOST_DIR/$DOMAIN.conf" ]; then
        cat <<EOF | sudo tee "$VHOST_DIR/$DOMAIN.conf" > /dev/null
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /srv/sites/$DOMAIN/public_html
    <Directory /srv/sites/$DOMAIN/public_html>
        Options FollowSymLinks Includes ExecCGI
        AllowOverride All
        Require all granted
    </Directory>
    <FilesMatch ".+\.ph(ar|p|tml)$">
        SetHandler "proxy:unix:/var/run/php/$username.sock|fcgi://$username"
    </FilesMatch>
</VirtualHost>
EOF
    fi

    sudo a2enconf proxy_fcgi setenvif
    sudo a2enmod proxy_fcgi
    sudo systemctl reload apache2
}

configure_php_pool() {
    if [ ! -f "$SITE_PHP_CONF" ]; then
        cat <<EOF | sudo tee "$SITE_PHP_CONF" > /dev/null
[$username]
user = $username
group = $username
listen.owner = $username
listen.group = $username
listen.mode = 0666
listen = /var/run/php/$username.sock
pm = ondemand
pm.max_children = 75
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.process_idle_timeout = 30s
pm.max_requests = 500
rlimit_files = 10000
request_terminate_timeout = 60
access.format = "%R - %u %t \\\"%m %r%Q%q\\\" %s %f %{mili}d %{kilo}M %C%%"
php_admin_value[error_log] = /var/log/php-fpm/$username-error.log
php_admin_flag[log_errors] = on
php_admin_value[memory_limit] = 128M
php_value[session.save_handler] = files
php_value[session.save_path] = /var/lib/php/plus/session
php_value[soap.wsdl_cache_dir] = /var/lib/php/plus/wsdlcache
EOF
        sudo systemctl restart php$PHP_VERSION-fpm
    fi
}

configure_efs_mount() {
    if ! grep -qs "$MOUNT_POINT" /etc/fstab; then
        echo "[INFO] Adding EFS mount to /etc/fstab"
        echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
    fi

    sudo mkdir -p "$MOUNT_POINT"
    sudo mount -a
}

main() {
    install_packages
    setup_user_dirs
    configure_apache_vhost
    configure_php_pool
    configure_efs_mount

    sudo systemctl enable apache2
    sudo systemctl start apache2
    sudo service php$PHP_VERSION-fpm restart
}

main "$@"
