#!/usr/bin/zsh

# Log the GitHub CLI in, but only if it isn't already. Runs right after the
# package step (which installs github-cli) and before anything that clones via
# `gh` (marketplaces.zsh, spotify-mcp.zsh).
#
# --web uses GitHub's device-code flow: gh prints a one-time code and a URL,
# waits for Enter, tries to open a browser and -- if there is none, e.g. on a
# text console -- just tells you to open the URL yourself. Once you approve the
# code in any browser, gh notices and init carries on by itself.
#
# Git goes over ssh. On a box with no key yet, gh offers to generate one and
# upload it to GitHub during this same login, which is what makes the later
# `gh repo clone` steps work on a fresh install.

if ! command -v gh &> /dev/null; then
    print -u2 "gh-login: gh is not installed (did the package step fail?); skipping"
    return 1
fi

if gh auth status --hostname github.com &> /dev/null; then
    print "    gh: already logged in"
    return 0
fi

print "    gh: not logged in -- starting device-code login"
gh auth login --hostname github.com --git-protocol ssh --web
