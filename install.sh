#!/bin/bash

ART_ROOT=/opt/art
ART_REPO_ROOT=$ART_ROOT/p

ARTCLI_HOME=$ART_REPO_ROOT/art-cli
ARTCLI_EXEC=$ARTCLI_HOME/bin/art.sh
ARTCLI_BIN=/usr/local/bin/art

die() {
  echo "$@" 1>&2
  exit 1
}

mk_root(){
  if [ ! -d "$ART_ROOT" ]; then
    echo "Creating directory $ART_ROOT ..." 
    sudo mkdir -p $ART_ROOT 
    sudo chmod -R 777 $ART_ROOT
  fi 
  [ ! -d "$ART_ROOT" ] && die "Directory $ART_ROOT not exists"  
  return 0
}

mk_home(){
  if [ ! -d "$ART_REPO_ROOT" ]; then
    echo "Creating directory $ART_REPO_ROOT ..." 
    sudo mkdir -p $ART_REPO_ROOT 
    sudo chmod -R 777 $ART_REPO_ROOT
  fi
  [ ! -d "$ART_REPO_ROOT" ] && die "Directory $ART_REPO_ROOT not exists"
  return 0
}

clone_repo(){
  local src=https://github.com/art-ws/art-cli.git
  [ ! -d "$ARTCLI_HOME/.git" ] && git clone $src "$ARTCLI_HOME"
  [ ! -d "$ARTCLI_HOME/.git" ] && die "Can't clone repository from $src"
  [ -d "$ARTCLI_HOME" ] && chmod -R 775 "$ARTCLI_HOME"
}

install_artcli(){
  [ ! -f $ARTCLI_EXEC ] && die "File '$ARTCLI_EXEC' not exists"
  [ -f $ARTCLI_BIN ] && sudo rm -f $ARTCLI_BIN 
  sudo ln -s $ARTCLI_EXEC $ARTCLI_BIN && \
    sudo chmod +x $ARTCLI_BIN
}

setup(){
  echo "Installing art-cli ..."
  mk_root && \
    mk_home && \
    clone_repo && \
    install_artcli && \
    echo "art-cli installed sucesfully at $ARTCLI_HOME" || \
    echo "art-cli installation failed"
}

verify(){
  echo "Verifying..."
  readlink -v $ARTCLI_BIN && \
    art help && \
    art version && \
    echo "OK" || \
    echo "FAILED" 
}

setup && verify
