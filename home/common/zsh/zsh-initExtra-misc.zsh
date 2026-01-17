setopt HIST_IGNORE_ALL_DUPS

if [ -n "$\{commands[fzf-share]\}" ]; then
  source "$(fzf-share)/key-bindings.zsh"
  source "$(fzf-share)/completion.zsh"
fi

# #region agent log
# Debug: log FZF and TMUX environment at shell init
__debug_log_file="/tmp/fzf-tmux-debug.log"
if [ -n "$TMUX" ]; then
  echo "{\"location\":\"zsh-initExtra-misc.zsh:shell-init\",\"message\":\"shell init inside tmux\",\"hypothesisId\":\"C,E\",\"data\":{\"TMUX\":\"$TMUX\",\"FZF_TMUX\":\"$FZF_TMUX\",\"FZF_TMUX_OPTS\":\"$FZF_TMUX_OPTS\",\"FZF_CTRL_R_OPTS\":\"$FZF_CTRL_R_OPTS\",\"fzf_history_widget_defined\":\"$(type fzf-history-widget 2>&1 | head -1)\"},\"timestamp\":$(date +%s000),\"sessionId\":\"debug-session\"}" >>"$__debug_log_file"
fi
# #endregion

# #region agent log
# Debug instrumentation for fzf+tmux issue
__debug_log_file="/tmp/fzf-tmux-debug.log"
__debug_fzf_history_widget() {
  # Log before fzf invocation
  echo "{\"location\":\"zsh-initExtra-misc.zsh:fzf-history-widget\",\"message\":\"fzf history widget invoked\",\"hypothesisId\":\"A,E,F\",\"data\":{\"TMUX\":\"$TMUX\",\"TMUX_PANE\":\"$TMUX_PANE\",\"FZF_TMUX\":\"$FZF_TMUX\",\"FZF_TMUX_OPTS\":\"$FZF_TMUX_OPTS\",\"FZF_TMUX_HEIGHT\":\"$FZF_TMUX_HEIGHT\",\"in_tmux\":\"$([ -n \"$TMUX\" ] && echo 'yes' || echo 'no')\",\"fzf_tmux_path\":\"$(which fzf-tmux 2>&1)\",\"tmux_socket_exists\":\"$([ -S /run/user/1000/tmux-1000/default ] && echo 'yes' || echo 'no')\"},\"timestamp\":$(date +%s000),\"sessionId\":\"debug-session\"}" >>"$__debug_log_file"

  # TEST FIX: Temporarily disable FZF_TMUX to see if plain fzf works
  local orig_fzf_tmux="$FZF_TMUX"
  export FZF_TMUX=0
  echo "{\"location\":\"zsh-initExtra-misc.zsh:fzf-history-widget-override\",\"message\":\"Disabled FZF_TMUX for test\",\"hypothesisId\":\"F\",\"data\":{\"orig_FZF_TMUX\":\"$orig_fzf_tmux\",\"new_FZF_TMUX\":\"$FZF_TMUX\"},\"timestamp\":$(date +%s000),\"sessionId\":\"debug-session\"}" >>"$__debug_log_file"

  # Call the original widget
  fzf-history-widget
  local ret=$?

  # Restore FZF_TMUX
  export FZF_TMUX="$orig_fzf_tmux"

  # Log after fzf invocation
  echo "{\"location\":\"zsh-initExtra-misc.zsh:fzf-history-widget-after\",\"message\":\"fzf history widget completed\",\"hypothesisId\":\"A,E,F\",\"data\":{\"exit_code\":\"$ret\"},\"timestamp\":$(date +%s000),\"sessionId\":\"debug-session\"}" >>"$__debug_log_file"
  return $ret
}
zle -N __debug_fzf_history_widget
bindkey '^R' __debug_fzf_history_widget
# #endregion

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
