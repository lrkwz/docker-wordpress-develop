#!/bin/bash

# Verificare i prerequisiti:
#   * deve esserci svn
#   * deve esserci git
#   * queste dir dev essere in svn
#   * questa dir non deve essere nel repository dello skeleton

CURDIR=`dirname $0`/..
PROJROOT=`cd "$CURDIR"; pwd`

docker-compose stop
docker-compose rm -fv

svn pd svn:ignore $PROJROOT
svn pd svn:ignore $PROJROOT/codebase
svn pd svn:ignore $PROJROOT/codebase/wp-content


svn pd svn:externals $PROJROOT/codebase
svn pd svn:externals $PROJROOT/codebase/wp-content/plugins
svn pd svn:externals $PROJROOT/codebase/wp-content/themes

rm -rf $PROJROOT/codebase/wp-content/plugins/wp-varnish
rm -rf $PROJROOT/codebase/wp-content/themes/twentythirteen
rm -rf $PROJROOT/codebase/wp-content/themes/twentytwelve
rm -rf $PROJROOT/codebase/wp-content/themes/twentyfourteen
rm -rf $PROJROOT/codebase/wp
rm -rf $PROJROOT/codebase/wp/wp-content/plugins/akismet
rm -rf $PROJROOT/codebase/wp-content/plugins/wordpress-seo
rm -rf $PROJROOT/codebase/wp-content/plugins/akismet
rm -rf $PROJROOT/codebase/wp-content/themes/twentyeleven
rm -rf $PROJROOT/codebase/wp-content/themes/twentyfifteen

svn rm --keep-local $PROJROOT/codebase
svn rm --keep-local $PROJROOT/html
svn rm --keep-local $PROJROOT/provision
svn rm --keep-local $PROJROOT/scripts
svn rm --keep-local $PROJROOT/docker-compose.yml

svn commit -m "Clean up"

rm -rf $PROJROOT/logs
