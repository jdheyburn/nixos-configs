#!/usr/bin/env bash
# podipt.sh <pod> <iptables args...> [NS env, default rel]
# iptables inside a pod's network namespace, from its kind node.
# Bus partition that Valkey 9 notices (inbound-only drops never PFAIL, since
# any inbound traffic counts as liveness): drop outbound cluster-bus packets
#   podipt.sh <pod> -A OUTPUT -p tcp --dport 16379 -m length --length 61:65535 -j DROP
#   podipt.sh <pod> -A OUTPUT -p tcp --sport 16379 -m length --length 61:65535 -j DROP
# Add `-d <peer IP>` to cut a single peer. Heal with: podipt.sh <pod> -F OUTPUT
set -euo pipefail
pod=$1; shift; ns=${NS:-rel}
node=$(kubectl -n "$ns" get pod "$pod" -o jsonpath='{.spec.nodeName}')
cid=$(docker exec "$node" crictl ps --name server --label "io.kubernetes.pod.name=$pod" -q | head -1)
pid=$(docker exec "$node" crictl inspect -o go-template --template '{{.info.pid}}' "$cid")
docker exec "$node" nsenter -t "$pid" -n iptables "$@"
