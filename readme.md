# [Docker image for Drupal 8 developers (ronnf89/drupal8fancydev)](https://hub.docker.com/r/ronnf89/drupal8fancydev/)

This image extends [drupal:8-apache](https://hub.docker.com/_/drupal/) oficial image and adds:
- [Composer](https://getcomposer.org/)
- [Drupal Console](https://drupalconsole.com/)


# How to use this image
The basic pattern for starting a drupal instance is:
```sh
$ docker run --name some-drupal -d ronnf89/drupal8fancydev
```
If you'd like to be able to access the instance from the host without the container's IP, standard port mappings can be used:
```sh
$ docker run --name some-drupal -p 8080:80 -d ronnf89/drupal8fancydev
```
Then, access it via http://localhost:8080 or http://host-ip:8080 in a browser.

There are multiple database types supported by this image, most easily used via standard container linking. In the default configuration, SQLite can be used to avoid a second container and write to flat-files. More detailed instructions for different (more production-ready) database types follow.

When first accessing the webserver provided by this image, it will go through a brief setup process. The details provided below are specifically for the "Set up database" step of that configuration process.

# Composer
By default, this image includes composer. Run composer into a running container as the following command:

```sh
$ docker exec CONTAINER_ID composer
```

# Drupal Console
By default, this image includes composer. Run Drupal Console into a running container as the following command:

```sh
$ docker exec CONTAINER_ID drupal
```

# MySQL
```sh
$ docker run --name some-drupal --link some-mysql:mysql -d ronnf89/drupal8fancydev
```
- Database type: MySQL, MariaDB, or equivalent
- Database name/username/password: <details for accessing your MySQL instance> (MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE; see environment variables in the description for mysql)
- ADVANCED OPTIONS; Database host: mysql (for using the /etc/hosts entry added by --link to access the linked container's MySQL instance)

# PostgreSQL
```sh
$ docker run --name some-drupal --link some-postgres:postgres -d ronnf89/drupal8fancydev
```
- Database type: PostgreSQL
- Database name/username/password: <details for accessing your PostgreSQL instance> (POSTGRES_USER, POSTGRES_PASSWORD; see environment variables in the description for postgres)
- ADVANCED OPTIONS; Database host: postgres (for using the /etc/hosts entry added by --link to access the linked container's PostgreSQL instance)

# Volumes
By default, this image does not include any volumes. There is a lot of good discussion on this topic in docker-library/drupal#3, which is definitely recommended reading.

There is consensus that /var/www/html/modules, /var/www/html/profiles, and /var/www/html/themes are things that generally ought to be volumes (and might have an explicit VOLUME declaration in a future update to this image), but handling of /var/www/html/sites is somewhat more complex, since the contents of that directory do need to be initialized with the contents from the image.

If using bind-mounts, one way to accomplish pre-seeding your local sites directory would be something like the following:

```sh
$ docker run --rm drupal tar -cC /var/www/html/sites . | tar -xC /path/on/host/sites
```
This can then be bind-mounted into a new container:

```sh
$ docker run --name some-drupal --link some-postgres:postgres -d \
    -v /path/on/host/modules:/var/www/html/modules \
    -v /path/on/host/profiles:/var/www/html/profiles \
    -v /path/on/host/sites:/var/www/html/sites \
    -v /path/on/host/themes:/var/www/html/themes \
    ronnf89/drupal8fancydev
```
Another solution using Docker Volumes:

```sh
$ docker volume create drupal-sites
```
```sh
$ docker run --rm -v drupal-sites:/temporary/sites drupal cp -aRT /var/www/html/sites /temporary/sites
```
```sh
$ docker run --name some-drupal --link some-postgres:postgres -d \
    -v drupal-modules:/var/www/html/modules \
    -v drupal-profiles:/var/www/html/profiles \
    -v drupal-sites:/var/www/html/sites \
    -v drupal-themes:/var/www/html/themes \
    ronnf89/drupal8fancydev
```

# [Docker Compose](https://github.com/docker/compose)

- add .env file at the root of your project with the following lines

```sh
DOMAIN=drupal8
DB_USERNAME=drupal8
DB_PASSWORD=drupal8
DB_DATABASE=drupal8
```

- add docker-compose.yml file at the root of your project with the following lines.

```sh
version: '3.1'

networks:
  drupal8:
    external: false

services:
  traefik:
    container_name: ${DOMAIN}-traefik
    image: traefik
    command: --web --docker --docker.domain=${DOMAIN}.localhost --logLevel=DEBUG
    ports:
      - "82:80"
      - "8082:8080"
      - "8028:8025"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /dev/null:/traefik.toml
    networks:
      - drupal8

  drupal:
    container_name: ${DOMAIN}-drupal
    image: ronnf89/drupal8fancydev
    volumes:
      - ./modules:/var/www/html/modules
      - ./profiles:/var/www/html/profiles
      - ./themes:/var/www/html/themes
      # this takes advantage of the feature in Docker that a new anonymous
      # volume (which is what we're creating here) will be initialized with the
      # existing content of the image at the same location
      - ./sites:/var/www/html/sites
    labels:
      - "traefik.backend=app-${DOMAIN}"
      - "traefik.frontend.rule=Host:app.${DOMAIN}.localhost"
      - "traefik.port=80"
    restart: always
    depends_on:
      - postgres
    networks:
      - drupal8

  postgres:
    container_name: ${DOMAIN}-postgres
    image: postgres:10
    environment:
      - POSTGRES_PGDATA=/var/lib/postgresql/data/pgdata
      - POSTGRES_USER=${DB_USERNAME}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=${DB_DATABASE}
    restart: always
    volumes:
      - ./pgdata:/var/lib/postgresql/data
    networks:
      - drupal8
    labels:
      - "traefik.enable=false"

  adminer:
    container_name: ${DOMAIN}-adminer
    image: adminer
    restart: always
    links:
      - postgres
    labels:
      - "traefik.backend=adminer-${DOMAIN}"
      - "traefik.frontend.rule=Host:adminer.${DOMAIN}.localhost"
      - "traefik.port=8080"
    networks:
      - drupal8
    
  mailhog:
    container_name: ${DOMAIN}-mailhog
    image: mailhog/mailhog
    labels:
      - "traefik.backend=mail-${DOMAIN}"
      - "traefik.frontend.rule=Host:mail.${DOMAIN}.localhost"
      - "traefik.port=8025"
    networks:
      - drupal8
  
volumes:
  db:
    driver: local
```

- Run command at your project root:
```sh
$ docker-compose up -d
```

Now you can access to your differents container services.

- Drupal: http://app.drupal8.localhost:82/
- Adminer: http://adminer.drupal8.localhost:82/
- Mailhog: http://mail.drupal8.localhost:82/
- Traefik: http://localhost:8082/dashboard/


Thanks for read me, please share me to your drupal community.

License
----

MIT


**Free Software, Hell Yeah!**

[//]: # (These are reference links used in the body of this note and get stripped out when the markdown processor does its job. There is no need to format nicely because it shouldn't be seen. Thanks SO - http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)


   [dill]: <https://github.com/joemccann/dillinger>
   [git-repo-url]: <https://github.com/joemccann/dillinger.git>
   [john gruber]: <http://daringfireball.net>
   [df1]: <http://daringfireball.net/projects/markdown/>
   [markdown-it]: <https://github.com/markdown-it/markdown-it>
   [Ace Editor]: <http://ace.ajax.org>
   [node.js]: <http://nodejs.org>
   [Twitter Bootstrap]: <http://twitter.github.com/bootstrap/>
   [jQuery]: <http://jquery.com>
   [@tjholowaychuk]: <http://twitter.com/tjholowaychuk>
   [express]: <http://expressjs.com>
   [AngularJS]: <http://angularjs.org>
   [Gulp]: <http://gulpjs.com>

   [PlDb]: <https://github.com/joemccann/dillinger/tree/master/plugins/dropbox/README.md>
   [PlGh]: <https://github.com/joemccann/dillinger/tree/master/plugins/github/README.md>
   [PlGd]: <https://github.com/joemccann/dillinger/tree/master/plugins/googledrive/README.md>
   [PlOd]: <https://github.com/joemccann/dillinger/tree/master/plugins/onedrive/README.md>
   [PlMe]: <https://github.com/joemccann/dillinger/tree/master/plugins/medium/README.md>
   [PlGa]: <https://github.com/RahulHP/dillinger/blob/master/plugins/googleanalytics/README.md>