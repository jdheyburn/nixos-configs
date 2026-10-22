#!/usr/bin/env bash
# oplog.sh <file> [namespace, default valkey-operator-system] &   -- operator log for the whole run
# `kubectl logs -f` ends when the manager pod goes. This reconnects and keeps
# appending: a new pod is read from its start, the same pod (stream dropped or
# container restarted) from the last line's timestamp, so lines from that one
# second can repeat.
f=$1; ns=${2:-valkey-operator-system}; last_pod=
touch "$f"
while true; do
  pod=$(kubectl -n "$ns" get pods -l control-plane=controller-manager \
    --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$pod" ]; then sleep 2; continue; fi
  since=$(tail -1 "$f" | cut -f1)
  if [ "$pod" != "$last_pod" ] || [ -z "$since" ]; then
    kubectl -n "$ns" logs -f "$pod" >> "$f" 2>/dev/null
  else
    kubectl -n "$ns" logs -f "$pod" --since-time="$since" >> "$f" 2>/dev/null
  fi
  last_pod=$pod
  sleep 2
done
