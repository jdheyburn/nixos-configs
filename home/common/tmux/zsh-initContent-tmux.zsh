# Kill all tmux sessions and clear resurrect data
# Works on both Linux and macOS
function tmux-nuke() {
    # Determine the tmux socket directory (macOS uses /private/tmp, Linux uses /tmp)
    local socket_dir
    if [[ "$OSTYPE" == "darwin"* ]]; then
        socket_dir="/private/tmp/tmux-$(id -u)"
    else
        socket_dir="/tmp/tmux-$(id -u)"
    fi

    # Kill all tmux processes
    pkill -9 tmux 2>/dev/null

    # Remove socket files
    rm -f "$socket_dir"/* 2>/dev/null

    # Remove resurrect last symlink to prevent auto-restore
    rm -f ~/.tmux/resurrect/last 2>/dev/null

    echo "tmux nuked: killed processes, cleared sockets, removed resurrect state"
}
