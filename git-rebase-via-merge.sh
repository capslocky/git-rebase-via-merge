#!/usr/bin/env bash
#
# The latest version of this script is here
# https://github.com/capslocky/git-rebase-via-merge
#
# Copyright (c) 2022 Baur Atanov
#

default_base_branch="origin/develop"
base_branch=${1:-$default_base_branch}
set -e

main() {
  echo "This script will perform rebase via merge."
  echo

  init

  git checkout --quiet "$current_branch_hash" # switching to detached head state (no current branch)
  git merge "$base_branch" -m "Hidden orphaned commit to save merge result." || true
  echo

  if merge_conflicts_present; then
    echo "You have at least one merge conflict."
    echo
    fix_merge_conflicts
  fi

  hidden_result_hash=$(get_hash HEAD)

  echo "Merge succeeded at hidden commit:"
  echo "$hidden_result_hash"
  echo

  echo "Starting rebase resolving any conflicts automatically."

  git checkout --quiet "$current_branch"
  git rebase "$base_branch" -X theirs || true

  if rebase_conflicts_present; then
    echo "You have at least one rebase conflict."
    echo
    fix_rebase_conflicts
  fi

  current_tree=$(git cat-file -p HEAD | grep tree)
  result_tree=$(git cat-file -p "$hidden_result_hash" | grep tree)

  if [ "$current_tree" != "$result_tree" ]; then
    echo "Restoring project state from the hidden merge with single additional commit."
    echo

    additional_commit_message="Rebase via merge. '$current_branch' rebased on '$base_branch'."
    additional_commit_hash=$(git commit-tree $hidden_result_hash^{tree} -p HEAD -m "$additional_commit_message")

    git merge --ff "$additional_commit_hash"
    echo
  else
    echo "You don't need additional commit. Project state is correct."
  fi

  echo "Done."
  exit 0
}

init() {
  current_branch=$(git symbolic-ref --short HEAD)

  if [ -z "$current_branch" ]; then
    echo "Can't rebase. There is no current branch: you are in detached head."
    exit 1
  fi

  base_branch_hash=$(get_hash "$base_branch")
  current_branch_hash=$(get_hash "$current_branch")

  if [ -z "$base_branch_hash" ]; then
    echo "Can't rebase. Base branch '$base_branch' not found."
    exit 1
  fi

  echo "Current branch:"
  echo "$current_branch ($current_branch_hash)"
  show_commit "$current_branch_hash"
  echo

  echo "Base branch:"
  echo "$base_branch ($base_branch_hash)"
  show_commit "$base_branch_hash"
  echo

  if [ -n "$(get_any_changed_files)" ]; then
    echo "Can't rebase. You need to commit changes in the following files:"
    echo
    get_any_changed_files
    exit 1
  fi

  if [ "$base_branch_hash" = "$current_branch_hash" ]; then
    echo "Can't rebase. Current branch is equal to the base branch."
    exit 1
  fi

  if [ -z "$(git rev-list "$base_branch" ^"$current_branch")" ]; then
    echo "Can't rebase. Current branch is already rebased."
    exit 1
  fi

  if [ -z "$(git rev-list ^"$base_branch" "$current_branch")" ]; then
    echo "Can't rebase. Current branch has no any unique commits. You can do fast-forward merge."
    exit 1
  fi

  while true; do
    echo "Continue (c) / Abort (a)"
    read input
    echo

    if [ "$input" = "c" ]; then
      break
    elif [ "$input" = "a" ]; then
      echo "Aborted."
      exit 1
    else
      echo "Invalid option."
      echo "Type key 'c' - to Continue or 'a' - to Abort."
      echo
    fi
  done
}

get_any_changed_files() {
  git status --porcelain --ignore-submodules=dirty | cut -c4-
}

get_unstaged_files() {
  git status --porcelain --ignore-submodules=dirty | grep -v "^. " | cut -c4-
}

get_files_with_conflict_markers() {
  git diff --check | cat
}

merge_conflicts_present() {
  file_merge="$(git rev-parse --show-toplevel)/.git/MERGE_HEAD"
  [ -e "$file_merge" ]
}

rebase_conflicts_present() {
  [[ $(git diff --name-only --diff-filter=U --relative) ]]
}

get_hash() {
  git rev-parse --short "$1" || true
}

show_commit() {
  git log -n 1 --pretty=format:"%<(20)%an | %<(14)%ar | %s" "$1"
}

fix_merge_conflicts() {
  while true; do
    echo "Fix all conflicts in the following files, stage all the changes and type 'c':"
    get_unstaged_files
    echo

    echo "List of conflict markers:"
    get_files_with_conflict_markers
    echo

    echo "Continue (c) / Abort (a)"
    read input
    echo

    if [ "$input" = "c" ]; then
      if [ -z "$(get_unstaged_files)" ]; then
        git commit -m "Hidden orphaned commit to save merge result."
        break
      else
        echo "There are still unstaged files."
        get_unstaged_files
        echo
      fi
    elif [ "$input" = "a" ]; then
      echo "Aborting merge."
      git merge --abort
      git checkout "$current_branch"
      echo "Aborted."
      exit 2
    else
      echo "Invalid option."
      echo "Type key 'c' - to Continue or 'a' - to Abort."
      echo
    fi
  done
}

fix_rebase_conflicts() {
  while true; do
    echo "Fix all conflicts in the following files, stage all the changes and type 'c':"
    get_unstaged_files
    echo

    echo "List of conflict markers:"
    get_files_with_conflict_markers
    echo

    echo "Continue (c) / Abort (a)"
    read input
    echo

    if [ "$input" = "c" ]; then
      if [ -z "$(get_unstaged_files)" ]; then
        git rebase --continue
        break
      else
        echo "There are still unstaged files."
        get_unstaged_files
        echo
      fi
    elif [ "$input" = "a" ]; then
      echo "Aborting rebase."
      git rebase --abort
      git checkout "$current_branch"
      echo "Aborted."
      exit 2
    else
      echo "Invalid option."
      echo "Type key 'c' - to Continue or 'a' - to Abort."
      echo
    fi
  done
}

main
