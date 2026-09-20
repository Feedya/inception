<?php
#------------------------------------------------------------------------------------------
#BUT DE SE FICHIER 
#   le but de se fichier est de charger les parametres en memoire vive (RAM)
#   sous forme de contante globales, et apres ca sera la ligne
#   
#   require_once ABSPATH . 'wp-settings.php';
#
#   qui va prendre le relais
#
#
#------------------------------------------------------------------------------------------

if (!function_exists('getenv_docker')) {
    function getenv_docker($env, $default) {
        if ($fileEnv = getenv($env . '_FILE')) {
            return rtrim(file_get_contents($fileEnv), "\r\n");
        } else if (($val = getenv($env)) !== false) {
            return $val;
        } else {
            return $default;
        }
    }
}

#GETENV DOCKER(1ER ARGUMENTS, 2EME ARGUMENTS)
#------------------------------------------------------------------------------------------
#
#getenv_docker(1er arguments, 2eme arguments) fonctionne en 3 etapes
#
#1 : elle va rajouter le suffixe _FILE au premier arguments
#       et elle va regarder si ca existe dans les secrets (compose.yaml)
#
#2 : si elle ne trouve rien dans les secrets, elle va aller regarder dans les
#       variables d environements mais cette fois sans suffixe _FILE
#
#3 : si elle ne trouve pas aussi elle va juste renvoyer le 2 eme arguments donner a elle
#
#
#------------------------------------------------------------------------------------------
#DEFINE(CLE, VALEUR)
#------------------------------------------------------------------------------------------
#
#define(CLE, VALEUR) : 
#   elle va creer une cle valeur 
#
#les cles valeurs sont disponible dans tout les autres fichier php qui suivent la requerre HTTP
#
#------------------------------------------------------------------------------------------

define( 'DB_NAME', getenv_docker('WORDPRESS_DB_NAME', 'wordpress') );
define( 'DB_USER', getenv_docker('WORDPRESS_DB_USER', 'example username') );
define( 'DB_PASSWORD', getenv_docker('WORDPRESS_DB_PASSWORD', 'example password') );

//j ai modifier cette ligne
define( 'DB_HOST', getenv_docker('WORDPRESS_DB_HOST', 'mariadbd') );

define( 'DB_CHARSET', getenv_docker('WORDPRESS_DB_CHARSET', 'utf8mb4') );
define( 'DB_COLLATE', getenv_docker('WORDPRESS_DB_COLLATE', '') );

define( 'AUTH_KEY',         getenv_docker('WORDPRESS_AUTH_KEY',         'put your unique phrase here') );
define( 'SECURE_AUTH_KEY',  getenv_docker('WORDPRESS_SECURE_AUTH_KE Y',  'put your unique phrase here') );
define( 'LOGGED_IN_KEY',    getenv_docker('WORDPRESS_LOGGED_IN_KEY',    'put your unique phrase here') );
define( 'NONCE_KEY',        getenv_docker('WORDPRESS_NONCE_KEY',        'put your unique phrase here') );
define( 'AUTH_SALT',        getenv_docker('WORDPRESS_AUTH_SALT',        'put your unique phrase here') );
define( 'SECURE_AUTH_SALT', getenv_docker('WORDPRESS_SECURE_AUTH_SALT', 'put your unique phrase here') );
define( 'LOGGED_IN_SALT',   getenv_docker('WORDPRESS_LOGGED_IN_SALT',   'put your unique phrase here') );
define( 'NONCE_SALT',       getenv_docker('WORDPRESS_NONCE_SALT',       'put your unique phrase here') );

$table_prefix = getenv_docker('WORDPRESS_TABLE_PREFIX', 'wp_');
define( 'WP_DEBUG', !!getenv_docker('WORDPRESS_DEBUG', '') );

if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) {
    $_SERVER['HTTPS'] = 'on';
}

if ($configExtra = getenv_docker('WORDPRESS_CONFIG_EXTRA', '')) {
    eval($configExtra);
}

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}


#------------------------------------------------------------------------------------------
#LIGNE IMPORTANTE 
#
#require_once : 
#      en gros elle va executer le fichier donner en parametres, ici c est 'wp_settings.php'
#       si elle ne trouve pas l erreur ca renvoie une erreur "E_COMPILE_ERROR"
#       
#       le _once est juste une condition de securiter
#           qui dit que on ne doit pas inclure se fichier avant nul part           
#           en gros on ne doit pas le toucher avant le require_once
#
#ABSPATH : c est le chemin absolu vers la "racine" du wordpress
#           on lui a donner une valeur nous meme avec define plus haut.
#
require_once ABSPATH . 'wp-settings.php';
#------------------------------------------------------------------------------------------
