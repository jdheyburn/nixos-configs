# Release notes

## Layout

Mirror the previous release (`gh release view <prev> --json body`), which uses this layout:

1. One line saying what the release adds, then a thank-you to contributors.
2. `## Breaking`: only if a CRD field was removed, renamed or re-typed. Give the before and after YAML, and the steps to migrate without losing data.
3. `## Upgrade notes`: one `###` heading per item (see below).
4. `## Features`: `### <What users get> (#PR, closes #issue)`, then a short paragraph on behaviour, not implementation. Link the docs page when one exists.
5. `## Fixes`: the same shape. Say what broke for users before the fix.
6. `## What's Changed` and `## New Contributors`: paste from GitHub. `target_commitish` must be a branch name, because a SHA is rejected:
   ```console
   gh api repos/valkey-io/valkey-operator/releases/generate-notes \
     -f tag_name=vX.Y.Z -f previous_tag_name=<prev> -f target_commitish=main -q .body
   ```
7. `**Full Changelog**: https://github.com/valkey-io/valkey-operator/compare/<prev>...vX.Y.Z`

Leave out CI, dependency bumps, refactors and test-only PRs from Features and Fixes. They appear in What's Changed.

## Upgrade notes

Cover each of these whenever it applies. Each comes from phase 1's areas and phase 2's evidence.

- **Minimum Kubernetes version**, from `docs/quickstart.md`, when it changed. Say what fails on an older version.
- **CRDs before the operator.** Give the commands, with `--force-conflicts`. Helm owns the fields of the CRDs it installed, so a plain server-side apply fails with a conflict on `.spec.versions`:
  ```console
  kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/valkey-io/valkey-operator/vX.Y.Z/config/crd/bases/valkey.io_valkeyclusters.yaml
  kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/valkey-io/valkey-operator/vX.Y.Z/config/crd/bases/valkey.io_valkeynodes.yaml
  ```
  If the "candidate manager on `<prev>` CRDs" scenario looped, say what users see (for example, stuck in `Reconciling/UpdatingNodes`).
- **RBAC**: each verb added in `config/rbac/role.yaml`, and why the operator needs it.
- **Whether upgrading rolls pods.** List every `template` change that causes it. If none, say pods are not rolled, and base that on the diff: only comment or marker changes in non-test Go means no roll.
- **Changed defaults.** Name each one, its old and new value, what users will notice, and the `spec` snippet that keeps the old behaviour.
- **New conditions or events** users will see on existing clusters.

## Patch releases

A patch is short: one intro line, `## Fixes`, and `## Upgrade notes` with two headings.

- **From the previous patch**: usually just the CRD commands, and whether pods roll.
- **From the previous minor**: a link to that minor's notes, plus anything this patch changes about them (for example, a lower minimum Kubernetes version).

## Creating the draft

```console
gh release create vX.Y.Z --draft --title vX.Y.Z --target <candidate SHA> --notes-file <file>
```

A draft creates no tag. GitHub tags the target when the user publishes, and the Publish workflow then pushes the `vX.Y.Z` images. After creating it, run `gh release view vX.Y.Z --json isDraft,targetCommitish` to confirm the draft is pinned to the candidate SHA.
