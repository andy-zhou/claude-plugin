---
persona: principal-engineer
date: 2026-02-08
artifact: docs/plans/2026-02-07-kani-tech-spec.md
scope: Architecture and design review covering system design, API contracts, data models, abstractions, complexity, and extensibility
sign-off: conditional-approve
confidence: high
---

## Summary

This review examines the Kani v4 technical specification from the perspective of system architecture, API design, data modeling, abstraction quality, and complexity management. The spec describes a multi-tenant platform providing persistent AI coding agent environments as a service, built on Kubernetes, Temporal, Postgres, Redis, and EFS. The headline finding is that this is a well-structured specification with sound architectural decisions -- particularly the hot-path/cold-path message routing split, the filesystem-as-source-of-truth invariant, and the use of Temporal for durable lifecycle management -- but it carries meaningful risks in its dual-source-of-truth pattern between Temporal and Postgres, an under-specified data model for multi-entity consistency, and several API design decisions that will create friction as the system evolves.

## Analysis

### Architecture: Hot Path / Cold Path Split

The decision to route messages directly to running pods (fast path) while using Temporal only for lifecycle transitions (cold path) is the single most important architectural choice in the spec and it is the right one. Temporal's value is in durable state machines, not low-latency message delivery. Keeping Temporal off the hot path means message delivery latency is bounded by a single HTTP hop from management server to kani-agent, not by Temporal's scheduling and persistence overhead.

The fallback mechanism -- direct POST failure triggers a Temporal signal -- is well-designed. It handles the stale cache case gracefully and relies on kani-agent's message-ID-based deduplication to prevent double delivery. This is a textbook approach to optimistic routing with pessimistic fallback.

The FIFO ordering invariant enforcement is subtle but correct: the Postgres status cache stays at `starting` until queue drain completes, so new messages cannot bypass queued messages via the fast path. This is worth calling out because it is the kind of invariant that is easy to break during future refactoring if the rationale is not well-understood.

### Architecture: Dual Source of Truth (Temporal + Postgres)

The spec explicitly states that Temporal is the source of truth for lifecycle state and Postgres holds a "read-optimized projection." This is a common and sometimes necessary pattern, but it introduces a category of bugs that the spec does not fully address.

**The problem:** There is a window between a Temporal state transition and the completion of the `UpdateInstanceStatus` activity where Postgres is stale. The spec acknowledges this for the fast-path fallback case but does not address it comprehensively. For example:

- A client calls `GET /instances/:id` immediately after a pod crash. Temporal knows the instance is idle; Postgres still says running. The client sees stale state.
- The reconciliation loop runs every 30 seconds and detects Postgres-Temporal drift. That is a 30-second window of stale reads, which is significant for a system with sub-second message delivery targets.
- `UpdateInstanceStatus` has unlimited retries, which is correct, but if Postgres is slow or the activity worker is backlogged, the staleness window grows unbounded.

This is not a fatal flaw -- it is an inherent tradeoff of the architecture -- but the spec should make the consistency model explicit. Clients need to understand that instance status from the REST API is eventually consistent with the actual lifecycle state, and the spec should document the expected staleness bound.

### Architecture: Reconciliation Loop Concerns

The reconciliation loop is positioned as a background safety net, which is appropriate. However, it concentrates four distinct responsibilities (zombie pods, cache drift, Redis cleanup, storage usage) into a single 30-second loop running on a single leader-elected replica. This creates several concerns:

1. **Blast radius.** If the storage usage check takes longer than expected (e.g., many filesystems, slow EFS `du` calls), it delays zombie pod detection and cache drift correction. These responsibilities have different latency requirements and should not block each other.
2. **Leader election scope.** All four responsibilities share a single leader election. If one needs to run more frequently (cache drift correction) or less frequently (storage usage refresh, which already has a separate "every 5 minutes" mention for quota enforcement), they are locked to the same 30-second cadence.
3. **Observability.** The spec includes a `kani_reconciliation_actions_total` metric but no metric for reconciliation loop duration. If the loop starts taking 25 seconds, there is a 5-second gap before the next run -- but no alert will fire.

### Data Model: Tenant-Scoped Denormalization

The denormalization of `tenant_id` on the `messages` table (explicitly noted: "Denormalized from Instance for RLS enforcement without joins") is a sound decision for the RLS enforcement pattern. However, the spec applies RLS inconsistently across the data model:

- The `messages` table denormalizes `tenant_id` for RLS.
- The `credentials` table has `tenant_id` directly (FK to Tenant).
- The `filesystems` table has `tenant_id` directly.
- The `instances` table has `tenant_id` directly.

This is consistent so far. But the `pod_tokens` table (described in Security section) has `instance_id` and `pod_name` but no explicit `tenant_id`. If RLS is intended to be enforced at the database level for all tenant-scoped data, `pod_tokens` needs `tenant_id` and an RLS policy. Otherwise, the management server must bypass RLS or join through `instances` to validate tenant ownership, which undermines the defense-in-depth argument.

### Data Model: The `config` JSON Blob on Tenant

The `tenant.config` column is typed as JSON with defaults described as "grace period, resource limits, rate limits." This is a flexible schema but the spec does not define the schema for this JSON blob anywhere in this document. It references `docs/plans/kani-api-spec.md` for details, but from a data modeling perspective, this matters because:

1. **Migration path.** JSON blobs in Postgres are easy to add fields to but hard to remove fields from or add constraints to. If `config` grows to include security-sensitive settings (rate limits, resource quotas), those settings need validation that a JSON blob does not naturally provide.
2. **Querying.** If the system needs to query tenants by config values (e.g., "find all tenants with grace period > 600s"), JSON queries in Postgres are possible but increasingly awkward as the schema grows.
3. **Defaults resolution.** The spec describes a hierarchy (system defaults -> tenant config -> instance config) but does not specify where defaults are resolved. Is it at write time (denormalized into the row) or read time (merged at query time)? This affects API behavior and cache invalidation.

### Data Model: Instance Status as Cache

The spec calls instance status in Postgres a "read-optimized projection" of Temporal workflow state. This is accurate but the data model does not make this relationship explicit. The `status` field on `instances` looks like any other column. A new engineer reading the schema would not know that this field is updated asynchronously by a Temporal activity and may be stale.

Consider: if someone writes a query that filters instances by status to make a decision (e.g., "count running instances to check against `max_instances`"), they may get incorrect results during the staleness window. The spec should identify which fields on the `instances` table are authoritative (set by the API at creation/update time) and which are projections (set asynchronously by Temporal). Candidates for projection: `status`, `pod_name`, `pod_incarnation`, `last_status_change`, `consecutive_failures`.

### API Design: Resource Naming and URL Structure

The API design is generally clean and RESTful but has several inconsistencies:

1. **Tenant endpoints.** `GET /tenant` and `PATCH /tenant` are singular (the authenticated tenant), but `POST /admin/tenants` is plural. This is a common pattern (singular for "self" routes, plural for collection routes) and is acceptable, but the auth endpoint `POST /auth/sse-token` omits the `/v1/` prefix in the spec text while all other tenant endpoints include it. This may be a documentation error but should be clarified.

2. **Credential rotation.** `PUT /credentials/:id` is described as "Rotate credential value." PUT semantics traditionally mean full replacement. If the intent is to replace only the secret value (not the name or type), PATCH or a sub-resource (`POST /credentials/:id/rotate`) would be more precise. The `?emergency=true` query parameter on a PUT is also unusual -- it controls side effects (pod restart behavior) rather than the representation of the resource.

3. **Instance stop/restart.** `POST /instances/:id/stop` and `POST /instances/:id/restart` use action sub-resources, which is appropriate for RPC-style operations. But `POST /instances/:id/stop` with `?force=true` silently changes the operation from "graceful stop" to "immediate kill." This should be documented as a distinct behavior, not a query parameter modifier.

4. **Filesystem file access.** `GET /filesystems/:id/files` (directory listing) and `GET /filesystems/:id/files/*path` (file read) overload the same path prefix with different semantics based on whether a sub-path is present. This works but may confuse client SDK authors. A more explicit split (`/filesystems/:id/tree` for listing, `/filesystems/:id/files/*path` for content) would reduce ambiguity.

### API Design: Idempotency Model

The idempotency key implementation for `POST /messages` is well-specified (24-hour retention, returns existing message ID on duplicate). However, there are gaps:

1. **Scope.** The idempotency key is described as per-instance. If a client sends the same key to two different instances, both should succeed. This should be explicitly stated.
2. **Other POST endpoints.** `POST /instances`, `POST /filesystems`, `POST /credentials` do not mention idempotency keys. Filesystem and tenant provisioning are asynchronous -- if a client retries a `POST /filesystems` due to a network timeout, they may create two filesystems. This is a common source of production issues.
3. **Concurrent duplicate requests.** If two requests with the same idempotency key arrive simultaneously, the spec does not describe the expected behavior. The typical answer is "one wins, the other blocks until the first completes then returns the same result," but this requires a locking mechanism (e.g., Postgres advisory lock on the idempotency key hash).

### API Design: Error Contract Gaps

The standard error response format is good (`code`, `message`, `details`), and the error reason codes table for streaming events is thorough. However:

1. **HTTP error codes for REST endpoints.** The spec defines SSE error reason codes but does not enumerate the error codes returned by REST endpoints. For example, what `code` is returned when `POST /instances` references a non-existent `filesystem_id`? Is it `RESOURCE_NOT_FOUND` (the filesystem) or `INVALID_REQUEST` (the request body)? This matters for client error handling.
2. **Rate limit error differentiation.** The spec says 429 is returned for both per-tenant rate limits and per-IP brute-force limits. Clients need to differentiate these (one is "slow down," the other is "your IP is blocked"). The `error.code` field should distinguish them.
3. **Partial failure on `PUT /credentials/:id`.** Credential rotation updates the K8s Secret and then restarts affected pods (rate-limited to 5 concurrent). If the K8s Secret update succeeds but pod restarts partially fail, what is the API response? 200 (credential rotated) or an error? The spec is silent.

### Abstraction Quality: Agent Plugin Interface

The `AgentPlugin` interface is well-designed for v1. It captures the essential operations (start, send, parse, shutdown) without leaking Kubernetes-specific details into the plugin. The `credPaths` map approach (passing file paths, not values) is a good abstraction boundary that supports both the current file-mount model and the future credential proxy model.

However, the `ParseOutput` method takes a `chan<- AgentEvent` and presumably runs as a goroutine reading stdout. The interface does not specify:

1. **Error handling.** What happens when `ParseOutput` encounters unparseable output? Does it emit an `AgentEvent` with `Type: Error`, or does it return an error and stop parsing?
2. **Lifecycle.** When `Shutdown` is called, does `ParseOutput` need to be explicitly canceled (via context), or does it return when the process exits?
3. **Backpressure.** If the events channel is full (downstream is slow), does `ParseOutput` block, drop events, or buffer internally?

These are the kinds of questions that will be answered ad-hoc during implementation and then become implicit contracts. Documenting them now saves significant debugging later.

### Abstraction Quality: Filesystem Provider Interface

The `FilesystemProvider` interface is clean and minimal. `MountSpec` returning Kubernetes-native types (`corev1.Volume`, `corev1.VolumeMount`) is pragmatic for v1 but couples the provider abstraction to Kubernetes. If a future deployment target is not Kubernetes (unlikely but possible), this interface would need to change.

More practically, the `MountSpec` method signature does not accept any pod-specific context. If a future provider needs to generate mount options based on the tenant's security tier or the instance's resource limits, the interface will need to change. Adding a `MountSpecOptions` struct parameter now (even if it is empty in v1) would be more extensible.

### Complexity: Temporal Workflow Versioning

The spec correctly identifies workflow versioning as a critical concern and prescribes `GetVersion` branching from day one. This is the right strategy for long-running workflows. However, the spec underestimates the operational complexity:

1. **Version branch proliferation.** Every workflow logic change adds a `GetVersion` branch. Over time, the workflow code accumulates dead branches that can only be removed when all instances created before that version have been deleted. For a system where instances may live for months, this means years of accumulated version branches.
2. **Testing.** Each version branch combination needs testing. If there are 5 version points, there are potentially 2^5 = 32 combinations. The spec does not mention a testing strategy for versioned workflows.
3. **No migration path.** The spec says old branches can be removed when all workflows on that version complete. But it provides no mechanism to identify which version each workflow is running. Adding a `workflow_version` field to the `instances` table (updated by the workflow) would make this tractable.

### Complexity: Grace Period Timer Reset

The grace period mechanism involves the management server signaling the Temporal workflow to reset the timer on every message delivery to a running instance. For an active session with many messages, this generates a high volume of Temporal signals -- one per message. Temporal handles signals well, but each signal is persisted in the workflow history. Over a long session with hundreds of messages, the workflow history grows, which increases replay time if the worker crashes and needs to reconstruct workflow state.

The spec does not mention Temporal's `ContinueAsNew` pattern, which is the standard solution for long-running workflows with growing history. Without it, a workflow that has processed thousands of messages (over an instance's lifetime of potentially months) could have a history large enough to cause replay timeouts.

### Complexity: Storage Quota Enforcement

The storage quota enforcement mechanism is a multi-layer system with concerning gaps:

1. The reconciliation loop polls storage usage and updates `storage_used_gb` -- but this runs every 30 seconds while the quota enforcement background job runs every 5 minutes.
2. `CreatePod` checks usage against quota before pod creation. But between the check and the pod actually running, other pods on the same filesystem could write data.
3. At 100% quota, pods can still start (warning only). At 110%, pods are stopped. This means an agent can write 10% more than the quota before anything happens, and the enforcement has a 5-minute detection delay.

This is acceptable for v1 but the 110% hard limit needs to account for the detection delay. An agent could write significantly more than 10% over quota in 5 minutes. The spec should clarify whether the 110% check is based on the last measurement (potentially 5 minutes old) or a real-time check.

### Naming and Developer Experience

The spec generally uses clear, consistent naming. A few observations:

1. **`pod_incarnation`** is a creative name but may confuse engineers unfamiliar with the metaphor. "pod_generation" or "pod_sequence" would be more immediately understandable.
2. **`init_completed`** as a boolean on the instances table conflates two meanings: "init has ever run successfully" and "init does not need to run." Resetting it to `false` on `init_commands` update is clever but non-obvious. A tri-state (`pending`, `completed`, `not_applicable`) or separate `init_commands_hash` (to detect when commands change) would be more explicit.
3. **`restart_after_destroy`** flag in the stopping flow is a side-channel communication mechanism between the message handler and the lifecycle state machine. It works but is the kind of implicit state that causes confusion in debugging. The spec documents it well, which helps.

### Technology Choices: Redis for Both Rate Limiting and Streaming

Redis serves two distinct roles: output streaming (Redis Streams) and rate limiting (sorted sets). These have different failure characteristics and different scaling profiles. The spec uses a single Redis deployment for both. If Redis is unavailable:

- Output streaming degrades gracefully (kani-agent buffers locally).
- Rate limiting silently fails open or closed (the spec does not specify). Failing open means no rate limits during a Redis outage; failing closed means all requests are rejected.

The spec should document the rate limit behavior during Redis unavailability. For a multi-tenant system, failing open during a Redis outage could allow a single tenant to overwhelm the system.

### State Machine Completeness

The instance state machine is well-defined with clear transitions. However, there are edge cases in the state diagram that are not fully addressed:

1. **`starting` -> `deleting`.** What happens to queued messages when an instance is deleted while starting? The spec says DELETE transitions any state to `deleting`, but it does not specify whether queued messages are drained, discarded, or marked as failed.
2. **`stopping` -> `stopping` (multiple stop requests).** If a client sends `POST /stop` while the instance is already stopping, the spec says nothing. Is it idempotent (returns 202, no-op) or an error?
3. **Concurrent PATCH and message delivery.** If `PATCH /instances/:id` changes `agent_config` (which kills the running pod), and a message is delivered to the pod between the PATCH and the pod kill, the message may be lost. The spec's deduplication is by `message_id` on the kani-agent side, but if the pod is killed, that deduplication state is lost.

## Assumptions

- The companion API specification (`docs/plans/kani-api-spec.md`) covers the detailed request/response schemas, `agent_config` fields, and `tenant.config` structure mentioned but not included in this document. This review does not have access to that document.
- The ADRs referenced (001-008) contain additional rationale that may address some of the concerns raised here. This review is based solely on the tech spec.
- Temporal Cloud pricing is compatible with the signal volume implied by the architecture (one signal per message to reset grace period timers). This was flagged in the deployment section but not analyzed.
- The management server is implemented in Go and uses pgx for Postgres connection pooling, as implied by the deployment section.
- "Row-Level Security" on the `pod_tokens` table is not mentioned; it is assumed this is an oversight rather than an intentional design decision.
- The `kani-agent` output endpoint on the management server (where kani-agent POSTs output) is a separate internal endpoint not exposed in the public API surface. Its authentication mechanism is the pod auth token.

## Recommendations

### P0 -- Must fix before proceeding

1. **Document the consistency model for instance status.** The dual-source-of-truth pattern between Temporal and Postgres is a core architectural decision. The spec must explicitly document: (a) which fields on the `instances` table are authoritative vs. projections, (b) the expected staleness bound for projected fields, and (c) the client-facing implication (reads are eventually consistent). Without this, engineers will write code that assumes Postgres status is authoritative and introduce subtle bugs.

2. **Add `ContinueAsNew` strategy for long-running instance workflows.** Temporal workflows accumulate event history. An instance that lives for months with thousands of messages will have a massive history that causes replay timeouts. The spec must define when and how the workflow calls `ContinueAsNew` to reset its history while preserving state. This is not a future optimization -- it is a correctness requirement for long-lived workflows.

3. **Specify rate limit behavior during Redis unavailability.** The spec describes Redis as the rate limiting backend but does not specify behavior when Redis is down. For a multi-tenant system, this is a critical decision: fail open (no rate limits, risk of one tenant overwhelming the system), fail closed (all requests rejected), or degrade to in-memory per-replica limits. This must be decided before implementation.

### P1 -- Should fix before production

1. **Add idempotency keys to `POST /filesystems` and `POST /credentials`.** These are state-creating endpoints. Network retries on creation requests without idempotency protection will create duplicate resources. At minimum, support an `Idempotency-Key` header with the same semantics as `POST /messages`.

2. **Separate reconciliation loop responsibilities.** The four responsibilities (zombie pods, cache drift, Redis cleanup, storage usage) should run as independent loops or at least independent goroutines with independent cadences. Cache drift correction should run more frequently (every 5-10 seconds); storage usage refresh is already specified at every 5 minutes. Coupling them to a single 30-second loop creates unnecessary blast radius.

3. **Add `tenant_id` and RLS policy to `pod_tokens` table.** The current design requires joining through `instances` to enforce tenant isolation on pod token validation. This undermines the defense-in-depth RLS pattern used everywhere else. Adding `tenant_id` directly (denormalized, as with `messages`) keeps the pattern consistent.

4. **Define concurrent duplicate idempotency key behavior.** When two requests with the same idempotency key arrive simultaneously for `POST /messages`, specify the expected behavior (one wins, other blocks and returns same result). This likely requires a Postgres advisory lock or a unique constraint with conflict handling.

5. **Add `workflow_version` tracking to instances.** Without a queryable field indicating which workflow version each instance is running, operators cannot determine when it is safe to remove old `GetVersion` branches. Add a `workflow_version` field to `instances`, updated by the workflow at startup or on `ContinueAsNew`.

6. **Clarify state transitions for edge cases.** Document behavior for: (a) DELETE while in `starting` state (what happens to queued messages), (b) duplicate `POST /stop` while already stopping, (c) concurrent PATCH and message delivery to a running instance. These will be discovered in testing if not addressed in design.

### P2 -- Consider improving

1. **Use `POST /credentials/:id/rotate` instead of `PUT /credentials/:id`.** The current PUT overload mixes resource replacement semantics with side-effect control (`?emergency=true`). A dedicated rotation endpoint is more explicit and avoids surprising behavior on what looks like a standard PUT.

2. **Add `MountSpecOptions` parameter to `FilesystemProvider.MountSpec`.** Even if empty in v1, this allows the interface to evolve without breaking changes when pod-specific or tenant-specific mount context is needed.

3. **Document `AgentPlugin.ParseOutput` contract.** Specify error handling (emit error event vs. return error), lifecycle (context cancellation vs. process exit), and backpressure (block vs. drop vs. buffer). These implicit contracts will be discovered painfully during implementation.

4. **Consider renaming `pod_incarnation` to `pod_generation`.** The current name is evocative but not immediately clear to all engineers. "Generation" is a well-established Kubernetes concept and would align with the platform's vocabulary.

5. **Add reconciliation loop duration metric and alert.** The loop runs every 30 seconds. If it takes more than 25 seconds, the effective interval degrades. A histogram metric on loop duration with an alert at >20 seconds would catch this before it becomes a problem.

6. **Specify storage quota enforcement real-time check option.** The current 5-minute polling window means agents can significantly exceed the 110% hard limit. Consider a synchronous usage check in `CreatePod` (in addition to the cached value) as a defense-in-depth measure, or document the expected over-quota write volume as an accepted risk.

7. **Extract `tenant.config` into a typed schema in this spec.** Even though the companion API spec covers request/response schemas, the data model section of this spec should define the structure of the `config` JSON blob, the default resolution strategy (write-time vs. read-time), and the validation rules. This is a core data model concern, not just an API concern.

## Sign-Off

**conditional-approve** -- The architecture is sound and the spec is unusually thorough for a v4 draft, with well-reasoned tradeoffs and clear ADR references. The conditional approval is based on the three P0 items: the consistency model must be documented before engineers can safely build against the dual-source-of-truth pattern, the `ContinueAsNew` strategy must be defined to prevent Temporal history growth from becoming a production incident, and the rate limit failover behavior must be specified to prevent a multi-tenant safety gap.
