# setup nginx
sudo apt update
sudo apt install nginx
sudo systemctl stop nginx.service
sudo systemctl start nginx.service
sudo systemctl enable nginx.service


# setup database
sudo apt-get install mariadb-server mariadb-client

#After installing MariaDB, the commands below can be used to stop, start and enable MariaDB service to always start up when the server boots.

sudo systemctl stop mariadb.service
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service


sudo mysql_secure_installation


sudo mysql -u root -p


sudo apt-get install software-properties-common
sudo add-apt-repository ppa:ondrej/php
# Then update and upgrade to PHP 7.4

sudo apt update


sudo apt install php7.4-fpm php7.4-common php7.4-mysql php7.4-gmp php7.4-curl php7.4-intl php7.4-mbstring php7.4-xmlrpc php7.4-gd php7.4-xml php7.4-cli php7.4-zip


# Logon to MariaDB database console using the commands below:

sudo mysql -u root -p

# Then create a database called drupal

CREATE DATABASE drupal;

# Next, create a database user called drupaluser and set password

CREATE USER 'drupaluser'@'localhost' IDENTIFIED BY 'drupal';

# Then grant the user full access to the database.

GRANT ALL ON drupal.* TO 'drupaluser'@'localhost' WITH GRANT OPTION;

#Finally, save your changes and exit.

FLUSH PRIVILEGES;
EXIT;



sudo apt install curl git
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer



cd /var/www/
sudo git clone --branch 8.8.5 https://git.drupal.org/project/drupal.git
cd /var/www/drupal
sudo composer install


sudo chown -R www-data:www-data /var/www/drupal/
sudo chmod -R 755 /var/www/drupal/


# Step 6: Configure Nginx

sudo nano /etc/nginx/sites-available/drupal

# A very good configuration settings for most Drupal site on Nginx server is below. This configuration should work great.

# Copy the content below and save into the file created above.

server {
    listen 80;
    listen [::]:80;
    root /var/www/drupal;
    index  index.php index.html index.htm;
    server_name  example.com www.example.com;

    client_max_body_size 100M;
    autoindex off;

    location ~ \..*/.*\.php$ {
        return 403;
    }

    location ~ ^/sites/.*/private/ {
        return 403;
    }

    # Block access to scripts in site files directory
    location ~ ^/sites/[^/]+/files/.*\.php$ {
        deny all;
    }

    # Block access to "hidden" files and directories whose names begin with a
    # period. This includes directories used by version control systems such
    # as Subversion or Git to store control files.
    location ~ (^|/)\. {
        return 403;
    }

    location / {
        try_files $uri /index.php?$query_string;
    }

    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }

    # Don't allow direct access to PHP files in the vendor directory.
    location ~ /vendor/.*\.php$ {
        deny all;
        return 404;
    }


    location ~ '\.php$|^/update.php' {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Fighting with Styles? This little gem is amazing.
    # location ~ ^/sites/.*/files/imagecache/ { # For Drupal <= 6
    location ~ ^/sites/.*/files/styles/ { # For Drupal >= 7
        try_files $uri @rewrite;
    }

    # Handle private files through Drupal. Private file's path can come
    # with a language prefix.
    location ~ ^(/[a-z\-]+)?/system/files/ { # For Drupal >= 7
        try_files $uri /index.php?$query_string;
    }
}
# Save the file and exit.


sudo ln -s /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/
sudo systemctl restart nginx.service


# Step 7: Install Let’s Encrypt Wildcard Certificates

sudo apt update
sudo apt-get install letsencrypt

sudo certbot certonly --manual --preferred-challenges=dns --email admin@example.com --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d example.com -d *.example.com



sudo crontab -e

# Then add the line below and save…

0 1 * * * /usr/bin/certbot renew >> /var/log/letsencrypt/renew.log



sudo nano /etc/nginx/sites-available/drupal

# Then add the highlighted lines to the VirtualHost file as shown below:

server {
     listen 80;
     listen [::]:80;
     server_name *.example.com;
     return 301 https://$host$request_uri;
}
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    root /var/www/drupal;
    index  index.php;
    server_name  example.com www.example.com;

    if ($host != "example.com") {
       return 301 https://example.com$request_uri;
      }

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_ciphers 'TLS13+AESGCM+AES128:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:50m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    ssl_ecdh_curve X25519:sect571r1:secp521r1:secp384r1;

    client_max_body_size 100M;
    autoindex off;

    location ~ \..*/.*\.php$ {
        return 403;
    }

    location ~ ^/sites/.*/private/ {
        return 403;
    }

    # Block access to scripts in site files directory
    location ~ ^/sites/[^/]+/files/.*\.php$ {
        deny all;
    }

    # Block access to "hidden" files and directories whose names begin with a
    # period. This includes directories used by version control systems such
    # as Subversion or Git to store control files.
    location ~ (^|/)\. {
        return 403;
    }

    location / {
        try_files $uri /index.php?$query_string;
    }

    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }

    # Don't allow direct access to PHP files in the vendor directory.
    location ~ /vendor/.*\.php$ {
        deny all;
        return 404;
    }


    location ~ '\.php$|^/update.php' {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Fighting with Styles? This little gem is amazing.
    # location ~ ^/sites/.*/files/imagecache/ { # For Drupal <= 6
    location ~ ^/sites/.*/files/styles/ { # For Drupal >= 7
        try_files $uri @rewrite;
    }

    # Handle private files through Drupal. Private file's path can come
    # with a language prefix.
    location ~ ^(/[a-z\-]+)?/system/files/ { # For Drupal >= 7
        try_files $uri /index.php?$query_string;
    }
}
# After the above, restart Nginx and PHP 7.4-FPM

sudo systemctl reload nginx
sudo systemctl reload php7.4-fpm