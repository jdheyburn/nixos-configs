#!/usr/bin/env bash
# loader-pod.sh <cluster> <tls:0|1> [namespace]  -> loader Pod manifest on stdout
# Needs configmap `loader` (loader.py) in the namespace:
#   kubectl -n rel create configmap loader --from-file=loader.py=scripts/loader.py
# Pins the pod to the control-plane node so drains never evict it.
set -euo pipefail
c=$1; tls=$2; ns=${3:-rel}
cp=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
cat <<YAML
apiVersion: v1
kind: Pod
metadata: {name: loader-$c, namespace: $ns, labels: {app: loader}}
spec:
  nodeSelector: {kubernetes.io/hostname: $cp}
  tolerations: [{operator: Exists}]
  containers:
  - name: l
    image: python:3.12-slim
    command: [sh, -c, "pip install -q --root-user-action=ignore valkey==6.1.0 && python /app/loader.py write"]
    env: [{name: VK_HOST, value: valkey-$c.$ns.svc.cluster.local}, {name: VK_TLS, value: "$tls"}]
    volumeMounts: [{name: app, mountPath: /app}, {name: data, mountPath: /data}, {name: tls, mountPath: /tls}]
  volumes:
  - {name: app, configMap: {name: loader}}
  - {name: data, emptyDir: {}}
  - {name: tls, secret: {secretName: $c-server, optional: true}}
YAML
