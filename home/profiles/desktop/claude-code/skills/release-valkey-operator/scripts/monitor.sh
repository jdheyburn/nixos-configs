#!/usr/bin/env bash
# monitor.sh [namespace] > monitor.log &   -- one line of cluster state every 3s
ns=${1:-rel}
while true; do
  ts=$(date -u +%H:%M:%S)
  sts=$(kubectl -n "$ns" get sts --no-headers 2>/dev/null | wc -l | tr -d ' ')
  pods=$(kubectl -n "$ns" get pods -l valkey.io/cluster --no-headers 2>/dev/null | wc -l | tr -d ' ')
  ownerless=$(kubectl -n "$ns" get pods -l valkey.io/cluster -o jsonpath='{range .items[*]}{.metadata.name}:{.metadata.ownerReferences[0].kind}{"\n"}{end}' 2>/dev/null | grep -c ':$')
  notready=$(kubectl -n "$ns" get pods -l valkey.io/cluster -o jsonpath='{range .items[*]}{.metadata.name}={.status.containerStatuses[*].ready}{"\n"}{end}' 2>/dev/null | grep false | cut -d= -f1 | tr '\n' ' ')
  vc=$(kubectl -n "$ns" get valkeycluster -o jsonpath='{range .items[*]}{.metadata.name}={.status.state}/{.status.reason} {end}' 2>/dev/null)
  echo "$ts sts=$sts pods=$pods ownerless=$ownerless vc=[$vc] notready=[$notready]"
  sleep 3
done
