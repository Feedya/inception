#ce script fabrique le cadenas de securiter HTTPS
#pour notre site (NGINX)

#!/usr/bin/env bash

set -Eeuo pipefail

entrypoint_log() {
	if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
		echo "$@"
	fi
}

ME=$(basename "$0")
SSL_DIR="/etc/nginx/ssl"
DOMAIN="${DOMAIN_NAME:-localhost}"

if [ -f "$SSL_DIR/nginx.crt" ] && [ -f "$SSL_DIR/nginx.key" ]; then
	entrypoint_log "$ME: SSL certificate already exists, skipping generation"
	exit 0
fi

mkdir -p "$SSL_DIR"

entrypoint_log "$ME: Generating self-signed SSL certificate for $DOMAIN"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout "$SSL_DIR/nginx.key" \
	-out "$SSL_DIR/nginx.crt" \
	-subj "/C=FR/ST=IDF/L=Paris/O=42/OU=inception/CN=$DOMAIN" \
	2>/dev/null

entrypoint_log "$ME: SSL certificate generated at $SSL_DIR"

exit 0
