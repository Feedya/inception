L'Erreur :

quand je lance mariadb n accepte pas la connexion de wordpress (handshake pas bien)

Erreur quand je fais make 

 Image mariadb:inception Built 
 Image wordpress:inception Built 
 Image nginx:inception Built 
 Container wordpress Running 
 Container mariadb Running 
 Container mariadb Waiting 
 Container mariadb Healthy 
 Container wordpress Waiting 
 Container wordpress Error dependency wordpress failed to start
dependency failed to start: container wordpress is unhealthy
make: *** [Makefile:74: all] Error 1

logs de wordpress :

wordpress  | mariadb-admin: connect to server at 'mariadb' failed
wordpress  | error: 'Received error packet before completion of TLS handshake. The authenticity of the following error cannot be verified: 1130 - Host '172.18.0.3' is not allowed to connect to this MariaDB server'
wordpress  | Check that mariadbd is running and that the socket: '/run/mysqld/mysqld.sock' exists!

logs de mariaDB :

mariadb  | 2026-09-20 14:04:40 95 [Warning] Aborted connection 95 to db: 'unconnected' user: 'unauthenticated' host: '172.18.0.3' (This connection closed normally without authentication)
mariadb  | 2026-09-20 14:04:42 96 [Warning] Aborted connection 96 to db: 'unconnected' user: 'unauthenticated' host: '172.18.0.3' (This connection closed normally without authentication)

se que j ai fait :

j ai verifier pour le user qui se co depuis wordpress a mariadb ca a l air tout bon
le fichier yaml et env ont l air bon aussi
j ai fais des modification dans les script qui m ont mener a rien