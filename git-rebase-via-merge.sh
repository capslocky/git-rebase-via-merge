#!/usr/bin/env bash

default_base_branch='origin/master'

base_branch=${1:-$default_base_branch}


main(){
  echo "This script will perform rebase via merge."
  echo

  init

  git checkout --quiet $current_branch_hash     # switching to detached head state
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
    echo "Can't rebase. There is no current branch: you are in detached head."
    exit 1
  fi 
  
  base_branch_hash=$(get_hash $base_branch)
  current_branch_hash=$(get_hash $current_branch)
  
  if [ -z "$base_branch_hash" ]; then
    echo "Can't rebase. Base branch '$base_branch' not found."
    exit 1
  fi 
  
  echo "Current branch:"
  echo "$current_branch ($current_branch_hash)"
  echo
  
  echo "Base branch:"
  echo "$base_branch ($base_branch_hash)"
  echo

  if [ "$base_branch_hash" = "$current_branch_hash" ]; then
    echo "Can't rebase. Current branch is equal to base branch."
    exit 1
  fi

  if [ -z "$(git rev-list $base_branch ^$current_branch)" ]; then
    echo "Can't rebase. Current branch is already rebased."
    exit 1
  fi

  if [ -z "$(git rev-list ^$base_branch $current_branch)" ]; then
    echo "Can't rebase. Current branch has no any unique commits. You can do fast-forward merge."
    exit 1
  fi

  if [ -n "$(get_any_changed_files)" ]; then
    echo "Can't rebase. You have uncommitted changes in following files:"
    echo
    get_any_changed_files
    exit 1
  fi


  message="Hidden temp commit to save result of merging '$base_branch' into '$current_branch' as detached head."
  
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


get_any_changed_files(){
  git status --porcelain | cut -c4-
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
  hidden_result_hash=$(get_hash HEAD)
  
  echo "Merge succeeded on hidden commit:"
  echo $hidden_result_hash
  echo

  echo "Starting rebase automatically resolving any conflicts in favor of current branch."
  echo 
  
  git checkout --quiet $current_branch
  git rebase $base_branch -X theirs
  echo
  
  restore_tree
}


restore_tree(){
  current_tree=$(git cat-file -p HEAD | grep tree)
  result_tree=$(git cat-file -p $hidden_result_hash | grep tree)

  if [ "$current_tree" != "$result_tree" ]; then
    echo "Restoring project state from hidden merge with single additional commit."
    echo

    additional_commit_message="Rebase via merge. '$current_branch' rebased on '$base_branch'."
    additional_commit_hash=$(git commit-tree $hidden_result_hash^{tree} -p HEAD -m "$additional_commit_message")
    
    git merge $additional_commit_hash
    echo
  else
    echo "You don't need additional commit. Project state is correct."
  fi
}


abort_merge(){
  git merge --abort
  git checkout $current_branch
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
