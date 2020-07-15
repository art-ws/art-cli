#!/bin/bash

# try to load ~/.artrc
[ -f ~/.artrc ] && source ~/.artrc

[ -z $ART_ROOT ] && ART_ROOT=/opt/art
[ -z $ART_REPO_ROOT ] && ART_REPO_ROOT=$ART_ROOT/p

[ -z $ARTCLI_HOME ] && ARTCLI_HOME=$ART_REPO_ROOT/art-cli
[ -z $ARTCLI_BIN ]  && ARTCLI_BIN=/usr/local/bin/art

rm_dir(){
  [ -d "$1" ] && sudo rm -fR "$1" && echo "$1 removed."
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
  rm_dir $ART_REPO_ROOT
  rm_dir $ART_ROOT
  return 0  
}

[ -d $ART_ROOT ] && \
  echo "You are going to delete folder $ART_ROOT and whole it content." && \
  echo "Directories:" && \
  ls $ART_ROOT && \
  echo ""

read -p "Continue (y/n) ?" choice
case "$choice" in
  y|Y) uninstall;;
  *) echo "Nothing has been deleted.";;
esac
