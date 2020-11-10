#!/bin/bash

echo_stderr() {
  echo "$@" 1>&2
}

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
# https://gist.github.com/jehiah/855086#file-simple_args_parsing-sh-L44
# https://stackoverflow.com/questions/428109/extract-substring-in-bash
# https://linuxhint.com/bash_lowercase_uppercase_strings/
# https://habr.com/ru/company/ruvds/blog/413725/
parse_args(){
  export ARGS_POSITIONAL=()
  export ARGS_KEYS=()
  export ARGS_ALL=()
  export ARGS_EXTRA=()
  export ARGS_META="ARGS_POSITIONAL[@] ARGS_KEYS[@] ARGS_ALL[@] ARGS_EXTRA[@]"
  local i=0    
  
  valid_name(){
     # https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
    local re='^\w+$'
    if [[ $1 =~ $re ]] ; then
      return 0   
    fi
    return 1
  }

  local extra="false"
  while [ "$1" != "" ]; do
    key="$1"
    
    [ "$extra" = "true" ] && ARGS_EXTRA+=("$key")    
    [ "$key" = "--" ] && extra="true"

    ARGS_ALL+=("$key")    
    ((i=i+1))

    case $key in

      --*)
        PARAM=`echo $1 | awk -F= '{print $1}'`
        VALUE=`echo $1 | awk -F= '{print $2}'`

        name="ARGS_${PARAM#*--}"
        name="${name^^}"
        valid_name "$name" \
          && eval "export ${name}='$VALUE'" \
          && ARGS_KEYS+=("$name")     
      ;;

      -*)
        name="ARGS_${key#*-}"
        name="${name^^}"
        valid_name "$name" \
         && eval "export ${name}='$key'" \
         && ARGS_KEYS+=("$name")  
      ;;

      *)
        name="ARGS_${key}"
        name="${name^^}"
        valid_name "$name" \
          && eval "export ${name}=$i" \
          && ARGS_KEYS+=("$name") \
          && ARGS_POSITIONAL+=("$key")
      ;;

    esac
    shift
  done
  
  set -- "${ARGS_POSITIONAL[@]}" # restore positional parameters

}

echo_deprecated(){
  echo_stderr "DEPRECATED! $@"
}

die() {
  echo "$@" 1>&2 
  exit 1
}

check_var(){
  [ -z "$1" ] && die "Variable name not specified"
  for varname in $@
  do
    # https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
    [ -z  "${!varname}" ] && die "Required variable '$varname' not defined"
  done
  return 0
}

check_dir(){
  [ -z "$1" ] && die "Directory path not specified"
  for dir in $@
  do
    [ ! -d "$dir" ] && die "Directory path $dir not exists"
  done  
  return 0
}

check_file(){
  [ -z "$1" ] && die "File path not specified"
  [ ! -f "$1" ] && die "Required file $1 not exists"
  return 0
}

list_projects(){
  check_dir "$ART_REPO_ROOT"
  ls -1 "$ART_REPO_ROOT"
}

starts_with() { case $2 in "$1"*) true;; *) false;; esac; }

# https://unix.stackexchange.com/questions/412868/bash-reverse-an-array#412874
array_reverse() {
  declare -n arr="$1" rev="$2"
  for i in "${arr[@]}"
  do
    rev=("$i" "${rev[@]}")
  done
}

# https://www.tutorialkart.com/bash-shell-scripting/bash-split-string/    
split_string_to_array() {
  local s="$1"
  local delim="$2"
  declare -n result="$3"
  oldIFS="$IFS"
  IFS="$delim"
  result=($s)
  IFS="$oldIFS"
}

# https://stackoverflow.com/questions/16461656/how-to-pass-array-as-an-argument-to-a-function-in-bash#16461878
array_join(){
  local delim="$1"
  shift
  local arr=("$@")
  
  local result=""
  local len=${#arr[@]}
  len=$((len-1))
  for i in $(seq 0 $len); 
  do 
    [ $i = 0 ] && d="" || d="$delim"
    result="${result}${d}${arr[i]}"
  done
  echo "$result"
}

resolve_relative_action(){
  
  array_trim_till_break_item() {
    declare -n input="$1" result="$2"
    local break_item="$3"
    check_var break_item  
    for item in "${input[@]}"
    do 
      [ "$item" = "$break_item" ] && break || result+=("$item")    
    done
  }

  local action="$1"
  local caller="$2"
  check_var ARTCLI_CONST_DIR action 
    
  if ( (starts_with "./" "$action") || (starts_with "../" "$action") ) && [ ! -z $caller ]  
  then
    local delim="/"
    split_string_to_array $action $delim arr_action
    split_string_to_array $caller $delim arr_caller

    array_reverse arr_caller arr_caller_reverse
    array_trim_till_break_item arr_caller_reverse arr_tmp1 "$ARTCLI_CONST_DIR"
    array_reverse arr_tmp1 arr_tmp2
    local len=${#arr_tmp2[@]}

    arr_result=()    
    arr_prefix=()
    local i=0
    for item in "${arr_action[@]}"
    do
      i=$((i+1))
      local dlen=${#item}
      [ $i -gt 1 ] && dlen=1 
      case $item  in
        ".")  len=$((len-$dlen)) ;;        
        "..") len=$((len-$dlen)) ;;
     		*) arr_prefix+=("$item")
      esac
    done

    len=$((len-1))
    for i in $(seq 0 $len); do arr_result+=("${arr_tmp2[i]}"); done
    for item in "${arr_prefix[@]}"; do arr_result+=("$item"); done
   
    local resolved_action=`array_join "$delim" "${arr_result[@]}"`
    echo "$resolved_action"
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
  [ "$action" = "." ] && full_path=`dirname $full_path` 

  # http://ryanstutorials.net/bash-scripting-tutorial/bash-if-statements.php
  if [ -f "$full_path" ] || [ -d "$full_path" ]
  then
    echo "$full_path"
    return 0
  fi

  return 1
}

lookup_path(){
  local path="$1"
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
    if ([ $? -eq 0 ] && [ ! -z "$full_path" ]); then
      echo "$p"
      return 0
    fi
  done
  return 1
}

execute(){
  local path="$1"
  check_var path
  shift
  
  full_path=`lookup_path $path`
  if [ $? -eq 0 ] && [ ! -z "$full_path" ]
  then
    source "$full_path"
  else
    die "Action '$path' not found."
  fi
}

exec_project_dir(){
  local exec_dir="$1"
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
  local action="$1"
  check_var action
  shift
  
  local project=`lookup_project $action`
  [ -z $project ] && die "Action '$action' not found"
  
  exec_project "$project" "$action" "$@"
}

dump_all_commands(){
  for p in `list_projects`
  do
    exec_project "$p" "."
  done
  return 0
}

artcli_get_var(){
  local name="$1"
  check_var name ARTCLI_VALUES_DIR

  local file_path="$ARTCLI_VALUES_DIR/$name"
  [ -f "$file_path" ] && cat "$file_path" || return 1
  return 0
}

artcli_rm_var(){
  local name="$1"
  check_var name ARTCLI_VALUES_DIR

  if [ "$name" = "--all" ]; then
    [ -d "$ARTCLI_VALUES_DIR" ] && rm -fr "$ARTCLI_VALUES_DIR" 
  else
    local file_path="$ARTCLI_VALUES_DIR/$name"
    [ -f "$file_path" ] && rm "$file_path"
  fi
  
  return 0
}

artcli_set_var(){
  local name="$1"
  local value="$2"
  check_var name ARTCLI_VALUES_DIR

  local file_path="$ARTCLI_VALUES_DIR/$name"
  if [ -z "$value" ]; then
    artcli_rm_var "$name" 
  else
    local dir_path=`dirname $file_path`
    [ ! -d "$dir_path" ] && mkdir -p "$dir_path"
    echo "$value" > "$file_path" 
  fi
  return 0
}

join_strings(){
  local delim="$1"
  shift
  local s=""
  for p in "$@" 
  do     
    [ -z "$s" ] && s="$p" || s="${s}${delim}${p}" 
  done
  echo "$s"
}

run(){
 local action="$1"
 shift
 check_var ARTCLI_CWD_VAR
 local cwd=`artcli_get_var $ARTCLI_CWD_VAR`
 
 if ([ -z $ARTCLI_CALLER ] \
     && [ ! -z "$cwd" ] \
     && [ "$action" != 'cd' ] \
     && [ "$action" != 'pwd' ]); then
  starts_with "/" "$action"
  local from_root=$?

  [ $from_root -ne 0 ] && action=`join_strings / $cwd $action`  
 fi 
 
 if [ -z "$action" ]; then
    dump_all_commands "$@"
 else
    try_execute "$action" "$@"
 fi
}

main(){
  # try to load ~/.artrc
  ARTCLI_HISTORY_ENABLED="FALSE"
  [ -f ~/.artrc ] && source ~/.artrc

  # define core env veriables
  [ -z $ART_USER_NAME  ] && ART_USER_NAME="$USER"
  [ -z $ART_USER_EMAIL ] && ART_USER_EMAIL="${ART_USER_NAME}@`hostname`"

  [ -z $ART_ROOT ] && ART_ROOT=/opt/art
  [ -z $ART_REPO_ROOT ] && ART_REPO_ROOT=$ART_ROOT/p

  ARTCLI_HOME=$ART_REPO_ROOT/art-cli

  check_dir "$ART_REPO_ROOT" "$ARTCLI_HOME"

  check_file $ARTCLI_HOME/bin/consts && source $ARTCLI_HOME/bin/consts 
  
  [ -z $ARTCLI_CALLER ] && [ $ARTCLI_HISTORY_ENABLED = "TRUE" ] && echo "$@" >> $ARTCLI_HISTORY_FILE
   
  run "$@"
}

main "$@"
