#-----------------------------------------------------------------------------
#on va inclue notre fichier .env qui contient
#tout les valeur/ports qu on a besoin
include srcs/.env
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#cette ligne va voir le systeme d exploitation sur le quelle est appeler
#ce makefile
OS      = $(shell uname)
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#le DOMAIN_NAME vient de srcs/.env
DOMAIN  = $(DOMAIN_NAME)
#-----------------------------------------------------------------------------


#-----------------------------------------------------------------------------
# docker compose va lire le fichier .yaml
# -f va specifier le fichier avec le quelle on veut travailler
#
#--progress=plain : 
#	le docker va montrer les logs pendant leur lancement
#
COMPOSE = docker compose -f srcs/compose.yaml --env-file srcs/.env --progress=plain
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#LES SECRETS
#direction des secrets
SECRETS_DIR = secrets
#les secrets seront stoquer en CLE = VALEUR
#les CLE de secrets qu on va avoir
SECRETS     = db_password db_root_password wp_admin_password wp_user_password
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#ici c est a cause du probleme qui est que
#sed -i n a pas la meme syntaxe en fonction si on est sur MAC ou LINUX
#si c est mac
#
#"sed -i" :
#c est un programme externe du shell, en mode comme dans minishell on a
#des commandes interne et externe
#
#cette fonction sert a modifier l interieur d un fichier
#
#donc ici on va creer une variable qui aura la valeur de
#sed -i ''
#ou
#sed -i
ifeq ($(OS), Darwin)
SED_I = sed -i ''
#si c est linux
else
SED_I = sed -i
endif
#un bloc de condition doit se terminer par endif
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#
# 1 : host
#	 qui va mettre dans etc/hosts notre nom de domaine et un ports associer
#
#2 : seed 
#	 ca va creer le dossier secrets ou ca va creer des fichier et dans chaque fichier
#	 il y aura des mots de passe
#
#
#
all: hosts seed volumes
	$(COMPOSE) up -d --build
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#la meme chose que make all
up: hosts seed volumes
	$(COMPOSE) up -d --build
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#elle va eteindre les containers et les detruits
#mais toutes les donnes stoquer dans les volumes reste la
down:
	$(COMPOSE) down
#-----------------------------------------------------------------------------


#-----------------------------------------------------------------------------
#va eteindre les containers mais sans les detruire
#ca va juste les arreter
stop:
	$(COMPOSE) stop
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#apres stop on fait start
start:
	$(COMPOSE) start
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#montre en temps reele les evenemtns qui se passe
logs:
	$(COMPOSE) logs -f
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#ca va montrer les info de nos containers
ps:
	$(COMPOSE) ps
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#va creer les dossier pour mes services
#pour wordpress et mariadb
#ou ils vont stoquer leur donnes	
#
#par defauts quand on eteints les docker en fesant make down ou make fclean
#	toute les donnes seront supprimer donc nous on va creer des dossier sur notre machine
#	a nous, comme ca quand on va eteindre les dockers nos data sont pas supprimer
#
#MARIADB   : 
#	son dossier va contenir les comptes utilisateur, login, password, etc...
#
#WORDPRESS :
#	son dossier va contenir le code source du site wordpress
#	se dossier sera partager avec NGINX qui lui va lire et donner	
#	les bons fichiers aux visiteur
#
#
volumes:
	@sudo mkdir -p $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
	@sudo chown -R $$(id -u):$$(id -g) $(DATA_PATH)
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#
#1 : ca va creer un dossier nommer "secrets"
#
#2 : dans ce dossier ca va creer des fichiers comme nos VALEUR dans fichier .yaml
#	pour les secrets
#
#3 : dans ces fichiers il y aura des mots de passe random de 48 charactere de long 
#
#4 : ca va faire chmod 644 pour enlever les droits de les voir 
#
#5 ; si il y a deja des mots de passe ca va supprimer les anciens et redemarrer MariaDB
#
seed:
	@mkdir -p $(SECRETS_DIR)
	@regenerated=0; \
	for name in $(SECRETS); do \
		file=$(SECRETS_DIR)/$$name.txt; \
		if [ ! -s $$file ]; then \
			openssl rand -hex 24 > $$file; \
			chmod 644 $$file; \
			echo "Generated $$file"; \
			regenerated=1; \
		fi; \
	done; \
	if [ "$$regenerated" = "1" ] && [ -d "$(DATA_PATH)/mariadb/mysql" ]; then \
		echo "New secrets generated but a MariaDB data directory already exists (old passwords baked in) - wiping it so MariaDB re-initializes with the new secrets."; \
		sudo rm -rf $(DATA_PATH)/mariadb; \
	fi
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#ce bloc va associer mon nom de domaine qui est ecrit dans le .env
#et le port 127.0.0.1
#dans le fichier /etc/hosts
#
#/etc/hosts : est un annuaire ou on assicie une adresse : fepopadi.42.fr
#											a un port   : 127.0.0.1 
#
#en gros ca veut dire que quand je tape sur internet "fepopadi.42.fr" ne cherche pas sur internet
#	mais redigire vers le port que je veux (la ici c est ma propre machine)
#
#
hosts:
	@if ! grep -q "$(DOMAIN)" /etc/hosts; then \
		echo "127.0.0.1 $(DOMAIN)" | sudo tee -a /etc/hosts > /dev/null; \
		echo "Added $(DOMAIN) to /etc/hosts"; \
	fi
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
clean: down
	docker compose -f srcs/compose.yaml down -v --rmi all
#@docker system prune -af
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
fclean: clean
	@docker compose -f srcs/compose.yaml down -v --remove-orphans 2>/dev/null || true
	@docker volume rm inception_mariadb_data inception_wordpress_data 2>/dev/null || true
	@sudo rm -rf $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
	@if grep -q "$(DOMAIN)" /etc/hosts; then \
		sudo $(SED_I) "/$(DOMAIN)/d" /etc/hosts; \
		echo "Removed $(DOMAIN) from /etc/hosts"; \
	fi
	@rm -rf $(SECRETS_DIR)
#	@docker volume rm inception_mariadb_data inception_wordpress_data 2>/dev/null || true
#	@sudo rm -rf $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
#	@if grep -q "$(DOMAIN)" /etc/hosts; then \
#		sudo $(SED_I) "/$(DOMAIN)/d" /etc/hosts; \
#		echo "Removed $(DOMAIN) from /etc/hosts"; \
#	fi
#	@rm -rf $(SECRETS_DIR)
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
re: fclean all
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
.PHONY: all up down stop start logs ps volumes seed hosts clean fclean re
#-----------------------------------------------------------------------------


#    MESSAGE VINCENT
#
#    Bonsoir Vincent, je t ecris pour un petit soucis que j ai eu par rapport a 
#		mon espace sur les odrinateurs de l ecole, j ai acheter les 10 gb en plus mais je
#		n ai pas repondu au bot de discord a temps, donc j aimerai savoir se que je dois faire 
#		pour pouvoir les avoir. 

