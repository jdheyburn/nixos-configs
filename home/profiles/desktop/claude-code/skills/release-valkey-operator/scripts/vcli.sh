#!/usr/bin/env bash
# vcli.sh <pod> <valkey-cli args...> [NS env, default rel]
# Runs valkey-cli as the operator user inside the pod's server container.
# VALKEY_TLS_ARGS is the TLS flag set the probes use, so TLS and mTLS work as-is.
pod=$1; shift
kubectl -n "${NS:-rel}" exec "$pod" -c server -- sh -c \
  "valkey-cli \${VALKEY_TLS_ARGS:-} --user \"\$VALKEY_USER\" --pass \"\$VALKEYCLI_AUTH\" --no-auth-warning $*"
