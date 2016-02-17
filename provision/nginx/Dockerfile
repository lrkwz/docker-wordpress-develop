FROM debian:jessie
#FROM nginx

MAINTAINER Luca Orlandi <luca.orlandi@gmail.com>

RUN apt-get update && apt-get install -y nginx

ADD nginx.conf /etc/nginx/
ADD wordpress.conf /etc/nginx/sites-available/
ADD restrictions.conf wordpress-ms-subdir.conf wordpress-ms-subdir-w3-total-cache.conf wordpress-ms-subdir-wp-super-cache.conf /etc/nginx/snippets/


RUN mkdir -p /etc/nginx/sites-enabled/ && ln -s /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-enabled/wordpress
RUN rm -f /etc/nginx/sites-enabled/default

RUN echo "upstream php-upstream { server php:9000; }" > /etc/nginx/conf.d/upstream.conf

RUN usermod -u 1000 www-data

CMD ["nginx", "-c", "/etc/nginx/nginx.conf"]
EXPOSE 80 443
