#!/bin/bash

die() {
  echo "$@" 1>&2
  exit 1
}

# try to load ~/.artrc
[ -f ~/.artrc ] && source ~/.artrc

# define core env veriables
[ -z $ART_USER_NAME  ] && ART_USER_NAME="$USER"
[ -z $ART_USER_EMAIL ] && ART_USER_EMAIL="${ART_USER_NAME}@`hostname`"
[ -z $ART_ROOT ] && ART_ROOT=/opt/art
[ -z $ART_REPO_ROOT ] && ART_REPO_ROOT=$ART_ROOT/p

[ ! -d $ART_REPO_ROOT ] && die "Directory '$ART_REPO_ROOT' not exists"

ARTCLI_HOME=$ART_ROOT/art-cli
source $ARTCLI_HOME/bin/ENV

dump_args(){
 local n=0
 while [ "$1" ]
 do
  ((n+=1))
  echo "$n = [$1]"
  shift
 done
}

exec_project_dir(){
  local exec_dir=$1
  shift

  [ -z $ART_PROJECT_PATH ] && die "ART_PROJECT_PATH not defined"


  local cwd="$ART_PROJECT_PATH"
  local project_path=`dirname $cwd`
  local project_name=`basename $project_path`

  local full_path="$cwd/$exec_dir"

  local prefix=""
  [ "$exec_dir" != "." ] && prefix="$exec_dir/"

  echo -e "\E[1;34m[$project_name]"
  local about_file="$full_path/$ART_CLI_ABOUT_DIR_FILE"
  if [ -f "$about_file" ]; then
    echo -e "\E[0;37m`cat $about_file`"
  fi

  local n=0
  for f in `ls $full_path | grep -v "^_"`
  do
    n=$((n+1))
    if [ -f $full_path/$f ] ; then
      echo -e "\E[1;39m$n) . $ART_CLI_CMD ${prefix}${f}"
    fi
    if [ -d $full_path/$f ] ; then
      local num=`find $full_path/$f -type f | wc -l`
      echo -e "\E[1;33m$n) * $ART_CLI_CMD ${prefix}${f} - $num command(s)"
    fi
  done
  echo -e "\E[0;37m"
}

exec_project_file(){
  local exec_file=$1
  shift

  [ -z $ART_PROJECT_PATH ] && die "ART_PROJECT_PATH not defined"

  local full_path="$ART_PROJECT_PATH/$exec_file"

  ART_EXEC_FILE_DIR=`dirname $full_path`
  ART_EXEC_FILE_NAME=`basename $full_path`
  
  ART__DIRNAME=$ART_EXEC_FILE_DIR
  ART__BASENAME=$ART_EXEC_FILE_NAME

  local before_file="$ART_EXEC_FILE_DIR/$ART_CLI_EXEC_BEFORE"
  [ -f "$before_file" ] && source $before_file

  local help_file=$ART_EXEC_FILE_DIR/"_$ART_EXEC_FILE_NAME.txt"
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
 shift
 [ -z $project ] && die "project not defined"

 local project_root_path="$ART_ROOT/$project"
 local project_path="$project_root_path/$ART_CLI_DIR"
 local path=$1
 shift
 [ -z $path ] && die "path not defined"

 local full_path="$project_path/$path"

 ART_PROJECT_ROOT_PATH="$project_root_path"
 ART_PROJECT="$project"
 ART_PROJECT_PATH="$project_path"
 ART_EXEC_ACTION="$path"

 if [ -f $full_path ]; then
   exec_project_file "$path" "$@"
   return $?
 elif [ -d $full_path ]; then
   exec_project_dir "$path" "$@"
   return $?
 fi

 return 1
}

execute_from_project(){
  local project=$1
  shift
  local path=$1
  shift
  [ -z $project ] && die "project not defined"
  [ -z $path ] && die "path not defined"

}

list_projects(){
  ls -1 $ART_ROOT
}

lookup_path_at_project(){
  local project=$1
  local path=$2
  [ -z $project ] && die "project not defined"
  [ -z $path ] && die "path not defined"

  local full_path="$ART_ROOT/$project/$ART_CLI_DIR/$path"
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
  [ -z $path ] && die "path not defined"
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
  [ -z $path ] && die "path not defined"
  for p in `list_projects`
  do
    full_path=`lookup_path_at_project $p $path`
    if [ $? -eq 0 ] && [ ! -z "$full_path" ]
    then
      echo "$p"
      return 0
    fi
  done
  return 1
}

execute(){
  local path=$1
  shift
  [ -z $path ] && die "path not defined"
  full_path=`lookup_path $path`
  if [ $? -eq 0 ] && [ ! -z "$full_path" ]
  then
    source $full_path
  else
    die "Action '$path' not found"
  fi
}

try_execute(){
 log "try_execute()" 
 local action=$1
 shift
 project=`lookup_project $action`
 [ $? -eq 0 ] || die "Action '$action' not found"
 log "project = $project"
 exec_project "$project" "$action" "$@"
}

dump_all_commands(){
  log "dump_all_commands()"
  for p in `list_projects`
  do
    exec_project $p "."
  done
  return 0
}

run(){
 local action=$1
 shift

 [ $debug == "1" ] && echo "TRY EXECUTE ACTION: $action"
 if [ -z $action ]
 then
   dump_all_commands
 else
   try_execute $action "$@"
 fi
}

run "$@"
