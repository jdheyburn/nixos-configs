
setopt HIST_IGNORE_ALL_DUPS

if [ -n "$\{commands[fzf-share]\}" ]; then
    source "$(fzf-share)/key-bindings.zsh"
    source "$(fzf-share)/completion.zsh"
fi

# Add Go binaries
export PATH="$HOME/go/bin:$PATH"

# Load in rbenv (really only for macbook)
if type rbenv &>/dev/null; then
  eval "$(rbenv init -)"
fi

# kube-ps1 - if installed
# probably not needed if using starship
kube_ps1="/usr/local/opt/kube-ps1/share/kube-ps1.sh"
if [ -f $kube_ps1 ]; then
  source $kube_ps1
  PS1='$(kube_ps1)'$PS1
fi

# brew and binaries not appearing on PATH for Applie Silicon
# https://discourse.nixos.org/t/brew-not-on-path-on-m1-mac/26770/3
if [[ $(uname) == "Darwin" ]] && [[ $(uname -m) == "arm64" ]]; then
     eval "$(/opt/homebrew/bin/brew shellenv)"
 fi
