#
#ce docker file va creer une image NGINX minimale 
#base sur Alpine Linux
#
#on utilise Alpine parceque c est tres leger
#
#
#
#
#
#
#


# syntax=docker/dockerfile:1
# escape=\
# check=error=true
# hadolint global ignore=DL3018

#--------------------------------------------------------------------------------
#ARG c est pour declarer une variable, CLE=VALEUR
ARG OS_VERSION=3.23.5
#--------------------------------------------------------------------------------



#--------------------------------------------------------------------------------
#FROM : veut dire prends cette image existante la 
FROM alpine:${OS_VERSION}
#--------------------------------------------------------------------------------

    
    
    
    
#--------------------------------------------------------------------------------
#RUN : va executer une commande systeme
#RUN fonctionne QUE pendant la creation de l image, nul part d autres
#
#set -eux : va regler le terminal pour le securiser
#
# - e : arrete la creation de l image si qqc bade
# - u : arrete si une variable inconnu est appeler ou vide
# - x : va ecrire dans les log la commande exacte qui est entrain de s executer
#
# c est flag vont fonctionner que sur le run donc que sur apk add --no-cache donc au
# final ils ne servent pas a grand chose
#
#apk add --no-cache :   telecharge le binaire BASH sur ALPINE LINUX
# et effaces les fichiers temporaire 
#
RUN set -eux; \
apk add --no-cache \
bash;
#--------------------------------------------------------------------------------
            
            
#--------------------------------------------------------------------------------
#SHELL va mettre le shell a se qu on veut pendant le run
#parceque normalement RUN utilise un shell minimaliste chepa quoi
#bah grace a SHELL on peut lui dire quelle shell il doit utiliser
#
#donc la on va utiliser bash 
#
#-o pipefall : va inspecter chaque fonction si 1 base on sort   
#
#-c : signifie qu on ferme le bash apres avoir fait RUN
#
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#--------------------------------------------------------------------------------
    
#--------------------------------------------------------------------------------
#
#ENV c est comme ARG on declare une variable CLE=VALEUR
#
#juste cette variable sera en vie toute la vie du container 
# pas seulement la creation de l image etc
#
# LANG : c est une variable d environnement qui dis le language de l ordi
#       genre c est quoi son code ASCII etc
#
# C.UTF-8 : encodage universelle
#
ENV LANG=C.UTF-8
#--------------------------------------------------------------------------------


RUN mkdir /docker-entrypoint-initnginx.d

#--------------------------------------------------------------------------------
#
#LABEL : ajoute des metadonner a l image qu on va creer
#
LABEL org.opencontainers.image.authors="POPADIN FEDOR" \
	  org.opencontainers.image.title="Nginx Inception" \
	  org.opencontainers.image.description="" \
	  org.opencontainers.image.licenses="FEDOR LISENCE" \
	  org.opencontainers.image.version="1.0.0"
#--------------------------------------------------------------------------------



ARG NGINX_PORT=443

RUN set -eux; \
	apk add --no-cache \
	gettext \
	openssl \
	nginx; \
	ln -sf /dev/stdout /var/log/nginx/access.log; \
	ln -sf /dev/stderr /var/log/nginx/error.log; \
	mkdir -p /etc/nginx/templates /etc/nginx/ssl

ENV NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/http.d

#--------------------------------------------------------------------------------
#
#VOLUME : en gros ca sera un espace qui est ouvert a l exterieur
#
VOLUME /var/www/html
#--------------------------------------------------------------------------------

#--------------------------------------------------------------------------------
#
#COPY : 
#
# on va copier un fichier/dossier depuis notre ordi (hote)
# au containeur qu on va creer, donc en mode il aura une copie
# de qqc qu on veut lui donner
#
COPY ./conf/default.conf /etc/nginx/templates/default.conf.template
#--------------------------------------------------------------------------------

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
COPY tools/* /docker-entrypoint-initnginx.d/
RUN chmod +x /docker-entrypoint-initnginx.d/*.sh

#--------------------------------------------------------------------------------
#
# ENTRYPOINT :
#
#   definis un programme qui sera executer a chaque demarage du containers
#
ENTRYPOINT [ "docker-entrypoint.sh" ]
#--------------------------------------------------------------------------------

#--------------------------------------------------------------------------------
#
#EXPOSE :
#
#   expose ne fait RIEN il est la juste pour prevenir en mode que ca c est EXPOSER
#   au monde exterieur
#
EXPOSE ${NGINX_PORT}
#--------------------------------------------------------------------------------

#--------------------------------------------------------------------------------
#
#STOPSIGNAL : 
#
#   definis le signal que docker va envoyer aux containers pour l eteindre
#
STOPSIGNAL SIGQUIT
#--------------------------------------------------------------------------------

#--------------------------------------------------------------------------------
#
# CMD : 
#   
#   definis les arguments par defauts passer a l ENTRYPOINT en mode c est les flags
#
#   imaginons que entrypoint c est "git"
#
#   alors dans CMD on peut mettre "push" ou "commit -m" ou n importe quoi d autres
#
CMD ["nginx", "-g", "daemon off;"]
#--------------------------------------------------------------------------------
