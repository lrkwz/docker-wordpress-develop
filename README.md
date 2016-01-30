Dockerized Wordpress
====================

Questo è un tipico skeletro di semplice applicazione Wordpress.

Può essere utilizzato per lo sviluppo in locale utilizzando Docker [1] come segue.

Setup
-----

1. Installa Docker seguendo le instruzioni che trovi sul sito [2] (verifica se dovesse essere necessario aggiungere il tuo utente al gruppo docker per non dovere utilizzare root)
2. Installa docker-compose [3]
3. Esegui il comando ```docker-compose build``` e attendi che le immagini necessarie vangano scaricate (non ti preoccupare questo avviene solo la prima volta)
4. Esegui il comando  ```docker-compose up``` (puoi aggiungere il parametro```-d``` per _demonizzare_ i contenitori)

Comandi di base
---------------

Se tutto va a buon fine a questo punto puoi puntare il browser su http://localhost

Per __interrompere i contenitori__ utilizza CTRL-C se non li hai _demonizzati_ altrimenti usa ```docker-compose stop```.

Per __osservare lo stato dei contenitori__ usa ```docker-compose ps```; vedrai i loro identificatori (_tag_ in docker-ese) e le porte che eventualmete espongono verso il tuo host (quindi accessibili sull'indirizzo localhost).

Per esempio:

    $ docker-compose ps
    Name                      Command               State               Ports                 
    ---------------------------------------------------------------------------------------------
    moreit_application_1   /bin/bash                        Up                                    
    moreit_db_1            /docker-entrypoint.sh mysqld     Up      0.0.0.0:3306->3306/tcp                      
    moreit_mail_1          /bin/sh -c java -jar /opt/ ...   Up      25/tcp                        
    moreit_nginx_1         nginx                            Up      443/tcp, 0.0.0.0:8080->80/tcp
    moreit_php_1           php5-fpm -F                      Up      0.0.0.0:9000->9000/tcp        
    moreit_varnish_1       /run.sh                          Up      0.0.0.0:80->80/tcp            

indica che il contenitore moreit_application_1 e attivo e non espone alcuna porta mentre moreit_db_1 espone la porta 3306/tcp verso gli altri contenitori e la stessa porta è anche bounded su localhost (quindi ad esempio puoi usare un qualunque client mysql per interrogare il database).

Come sono composti e cosa contengono questi contenitori?
--------------------------------------------------------

Il file docker-compose definisce 6 differenti contenitori:

### application
E' un semplice [__data volume container__](https://docs.docker.com/engine/userguide/dockervolumes/) che monta la directory codebase come ```/var/www/html```; ho scelto di utilizzare un data volume container in modo da poterlo riutilizzare su più altri container qualora volessimo fare per esempio delle prove di scalabilità.

### db
E' un contenitore basato sulla immagine ufficiale di MariaDB (utilizza la medesima versione presente in produzione). Questa immagine inizializza il database e gli account al momento della creazione del contenitore, inoltre vengono eseguiti tutti gli script (sh e sql) presenti nella directory scripts (montata come ```/docker-entrypoint-initdb.d```).

I file del database sono memorizzati sul _data volume container_ application

### mail
E' basato sulla immagine fakesmtp ed espone la porta 25 verso gli altri container in modo da potere essere utilizzato come SMTP.

Le mail vengono salvate in file distinti nella directory ```logs/mail```.

### php
Questo contenitore viene costruito a partire da una debian vuota sulla quale vengono installati php-fpm e tutti i vari moduli necessari.

Utilizza il contenitore application, db e mail.

### nginx
Anche questo contenitore è costruito a partire da una debian vuota e installa al momento della build nginx e tutti i file di configurazione necessari per redirigere le richieste verso il contenitore php.

Utilizza il contenitore php.
Espone la porta http://localhost:8080

### varnish
Installa una immagine standard contenente varnish e un file default.vcl ottenuto a partire da quello di produzione.

Utilizza il contenitore nginx.
Espone la porta http://localhost

[1] http://www.docker.com
[2] https://docs.docker.com/engine/installation/
[3] https://docs.docker.com/compose/install/
