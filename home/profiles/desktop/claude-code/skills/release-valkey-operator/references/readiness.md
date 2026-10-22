# Readiness testing

Contents: static review · cluster setup · the upgrade gate · scenario matrix · pitfalls · findings artifact

## Static review subagent

Dispatch one general-purpose subagent in the background against a worktree at the candidate. Its prompt covers three things:

1. The `code-review` skill at `medium` on `<prev>..<candidate>`.
2. The `kubernetes-operator-design` skill on `git diff <prev>..<candidate> -- api/ config/crd/`.
3. An **upgrade-compat audit** of a cluster created by `<prev>` and then run by the candidate:
   - which pod template, Service, ConfigMap or `valkey.conf` changes roll existing clusters;
   - CRD schema changes that reject or alter stored objects, and CEL rules that need a newer API server;
   - label, selector, ownership and `serviceName` changes;
   - RBAC the Helm chart must add.

Ask for each finding with file:line, a failure scenario, and **what to observe on kind to confirm or refute it**. Turn each of those observations into a check in the plan. A static finding is a hypothesis until kind confirms it.

## Cluster setup

- Create one cluster for the release from `scripts/kind-zones.yaml`, named `release-<x-y>-review`. Export its kubeconfig to `/tmp/kind-<name>.kubeconfig`.
- Install cert-manager at the version in `test/utils/utils.go` (`certmanagerVersion`).
- **Operator images.** The Publish workflow pushes every `main` commit to `ghcr.io/valkey-io/valkey-operator:<sha7>`, and every release to `:vX.Y.Z`. Use those images, since they are the exact artifacts being promoted. Build and `kind load` locally only for unmerged fix branches: `make docker-build IMG=valkey-operator:<tag>`, using a tag other than `latest`.
- **Valkey images** are multi-arch, and `kind load` fails on them. Let the nodes pull.
- Install `<prev>` from a worktree at the previous tag with `make install` and `make deploy IMG=<prev image>`. Restore `config/manager/kustomization.yaml` afterwards, because `make deploy` edits it.
- Apply `scripts/workloads.yaml`, after checking its fields exist in `<prev>`'s API. Then start a loader per cluster (`scripts/loader-pod.sh plain 0 | kubectl apply -f -`, `scripts/loader-pod.sh tlsc 1 | ...`), `scripts/monitor.sh > monitor.log &` and `scripts/oplog.sh operator.log &`.
- Count from `operator.log`, never from `kubectl logs deploy/...`: that shows only the current manager pod, so a manager restart loses every earlier line. Count from it, never from events either: Kubernetes merges similar events, so event counts come out low.

The two gate clusters are chosen so bugs surface:

- `plain` has 3 shards, 1 replica each, and PVC persistence.
- `tlsc` has 3×1 TLS, **no persistence**, and a server cert with DNS SANs only.

Persistence masks roll-order bugs: a pod restarting from its PVC keeps its data. So the non-persistent cluster is the one that shows data loss when two members of a shard restart together. DNS-only SANs catch any operator client that verifies against a pod IP.

## The upgrade gate

This is the check that decides a release. Run it for every minor and every patch.

1. Record a baseline: pod UIDs, StatefulSet `serviceName` and config-hash annotation, ValkeyNode roles, and `CONFIG GET` for any config default that changed.
2. Note `T0`. From the candidate worktree, run `make install` (CRDs), then `make deploy IMG=<candidate image>`, then restore `config/manager/kustomization.yaml`. `make deploy` applies the image and the RBAC together under the kustomize name prefix, as a kustomize user upgrades; a bare `kubectl apply -f config/rbac/role.yaml` creates an unprefixed `manager-role` bound to nothing.
3. Wait until every pod has a `creationTimestamp` after `T0` (or none do, if no template input changed) and each cluster is `Ready`.
4. Check each row. The gate passes only when every row matches:

| Check | Pass | Source |
|---|---|---|
| Pods not ready at once, per cluster | 1 at most | `monitor.log` |
| StatefulSet count | never below the pod count; 0 pods without an owner | `monitor.log` |
| Roll order | replica before primary in every shard | pod `creationTimestamp` |
| Proactive failovers | one per primary rolled | `grep -c 'proactive failover completed' operator.log` |
| TLS verify errors | 0 | `grep -c 'IP SANs' operator.log` |
| Missing StatefulSets | 0 | `grep -c 'StatefulSet missing while pod exists' operator.log` |
| Acked writes lost | 0 in both clusters | `kubectl exec loader-<c> -- python /app/loader.py verify` |
| Config after upgrade | matches the release notes' claims | `scripts/vcli.sh <pod> config get <key>` |

If no template input changed, the pass condition changes: no pod UID changes at all.

## Scenario matrix

A **patch** runs the gate, then the rows for the areas its change table touches. A **minor** runs every row. All of them run under loader write load, and each ends with a verify. Run the rows in table order: the last one loses writes on `tlsc` by design.

A cluster **settles** when, for 3 minutes after it reports Ready, `operator.log` gains no `initiating proactive failover` and no `updated StatefulSet pod template` line for it, and every StatefulSet stays at `generation` 1. Ready alone proves nothing: a template the API server rewrites on read keeps the operator rolling and failing over a Ready cluster.

| Scenario | Area | What to check |
|---|---|---|
| CRD apply on the documented minimum Kubernetes (`kindest/node:v1.<min>`, a single-node cluster) | `api`, `k8s-min` | both CRDs apply; the new rules accept a valid value and reject an invalid one with a server-side dry run |
| Candidate manager on `<prev>` CRDs (separate single-node cluster; `kubectl set image` only) | `api` | whether it loops. Count `Updated ValkeyNode` over 3 minutes. The notes must tell users about any loop. |
| Mixed CRDs: candidate ValkeyCluster CRD, `<prev>` ValkeyNode CRD (same single-node cluster) | `api` | set each new field on a running cluster; whether it loops, and whether the field reaches the pods. A field that is silently dropped goes in the notes as "apply both CRDs". |
| Graceful primary delete | `roll` | replica promoted within seconds; the old primary rejoins as a replica |
| Drain a worker holding primaries | `roll` | failover per primary; the PDB blocks a second eviction |
| Valkey image roll, patch then minor (for example 9.0.x to 9.1.x) | `roll`, `template` | one node at a time, a failover per primary, 0 client errors |
| Shards up by 1, then back down | `roll` | slots rebalance; removed nodes are forgotten |
| Replicas 1 to 2 to 1 | `roll` | 0 lost |
| Operator pod deleted mid-roll | `roll` | the roll resumes in order |
| Fresh cluster per new feature, with `replicas: 1` | `feature` | configure the feature through the CR, prove it with a real client (for example `ACL WHOAMI` via mTLS or `CLUSTER SLOTS` hostnames), and check the cluster settles |
| Bus partition (`scripts/podipt.sh`) | `roll` (failure detection) | readyShards and the roll gate stay correct with one stale viewer |
| SIGKILL a primary on `tlsc` (`scripts/hardkill.sh`), last | `roll`, `template` | restart time against `cluster-node-timeout`; writes lost. Without persistence a crashed primary can restart empty and lose its shard's writes, so later verifies on `tlsc` report them too: recreate `loader-tlsc` if anything runs after this row |

## Pitfalls

- A `kind create` switches the default kubectl context. Every command after it still pins `KUBECONFIG`.
- The loader pod pins itself to the control-plane node so that drains do not evict it. `loader-pod.sh` looks the node up; do not hardcode it.
- With local-path PVCs, a pod evicted by a drain stays `Pending` until you uncordon, because its PV is pinned to the drained node. That is a kind limitation, not a finding.
- After a scale-in, removed nodes linger in `CLUSTER NODES` as `fail` for up to `cluster-node-timeout` after the cluster reports Ready.
- Envtest runs a newer Kubernetes than the documented minimum. Only a kind cluster at the minimum proves CRD compatibility.
- If a laptop sleeps, kind API servers can fail TLS handshakes afterwards. Recreate the cluster rather than debug it.
- Other sessions create kind clusters mid-run, and Docker's CPU runs out before its memory. Starvation shows as API server `TLS handshake timeout`, every exporter sidecar restarting on liveness at once, a loader `OOMKilled` and the manager restarting on a lost lease. Run `docker stats --no-stream` before each scenario, wait out a starved spell rather than recreate the cluster, then check `valkey-server` restart counts and verify before you go on. A scenario that overlapped a starved spell is rerun.
- Loader writes go through `app`/`apppass`. Add the ACL user when you create the cluster, because a later change takes about 60s to reach every pod.
- The shell is zsh: `for c in "a b"; do set -- $c` leaves `$c` unsplit. Write one call per case.
- YAML 1.1 reads bare `y`, `n`, `yes` and `no` as booleans, in a resource name or a label value alike. Quote them.
- `kubectl apply` copies the object into its last-applied annotation, so a large annotation fails on `metadata.annotations` before any CEL rule runs. Test size limits with `kubectl create --dry-run=server`.

## Findings artifact

Publish one artifact per release (use the Artifact quickstart), and update it in place as fixes retest. The sections, in order:

1. The verdict: not ready, ready after notes, or ready.
2. A tally.
3. The blockers, each with its evidence, file:line, impact, a fix direction, and its issue link once posted.
4. The upgrade-gate timeline as a table.
5. The scenario table with verdicts.
6. Minor findings and follow-ups: what was seen on kind, and what came from static review only.
7. The environment: clusters, image tags, SHAs.

When a retest follows fixes, add a before and after table: the first candidate against the new one.
