#!/usr/bin/env bash
input=$(cat)

user=$(whoami)
dir=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')

# Git branch (skip optional locks to avoid blocking)
branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)

# Context window usage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build the status line
parts=""

# user@host:dir
host=$(hostname -s)
parts="${user}@${host}:$(basename "$dir")"

# git branch
if [ -n "$branch" ]; then
  parts="${parts} [${branch}]"
fi

# model
parts="${parts} | ${model}"

# context
if [ -n "$used_pct" ]; then
  printf_pct=$(printf "%.0f" "$used_pct")
  parts="${parts} | ctx:${printf_pct}%"
fi

printf "%s" "$parts"
