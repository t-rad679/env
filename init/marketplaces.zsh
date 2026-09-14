#!/usr/bin/zsh

# Clone my local Claude plugin marketplaces (referenced from claude/settings.json
# as directory sources under ~/src). Skips anything already present. Needs the
# gh login step to have succeeded.

typeset -a marketplaces
marketplaces=(t-rad679/tinkertask-skills t-rad679/ping-pong-skills)

rc=0
for repo in $marketplaces; do
    dest="$HOME/src/${repo:t}"
    if [[ -d $dest ]]; then
        print "    $dest already present"
        continue
    fi
    if ! gh repo clone "$repo" "$dest"; then
        print -u2 "    clone of $repo failed -- check the name with: gh repo list ${repo:h}"
        rc=1
    fi
done
return $rc
