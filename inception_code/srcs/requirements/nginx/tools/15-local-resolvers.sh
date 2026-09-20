#!/usr/bin/env bash
#ce script sert à noter l'adresse de l'annuaire téléphonique de votre réseau (le DNS)
#en gros les adresse de nos container de WordPress et Mariadb
#pour que NGINX sache à qui s'adresser s'il doit chercher une adresse IP de ces containers

set -Eeuo pipefail

LC_ALL=C
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[ "${NGINX_ENTRYPOINT_LOCAL_RESOLVERS:-}" ] || exit 0

NGINX_LOCAL_RESOLVERS=$(awk 'BEGIN{ORS=" "} $1=="nameserver" {if ($2 ~ ":") {print "["$2"]"} else {print $2}}' /etc/resolv.conf)

NGINX_LOCAL_RESOLVERS="${NGINX_LOCAL_RESOLVERS% }"

export NGINX_LOCAL_RESOLVERS
