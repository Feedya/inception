#!/usr/bin/env bash

#entrypoint de root bash en haut
set -Eeuo pipefail
shopt -s nullglob
#
#ce script c est le chef d orchestre de mariaDB 
#
#il va preparer le systeme mariaDB, 
#
#il fonctionne en 5 etapes
#
#1. 
#
#   il va lire le fichier .conf pour recuperer les chemins cruciaux 
#   il charge les variables d environements (.env)
#
#2. 
#   il verifie que les dossier de donnes /var/lib/mysql existe bien
#   si le container demarre en root il va les donner a l utilisateur mysql
#
#3.
#   verifie que /var/lib/mysql/mysql existe
#   si ca existe pas ca le creer
#
#4. QUE SI C EST LA TOUTE PREMIERE FOIS DE L HISTPOIRE DU CONTAINER
#   il va installer mariadb avec mariadb-install-db
#   il lance un serveur temporaire en arriere plan, sans aucun reseaux 
#   il execute tout les scripts
#   il eteints le serveur   
#
#5.
#   il va reallumer   
#
#on fait ca parceque la premiere fois on fait le mode chantier on le creer etc
#
#


_is_sourced() {
	[ "${#FUNCNAME[@]}" -ge 2 ] \
		&& [ "${FUNCNAME[0]}" = '_is_sourced' ] \
		&& [ "${FUNCNAME[1]}" = 'source' ]
}

mysql_log()
{
	local type="$1"; shift
	printf '%s [%s] [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$type" "$*"
}
mysql_note()
{
	mysql_log Note "$@"
}
mysql_warn()
{
	mysql_log Warn "$@" >&2
}
mysql_error()
{
	mysql_log ERROR "$@" >&2
	exit 1
}

_mysql_want_help() {
	local arg
	for arg; do
		case "$arg" in
			-'?'|--help|--print-defaults|-V|--version)
				return 0
				;;
		esac
	done
	return 1
}

_verboseHelpArgs=(
	--verbose --help
)

mysql_check_config() {
	local toRun=( "$@" "${_verboseHelpArgs[@]}" ) errors
	if ! errors="$("${toRun[@]}" 2>&1 >/dev/null)"; then
		mysql_error $'mariadbd failed while attempting to check config\n\tcommand was: '"${toRun[*]}"$'\n\t'"$errors"
	fi
}

mysql_get_config() {
	local conf="$1"; shift
	"$@" "${_verboseHelpArgs[@]}" 2>/dev/null \
		| awk -v conf="$conf" '$1 == conf && /^[^ \t]/ { sub(/^[^ \t]+[ \t]+/, ""); print; exit }'
}

#cette fonction ne va pas me laisser allumer MariaDB si j ai 2 variables
#d env pour le password pour mariadb {MARIADB_PASSWORS}, {MARIADB_PASSWORD_FILE} 
#
#cette fonction va lire {MARIADB_PASSWORD_FILE} et creer {MARIADB_PASSWORD}
#
file_env()
{
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		mysql_error "Both $var and $fileVar are set (but are exclusive)"
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

_mariadb_file_env() {
	local var="$1"; shift
	local maria="MARIADB_${var#MYSQL_}"
	file_env "$var" "$@"
	file_env "$maria" "${!var}"
	if [ "${!maria:-}" ]; then
		export "$var"="${!maria}"
	fi
}

docker_setup_env() {
	declare -g DATADIR SOCKET PORT
	DATADIR="$(mysql_get_config 'datadir' "$@")"
	SOCKET="$(mysql_get_config 'socket' "$@")"
	PORT="$(mysql_get_config 'port' "$@")"

	_mariadb_file_env 'MYSQL_ROOT_HOST' '%'
	_mariadb_file_env 'MYSQL_DATABASE'
	_mariadb_file_env 'MYSQL_USER'
	_mariadb_file_env 'MYSQL_PASSWORD'
	_mariadb_file_env 'MYSQL_ROOT_PASSWORD'
	file_env 'MARIADB_USER_HOST' '%'

	declare -g DATABASE_ALREADY_EXISTS=''
	if [ -d "$DATADIR/mysql" ]; then
		DATABASE_ALREADY_EXISTS='true'
	fi
}

docker_create_db_directories() {
	local user; user="$(id -u)"
	mkdir -p "$DATADIR"

	if [ "$user" = "0" ]; then
		find "$DATADIR" \! -user mysql \( -exec chown mysql: '{}' + -o -true \)
		if [ "${SOCKET:0:1}" != '@' ]; then # not abstract sockets
			find "${SOCKET%/*}" -maxdepth 0 \! -user mysql \( -exec chown mysql: '{}' \; -o -true \)
		fi

		local cgroup; cgroup=$(</proc/self/cgroup)
		local mempressure="/sys/fs/cgroup/${cgroup:3}/memory.pressure"
		if [ -w "$mempressure" ]; then
			chown mysql: "$mempressure" || mysql_warn "unable to change ownership of $mempressure, functionality unavailable to MariaDB"
		else
			mysql_warn "$mempressure not writable, functionality unavailable to MariaDB"
		fi
	fi
}

docker_verify_minimum_env() {
	if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
		mysql_error $'Database is uninitialized and password option is not specified\n\tYou need to specify MARIADB_ROOT_PASSWORD'
	fi
	if [ -z "$MARIADB_PASSWORD" ]; then
		mysql_error "You need to specify MARIADB_PASSWORD"
	fi
}

docker_init_database_dir() {
	mysql_note "Initializing database files"
	installArgs=( --datadir="$DATADIR" --rpm --auth-root-authentication-method=normal )

	local mariadbdArgs=()
	for arg in "${@:2}"; do
		if [[ "$arg" =~ [[:space:]] ]]; then
			mysql_warn "Not passing argument \'$arg\' to mariadb-install-db because mariadb-install-db does not support arguments with whitespace."
		else
			mariadbdArgs+=("$arg")
		fi
	done
	mariadb-install-db "${installArgs[@]}" "${mariadbdArgs[@]}" \
		--cross-bootstrap \
		--skip-test-db \
		--old-mode='UTF8_IS_UTF8MB3' \
		--default-time-zone=SYSTEM --enforce-storage-engine= \
		--skip-log-bin \
		--expire-logs-days=0 \
		--loose-innodb_buffer_pool_load_at_startup=0 \
		--loose-innodb_buffer_pool_dump_at_shutdown=0
	mysql_note "Database files initialized"
}

docker_sql_escape_string_literal() {
	local newline=$'\n'
	local escaped=${1//\\/\\\\}
	escaped="${escaped//$newline/\\n}"
	echo "${escaped//\'/\\\'}"
}

docker_exec_client() {
	if [ -n "$MYSQL_DATABASE" ]; then
		set -- --database="$MYSQL_DATABASE" "$@"
	fi
	mariadb --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" "$@"
}

docker_process_sql() {
	if [ '--dont-use-mysql-root-password' = "$1" ]; then
		shift
		MYSQL_PWD='' docker_exec_client "$@"
	else
		MYSQL_PWD=$MARIADB_ROOT_PASSWORD docker_exec_client "$@"
	fi
}

docker_temp_server_start() {
	"$@" --skip-networking --default-time-zone=SYSTEM --socket="${SOCKET}" --wsrep_on=OFF \
		--expire-logs-days=0 \
		--skip-slave-start \
		--loose-innodb_buffer_pool_load_at_startup=0 \
		&
	declare -g MARIADB_PID
	MARIADB_PID=$!
	mysql_note "Waiting for server startup"
	extraArgs=()
	if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
		extraArgs+=( '--dont-use-mysql-root-password' )
	fi
	local i
	for i in {30..0}; do
		if docker_process_sql "${extraArgs[@]}" --database=mysql \
			--skip-ssl --skip-ssl-verify-server-cert \
			<<<'SELECT 1' &> /dev/null; then
			break
		fi
		sleep 1
	done
	if [ "$i" = 0 ]; then
		mysql_error "Unable to start server."
	fi
}

docker_process_init_files() {
	mysql=( docker_process_sql )

	echo
	local f
	for f; do
		case "$f" in
			*.sh)
				if [ -x "$f" ]; then
					mysql_note "$0: running $f"
					"$f"
				else
					mysql_note "$0: sourcing $f"
					. "$f"
				fi
				;;
			*.sql)     mysql_note "$0: running $f"; docker_process_sql < "$f"; echo ;;
			*.sql.gz)  mysql_note "$0: running $f"; gunzip -c "$f" | docker_process_sql; echo ;;
			*.sql.xz)  mysql_note "$0: running $f"; xzcat "$f" | docker_process_sql; echo ;;
			*.sql.zst) mysql_note "$0: running $f"; zstd -dc "$f" | docker_process_sql; echo ;;
			*)         mysql_warn "$0: ignoring $f" ;;
		esac
		echo
	done
}

docker_temp_server_stop() {
	kill "$MARIADB_PID"
	wait "$MARIADB_PID"
}

docker_mariadb_init()
{
	ls /docker-entrypoint-initdb.d/ > /dev/null

	docker_init_database_dir "$@"

	mysql_note "Starting temporary server"
	docker_temp_server_start "$@"
	mysql_note "Temporary server started."

	docker_process_init_files /docker-entrypoint-initdb.d/*

	mysql_note "Stopping temporary server"
	docker_temp_server_stop
	mysql_note "Temporary server stopped"

	echo
	mysql_note "MariaDB init process done. Ready for start up."
	echo
}

_main() {
	if [ "${1:0:1}" = '-' ]; then
		set -- mariadbd "$@"
	fi
	if [ "$1" = 'mariadbd' ] || [ "$1" = 'mysqld' ] && ! _mysql_want_help "$@"; then
		mysql_note "Entrypoint script for MariaDB Server ${MARIADB_VERSION} started."

		mysql_check_config "$@"
		docker_setup_env "$@"
		docker_create_db_directories

        #cette ligne dis que si c est le root qui execute se script alors 
        #lance en normal mysql
		if [ "$(id -u)" = "0" ]; then
			mysql_note "Switching to dedicated user 'mysql'"
            #exec va remplacer le processus courant donc en gros ca va eteindre se script et
            #allumer BASH_SOURCE
            #BASH_SOURCE est un tableaux deja donner par bash 
            #cette liste contient tout les processus qui sont lancer
            #donc BASH_SOURCE[0] c est ce fichier la
            #et BASH_SOURCE[1] sera le processus qui a lencer ce fichier
            #du coup cette ligne va exec
            #il va lancer ce script en mysql
			exec gosu mysql "${BASH_SOURCE[0]}" "$@"
		fi

		if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
			docker_verify_minimum_env
			docker_mariadb_init "$@"
		fi
	fi
	exec "$@"
}

if ! _is_sourced; then
	_main "$@"
fi

echo "fin de fichier mariadb"