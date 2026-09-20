#
#
#1 : on telecharge gosu
#
#2 : on copie gosu
#
#3 : installation propre de mariadb
#
#4 : preparation des dossier systeme
#
#5 : nettoyage et configuration
#
#6 : integration des fichiers personelle
#
#7 : finalisation de l image
#

# syntax=docker/dockerfile:1
# escape=\
# check=error=true
# hadolint global ignore=DL3008

#---------------------------------------------------------------
#ARG signifie qu on va creer une variable
#qui sera en vie que pendant la fabrication de l image
ARG OS_VERSION=bookworm
#cette variable sera utiliser dans le cas
#si {OS_VERSION} n a pas de valeur
#---------------------------------------------------------------

#on part d une os vierge
#gosu va remplacer sudo, parceque sudo est trop lent
FROM debian:${OS_VERSION} AS gosu-downloader

ARG GOSU_VERSION=1.19
ENV GOSU_VERSION=${GOSU_VERSION}
ARG GOSU_GPG=B42F6819007F00F88E364FD4036A9C25BF357DD4

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
	ca-certificates \
	gnupg \
	wget; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -q -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -q -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	GNUPGHOME="$(mktemp -d)"; \
	export GNUPGHOME; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "${GOSU_GPG}"; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	\
	chmod +x /usr/local/bin/gosu; \
# verify that the binary works
	gosu --version; \
	gosu nobody true

FROM debian:${OS_VERSION} AS base

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN mkdir /docker-entrypoint-initdb.d

COPY --from=gosu-downloader /usr/local/bin/gosu /usr/local/bin/gosu

ENV LANG=C.UTF-8

LABEL org.opencontainers.image.authors="Demont Pieric" \
	  org.opencontainers.image.title="MariaDB Database Inception" \
	  org.opencontainers.image.description="MariaDb Database for relational SQL" \
	  org.opencontainers.image.licenses="MIT" \
	  org.opencontainers.image.version="1.0.0"

ARG DB_VERSION=10.11.18
#on remet le port ici quand il est deja definis dans le .env
ARG MARIADB_PORT=3306

ENV MARIADB_VERSION=${DB_VERSION}

RUN \
	mkdir -p /var/lib/mysql/mysql; \
	touch /var/lib/mysql/mysql/user.frm; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		mariadb-server; \
	rm -rf /var/lib/apt/lists/*; \
	rm -rf /var/lib/mysql; \
	mkdir -p /var/lib/mysql /run/mysqld; \
	chown -R mysql:mysql /var/lib/mysql /run/mysqld; \
	chmod 1777 /run/mysqld; \
	find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log|user\s)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log|user\s)/#&/'; \
	printf "[mariadb]\nhost-cache-size=0\nskip-name-resolve\n" > /etc/mysql/mariadb.conf.d/05-skipcache.cnf; \
	if [ -L /etc/mysql/my.cnf ]; then \
		sed -i -e '/includedir/ {N;s/\(.*\)\n\(.*\)/\n\2\n\1/}' /etc/mysql/mariadb.cnf; \
	fi

VOLUME /var/lib/mysql

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

COPY tools/* /docker-entrypoint-initdb.d/
RUN chmod -x /docker-entrypoint-initdb.d/*.sh

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE ${MARIADB_PORT}

CMD ["mariadbd"]