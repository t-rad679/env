#!/bin/bash
# Pulls the local copy of a default branch and rebases the current branch
# onto it. Does not pull the current branch
#
# Usage (default branch is master):
#     git update
#
# Usage (default branch is not master):
#     git update <default_branch_name>

BRANCH="$(git branch --show-current)"
DEFAULT_BRANCH=develop
if [ ! -z "$1" ]; then
	DEFAULT_BRANCH="$1"
fi

STASH_OUTPUT=$(git stash)
echo $STASH_OUTPUT

git checkout $DEFAULT_BRANCH
git pull
git checkout $BRANCH
git rebase $DEFAULT_BRANCH

if [[ $STASH_OUTPUT != "No local changes to save" ]]; then
	git stash apply
fi
