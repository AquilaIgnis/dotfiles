if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_DISABLE_COMPFIX="true" #root comp
ZSH_THEME="powerlevel10k/powerlevel10k"

export ZSH="$HOME/.oh-my-zsh"
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST
export EDITOR='nvim'
export VISUAL='nvim'

export PATH="$HOME/scripts:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/go/bin/:$PATH"
export PATH="$HOME/google-cloud-sdk/bin/:$PATH"
export PATH="/home/mahalo/.stripe/bin:$PATH"


export PYTHONUNBUFFERED=1
export QT_QPA_PLATFORMTHEME=qt5ct
export MANPAGER="sh -c 'awk '\''{ gsub(/\x1B\[[0-9;]*m/, \"\", \$0); gsub(/.\x08/, \"\", \$0); print }'\'' | bat -p -lman'"
export NO_AT_BRIDGE=1 #disable accessibility
export GTK_A11Y=none

# some more ls aliases
alias update='sudo dnf update && flatpak -y update'
alias cl='clear'
alias src='source ~/.zshrc'
alias neogit='onefetch'
alias update-grub='grub2-mkconfig -o /boot/grub2/grub.cfg'
alias vim='nvim'
alias xc='wl-copy'
alias goadum='ssh -x mal0@192.168.1.209'
alias zz='python $HOME/scripts/devmode.py'
alias docker-compose='docker compose'
alias ddown='docker compose down'
alias dps='docker container ls --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" -a'
alias yzz='yazi'
alias sr='source .venv/bin/activate'
alias ncdu='ncdu --color dark'
alias git-push='git remote | xargs -n1 git push'
alias gc='git clone --depth=1'
alias apksigner='$HOME/Android/Sdk/build-tools/37.0.0/apksigner'
alias fd='fd --no-ignore'

### Plugins ###
plugins=(zsh-autosuggestions python virtualenv fzf)

function cd {
    builtin cd "$@" && ls
}

function .. {
    builtin cd .. "$@" && ls
}


source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

if [[ -t 0 ]]; then
  stty -ixon
fi

# open file with nvim
fzf-nvim-widget() {
  local file

  file=$(
    (
      unset FZF_DEFAULT_COMMAND
      fzf --walker=file,follow < /dev/tty
    )
  ) || {
    zle reset-prompt
    return
  }

  [[ -z "$file" ]] && return

  zle -I
  nvim -- "$file"
  zle reset-prompt
}

zle -N fzf-nvim-widget
bindkey '^S' fzf-nvim-widget


# search git by message
fgl() {
  fzf --disabled \
    --bind 'start:reload:git log --all --oneline 2>&1 | sed "/^gpg:/d"' \
    --bind 'change:reload:git log --all --oneline -i -F --grep {q} 2>&1 | sed "/^gpg:/d"' \
    --preview 'git show --color=always {1} 2>&1 | sed "/^gpg:/d"' \
    --preview-window 'right:60%'
}



eval "$(uv generate-shell-completion zsh)"

# Added by Antigravity CLI installer
export PATH="/home/mahalo/.local/bin:$PATH"
