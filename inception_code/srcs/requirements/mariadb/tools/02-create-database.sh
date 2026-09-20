#
#se script va etre appeler au demarrage de mariaDB 
#
#il va creer la base des donnes vide pour le site WordPress
#
#il va prendre le nom de domaine depuis le env
#qui se trouve sous {MARIADB_DATABASE}
#
#
#


#!/usr/bin/env bash
# Creates a custom database
if [ -n "$MARIADB_DATABASE" ]; then
    mysql_note "Creating database ${MARIADB_DATABASE}"
    docker_process_sql --database=mysql --binary-mode <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`$MARIADB_DATABASE\`;
EOSQL
fi