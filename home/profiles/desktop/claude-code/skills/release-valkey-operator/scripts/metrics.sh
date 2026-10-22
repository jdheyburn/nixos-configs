#!/usr/bin/env bash
# metrics.sh <pod> [regex, default '^redis_up '] [NS env, default rel]
# Exporter metrics for a Valkey pod. The exporter image has no wget or curl,
# so the request runs from the loader-plain pod's Python.
#   metrics.sh valkey-plain-0-0-0
#   metrics.sh valkey-tlsc-0-0-0 '^redis_(up|connected_clients) '
set -euo pipefail
pod=$1; re=${2:-'^redis_up '}; ns=${NS:-rel}
ip=$(kubectl -n "$ns" get pod "$pod" -o jsonpath='{.status.podIP}')
case $ip in *:*) ip="[$ip]";; esac
kubectl -n "$ns" exec loader-plain -- python -c "
import re, urllib.request
body = urllib.request.urlopen('http://$ip:9121/metrics', timeout=5).read().decode()
print('\n'.join(l for l in body.splitlines() if re.search(r'''$re''', l)))"
