FROM php:5.6-fpm

MAINTAINER Luca Orlandi <luca.orlandi@gmail.com>

#RUN apt-get update && apt-get upgrade -y && apt-get install -y php5-common php5-cli php5-fpm php5-mcrypt php5-mysql php5-apcu php5-gd php5-imagick php5-curl php5-intl php5-xdebug

# install the PHP extensions we need
RUN apt-get update && apt-get install -y libpng12-dev libjpeg-dev && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
	&& docker-php-ext-install gd mysql opcache


ADD 99-wordpress.ini 20-xdebug.ini /etc/php5/cli/conf.d/
ADD 99-wordpress.ini 20-xdebug.ini /etc/php5/fpm/conf.d/
ADD wordpress.pool.conf /etc/php5/fpm/pool.d/

RUN usermod -u 1000 www-data

RUN apt-get update && apt-get upgrade -y && apt-get install -y msmtp
ADD msmtprc /etc/.msmtp_php
RUN chown www-data. /etc/.msmtp_php && chmod 600 /etc/.msmtp_php

#CMD ["php5-fpm","-F"]
#EXPOSE 9000
