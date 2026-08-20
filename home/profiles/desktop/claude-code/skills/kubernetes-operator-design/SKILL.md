---
name: kubernetes-operator-design
description: Use when designing Kubernetes CRDs, reviewing CRD schemas, writing controllers or reconcile loops, building Kubernetes operators, or evaluating API fields for bool/map/enum/optional/cross-namespace patterns. Use when you see fields like tlsEnabled bool, config map[string]string, backupNamespace string, ready bool, message string, or status without conditions, or CamelCase-concatenated field names.
---

# Kubernetes Operator Design

## Overview

CRDs and controllers contain well-known design traps that are cheap to avoid early and expensive to fix after the API ships. This skill encodes patterns from the Kubernetes API conventions and the "Charlie Don't" KubeCon talk series.

**Reference docs:** [API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md) · [API Changes](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api_changes.md)

**Linter:** Run [Kubernetes API Linter (KAL)](https://github.com/kubernetes-sigs/kube-api-linter) to catch common CRD mistakes automatically.

## CRD Design

### Field Naming

**No CamelCase concatenation.** When two fields share a prefix, they belong in a nested struct:

```yaml
# ❌ Bad
spec.nodeDrainGracePeriod: 30s
spec.nodeDrainTimeout: 60s

# ✅ Good
spec.nodeDrain.gracePeriod: 30s
spec.nodeDrain.timeout: 60s
```

**Sentence-building test.** Read the YAML aloud: "I want a cluster with node-drain that has a grace-period of 30s." If it sounds natural, the nesting is right. If it doesn't, rename.

**No generic terms — call these out explicitly in reviews.** `status.ready bool` and `status.message string` are the canonical bad examples: "ready" for what? which message? What happens when there are two independent failure modes? Also flag: `status.phase`, `spec.enabled`, any name that only makes sense with the surrounding type as context.

The fix for `ready`/`message` in status is always `status.conditions` using `metav1.Condition` — not renaming to something more specific, because the whole point of conditions is that you can express multiple orthogonal states with history and reason codes. See the [Status section](#status) below.

**No abbreviations or synonyms.** Define a glossary of project terms and use them consistently. Changing a field name is a breaking change.

**Use `int32`/`int64` for integers.** Never unsigned, never `float` in spec fields.

### Status

- Always add a `status` subresource unless the object is input-only (e.g. a `Secret`-like config) or intent/result live in separate objects (e.g. `PVC`/`PV`).
- **Declare the status subresource** in the CRD version spec or `r.Status().Update()` / `r.Status().Patch()` will silently fall back to updating the whole object:
  ```yaml
  versions:
  - name: v1alpha1
    subresources:
      status: {}
  ```
- `status` MUST have a `conditions` stanza using `metav1.Condition` (type, status, reason, message, lastTransitionTime). This is the fix for `ready bool` and `message string` — not just better naming, but a richer model that supports multiple orthogonal failure modes, history, and reason codes.
- **Condition names use adjectives or past-tense verbs** ("Ready", "Succeeded", "Degraded") — not present-tense verbs ("Reconciling"). Report conditions early, even with `status: Unknown`, rather than omitting them until outcome is known.
- Add `observedGeneration` both at the top of `status` AND inside each Condition item. Without it, tooling cannot tell if status reflects the current spec.
- Conditions are a `listType=map` keyed on `type` — effectively a map, so controllers can merge individual conditions without overwriting others.

### Fields: Optional vs Required

- Mark fields `+optional` by default. Only mark `+required` when absence is genuinely invalid.
- Provide `+kubebuilder:default=` where a sensible default exists.
- **Defaults are not persisted to storage.** If you retrieve and re-save an object, the default gets written in. If you change the default later, previously-saved objects keep the old value — new objects see the new default. Plan for this.
- For optional structs, use a pointer (`*MyStruct`) so the zero value (nil) is distinguishable from an explicitly-set empty struct.

### No Bool Fields

Never use `bool` for spec fields. You'll need a third state eventually and then you get `tlsEnabled`, `tlsEnabledStrict`, `tlsEnabledFips`...

Use a string enum instead:

```go
// +kubebuilder:validation:Enum=Disabled;Enabled;Enforced
// TLSMode controls TLS behaviour. Values may be added in future versions;
// clients MUST handle unknown values gracefully.
type TLSMode string
const (
    TLSDisabled TLSMode = "Disabled"
    TLSEnabled  TLSMode = "Enabled"
    TLSEnforced TLSMode = "Enforced"
)
```

**For extensibility:**
1. The docstring MUST say "Values may be added; clients must handle unknown values."
2. All switch statements on the enum MUST have a `default:` case.

Without both, adding an enum value is a breaking change.

### No Freeform Maps

`map[string]string` is only acceptable for annotations and labels. Anywhere else it causes:
- Keys are values disguised as field names (breaks structural schema)
- GitOps conflicts when two actors manage different keys
- No validation

Use `+listType=map` with an explicit struct instead:

```yaml
# Instead of config: map[string]string
config:
  type: array
  x-kubernetes-list-type: map
  x-kubernetes-list-map-keys: [name]
  items:
    type: object
    required: [name, value]
    properties:
      name: {type: string}
      value: {type: string}
```

### Cross-Namespace References

Never allow a field like `backupNamespace: other-namespace`. This lets one namespace affect another without consent — a security boundary violation.

**Required pattern: bidirectional handshake**
- The referrer specifies the target.
- The target namespace owner must explicitly permit inbound access (Gateway API uses `ReferenceGrant` for this).
- If neither side has agreed, the controller must reject or ignore the reference.

### Go Struct Design

**Don't embed external API structs.** If your CRD embeds e.g. `kubeadm.InitConfiguration`, you inherit all of kubeadm's versioning lifecycle — changes in their API can break yours. Copy, adapt, and evolve your own struct; map to the external type internally.

**Don't share structs across different Kinds.** `DatabaseCluster` and `DatabaseClusterTemplate` may look identical today, but adding a runtime-specific field to `DatabaseCluster` will pollute the template's schema. Maintain separate structs. *"A little duplication is better than a deep dependency."*

Safe to reuse: `metav1.TypeMeta`, `metav1.ObjectMeta`, `metav1.Condition`, `metav1.Time` — these are explicitly designed for reuse.

## Controller Patterns

### Use a Framework

Do not build a raw caching client with Informers. Handling concurrency, ordering, and eventual consistency is hard to get right.

Use a framework that handles watch, cache, coalescing, and ordering for you:
- **controller-runtime** (most common, kubebuilder default)
- **krt** (Istio/Envoy Gateway)
- **StateDB** (Cilium)

For operator HA, use controller-runtime's built-in **leader election**.

### Patch, Not Update

Always use `Patch` instead of `Update`, especially for status. `Update` sends the whole object and races with concurrent writers. `Patch` sends only the delta.

```go
patch := client.MergeFrom(cluster.DeepCopy())
cluster.Status.ObservedGeneration = cluster.Generation
cluster.Status.Phase = "Ready"
if err := r.Status().Patch(ctx, &cluster, patch); err != nil {
    return ctrl.Result{}, err
}
```

### Minimise API Server Calls

- Don't send no-op updates. Compare before writing.
- Don't write status in the middle of reconcile and again at the end — write once at the end.
- Every unnecessary `Update` blocks the API server doing useful work.

### controller-runtime Predicate Footgun

`For(resource, WithPredicates(...))` predicates apply **only** to that resource. They do NOT apply to resources added with `Watches(...)`. Each `Watches()` call needs its own predicate:

```go
// ❌ Wrong: predicate on For() does not apply to Watches()
ctrl.NewControllerManagedBy(mgr).
    For(&myv1.Foo{}, builder.WithPredicates(myPredicate)).
    Watches(&corev1.ConfigMap{}, handler.EnqueueRequestForOwner(...)).
    Complete(r)

// ✅ Correct: predicate on each Watch
ctrl.NewControllerManagedBy(mgr).
    For(&myv1.Foo{}, builder.WithPredicates(myPredicate)).
    Watches(&corev1.ConfigMap{}, handler.EnqueueRequestForOwner(...),
        builder.WithPredicates(myOtherPredicate)).
    Complete(r)
```

## API Versioning

**Breaking changes require a version bump.** These are breaking:
- Removing or renaming a field
- Making a mutable field immutable
- Tightening validation (e.g. reducing max length)
- Adding a required field without a default
- Making an optional field required

**Compatible (no bump needed):** add `+optional` fields with defaults, loosen validation, add enum values (if extensibility was declared).

**Deprecation policy:** `v1beta1` fields must be deprecated for at least 3 releases (≈1 year) before removal. Removal still requires a version bump.

If versions are incompatible, you need a conversion webhook.

## Architecture: Modular Controllers

Avoid monolithic controllers that reconcile a large CRD doing many things. Instead:

- **Coordinator controller**: watches the primary CRD, delegates to microcontrollers.
- **Microcontrollers**: each owns one concern (networking, storage, backup). Clear ownership, independently testable.
- **Decouple CRD translation from controller logic**: the controller should translate spec → desired state; a separate layer applies it. Helm's values-to-manifests pattern is a good mental model.

Automate where risks can be mitigated (minor upgrades, config changes). Orchestrate where they can't (major version upgrades). Use `status`, `conditions`, and events to give operators visibility.

**Testing:** [kuttl](https://github.com/kudobuilder/kuttl) for operator E2E tests; controller-runtime has a built-in test framework for unit testing reconcilers.

## Quick Reference Checklist

| Check | What to look for |
|---|---|
| Field naming | No CamelCase concat; nested structs; sentence-building test; no generic terms |
| Generic status fields | Flag `ready bool`, `message string` — these are context-free; replace with `status.conditions` |
| status subresource | `subresources: status: {}` declared in version spec |
| status.conditions | `metav1.Condition` with type/status/reason/message/lastTransitionTime/observedGeneration |
| Condition names | Adjectives/past-tense ("Ready", "Succeeded"); report Unknown early |
| observedGeneration | Present on status root AND each Condition; set in controller |
| Bool fields | Replace with string enum + extensibility docstring + default switch case |
| map[string]string | Only for labels/annotations; use listType=map struct array elsewhere |
| Cross-namespace refs | Require bidirectional handshake (ReferenceGrant pattern) |
| Required vs optional | Default to optional; use +kubebuilder:default |
| Default persistence | Defaults not stored until object round-trips through API server |
| Go struct embedding | Don't embed external API structs; copy and adapt instead |
| Shared structs | Don't share structs across Kinds unless designed for reuse |
| Int types | int32 or int64; no unsigned; no float in spec |
| Controller client | Use framework (controller-runtime/krt/StateDB), never raw Informers |
| Status updates | Use Patch not Update; write once at end; set observedGeneration |
| No-op updates | Check before writing; don't write unchanged status |
| Predicate scope | For() predicates don't apply to Watches() |
| Breaking changes | Version bump required; deprecation = 3 releases minimum |
| Linting | Run KAL (Kubernetes API Linter) |
