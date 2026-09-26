#!/usr/bin/env bash

#la premiere ligne est un shebang
#Il lit les 2 premiers octets.
#S'il voit #!, il comprend :
#« ce fichier doit être exécuté par l'interpréteur écrit juste après ».


#
set -Eeuo pipefail

#ici ca va extraitre
#le mot de passe depuis le FILE de 
if [ -n "${WORDPRESS_DB_PASSWORD_FILE:-}" ] && [ -f "$WORDPRESS_DB_PASSWORD_FILE" ]; then
    printf 'dans boucle extraction'
    WORDPRESS_DB_PASSWORD="$(< "$WORDPRESS_DB_PASSWORD_FILE")"
fi

#dans la boucle j avais un --silent que j ai enlver comme ca on peut voir les messages d erreur 
#cette boucle la va ping mariadb
#elle va se connecter au seveur dont le nom de l hote est "mariadb"
#et ca va essayer de se connecter avec les logns "WORDPRESS_DB_USER" et "WORDPRESS_DB_PASSWORD"
#
#mariadb-admin ping : c est une commande propre a Mariadb
# elle ouvre une connexion TCP 
#
#--------------------------------------------------------------------
while ! mariadb-admin \
    --skip-ssl \
    ping \
    -h"mariadb" \
    -u"$WORDPRESS_DB_USER" \
    -p"$WORDPRESS_DB_PASSWORD" \
    --silent
do
    echo "dans boucle connexion"
    sleep 2
done

#    avec le ! devant mariadb-admin ca veut dire que la boucle tourne tant que le ping n a pas reussis 
#    mariadb-admin                   #mariadb-admin est un outil fourni par MARIADB
#                                    #qui sert a adminitstrer un serveur (verifier si il tourne) ici on l utilise avec ping
#    --skip-ssl \                    #ne pas utilise SSL
#    ping \                          #demande au serveur si il est vivant
#    -h"mariadb" \                   #-h : host
#    -u"$WORDPRESS_DB_USER" \        #-u : user
#    -p"$WORDPRESS_DB_PASSWORD" \    #-p : password
#    --silent                        #juste le code de retour 

#se que ce while veut dire :

#ca dit a mariadb-admin de faire un ping sans utiliser SSL au serveur "mariadb"
#et de te connecter en tant que user avec le password
#--------------------------------------------------------------------


echo "Connexion MariaDB reussie !"

#-------------------------------------------------------------------------------------------------------------------------
#cette fonction vient des images docker officiel
#
#son but c est de faire passer un "secret" via un fichier ou directement en variable (<-se qui est faux)
file_env()
{
    #local var : on creer une variable qui va exister que dans la fonction
    local var="$1" #$1 : c est le premier arguments qu on passe a cette fonction
    local fileVar="${var}_FILE" #on ajoute _FILE au premier arguments

    local def="${2:-}" #on prend le deuxieme arguments $2 le :- est "variable : valeur par defauts"
                       #si variable existe on prend variable sinon on prend par defaut 
                       #comme ici on a rien apres le ":-" le def sera une chaine vide
    
    #se if verifie si les deux variable var et fileVar sont pas vide alors c est faux et on sort
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ];
    then
        echo >&2 "ERROR: both $var and $fileVar are set (but are exclusive) dans file_env docker_entrypoint de wordpress"
        exit 1
    fi
    local val="$def" #on reprend la valeur de def (definis en haut)
    if [ "${!var:-}" ];
    then
        val="${!var}"
    elif [ "${!fileVar:-}" ];
    then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}
#-------------------------------------------------------------------------------------------------------------------------



if [ "${1-}" = 'php-fpm83' ] || { self="$(basename "$0")" && [ "$self" = 'docker-ensure-installed.sh' ]; }; then
    uid="$(id -u)"
    gid="$(id -g)"
    if [ "$uid" = '0' ]; then
        user='www-data'
        group='www-data'
    else
        user="$uid"
        group="$gid"
    fi

    if [ ! -e index.php ] && [ ! -e wp-includes/version.php ]; then
        if [ "$uid" = '0' ] && [ "$(stat -c '%u:%g' .)" = '0:0' ]; then
            chown "$user:$group" .
        fi

        echo >&2 "WordPress not found in $PWD - copying now..."
        if [ -n "$(find -mindepth 1 -maxdepth 1 -not -name wp-content)" ]; then
            echo >&2 "WARNING: $PWD is not empty! (copying anyhow)"
        fi
        sourceTarArgs=(
            --create
            --file -
            --directory /usr/src/wordpress
        )
        targetTarArgs=(
            --extract
            --file -
        )
        if [ "$uid" != '0' ]; then
            targetTarArgs+=( --no-overwrite-dir )
        fi
        for contentPath in \
            /usr/src/wordpress/.htaccess \
            /usr/src/wordpress/wp-content/*/*/ \
        ; do
            contentPath="${contentPath%/}"
            [ -e "$contentPath" ] || continue
            contentPath="${contentPath#/usr/src/wordpress/}"
            if [ -e "$PWD/$contentPath" ]; then
                echo >&2 "WARNING: '$PWD/$contentPath' exists! (not copying the WordPress version)"
                sourceTarArgs+=( --exclude "./$contentPath" )
            fi
        done
        tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
        chown -R "$user:$group" .
        echo >&2 "Complete! WordPress has been successfully copied to $PWD"
    fi

    wpEnvs=( "${!WORDPRESS_@}" )
    if [ ! -s wp-config.php ] && [ "${#wpEnvs[@]}" -gt 0 ]; then
        for wpConfigDocker in \
            wp-config-docker.php \
            /usr/src/wordpress/wp-config-docker.php \
        ; do
            if [ -s "$wpConfigDocker" ]; then
                echo >&2 "No 'wp-config.php' found in $PWD, but 'WORDPRESS_...' variables supplied; copying '$wpConfigDocker' (${wpEnvs[*]})"
                awk '
                    /put your unique phrase here/ {
                        cmd = "head -c1m /dev/urandom | sha1sum | cut -d\\  -f1"
                        cmd | getline str
                        close(cmd)
                        gsub("put your unique phrase here", str)
                    }
                    { print }
                ' "$wpConfigDocker" > wp-config.php
                if [ "$uid" = '0' ]; then
                    chown "$user:$group" wp-config.php || true
                fi
                break
            fi
        done
    fi

    file_env 'WORDPRESS_ADMIN_PASSWORD'
    file_env 'WORDPRESS_USER_PASSWORD'

    if [ -s wp-config.php ] && ! wp --allow-root core is-installed 2>/dev/null; then
        if echo "${WORDPRESS_ADMIN_USER}" | grep -iq 'admin'; then
            echo >&2 "ERROR: WORDPRESS_ADMIN_USER '${WORDPRESS_ADMIN_USER}' cannot contain 'admin'"
            exit 1
        fi

        echo >&2 "Installing WordPress..."
        wp --allow-root core install \
            --url="${WORDPRESS_URL}" \
            --title="${WORDPRESS_TITLE}" \
            --admin_user="${WORDPRESS_ADMIN_USER}" \
            --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
            --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
            --skip-email
        echo >&2 "WordPress installed successfully."

        if [ -n "${WORDPRESS_USER:-}" ]; then
            wp --allow-root user create \
                "${WORDPRESS_USER}" \
                "${WORDPRESS_USER_EMAIL}" \
                --role=editor \
                --user_pass="${WORDPRESS_USER_PASSWORD}"
            echo >&2 "User '${WORDPRESS_USER}' created."
        fi
    fi
fi

exec "$@"