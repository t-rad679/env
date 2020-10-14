#!/bin/bash

# Removes local copies of branches that are gone on the remote side
git remote prune origin
git branch -vv | grep ': gone]'|  grep -v "\*" | awk '{ print $1; }' | xargs git branch -D
