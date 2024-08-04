FROM debian:bullseye-slim

LABEL maintainer="763658875@qq.com"

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive
ENV NGINX_VERSION 1.25.2-1~bullseye
ENV php8_conf /etc/php/8.1/fpm/php.ini
ENV fpm8_conf /etc/php/8.1/fpm/pool.d/www.conf
ENV php7_conf /etc/php/7.4/fpm/php.ini
ENV fpm7_conf /etc/php/7.4/fpm/pool.d/www.conf
ENV COMPOSER_VERSION 2.5.8

# Install Basic Requirements nginx
RUN buildDeps='curl gcc g++ make autoconf libc-dev zlib1g-dev pkg-config' \
    && set -x \
    && apt-get update \
    && apt-get install --no-install-recommends $buildDeps --no-install-suggests -q -y gnupg2 dirmngr wget apt-transport-https lsb-release ca-certificates \
    && \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
          found=''; \
          for server in \
                  ha.pool.sks-keyservers.net \
                  hkp://keyserver.ubuntu.com:80 \
                  hkp://p80.pool.sks-keyservers.net:80 \
                  pgp.mit.edu \
          ; do \
                  echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
                  apt-key adv --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
          done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    echo "deb http://nginx.org/packages/mainline/debian/ bullseye nginx" >> /etc/apt/sources.list \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -q -y \
            apt-utils \
            nano \
            vim \
            net-tools \
            zip \
            unzip \
            python3-pip \
            python-setuptools \
            git \
            libmemcached-dev \
            libmemcached11 \
            libmagickwand-dev \
            imagemagick \
            inetutils-ping \
            chromium-browser \
            nginx=${NGINX_VERSION}

# Install php8 php7 pip
RUN apt-get install --no-install-recommends --no-install-suggests -q -y \
            php8.1-fpm \
            php8.1-cli \
            php8.1-bcmath \
            php8.1-dev \
            php8.1-common \
            php8.1-opcache \
            php8.1-readline \
            php8.1-mbstring \
            php8.1-curl \
            php8.1-gd \
            php8.1-imagick \
            php8.1-mysql \
            php8.1-zip \
            php8.1-pgsql \
            php8.1-intl \
            php8.1-xml \
            php8.1-tidy \
            php8.1-sqlite3 \
            php8.1-ldap \
            php8.1-ftp \
            php8.1-gmp \
            php8.1-bz2 \
            php7.4-fpm \
            php7.4-cli \
            php7.4-bcmath \
            php7.4-dev \
            php7.4-common \
            php7.4-opcache \
            php7.4-readline \
            php7.4-mbstring \
            php7.4-curl \
            php7.4-gd \
            php7.4-imagick \
            php7.4-mysql \
            php7.4-zip \
            php7.4-pgsql \
            php7.4-intl \
            php7.4-xml \
            php7.4-tidy \
            php7.4-sqlite3 \
            php7.4-ldap \
            php7.4-ftp \
            php7.4-gmp \
            php7.4-bz2 \
            php7.4-redis \
            php7.4-memcached \
            php-pear \
    && pecl -d php_suffix=8.1 install -o -f redis memcached mongodb \
    && mkdir -p /run/php \
    && pip install wheel \
    && pip install supervisor \
    && pip install webssh \
    && pip install git+https://github.com/coderanger/supervisor-stdout \
    && echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
    && rm -rf /etc/nginx/conf.d/default.conf \
    # Install php8
    && sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php8_conf} \
    && sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 2G/g" ${php8_conf} \
    && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 1G/g" ${php8_conf} \
    && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 1G/g" ${php8_conf} \
    && sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php8_conf} \
    && sed -i -e "s/;date.timezone\s*=\s*/date.timezone = Asia\/Shanghai/g" ${php8_conf} \
    && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/8.1/fpm/php-fpm.conf \
    && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm8_conf} \
    && sed -i -e "s/pm.max_children = 5/pm.max_children = 10/g" ${fpm8_conf} \
    && sed -i -e "s/pm.start_servers = 2/pm.start_servers = 5/g" ${fpm8_conf} \
    && sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm8_conf} \
    && sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 8/g" ${fpm8_conf} \
    && sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm8_conf} \
    && sed -i -e "s/www-data/nginx/g" ${fpm8_conf} \
    && sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm8_conf} \
    && echo "extension=redis.so" > /etc/php/8.1/mods-available/redis.ini \
    && echo "extension=memcached.so" > /etc/php/8.1/mods-available/memcached.ini \
    && echo "extension=imagick.so" > /etc/php/8.1/mods-available/imagick.ini \
    && echo "extension=mongodb.so" > /etc/php/8.1/mods-available/mongodb.ini \
    && ln -sf /etc/php/8.1/mods-available/redis.ini /etc/php/8.1/fpm/conf.d/20-redis.ini \
    && ln -sf /etc/php/8.1/mods-available/redis.ini /etc/php/8.1/cli/conf.d/20-redis.ini \
    && ln -sf /etc/php/8.1/mods-available/memcached.ini /etc/php/8.1/fpm/conf.d/20-memcached.ini \
    && ln -sf /etc/php/8.1/mods-available/memcached.ini /etc/php/8.1/cli/conf.d/20-memcached.ini \
    && ln -sf /etc/php/8.1/mods-available/imagick.ini /etc/php/8.1/fpm/conf.d/20-imagick.ini \
    && ln -sf /etc/php/8.1/mods-available/imagick.ini /etc/php/8.1/cli/conf.d/20-imagick.ini \
    && ln -sf /etc/php/8.1/mods-available/mongodb.ini /etc/php/8.1/fpm/conf.d/20-mongodb.ini \
    && ln -sf /etc/php/8.1/mods-available/mongodb.ini /etc/php/8.1/cli/conf.d/20-mongodb.ini \
    # Install php7
    && sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php7_conf} \
    && sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 2G/g" ${php7_conf} \
    && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 1G/g" ${php7_conf} \
    && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 1G/g" ${php7_conf} \
    && sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php7_conf} \
    && sed -i -e "s/;date.timezone\s*=\s*/date.timezone = Asia\/Shanghai/g" ${php7_conf} \
    && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.4/fpm/php-fpm.conf \
    && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm7_conf} \
    && sed -i -e "s/pm.max_children = 5/pm.max_children = 10/g" ${fpm7_conf} \
    && sed -i -e "s/pm.start_servers = 2/pm.start_servers = 5/g" ${fpm7_conf} \
    && sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm7_conf} \
    && sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 8/g" ${fpm7_conf} \
    && sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm7_conf} \
    && sed -i -e "s/www-data/nginx/g" ${fpm7_conf} \
    && sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm7_conf} \
    && echo "extension=imagick.so" > /etc/php/7.4/mods-available/imagick.ini \
    && ln -sf /etc/php/7.4/mods-available/imagick.ini /etc/php/7.4/fpm/conf.d/20-imagick.ini \
    && ln -sf /etc/php/7.4/mods-available/imagick.ini /etc/php/7.4/cli/conf.d/20-imagick.ini \
    # Install Composer
    && curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
    && rm -rf /tmp/composer-setup.php

# Install nodejs npm yarn
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update && apt-get install yarn

# Install wkhtmltox
# COPY ./wkhtmltox.deb /wkhtmltox.deb
RUN wget "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_amd64.deb" -O wkhtmltox.deb \
   && apt-get update && apt-get install -y fontconfig libjpeg62-turbo libxrender1 xfonts-utils xfonts-75dpi xfonts-base \
   && dpkg -i /wkhtmltox.deb

# Clean up
RUN rm -rf /tmp/pear \
    && apt-get purge -y --auto-remove $buildDeps \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* /wkhtmltox.deb

# htmltopdf font
COPY ./SIMSUN.TTC /usr/share/fonts

# Supervisor config
COPY ./supervisord.conf /etc/supervisor/supervisord.conf

# Override nginx's default config
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Override default nginx welcome page
COPY html /usr/share/nginx/html

# Copy Scripts
COPY ./start.sh /start.sh
# abandon this:COPY --from=ebooktool /root-layer/ /
RUN chmod -R 777 ./start.sh /etc/supervisor/supervisord.conf

EXPOSE 80

CMD ["/start.sh"]
