FROM drupal:8-apache

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y git \
    && apt-get install bash-completion \
    && cp /etc/skel/.bashrc ~/

RUN curl -s https://getcomposer.org/installer | php \
    && mv /var/www/html/composer.phar /usr/local/bin/composer \
    && composer self-update

RUN composer require drupal/console:~1.0 --prefer-dist --optimize-autoloader

RUN curl https://drupalconsole.com/installer -L -o drupal.phar \
    && mv drupal.phar /usr/local/bin/drupal \
    && chmod +x /usr/local/bin/drupal \
    && drupal