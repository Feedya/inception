#
#se script s allumer au demarrage de mariaDB
#
#se script sert a le compte utilisateur standart de MariaDB
#et donner tout les droits a cette utilisateur sur WordPress
#
#il va utiliser les valeur de .env
#
#{MARIADB_PASSWORD}, {MARIADB_USER}, {MARIADB_USER_HOST}, {MARIADB_DATABASE}
#
#
#

#!/usr/bin/env bash
# 1. Si MARIADB_PASSWORD_FILE existe, on extrait le mot de passe depuis le fichier
if [ -n "${MARIADB_PASSWORD_FILE:-}" ] && [ -f "$MARIADB_PASSWORD_FILE" ]; then
    MARIADB_PASSWORD="$(< "$MARIADB_PASSWORD_FILE")"
fi

# 2. On s'assure que le joker distant est defini par defaut : "${MARIADB_USER_HOST:=%}"
# Creates a user if specified
if [ -n "$MARIADB_PASSWORD" ] && [ -n "$MARIADB_USER" ]; then
    mysql_note "Creating user ${MARIADB_USER}"
    userPasswordEscaped=$(docker_sql_escape_string_literal "${MARIADB_PASSWORD}")
    createUser="CREATE USER '$MARIADB_USER'@'$MARIADB_USER_HOST' IDENTIFIED BY '$userPasswordEscaped';"
    userGrants=
    if [ -n "$MARIADB_DATABASE" ]; then
        mysql_note "Giving user ${MARIADB_USER} access to schema ${MARIADB_DATABASE}"
        userGrants="GRANT ALL ON \`${MARIADB_DATABASE//_/\\_}\`.* TO '$MARIADB_USER'@'$MARIADB_USER_HOST';"
    fi
    docker_process_sql --database=mysql --binary-mode <<-EOSQL
    ${createUser}
    ${userGrants}
EOSQL
fi