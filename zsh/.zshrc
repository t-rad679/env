# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

autoload -U +X compinit && compinit

source $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh
FZF_BASE=$(brew --prefix)/opt/fzf
antidote load

# Load custom scripts
export ZSH_CUSTOM=~/env

if [ -f $ZSH_CUSTOM/env_setup.zsh ]; then
    source $ZSH_CUSTOM/env_setup.zsh
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

