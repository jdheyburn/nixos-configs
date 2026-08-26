---
name: review-valkey-operator-pr
description: Use when asked to review a valkey-operator PR or branch by validating it against a local kind cluster (e.g. "/review-valkey-operator-pr 382", "review this PR locally", "kind-validate this change and review it").
---

# Reviewing a PR with kind validation

Validate the change on a real kind cluster, run the code-review skill, and write one combined report.

## Workflow

1. **Resolve the target.**
   - PR number given: `gh pr view <n> --json state,title,body,headRefName`. Open PR → check it out in a worktree under `.worktrees/`. Merged PR → review its merge commit on `main`.
   - No number: use the current branch/worktree as-is; find its PR with `gh pr view --json number,title,body`.
2. **Understand the change.** Read the diff, the PR description, and every issue the PR references (`gh issue view <n>` — the body plus any repro steps or acceptance criteria in comments). Derive (a) the behaviors to exercise — including a scenario reproducing the referenced issue's original failure, so the review confirms the PR resolves what it claims to close — and (b) the cluster shape they need — node count, zone labels, cert-manager, anything the scenarios depend on.
3. **Kick off code review in the background.** Invoke the `code-review` skill on the target diff at `medium` effort. It runs while the cluster work proceeds; its findings feed steps 6 and 7.
4. **Create a dedicated cluster** — always a fresh one, named for this review, so concurrent agents and in-flight work never share a cluster. `make setup-test-e2e KIND_CLUSTER=pr-<n>-review` gives the standard 1 control-plane + 2 workers; hand-write a kind config instead when the change needs more (zone labels, extra workers). If `pr-<n>-review` already exists it is a leftover from a previous run of this same review: `kind delete cluster --name pr-<n>-review` first. The cluster outlives the review — record its name in the report and leave teardown to your human partner.

   Then pin a kubeconfig. The ambient kubectl context may be a **production cluster**, and `make install`/`deploy`/`undeploy` invoke kubectl on whatever context is ambient:

   ```sh
   kind export kubeconfig --name <cluster> --kubeconfig /tmp/kind-<cluster>.kubeconfig
   ```

   From here on, every cluster-touching command — `make` and `kubectl` alike — runs with `KUBECONFIG=/tmp/kind-<cluster>.kubeconfig`. Shell state does not persist between tool calls, so re-export it at the top of each block (or prefix each command); an export from an earlier block protects nothing.
5. **Build and deploy** (see Gotchas):
   ```sh
   export KUBECONFIG=/tmp/kind-<cluster>.kubeconfig  # scopes this block only
   kubectl config current-context                    # must print kind-<cluster>; anything else: stop
   make docker-build IMG=valkey-operator:pr-<n>
   kind load docker-image valkey-operator:pr-<n> --name <cluster>
   make install
   make deploy IMG=valkey-operator:pr-<n>
   kubectl -n valkey-operator-system rollout status deploy --timeout=180s
   ```
6. **Validate.** Design scenarios from the diff: exercise the changed behavior directly (apply CRs, mutate specs, watch conditions and operator logs), including at least one scenario that would fail without the change. When the code-review findings from step 3 arrive, add a scenario for any finding the cluster can confirm or refute. Capture every command and its observed output as you go — the report quotes them verbatim. When done, delete the CRs you created; keep the cluster.
7. **Report.** Write `docs/superpowers/reviews/PR-<n>.md` (branch name as filename when there is no PR). Leave it untracked — your human partner stages and commits. Sections, in order:
   1. Verdict
   2. Change summary
   3. Environment — cluster name and config, image tag, commit SHAs
   4. Validation scenarios — per scenario: purpose, commands, observed output, pass/fail
   5. Code review findings
   6. Follow-ups

## Gotchas

- `make test-e2e` chains `cleanup-test-e2e`, which deletes the kind cluster mid-review. To run e2e specs against your cluster: `KIND_CLUSTER=<cluster> go test -tags=e2e ./test/e2e/ -v -ginkgo.label-filter "<label>"`.
- Tag images with something other than `latest` — `:latest` implies `imagePullPolicy: Always`, which breaks kind-loaded images.
- `make deploy` runs `kustomize edit set image`, dirtying `config/manager/kustomization.yaml`. Snapshot its diff before deploying and restore it after.
- TLS-related changes need cert-manager in the cluster (the e2e suite installs it — see `test/e2e/e2e_suite_test.go`).
