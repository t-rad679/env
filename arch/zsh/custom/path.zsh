#!/bin/bash

if [ -d ~/bin ]; then
    export PATH=~/bin:$PATH
fi

if [ -d ~/.local/bin ]; then
    export PATH=~/.local/bin:$PATH
fi
