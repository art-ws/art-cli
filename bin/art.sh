#!/bin/bash

die() {
  echo "$@" 1>&2
  exit 1
}

check_dir(){
  [ ! -d $1 ] && die "Required directory $1 not exists"
  return 0
}

check_file(){
  [ ! -f $1 ] && die "Required file $1 not exists"
  return 0
}

check_var(){
  [ -z $1 ] && die "Variable name not specified"
  local varname=$1
  # https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
  [ -z  ${!varname} ] && die "Required variable '$varname' not defined"  
  return 0
}

# try to load ~/.artrc
[ -f ~/.artrc ] && source ~/.artrc

# define core env veriables
[ -z $ART_USER_NAME  ] && ART_USER_NAME="$USER"
[ -z $ART_USER_EMAIL ] && ART_USER_EMAIL="${ART_USER_NAME}@`hostname`"

[ -z $ART_ROOT ] && ART_ROOT=/opt/art
[ -z $ART_REPO_ROOT ] && ART_REPO_ROOT=$ART_ROOT/p

ARTCLI_HOME=$ART_REPO_ROOT/art-cli

check_dir $ART_REPO_ROOT
check_dir $ARTCLI_HOME

check_file $ARTCLI_HOME/bin/consts && source $ARTCLI_HOME/bin/consts 

exec_project_dir(){
  local exec_dir=$1
  check_var exec_dir
  shift

  check_var ARTCLI_PROJECT_PATH
    
  local cwd="$ARTCLI_PROJECT_PATH"
  check_dir $cwd

  local project_path=`dirname $cwd`
  local project_name=`basename $project_path`

  local full_path="$cwd/$exec_dir"

  local prefix=""
  [ "$exec_dir" != "." ] && prefix="$exec_dir/"

  echo -e "\E[1;34m[ $project_name ]"

  check_var ARTCLI_CONST_ABOUT_FILE

  local about_file="$full_path/$ARTCLI_CONST_ABOUT_FILE"
  if [ -f "$about_file" ]; then
    echo -e "\E[0;37m`cat $about_file`"
  fi

  check_var ARTCLI_CONST_EXEC

  local n=0 
  for f in `ls $full_path | grep -v "^\."`
  do
    n=$((n+1))
    
    if [ -f $full_path/$f ] ; then
      local note=""
      local note_path="$full_path/.$f.note.txt"      
      [ -f $note_path ] && note=`cat $note_path`
      echo -e "\E[1;39m$n) . $ARTCLI_CONST_EXEC ${prefix}${f} $note"
    fi

    if [ -d $full_path/$f ] ; then
      local item_path="$full_path/$f"
      local link_path=`readlink -f $item_path`
      local num=`find $link_path -type f | wc -l`
      echo -e "\E[1;33m$n) * $ARTCLI_CONST_EXEC ${prefix}${f} - $num command(s)"
    fi

  done
  echo -e "\E[0;37m"
}

exec_project_file(){
  local exec_file=$1
  check_var exec_file
  shift

  check_var ARTCLI_PROJECT_PATH

  local full_path="$ARTCLI_PROJECT_PATH/$exec_file"

  ARTCLI_ACTION_DIR_PATH=`dirname $full_path`
  ARTCLI_ACTION_FILE_NAME=`basename $full_path`
  
  check_var ARTCLI_ACTION_DIR_PATH
  check_var ARTCLI_ACTION_FILE_NAME
  check_var ARTCLI_CONST_BEFORE_FILE

  local before_file="$ARTCLI_ACTION_DIR_PATH/$ARTCLI_CONST_BEFORE_FILE"
  [ -f "$before_file" ] && source $before_file

  local help_file="$ARTCLI_ACTION_DIR_PATH/.$ARTCLI_ACTION_FILE_NAME.help.txt"
  if [ -f $help_file ] && [ "$1" == "help" ];
  then
    cat $help_file
    return 0
  else
    source $full_path
    return $?
  fi

  return 1
}

exec_project(){
  local project=$1
  check_var project
  shift

  check_dir $ART_REPO_ROOT
  check_var ARTCLI_CONST_DIR

  local project_root_path="$ART_REPO_ROOT/$project"
  local project_path="$project_root_path/$ARTCLI_CONST_DIR"
  
  local path=$1
  check_var path
  shift

  local full_path="$project_path/$path"

  ARTCLI_PROJECT_ROOT="$project_root_path"
  ARTCLI_PROJECT="$project"
  ARTCLI_PROJECT_PATH="$project_path"
  ARTCLI_ACTION="$path"

  check_var ARTCLI_PROJECT_ROOT
  check_var ARTCLI_PROJECT
  check_var ARTCLI_PROJECT_PATH
  check_var ARTCLI_ACTION

  if [ -f $full_path ]; then
    exec_project_file "$path" "$@"
    return $?
  elif [ -d $full_path ]; then
    exec_project_dir "$path" "$@"
    return $?
  fi

  return 1
}

list_projects(){
  check_dir $ART_REPO_ROOT
  ls -1 $ART_REPO_ROOT
}

lookup_path_at_project(){
  local project=$1
  local path=$2

  check_var project
  check_var path
  check_dir $ART_REPO_ROOT
  check_var ARTCLI_CONST_DIR

  local full_path="$ART_REPO_ROOT/$project/$ARTCLI_CONST_DIR/$path"
  # http://ryanstutorials.net/bash-scripting-tutorial/bash-if-statements.php
  if [ -f "$full_path" ] || [ -d "$full_path" ]
  then
    echo "$full_path"
    return 0
  fi

  return 1
}

lookup_path(){
  local path=$1
  check_var path

  for p in `list_projects`
  do
    full_path=`lookup_path_at_project $p $path`
    if [ $? -eq 0 ] && [ ! -z "$full_path" ]
    then
      echo "$full_path"
      return 0
    fi
  done
  return 1
}

lookup_project(){
  local path=$1
  check_var path
  
  for p in `list_projects`
  do
    full_path=`lookup_path_at_project $p $path`
    if [ $? -eq 0 ] && [ ! -z "$full_path" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

execute(){
  local path=$1
  check_var path
  shift
  
  full_path=`lookup_path $path`
  if [ $? -eq 0 ] && [ ! -z "$full_path" ]
  then
    source $full_path
  else
    die "Action '$path' not found"
  fi
}

try_execute(){
  local action=$1
  check_var action
  shift
  local project=`lookup_project $action`
  [ -z $project ] && die "Action '$action' not found"
  exec_project "$project" "$action" "$@"
}

dump_all_commands(){
  for p in `list_projects`
  do
    exec_project $p "."
  done
  return 0
}

run(){
 local action=$1
 shift

 if [ -z $action ]; then
   dump_all_commands
 else
   try_execute $action "$@"
 fi
}

run "$@"
