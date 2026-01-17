
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

# brew and binaries not appearing on PATH for Applie Silicon
# https://discourse.nixos.org/t/brew-not-on-path-on-m1-mac/26770/3
if [[ $(uname) == "Darwin" ]] && [[ $(uname -m) == "arm64" ]]; then
     eval "$(/opt/homebrew/bin/brew shellenv)"
 fi
