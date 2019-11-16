#!/bin/bash

art_root=/opt/art
art_home=$art_root/p
artcli_home=$art_home/art-cli
artcli_src=$artcli_home/bin/art.sh
artcli_bin=/usr/local/bin/art

die() {
  echo "$@" 1>&2
  exit 1
}

mk_root(){
  if [ ! -d "$art_root" ]
  then
    echo "Creating folder '$art_root' ..."
    sudo mkdir -p $art_root
    sudo chmod -R 777 $art_root
  fi 
  [ -d "$art_root" ] || die "Folder '$art_root' not exists"
}

mk_home(){
  if [ ! -d "$art_home" ]
  then
    echo "Creating folder $art_home ..."
    mkdir -p $art_home
    sudo chmod -R 777 $art_home
  fi
  [ -d "$art_home" ] || die "Folder '$art_home' not exists"
}

clone_repo(){ 
  local src=git@github.com:art-ws/art-cli.git
  [ -d "$artcli_home/.git" ] || git clone $src "$artcli_home"
  [ -d "$artcli_home/.git" ] || die "Can't clone repository from $src"
  [ -d "$artcli_home" ] && chmod -R 777 "$artcli_home"
}

install_art(){
  [ -f $artcli_src ] || die "File '$artcli_src' not exists"
  [ -f $artcli_bin ] && sudo rm -f $artcli_bin 
  sudo ln -s $artcli_src $artcli_bin
}

setup(){
  echo "Installing art-cli ..."
  mk_root && \
  mk_home && \
  clone_repo && \
  install_art &&
  echo "art-cli installed"
}

verify(){
  echo "Verifying..."
  readlink $artcli_bin && art help && art version && echo "art-cli installed successfully" 
}

setup
verify
