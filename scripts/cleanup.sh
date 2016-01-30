#!/bin/bash

# Verificare i prerequisiti:
#   * deve esserci svn
#   * deve esserci git
#   * queste dir dev essere in svn
#   * questa dir non deve essere nel repository dello skeleton

CURDIR=`dirname $0`/..
PROJROOT=`cd "$CURDIR"; pwd`

echo $PROJROOT
svn pd svn:ignore $PROJROOT
svn pd svn:ignore $PROJROOT/codebase
svn pd svn:ignore $PROJROOT/codebase/wp-content


svn pd svn:externals $PROJROOT/codebase
svn pd svn:externals $PROJROOT/codebase/wp-content/plugins
svn pd svn:externals $PROJROOT/codebase/wp-content/themes

rm -rf $PROJROOT/codebase/wp-content/plugins/wp-varnish
