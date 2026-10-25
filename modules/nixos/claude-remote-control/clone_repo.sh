#!/usr/bin/env bash
# Usage: clone_repo.sh URL DEST [ATTEMPTS] [DELAY]
#
# Clones URL into DEST, retrying ATTEMPTS times DELAY seconds apart. At boot
# the service can start before the container resolves DNS, and one failed
# clone would leave that server down until the next restart.
set -euo pipefail

url=$1
dest=$2
attempts=${3:-6}
delay=${4:-10}

for i in $(seq 1 "$attempts"); do
  if git clone "$url" "$dest"; then
    exit 0
  fi
  if [ "$i" -lt "$attempts" ]; then
    echo "clone of $url failed (attempt $i of $attempts); retrying in ${delay}s" >&2
    sleep "$delay"
  fi
done
exit 1
