#!/usr/bin/env bash

default_base_branch='master'

base_branch=${1:-$default_base_branch}


main(){
  echo "This script will perform rebase via merge."
  echo

  init

  git checkout -b $temp_branch
  git merge $base_branch -m "$message"
  echo

  if check_merge_in_progress; then
    conflict_menu
  else
    merge_done
  fi

  echo "Done."
}


init(){
  current_branch=$(git symbolic-ref --short HEAD)

  if [ -z "$current_branch" ]; then
    echo "There is no current branch: you are in detached head."
    exit 1
  fi 
  
  local base_branch_hash=$(get_hash $base_branch)
  local current_branch_hash=$(get_hash $current_branch)
  
  if [ -z "$base_branch_hash" ]; then
    echo "Base branch '$base_branch' not found."
    exit 1
  fi 
  
  echo "Current branch:"
  echo "$current_branch ($current_branch_hash)"
  echo
  
  echo "Base branch:"
  echo "$base_branch ($base_branch_hash)"
  echo

  if [ "$base_branch_hash" = "$current_branch_hash" ]; then
    echo "Current branch is equal to base branch."
    exit 1
  fi

  if [ -z "$(git rev-list $base_branch ^$current_branch)" ]; then
    echo "Current branch is already rebased!"
    exit 1
  fi

  if [ -z "$(git rev-list ^$base_branch $current_branch)" ]; then
    echo "Current branch has no any unique commits. You can do fast-forward merge."
    exit 1
  fi

  temp_branch=$current_branch-temp
  
  echo "Temp branch:"
  echo "$temp_branch"
  echo
  
  message="Temp commit on branch '$temp_branch' to save result of merging '$base_branch' into '$current_branch'."
  
  while true
  do
    echo "Continue (c) / Abort (a)"
    read input
    echo
    
    if [ "$input" = "c" ]; then
      break
    elif [ "$input" = "a" ]; then
      echo "Aborting."
      exit 1
    else  
      echo "Type 'c' - Continue or 'a' - Abort."
      echo
    fi
  done
}


get_unstaged_files(){
  git status --porcelain | grep -v '^. ' | cut -c4-
}


check_merge_in_progress(){
  git merge HEAD &> /dev/null
  (( $? > 0 ))
}


get_hash(){
  git rev-parse --short "$1"
}


merge_done(){
  git checkout $current_branch
  git rebase $base_branch -X theirs
  restore_tree
  git branch -D $temp_branch
}


restore_tree(){
  local current_tree=$(git cat-file -p HEAD | grep tree)
  local temp_tree=$(git cat-file -p $temp_branch | grep tree)

  if [ "$current_tree" != "$temp_tree" ]; then
    commit_hash=$(git commit-tree $temp_branch^{tree} -p HEAD -m "Rebase via merge. '$current_branch' rebased on '$base_branch'.")
    git merge $commit_hash
  fi
}


abort_merge(){
  git merge --abort
  git checkout $current_branch
  git branch -D $temp_branch
}


conflict_menu(){
  echo "You have at least one merge conflict."
  echo
  
  while true
  do
    echo "Fix all conflicts in the following files, stage them up and type 'c':"
    get_unstaged_files
    
    echo "Continue (c) / Abort (a)"
    read input
    echo
    
    if [ "$input" = "c" ]; then
      if [ -n "$(get_unstaged_files)" ]; then
        echo "There are still unstaged files."
        echo
        continue
      else
        git commit -m "$message"
        merge_done
        break
      fi
    elif [ "$input" = "a" ]; then
        echo "Aborting merge and operation."
        abort_merge
        exit 2
    else
        echo "Type 'c' - Continue or 'a' - Abort."
        echo
    fi
  done
}


main
