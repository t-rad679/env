# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

autoload -U +X compinit && compinit

# --- antidote (zsh plugin manager) ---
# Source antidote from wherever it lives on this machine and load the plugins
# listed in ~/.zsh_plugins.txt:
#   macOS -> Homebrew    Arch -> AUR `antidote`    fallback -> git clone ~/.antidote
_antidote_candidates=()
if command -v brew &> /dev/null; then
  _antidote_candidates+="$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
  export FZF_BASE="$(brew --prefix)/opt/fzf"
fi
_antidote_candidates+=(
  /usr/share/antidote/antidote.zsh
  /usr/share/zsh/plugins/antidote/antidote.zsh
  "$HOME/.antidote/antidote.zsh"
)

_antidote_found=0
for _f in $_antidote_candidates; do
  if [[ -r $_f ]]; then
    source $_f
    antidote load          # reads ~/.zsh_plugins.txt
    _antidote_found=1
    break
  fi
done
(( _antidote_found )) || print -u2 "antidote not found -- run: git clone --depth=1 https://github.com/mattmc3/antidote.git ~/.antidote"
unset _f _antidote_found _antidote_candidates

# Load custom scripts. antidote has no $ZSH_CUSTOM auto-loader, so source every
# *.zsh directly, in alphabetical order.
export ZSH_CUSTOM=~/env

for script in $ZSH_CUSTOM/*.zsh(N); do
    source $script
done

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
