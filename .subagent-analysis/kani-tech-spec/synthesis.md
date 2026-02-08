---
topic: kani-tech-spec
date: 2026-02-08
personas: [security-engineer, principal-engineer, reliability-engineer]
overall-status: conditional-approve
---

## Overall Status

All three personas issued **conditional-approve** with high confidence. The Kani v4 technical specification demonstrates strong engineering across security (defense-in-depth isolation), architecture (hot-path/cold-path split, Temporal lifecycle management), and reliability (degraded mode coverage, SLO definitions). The conditional approvals are driven by addressable gaps rather than fundamental design flaws. The specification is ready for implementation once the P0 items below are resolved.

## Consensus

All three personas agree on the following:

- The hot-path / cold-path message routing split is a sound architectural decision that enables both low latency and graceful degradation.
- The defense-in-depth isolation model (gVisor + RLS + NetworkPolicy + namespace isolation + EFS Access Points) is strong.
- The `init_commands` feature needs clearer specification of its execution mechanism and security boundary.
- The dual-source-of-truth pattern (Temporal + Postgres) requires explicit documentation of the consistency model and staleness bounds.
- The specification is unusually thorough for a pre-implementation document.
- The deployment strategy (rollout, rollback, migration) is the weakest area of the spec.

## Conflicts

### NetworkPolicy egress enforcement mechanism

- **Topic**: How port 443 egress is enforced — whether DNS filtering alone is sufficient or IP-level NetworkPolicy rules are needed.
- **Positions**: Security-engineer flags this as a P0 concern (direct IP connections could bypass DNS filtering if port 443 is open to 0.0.0.0/0). Principal-engineer and reliability-engineer do not address this specific concern.
- **Resolution**: security-engineer has domain authority over network isolation and egress controls.
- **Rationale**: This falls squarely within the security-engineer's scope (tenant/process/network isolation boundaries).

### Reconciliation loop design

- **Topic**: Whether the reconciliation loop's four responsibilities should be separated.
- **Positions**: Principal-engineer recommends separating the loop into independent goroutines with independent cadences (P1). Reliability-engineer notes the loop's scaling concerns but frames it as a monitoring gap rather than an architectural issue.
- **Resolution**: principal-engineer has domain authority over component boundaries and abstraction design.
- **Rationale**: The decision about how to decompose responsibilities within a component is an architecture concern.

### Init commands execution via kubectl exec

- **Topic**: Whether init commands should run via `kubectl exec` or via kani-agent.
- **Positions**: Security-engineer focuses on the RBAC implications (`pods/exec` permission in tenant namespaces) and command injection surface. Principal-engineer recommends executing via kani-agent to avoid the Kubernetes API dependency on the critical path. Both flag it as needing attention but with different framing.
- **Resolution**: Escalate — this is both a security concern (RBAC blast radius) and an architecture concern (critical path dependency). Both perspectives are valid.
- **Rationale**: This crosses security and architecture domains and requires human judgment on the tradeoff between operational simplicity (kani-agent execution) and security isolation (keeping kubectl exec with controlled RBAC).

### Temporal workflow decomposition

- **Topic**: Whether the instance lifecycle workflow should be decomposed into parent + child workflows.
- **Positions**: Principal-engineer recommends decomposition (P1) to reduce versioning blast radius. Reliability-engineer does not address workflow structure directly but flags deployment rollback complexity with `GetVersion`.
- **Resolution**: principal-engineer has domain authority over abstraction and complexity management.
- **Rationale**: Workflow decomposition is an architecture and abstraction decision.

## Consolidated Recommendations

### P0

1. **Clarify NetworkPolicy egress implementation for port 443** — Document whether FQDN-based rules (Cilium), broad 0.0.0.0/0 with DNS-only enforcement, or dynamically-maintained IP CIDRs are used. (security-engineer)
2. **Document admin API authentication and key management** — Specify storage, rotation, revocation, MFA, and IP-allowlisting for admin keys. (security-engineer)
3. **Specify init_commands execution mechanism and security boundary** — Document shell vs. direct exec, timeouts, and RBAC implications. (security-engineer, principal-engineer)
4. **Document the consistency model for Temporal-Postgres dual source of truth** — Identify authoritative vs. projected fields, staleness bounds, and client-facing implications. (principal-engineer)
5. **Add ContinueAsNew strategy for long-running Temporal workflows** — Prevent workflow history growth from causing replay timeouts. (principal-engineer)
6. **Specify rate limit behavior during Redis unavailability** — Decide: fail open, fail closed, or degrade to in-memory per-replica limits. (principal-engineer, reliability-engineer)
7. **Define deployment rollout and rollback strategy** — Cover management server, Temporal workers, kani-agent images, and database migrations with rollback procedures. (reliability-engineer)
8. **Add error budget burn rate alerting** — Supplement instantaneous rate alerts with multi-window burn rate alerts. (reliability-engineer)

### P1

1. **Implement mTLS for management server to kani-agent communication** (security-engineer)
2. **Document SSE token implementation details** — JWT vs opaque, storage, validation, availability impact. (security-engineer)
3. **Add Redis at-rest encryption requirement** (security-engineer)
4. **Require SBOM generation in CI/CD** (security-engineer)
5. **Document admin API RLS bypass model** (security-engineer)
6. **Add credential expiration or rotation reminders** (security-engineer)
7. **Document bootstrap credential management** — How management server authenticates to Postgres, Redis, Temporal, K8s API. (security-engineer)
8. **Harden CoreDNS ConfigMap update path** (security-engineer)
9. **Decompose instance lifecycle Temporal workflow** — Parent + child workflows to reduce versioning blast radius. (principal-engineer)
10. **Add idempotency keys to POST /filesystems and POST /credentials** (principal-engineer)
11. **Add explicit side-effect indicators to PATCH /instances responses** (principal-engineer)
12. **Define forward-compatibility contract for API clients** (principal-engineer)
13. **Add tenant_id and RLS policy to pod_tokens table** (principal-engineer)
14. **Add EFS performance benchmarks** (principal-engineer)
15. **Add cold-start SLO** (reliability-engineer)
16. **Specify database migration strategy** (reliability-engineer)
17. **Add Postgres connection pool capacity planning** (reliability-engineer)
18. **Address Temporal-down-plus-pod-crash scenario** (reliability-engineer)
19. **Add per-tenant circuit breaker at Temporal level** (reliability-engineer)
20. **Quantify kani-agent output buffer behavior** (reliability-engineer)
21. **Define operational dashboard requirements** (reliability-engineer)

### P2

1. **Add insider threat to the threat model** (security-engineer)
2. **Define base image rebuild cadence** (security-engineer)
3. **Add audit log integrity verification** (security-engineer)
4. **Add Redis key prefixing defense-in-depth** (security-engineer)
5. **Document reconciliation loop idempotency** (security-engineer)
6. **Use POST /credentials/:id/rotate instead of PUT** (principal-engineer)
7. **Add MountSpecOptions parameter to FilesystemProvider.MountSpec** (principal-engineer)
8. **Document AgentPlugin.ParseOutput contract** (principal-engineer)
9. **Consider renaming pod_incarnation to pod_generation** (principal-engineer)
10. **Add reconciliation loop duration metric** (principal-engineer)
11. **Add streaming output delivery SLO** (reliability-engineer)
12. **Consider API key hash cache for Postgres outage resilience** (reliability-engineer)
13. **Add EFS latency metrics and alerting** (reliability-engineer)
14. **Specify log aggregation infrastructure** (reliability-engineer)
15. **Add Temporal workflow execution latency metric** (reliability-engineer)
16. **Consider load shedding and priority queuing** (reliability-engineer)

## Open Questions

1. **Init commands: kubectl exec vs kani-agent execution** — The security-engineer and principal-engineer both flag this but from different angles (RBAC blast radius vs critical path dependency). This is a security-vs-architecture tradeoff that requires human input on the acceptable risk profile.
2. **Complexity vs security: credential proxy scope in v1.1** — The security-engineer notes that the v1.1 credential proxy only proxies AI provider calls, meaning exfiltration via legitimate egress domains remains possible. Determining whether the proxy should also inspect/restrict request bodies is a product decision.

## Next Steps

1. **Resolve all P0 items** — These must be addressed before implementation begins. They represent ambiguities or gaps that would cause divergent implementations or production incidents.
2. **Prioritize P1 items into pre-production milestones** — Group by theme (deployment, auth, observability) and assign to implementation sprints.
3. **Make a decision on init_commands execution model** — Convene security and architecture leads to resolve the kubectl exec vs kani-agent tradeoff.
4. **Update the spec** — Incorporate resolutions into a v5 of the tech spec.
5. **Begin implementation** — The architecture is fundamentally sound. P0 items are specification gaps, not design flaws.
