#!/bin/bash

# Renames a branch, both locally and remote.
#
# Technically, it renames the local branch, then deletes and recreates
# the remote.
#
# Usage:
#     git rename-branch old_branch new_branch

BRANCH_NAME=$1
if [[ -z "$BRANCH_NAME" ]];
then
	echo "Branch name not specified. Cannot proceed"
	exit $FALSE
fi
NEW_NAME=$2
if [[ -z "$NEW_NAME" ]];
then
	echo "New name not specified. Cannot proceed"
	exit $FALSE
fi

git checkout "$BRANCH_NAME"
if [[ $? -ne $TRUE ]];
then
	echo "Branch name did not match any existing branch"
	exit $FALSE
fi
git branch -m "$NEW_NAME"
if [[ $? -ne $TRUE ]];
then
	echo "Failed to rename branch"
	exit $FALSE
fi

git push origin --delete "$BRANCH_NAME"
if [[ $? -ne $TRUE ]];
then
	echo "failed to delete remote branch"
	exit $FALSE
fi
git push origin -u "$NEW_NAME"
if [[ $? -ne $TRUE ]];
then
	echo "Succeeded in deleting remote branch, BUT failed in adding the one with the new name"
	exit $FALSE
fi