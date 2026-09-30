# Helm charts

The charts live in `~/code/valkey-helm` (`valkey-io/valkey-helm`). Each release updates two of them:

- `valkey-operator` installs the operator and its CRDs.
- `valkey-resources` installs one ValkeyCluster from a `cluster.spec` drop-in.

Wait until the operator release is published, so the tag and the `ghcr.io/valkey-io/valkey-operator:vX.Y.Z` image exist.

## Branches

Create one worktree per chart from `origin/main`, outside the repo, so the user's checkout stays untouched:

```console
git -C ~/code/valkey-helm fetch origin
git -C ~/code/valkey-helm worktree add -b <user>/valkey-operator-X.Y <dir> origin/main
git -C ~/code/valkey-helm worktree add -b <user>/valkey-resources-A.B <dir> origin/main
```

Before editing, check open valkey-helm PRs (`gh pr list`). One may already sync part of this release, as #251 did for the `pods: delete` RBAC. Ask the user whether to merge it first or fold it in.

## valkey-operator chart

| File | Change |
|---|---|
| `Chart.yaml` | `version`: a new minor for an operator minor (0.7.0 for v0.7.x). For an operator patch whose chart minor has not shipped yet, keep `version` and change only `appVersion`. `appVersion: "vX.Y.Z"`. Leave `kubeVersion` as it is. |
| `crds/*.yaml` | `git show vX.Y.Z:config/crd/bases/<file> > crds/<file>` for both files. Fetch tags first: a failed `git show` still truncates the file, so check the line counts afterwards. |
| `templates/clusterrole.yaml` | Compare its rules with `config/rbac/role.yaml` at the tag. Add any missing verb. |
| `README.md` | the Version and AppVersion badges; the Kubernetes prerequisite if the documented minimum changed |
| `CHANGELOG.md` | a new top entry: the default operator version with a link to the release notes, each chart-visible change, and the CRD note |
| `UPGRADE.md` | a new top section, `## From A.x to B.0`: the CRD commands at the new tag with `--force-conflicts`, why they come first, then `helm upgrade`. If any older section still lacks `--force-conflicts`, fix it too. |

## valkey-resources chart

| File | Change |
|---|---|
| `Chart.yaml` | `version` bump; `appVersion: "vX.Y.Z"`; leave `kubeVersion` as it is |
| `README.md` | badges; the "valkey-operator **vX.Y.Z+** installed" prerequisite; release-notes links |
| `tests/valkeycluster_test.yaml` | the expected `valkey/valkey:vX.Y.Z`, since the fixture templates `.Chart.AppVersion` |
| `values.yaml` | the `appVersion (vX.Y.Z)` comment above `cluster.spec` |
| `CHANGELOG.md` | a new top entry: the appVersion, and the new CR fields available through `cluster.spec` |

## Verify

1. In each worktree, run `helm lint ./<chart>` and `helm unittest ./<chart>`.
2. On a fresh kind cluster (`scripts/kind-zones.yaml`), follow UPGRADE.md exactly as written:
   - Extract the currently released charts with `git -C ~/code/valkey-helm archive origin/main valkey-operator valkey-resources | tar -x -C <dir>`.
   - Install them with their default image. Create the gate workloads through `valkey-resources`, one plain release and one using `examples/tls.yaml`. Use `fullnameOverride` so the names match the loader's.
   - Start the loaders and the monitor.
   - Apply the CRD step, `helm upgrade` the operator chart, then `helm upgrade` both resources releases.
   - Check the gate table from `readiness.md`, plus `kubectl auth can-i` for every RBAC verb added.

   The Helm deployment is named `valkey-operator`; the kustomize one is `valkey-operator-controller-manager`.
3. Uninstall everything, delete the CRDs, and install the new charts from scratch:
   - One release from the chart examples: `minimal`, `persistence`, `scheduling-zone-spread` and `users-acl`. `users-acl` needs a `valkey-users` Secret with `alicepw`.
   - One release using this version's new CR fields.
   - Both must reach Ready, and each new feature must work with a real client.
4. If the documented minimum Kubernetes changed, run a fresh install on a kind cluster at that version too.

## PRs

- Titles: `Release valkey-operator <chart version>` and `Release valkey-resources <chart version>`.
- Body: the release link or links, one bullet per change, then `### Testing` with the lint and unittest results and the kind runs.
- The operator chart merges first, because resources workloads need its CRDs. Say so in the resources PR.
