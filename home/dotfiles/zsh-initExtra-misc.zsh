
setopt HIST_IGNORE_ALL_DUPS

if [ -n "$\{commands[fzf-share]\}" ]; then
    source "$(fzf-share)/key-bindings.zsh"
    source "$(fzf-share)/completion.zsh"
fi

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
