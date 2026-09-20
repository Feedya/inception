#ce script sert a veroiller le compte du root
#
#
#quand mariaDB s installe le root n a souvent pas de mot de passe
#ou possede des acces non securiser 
#
#se script automatise se qu un hummain ferait 
#avec la commande "mysql_secure_installation"
#il pose le mot de passe secret defini dans votre .env et supprime tous les acces anonymes ou superflu
#
#
#se script sera appeler au demaragge du container mariaDB 
#
#il est appeler automatiquement par le script d entree (entrypoint)
#
#
#



#!/usr/bin/env bash
rootCreate=
rootPasswordEscaped=
if [ -n "$MARIADB_ROOT_PASSWORD" ]; then
    rootPasswordEscaped=$(docker_sql_escape_string_literal "${MARIADB_ROOT_PASSWORD}")
    if [ -n "$MARIADB_ROOT_HOST" ] && [ "$MARIADB_ROOT_HOST" != 'localhost' ]; then
        read -r -d '' rootCreate <<-EOSQL || true
        CREATE USER 'root'@'${MARIADB_ROOT_HOST}' IDENTIFIED BY '${rootPasswordEscaped}' ;
        GRANT ALL ON *.* TO 'root'@'${MARIADB_ROOT_HOST}' WITH GRANT OPTION ;
        GRANT PROXY ON ''@'%' TO 'root'@'${MARIADB_ROOT_HOST}' WITH GRANT OPTION;
EOSQL
    fi

    mysql_note "Securing system users (equivalent to running mysql_secure_installation)"
    docker_process_sql --dont-use-mysql-root-password --database=mysql --binary-mode <<-EOSQL
    -- Securing system users shouldn't be replicated
    SET @orig_sql_log_bin= @@SESSION.SQL_LOG_BIN;
    SET @@SESSION.SQL_LOG_BIN=0;
    -- we need the SQL_MODE NO_BACKSLASH_ESCAPES mode to be clear for the password to be set
    SET @@SESSION.SQL_MODE=REPLACE(@@SESSION.SQL_MODE, 'NO_BACKSLASH_ESCAPES', '');
    DROP USER IF EXISTS root@'127.0.0.1', root@'::1';
    EXECUTE IMMEDIATE CONCAT('DROP USER IF EXISTS root@\'', @@hostname,'\'');
    SET PASSWORD FOR 'root'@'localhost'= PASSWORD('${rootPasswordEscaped}');
    ${rootCreate}
    SET @@SESSION.SQL_LOG_BIN=@orig_sql_log_bin;
EOSQL
fi