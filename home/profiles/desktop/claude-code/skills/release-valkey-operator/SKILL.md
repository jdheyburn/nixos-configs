---
name: release-valkey-operator
description: Cut a valkey-operator release (readiness testing on kind, blocker issues, release notes, draft GitHub release, valkey-helm chart PRs).
disable-model-invocation: true
argument-hint: <version, e.g. 0.8.0> [phase]
---

# Releasing valkey-operator

Take `vX.Y.Z` from a **candidate** commit to a published release and its Helm chart PRs, in four phases. Start at the phase the request names ("draft notes for 0.7.1" starts at phase 3), but always run phase 1 first: every later phase reads its change table.

The release is a **minor** when Z is 0 and a **patch** otherwise. The two differ only in how much readiness testing runs.

## Ground rules

- **Release train.** Only merged work ships. The candidate is the head of `upstream/main` when phase 1 runs. Before starting a later phase, check `upstream/main` has not moved; if it has, redo phase 1 and tell the user what changed.
- **The user publishes.** Create the GitHub release as a draft and hand it over. `gh release edit` replaces the whole body, so read the release first (`gh release view vX.Y.Z --json isDraft,body`) and carry over any edits made in the UI.
- **Writing.** Every issue, release note and PR body goes through `compound-writing:cw-ai-check` before it is shown or posted. Each claim in it is verified against the code or a kind run, and your summary says which.
- **Clusters.** Pin `KUBECONFIG` on every cluster-touching command, as in `review-valkey-operator-pr`. Docker has about 7.7 GiB: list `kind get clusters` before creating one, and ask before deleting a cluster this release did not create.
- **Worktrees.** Build, test and commit from fresh worktrees (the candidate, the previous tag, each chart branch) so the user's checkouts and staged work stay untouched.

## Phase 1: Scope

1. `git fetch upstream --tags`. The previous release is the highest existing `v*` tag below `vX.Y.Z`. Record the candidate SHA.
2. List `git log --oneline <prev>..upstream/main`. For each PR, get the issues it closes: `gh pr view <n> --json closingIssuesReferences`.
3. Tag each change with the **areas** it touches, since readiness scenarios are chosen by area:
   - `api`: `git diff <prev>..<candidate> -- api config/crd` (CRD schema, CEL rules, new fields).
   - `rbac`: `config/rbac/role.yaml` changed (the Helm ClusterRole must follow).
   - `template`: pod template inputs, meaning `valkeynode_resources.go`, the base config in `config.go`, the probe scripts, the exporter. Any change here rolls every existing cluster on upgrade.
   - `roll`: the roll, failover and cluster-state code.
   - `k8s-min`: the minimum Kubernetes version in `docs/quickstart.md`.
   - `feature`: new user-facing behaviour.

Phase 1 is done when you have the candidate SHA, the previous tag, and a change table (PR, title, closes, areas) that the user has seen.

## Phase 2: Readiness

Read [`references/readiness.md`](references/readiness.md) before planning. It holds the cluster setup, the **upgrade gate**, the scenario matrix and the known pitfalls.

1. Start the static review subagent in the background (prompt in the reference).
2. Write the test plan: the upgrade gate, plus the scenarios the change table's areas call for. Show it to the user before running anything.
3. Run the plan on kind. Record each scenario's commands, observed output and verdict as you go.
4. Publish a findings artifact (layout in the reference).
5. For each **blocker**, draft a bug issue using the repo's template. Show the drafts; the user decides which block the release and when each is posted.
6. When blocker fixes merge, redo phase 1 and rerun the upgrade gate, plus any scenario the fix touches, against the new candidate. Update the artifact.

Phase 2 is done when every planned scenario has a verdict backed by evidence, and the user has ruled on every blocker.

## Phase 3: Release notes

Read [`references/release-notes.md`](references/release-notes.md), then draft the notes, run cw-ai-check, and show them. Once the user approves, create the draft release pinned to the candidate SHA.

Phase 3 is done when a draft release `vX.Y.Z` exists, its body matches the approved notes, and the user knows it is waiting for them to publish.

## Phase 4: Helm charts

Read [`references/helm.md`](references/helm.md). It covers both charts in `~/code/valkey-helm`, the file checklist, kind testing, and the PR format.

Phase 4 is done when both chart PRs are open, `helm lint` and `helm unittest` pass on each, and the kind upgrade and fresh-install runs have passed against the published operator image.

## Scripts

`scripts/` holds the tooling the readiness and Helm tests share. Each script documents its arguments at the top; all of them expect `KUBECONFIG` to be exported.

- `kind-zones.yaml`: a kind cluster with 1 control plane and 3 workers labelled `zone-a`, `zone-b` and `zone-c`.
- `workloads.yaml`: the gate's two ValkeyClusters, with their CA, certs and ACL user.
- `loader.py` and `loader-pod.sh`: write sequential keys, record each **acked write**, and verify them all later.
- `monitor.sh`: logs StatefulSet count, pods without an owner, cluster state and not-ready pods every 3s.
- `vcli.sh`: `valkey-cli` as the operator user inside a pod, with TLS handled.
- `hardkill.sh`: SIGKILLs a pod's `valkey-server` from its kind node.
- `podipt.sh`: runs `iptables` in a pod's network namespace, for bus partitions.
