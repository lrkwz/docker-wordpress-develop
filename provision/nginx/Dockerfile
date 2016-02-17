FROM debian:jessie
#FROM donbeave/nginx-pagespeed:1.8.0-1

MAINTAINER Luca Orlandi <luca.orlandi@gmail.com>

RUN apt-get update && apt-get install -y curl
RUN echo "deb http://nginx.org/packages/ubuntu/ trusty nginx" > /etc/apt/sources.list.d/nginx.list \
 && echo "deb-src http://nginx.org/packages/ubuntu/ trusty nginx" >> /etc/apt/sources.list.d/nginx.list \
 && curl -o nginx_signing.key http://nginx.org/keys/nginx_signing.key && apt-key add nginx_signing.key \
 && apt-get update && apt-get install -y nginx

ADD nginx.conf /etc/nginx/
ADD wordpress.conf /etc/nginx/sites-available/
#ADD fastcgi_params /etc/nginx/

RUN mkdir -p /etc/nginx/sites-enabled \
 && rm -f /etc/nginx/sites-enabled/default \
 && ln -s /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-enabled/default

RUN echo "upstream php-upstream { server php:9000; }" > /etc/nginx/conf.d/upstream.conf

RUN usermod -u 1000 www-data
VOLUME /etc/nginx/snippets
COPY snippets/max_expires.conf /etc/nginx/conf.d

CMD ["nginx"]

EXPOSE 80
EXPOSE 443
