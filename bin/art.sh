#!/bin/bash

echo_stderr() {
  echo "$@" 1>&2
}

die() {
  echo "$@" 1>&2 
  exit 1
}

check_var(){
  [ -z $1 ] && die "Variable name not specified"
  for varname in $@
  do
    # https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
    [ -z  ${!varname} ] && die "Required variable '$varname' not defined"
  done
  return 0
}

check_dir(){
  [ -z $1 ] && die "Directory path not specified"
  for dir in $@
  do
    [ ! -d $dir ] && die "Directory path $dir not exists"
  done  
  return 0
}

check_file(){
  [ -z $1 ] && die "File path not specified"
  [ ! -f $1 ] && die "Required file $1 not exists"
  return 0
}

list_projects(){
  check_dir $ART_REPO_ROOT
  ls -1 $ART_REPO_ROOT
}

starts_with() { case $2 in "$1"*) true;; *) false;; esac; }

# https://unix.stackexchange.com/questions/412868/bash-reverse-an-array#412874
reverse_array() {
  declare -n arr="$1" rev="$2"
  for i in "${arr[@]}"
  do
    rev=("$i" "${rev[@]}")
  done
}

filter_array_till_break_item() {
  # first argument is the array to filter
  # second is the output array
  declare -n arr="$1" res="$2"
  local break_item="$3"
  for item in "${arr[@]}"
  do
    if [ $item = $break_item ] 
    then
      break
    else
      res+=("$item")
    fi    
  done
}

resolve_relative_action(){
  local action="$1"
  local caller="$2"
  check_var ARTCLI_CONST_DIR action 
  
  if starts_with "." "$action" && [ ! -z $caller ]  
  then
    local delim="/"
    # https://www.tutorialkart.com/bash-shell-scripting/bash-split-string/    
    oldIFS="$IFS"
    IFS="$delim"
    arr_action=($action)
    arr_caller=($caller)
    IFS="$oldIFS"

    reverse_array arr_caller arr_rev_caller
    filter_array_till_break_item arr_rev_caller arr1 "$ARTCLI_CONST_DIR"
    reverse_array arr1 arr2
    local len=${#arr2[@]}

    arr_path=()
    # https://linuxconfig.org/how-to-use-arrays-in-bash-script
    
    arr_path2=()
    for item in "${arr_action[@]}"
    do
      case $item  in
        ".")
          len=$((len-1))
       	  ;;
        
        "..")
          len=$((len-2))
          ;;

     		*)
          arr_path2+=("$item")
      esac
    done

    # https://stackoverflow.com/questions/169511/how-do-i-iterate-over-a-range-of-numbers-defined-by-variables-in-bash#169517
    len=$((len-1))
    for i in $(seq 0 $len); 
    do 
      arr_path+=("${arr2[i]}")
    done

    for item in "${arr_path2[@]}"
    do
      arr_path+=("$item")
    done

    local s=""
    local len1=${#arr_path[@]}
    len1=$((len1-1))
    for i in $(seq 0 $len1); 
    do 
      [ $i = 0 ] && dlm="" || dlm="$delim"
      s="${s}${dlm}${arr_path[i]}"
    done

    echo "$s"
  else
    echo "$action"
  fi

  
  return 0
}

lookup_path_at_project(){
  local project="$1"
  local action="$2"

  check_var ARTCLI_CONST_DIR project action
  check_dir $ART_REPO_ROOT
  
  local base_path="$ART_REPO_ROOT/$project/$ARTCLI_CONST_DIR"    
  
  local resolved_action=`resolve_relative_action $action $ARTCLI_CALLER`
  
  local full_path="$base_path/$resolved_action"
  
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
  local action="$1"
  check_var action
  
  for p in `list_projects`
  do
    local full_path=`lookup_path_at_project $p $action`
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
    local item_path="$full_path/$f"

    if [ -f $item_path ] ; then
      local note=""
      local note_path="$full_path/.$f.note.txt"      
      [ -f $note_path ] && note=`cat $note_path`
      echo -e "\E[1;39m$n) . $ARTCLI_CONST_EXEC ${prefix}${f} $note"
    fi

    if [ -d $item_path ] ; then      
      local link_path=`readlink -f $item_path`
      local num=`find $link_path -type f | wc -l`
      echo -e "\E[1;33m$n) * $ARTCLI_CONST_EXEC ${prefix}${f} - $num command(s)"
    fi

  done
  echo -e "\E[0;37m"
}

exec_project_file(){
  local resolved_action="$1"
  check_var resolved_action
  shift

  check_var ARTCLI_PROJECT_PATH
  
  local full_path="$ARTCLI_PROJECT_PATH/$resolved_action"

  ARTCLI_ACTION_DIR_PATH=`dirname $full_path`
  ARTCLI_ACTION_FILE_NAME=`basename $full_path`
  
  check_var ARTCLI_ACTION_DIR_PATH ARTCLI_ACTION_FILE_NAME ARTCLI_CONST_BEFORE_FILE

  local before_file="$ARTCLI_ACTION_DIR_PATH/$ARTCLI_CONST_BEFORE_FILE"
  [ -f "$before_file" ] && source $before_file

  local help_file="$ARTCLI_ACTION_DIR_PATH/.$ARTCLI_ACTION_FILE_NAME.help.txt"
  
  if [ "$1" == "help" ]; then
    if [ -f $help_file ]; then
      cat $help_file
      return 0
    else
      echo "Help file $help_file not exists"
      return 1    
    fi
  else
    ARTCLI_CALLER="$full_path" source $full_path
    return $?
  fi

  return 1
}

exec_project(){
  local project="$1"
  check_var project
  shift

  check_dir $ART_REPO_ROOT
  check_var ARTCLI_CONST_DIR

  local project_root_path="$ART_REPO_ROOT/$project"
  local project_path="$project_root_path/$ARTCLI_CONST_DIR"
  
  local action="$1"
  check_var action
  shift
  
  local resolved_action=`resolve_relative_action $action $ARTCLI_CALLER`
  
  local full_path="$project_path/$resolved_action"

  ARTCLI_PROJECT_ROOT="$project_root_path"
  ARTCLI_PROJECT="$project"
  ARTCLI_PROJECT_PATH="$project_path"
  ARTCLI_ACTION="$action"
  ARTCLI_ACTION_RESOLVED="$resolved_action"

  check_var ARTCLI_PROJECT_ROOT ARTCLI_PROJECT \
    ARTCLI_PROJECT_PATH ARTCLI_ACTION ARTCLI_ACTION_RESOLVED

  if [ -f $full_path ]; then
    exec_project_file "$resolved_action" "$@"
    return $?
  elif [ -d $full_path ]; then
    exec_project_dir "$resolved_action" "$@"
    return $?
  fi

  return 1
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

main(){
  # try to load ~/.artrc
  [ -f ~/.artrc ] && source ~/.artrc

  # define core env veriables
  [ -z $ART_USER_NAME  ] && ART_USER_NAME="$USER"
  [ -z $ART_USER_EMAIL ] && ART_USER_EMAIL="${ART_USER_NAME}@`hostname`"

  [ -z $ART_ROOT ] && ART_ROOT=/opt/art
  [ -z $ART_REPO_ROOT ] && ART_REPO_ROOT=$ART_ROOT/p

  ARTCLI_HOME=$ART_REPO_ROOT/art-cli

  check_dir "$ART_REPO_ROOT" "$ARTCLI_HOME"

  check_file $ARTCLI_HOME/bin/consts && source $ARTCLI_HOME/bin/consts 

  run "$@"
}

main "$@"
