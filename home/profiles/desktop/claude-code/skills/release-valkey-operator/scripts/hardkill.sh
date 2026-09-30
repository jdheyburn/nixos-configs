#!/usr/bin/env bash
# hardkill.sh <pod> [NS env, default rel] -- SIGKILL valkey-server from the kind node
# (the Valkey image has no kill binary).
set -euo pipefail
pod=$1; ns=${NS:-rel}
node=$(kubectl -n "$ns" get pod "$pod" -o jsonpath='{.spec.nodeName}')
cid=$(docker exec "$node" crictl ps --name server --label "io.kubernetes.pod.name=$pod" -q | head -1)
pid=$(docker exec "$node" crictl inspect -o go-template --template '{{.info.pid}}' "$cid")
docker exec "$node" kill -9 "$pid" && echo "killed $pod pid=$pid on $node at $(date -u +%H:%M:%S)"
