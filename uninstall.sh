#!/bin/bash

# try to load ~/.artrc
[ -f ~/.artrc ] && source ~/.artrc

[ -z $ART_ROOT ] && ART_ROOT=/opt/art
[ -z $ART_REPO_ROOT ] && ART_REPO_ROOT=$ART_ROOT/p

[ -z $ARTCLI_HOME ] && ARTCLI_HOME=$ART_REPO_ROOT/art-cli
[ -z $ARTCLI_BIN ]  && ARTCLI_BIN=/usr/local/bin/art

rm_dir(){
  [ -d "$1" ] && sudo rm -fR "$1"
  echo "Directory $1 not exists"
}

rm_artcli(){
  [ -f $ARTCLI_BIN ] && sudo rm -f $ARTCLI_BIN 
  echo "File $ARTCLI_BIN not exists"
}

uninstall(){
  echo "Uninstalling art-cli ..."
  rm_artcli
  rm_dir $ARTCLI_HOME
  return 0  
}

uninstall
