# syntax=docker/dockerfile:1
# escape=\
# check=error=true
# hadolint global ignore=DL3018

ARG OS_VERSION=3.23.5

FROM alpine:${OS_VERSION}

ARG WORDPRESS_PORT=9000

RUN set -eux; \
	apk add --no-cache \
	bash \
	curl \
	ghostscript \
	imagemagick \
	less \
	mariadb-client \
	php83 \
	php83-fpm \
	php83-mysqli \
	php83-curl \
	php83-dom \
	php83-exif \
	php83-fileinfo \
	php83-pecl-igbinary \
	php83-pecl-imagick \
	php83-intl \
	php83-mbstring \
	php83-openssl \
	php83-xml \
	php83-zip \
	php83-opcache \
	php83-pecl-redis \
	php83-pecl-timezonedb \
	php83-bcmath \
	php83-gd \
	php83-iconv \
	php83-shmop \
	php83-simplexml \
	php83-sodium \
	php83-xmlreader \
	php83-phar \
	php83-tokenizer \
	; \
	ln -sf /usr/bin/php83 /usr/local/bin/php

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN getent group www-data || addgroup -g 82 -S www-data; \
	id www-data 2>/dev/null || adduser -u 82 -D -S -G www-data www-data

ENV PHP_INI_DIR=/etc/php83

RUN sed -i \
	"s/^listen = 127.0.0.1:9000/listen = 0.0.0.0:${WORDPRESS_PORT}/; \
	s/^;clear_env = no/clear_env = no/" \
	/etc/php83/php-fpm.d/www.conf

RUN  \
	{ \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
	} > "$PHP_INI_DIR/conf.d/opcache-recommended.ini"

RUN \
	{ \
		echo 'error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR'; \
		echo 'display_errors = Off'; \
		echo 'display_startup_errors = Off'; \
		echo 'log_errors = On'; \
		echo 'error_log = /dev/stderr'; \
		echo 'log_errors_max_len = 1024'; \
		echo 'ignore_repeated_errors = On'; \
		echo 'ignore_repeated_source = Off'; \
		echo 'html_errors = Off'; \
	} > "$PHP_INI_DIR/conf.d/error-logging.ini"

ENV LANG=C.UTF-8

LABEL org.opencontainers.image.authors="Demont Pieric" \
	  org.opencontainers.image.title="WordPress Inception" \
	  org.opencontainers.image.description="WordPress with PHP-FPM"\
	  org.opencontainers.image.licenses="MIT" \
	  org.opencontainers.image.version="1.0.0"

ARG WP_VERSION=7.0
ARG WP_SHA=e50bb75667ecaa0eac0694fb3c7b024afc96fde0

WORKDIR /var/www/html

RUN mkdir -p /usr/src; \
	curl -o wordpress.tar.gz -fL "https://wordpress.org/wordpress-${WP_VERSION}.tar.gz"; \
	echo "${WP_SHA} *wordpress.tar.gz" | sha1sum -c -; \
	\
	tar -xzf wordpress.tar.gz -C /usr/src/; \
	rm wordpress.tar.gz; \
	\
	[ ! -e /usr/src/wordpress/.htaccess ]; \
	{ \
		echo '# BEGIN WordPress'; \
		echo ''; \
		echo 'RewriteEngine On'; \
		echo 'RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]'; \
		echo 'RewriteBase /'; \
		echo 'RewriteRule ^index\.php$ - [L]'; \
		echo 'RewriteCond %{REQUEST_FILENAME} !-f'; \
		echo 'RewriteCond %{REQUEST_FILENAME} !-d'; \
		echo 'RewriteRule . /index.php [L]'; \
		echo ''; \
		echo '# END WordPress'; \
	} > /usr/src/wordpress/.htaccess; \
	\
	chown -R www-data:www-data /usr/src/wordpress

ENV WORDPRESS_CLI_GPG=63AF7AA15067C05616FDDD88A3A2E8F226F0BC06

ARG WP_CLI_VERSION=2.12.0
ARG WP_CLI_SHA512=be928f6b8ca1e8dfb9d2f4b75a13aa4aee0896f8a9a0a1c45cd5d2c98605e6172e6d014dda2e27f88c98befc16c040cbb2bd1bfa121510ea5cdf5f6a30fe8832

RUN apk add --no-cache --virtual .fetch-deps \
	gnupg; \
	\
	curl -o /usr/local/bin/wp.gpg -fL "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar.gpg"; \
	\
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$WORDPRESS_CLI_GPG"; \
	gpg --batch --decrypt --output /usr/local/bin/wp /usr/local/bin/wp.gpg; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/wp.gpg; unset GNUPGHOME; \
	\
	echo "${WP_CLI_SHA512} */usr/local/bin/wp" | sha512sum -c -; \
	chmod +x /usr/local/bin/wp; \
	\
	apk del --no-network .fetch-deps; \
	\
	wp --allow-root --version

VOLUME /var/www/html

COPY --chown=www-data:www-data conf/wp-config-docker.php /usr/src/wordpress/
COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
	ln -svfT docker-entrypoint.sh /usr/local/bin/docker-ensure-installed.sh

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE ${WORDPRESS_PORT}

CMD ["php-fpm83", "--nodaemonize"]
