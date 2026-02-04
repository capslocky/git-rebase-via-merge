#!/usr/bin/env bash
#
# https://github.com/capslocky/git-rebase-via-merge

default_base_branch="origin/develop"
base_branch=${1:-$default_base_branch}
export GIT_ADVICE=0
set -e

main() {
  echo "This script will perform a rebase via merge."
  echo
  init
  
  git checkout --quiet "$current_branch_hash" # checkout to detached head (no branch, only commit)
  git merge "$base_branch" -m "Hidden orphaned commit with merge result." || true
  echo

  if [ -n "$(get_unstaged_files)" ]; then
    prompt_user_to_fix_conflicts
  fi

  hidden_result_hash=$(get_hash HEAD)

  echo "Merge succeeded. The target state is: $hidden_result_hash"
  echo "Starting rebase. Any conflicts will be resolved automatically."
  echo

  git checkout --quiet "$current_branch"
  git rebase "$base_branch" -X theirs 2>/dev/null || true # here option 'theirs' means choosing our changes.

  while [ -n "$(get_unstaged_files)" ]; do
    echo "File-level conflict detected. Removing their file, keeping ours." # e.g. parallel file rename
    git status --porcelain
    git status --porcelain | grep -E "^(DD|AU|UD) " | cut -c4- | xargs -r git rm --
    git add -A
    echo
    git -c core.editor=true rebase --continue 2>/dev/null || true # suppressing opening commit message editor
  done

  current_tree=$(git cat-file -p HEAD | grep "^tree")
  result_tree=$(git cat-file -p "$hidden_result_hash" | grep "^tree")

  if [ "$current_tree" != "$result_tree" ]; then
    echo "Restoring the project state from the hidden result with one additional commit."
    echo

    additional_commit_message="Rebase via merge. '$current_branch' rebased on '$base_branch'."
    additional_commit_hash=$(git commit-tree $hidden_result_hash^{tree} -p HEAD -m "$additional_commit_message")

    git merge --ff "$additional_commit_hash"
    echo
  fi

  echo "Done. Current branch:"
  echo "$(git branch --show-current) ($(get_hash HEAD))"
  show_commit HEAD
  exit 0
}

init() {
  if [ -d "$(git rev-parse --git-path rebase-merge)" ]; then
    echo "Can't rebase. Rebase in progress detected. Continue or abort existing rebase."
    exit 1
  fi

  if [ -f "$(git rev-parse --git-path MERGE_HEAD)" ]; then
    echo "Can't rebase. Merge in progress detected. Continue or abort existing merge."
    exit 1
  fi

  current_branch=$(git branch --show-current)
  current_branch_hash=$(get_hash "$current_branch")
  base_branch_hash=$(get_hash "$base_branch")

  if [ -z "$current_branch" ]; then
    echo "Can't rebase. There is no current branch: detached head."
    exit 1
  fi

  if [ -z "$base_branch_hash" ]; then
    echo "Can't rebase. Base branch '$base_branch' not found."
    exit 1
  fi

  echo "Current branch:"
  echo "$current_branch ($current_branch_hash)" # we can restore branch with: git reset 71e5dfa
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

  echo "Continue (c) / Abort (a)"
  read input

  if [ "$input" != "c" ]; then
    echo "Aborted."
    exit 1
  fi
}

prompt_user_to_fix_conflicts() {
  echo "Fix all conflicts in the following files, stage all changes, do not commit, and type 'c':"
  get_unstaged_files
  echo

  while true; do
    echo "Continue merge (c) / Abort merge (a)"
    read input
    echo

    if [ "$input" = "c" ]; then
      if [ -n "$(get_unstaged_files)" ]; then
        echo "There are still unstaged files:"
        get_unstaged_files
        echo
      else
        git -c core.editor=true merge --continue # suppressing opening commit message editor
        break
      fi
    elif [ "$input" = "a" ]; then
      echo "Aborting merge."
      git merge --abort
      git checkout "$current_branch"
      exit 2
    else
      echo "Invalid option: $input"
    fi
  done
}

get_any_changed_files() {
  git status --porcelain --ignore-submodules=dirty | cut -c4-
}

get_unstaged_files() {
  git status --porcelain --ignore-submodules=dirty | grep -v "^. " | cut -c4-
}

get_hash() {
  git rev-parse --short "$1" 2>/dev/null || true
}

show_commit() {
  git log -n 1 --pretty=format:"%<(20)%an | %<(14)%ar | %s" "$1"
}

main