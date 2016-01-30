#!/bin/bash

# Verificare i prerequisiti:
#   * deve esserci svn
#   * deve esserci git
#   * queste dir dev essere in svn
#   * questa dir non deve essere nel repository dello skeleton

CURDIR=`dirname $0`/..
PROJROOT=`cd "$CURDIR"; pwd`

WP_VERSION=$WP_VERSION

echo $PROJROOT
svn ps svn:ignore "logs" $PROJROOT
svn ps svn:ignore "wp-config-local.php" $PROJROOT/codebase
svn ps svn:ignore "uploads" $PROJROOT/codebase/wp-content

svn ps svn:externals "wp http://core.svn.wordpress.org/tags/$WP_VERSION/" $PROJROOT/codebase
svn ps svn:externals "akismet http://plugins.svn.wordpress.org/akismet/tags/3.0.4
 wordpress-seo http://plugins.svn.wordpress.org/wordpress-seo/tags/3.0.7" $PROJROOT/codebase/wp-content/plugins
svn ps svn:externals "twentyeleven http://core.svn.wordpress.org/tags/$WP_VERSION/wp-content/themes/twentyeleven
twentytwelve http://core.svn.wordpress.org/tags/$WP_VERSION/wp-content/themes/twentytwelve
twentythirteen http://core.svn.wordpress.org/tags/$WP_VERSION/wp-content/themes/twentythirteen
twentyfourteen http://core.svn.wordpress.org/tags/$WP_VERSION/wp-content/themes/twentyfourteen
twentyfifteen http://core.svn.wordpress.org/tags/$WP_VERSION/wp-content/themes/twentyfifteen" $PROJROOT/codebase/wp-content/themes

cd $PROJROOT/codebase/wp-content/plugins
git clone https://github.com/pkhamre/wp-varnish.git
