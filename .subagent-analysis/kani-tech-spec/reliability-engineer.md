---
persona: reliability-engineer
date: 2026-02-08
artifact: docs/plans/2026-02-07-kani-tech-spec.md
scope: Reliability and operability review covering failure modes, observability, SLOs, scaling, deployment, recovery, and operational readiness
sign-off: conditional-approve
confidence: high
---

## Summary

This review evaluates the Kani v4 Technical Specification from a reliability and operability perspective, focusing on failure modes, observability coverage, SLO quality, scaling bottlenecks, deployment strategy, recovery procedures, and operational readiness. The specification is notably thorough for a pre-implementation document: it enumerates degraded mode behavior for each infrastructure dependency, defines concrete SLOs with measurement methodology, specifies activity retry policies with non-retryable error classifications, and includes a reconciliation loop for drift detection. The headline finding is that while the failure-mode analysis and observability instrumentation are strong, there are gaps in deployment rollout strategy, SLO coverage for critical user-facing paths, capacity planning under load, and runbook/playbook readiness that should be addressed before production launch.

## Analysis

### SLO Quality and Coverage

The spec defines three SLOs: API Availability (99.9%), Message Delivery Latency (<200ms p95), and Pod Warm-Start Latency (<15s p95). These are well-structured with clear SLI definitions and measurement methodology. The error budget policy (reliability over features when budget exhausted) is appropriate.

However, several important gaps exist:

1. **No SLO for cold-start latency.** The spec explicitly excludes cold starts from the message delivery SLO and mentions cold-start as "a separate metric," but never defines an SLO for it. Cold starts are the first user experience for idle instances -- this is where users form their reliability perception. The success metrics table lists a target of <30s for cold starts, but this is not promoted to an SLO with error budget tracking.

2. **No SLO for streaming output delivery.** The SSE path (management server -> Redis -> client) has no latency or availability SLO. If Redis degrades or the SSE delivery pipeline stalls, clients experience silence with no contractual expectation to measure against.

3. **No SLO for data durability.** The filesystem is "the source of truth" per the key invariant, but there is no durability SLO. The EFS backup section mentions RPO of 24 hours (or 4 hours with a custom plan), but this is not tied to an SLO commitment. If a filesystem is lost, the blast radius is total for that instance's state.

4. **Error budget accounting is underspecified.** The spec says SLOs are "measured at the load balancer" or "via distributed tracing" but does not specify how error budget consumption is calculated, reported, or made visible to the team. Without a dashboard and alerting on error budget burn rate, the error budget policy is unenforceable.

### Failure Mode Analysis

The degraded mode behavior section is one of the strongest parts of the spec, covering Postgres, Redis, Temporal, EFS, and CoreDNS unavailability. Each scenario describes the impact and the residual functionality. This is well above average for a tech spec.

Specific observations:

**Postgres failure blast radius is large.** All API calls fail with 503 because auth depends on Postgres. This means even read-only status checks for running instances are unavailable. The spec should consider whether a short-lived auth cache (e.g., validated API key hash cached in memory for 60s) could allow status reads during brief Postgres outages.

**Redis failure is well-contained.** The kani-agent buffer (64MB) absorbs Redis outages gracefully. However, the buffer cap behavior is concerning: "If the buffer fills, kani-agent emits a local error and stops accepting new messages until the buffer drains." This means a prolonged Redis outage (minutes) with a chatty agent could cause message loss or agent stall. The spec does not quantify how long 64MB lasts under typical output rates.

**Temporal failure allows running instances to continue** via the fast-path direct routing. This is a strong design decision. However, the spec does not address what happens to the Postgres status cache during a prolonged Temporal outage. If a running pod crashes while Temporal is down, the `UpdateInstanceStatus` activity cannot run, leaving Postgres showing `running` for a dead pod. The fast-path will keep trying to POST to a dead pod IP. The fallback to Temporal signal path will also fail (Temporal is down). The message is effectively lost until Temporal recovers. The reconciliation loop (which compares Postgres to Temporal state) also cannot correct this without Temporal.

**EFS partial degradation (elevated latency) is under-addressed.** The spec notes that the stall timeout catches EFS hangs, but a stall timeout of 300 seconds is a very long time for a user to wait before learning something is wrong. There is no mention of EFS latency metrics or alerting on elevated NFS operation times that could provide early warning.

**CoreDNS failure is well-scoped** per namespace with PDB protection. The blast radius is limited to a single tenant.

### Scaling Characteristics and Bottlenecks

**Target: 500+ concurrent instances per cluster.** The spec provides this as a capacity target but does not break down the resource math.

**Postgres connection pooling.** Pool size of 25 per management server replica with `max_connections >= 200`. If there are 8 management server replicas, that is 200 connections, consuming all of `max_connections`. Adding replicas for horizontal scaling would exceed Postgres connection limits. The spec should specify the expected replica count range and whether PgBouncer or a similar external connection pooler is needed.

**Redis single primary.** A single Redis primary with one replica is specified for v1. All output for all instances flows through this single Redis primary. At 500 concurrent instances, each potentially producing continuous output, the XADD write rate could be substantial. The spec does not estimate the expected Redis operations per second or validate that a single cache.r6g.large can handle the write throughput. The `noeviction` policy combined with `XTRIM MAXLEN ~1000` after every XADD adds write amplification.

**Reconciliation loop frequency.** The reconciliation loop runs every 30 seconds using informers for pod state. At 500 instances, the Postgres-Temporal cache drift check requires querying Temporal workflow state for each instance. The spec does not describe how this scales -- is it a batch query or N individual queries? At 500 instances every 30 seconds, this could put significant load on both Temporal Cloud and Postgres.

**EFS throughput.** Elastic Throughput mode scales with usage, but the spec acknowledges no per-filesystem I/O limits (noisy neighbor problem). A single tenant running `git clone` of a large repo could saturate EFS throughput affecting all tenants sharing the same underlying EFS filesystem. There is no mention of EFS burst credit monitoring or throughput alerts.

**Rate limiting state in Redis.** Rate limiting uses Redis sorted sets with MULTI/EXEC. Under high concurrency, this adds contention to the same Redis primary that handles output streams. The spec does not discuss whether rate limiting should use a separate Redis instance or at minimum a separate logical database.

### Deployment Strategy

This is the weakest area of the spec from a reliability perspective.

**No rollout strategy specified.** The spec does not describe how the management server, kani-agent images, or Temporal workers are deployed. There is no mention of canary deployments, blue-green, rolling updates, or progressive rollout. For a multi-tenant platform where a bad deploy affects all tenants simultaneously, this is a significant gap.

**Temporal workflow versioning is addressed** via `GetVersion` branching, which is the right approach. However, the spec does not describe the deployment sequence: should Temporal workers be deployed before or after the management server? If the management server starts signaling workflows with new signal types before workers are updated to handle them, signals will fail.

**kani-agent image updates.** The spec specifies immutable tags with digest pinning, which is good. However, it does not describe how image updates are rolled out to running instances. Are running pods left on the old image until their next grace period teardown? Is there a mechanism to force-rotate all pods to a new image? What is the expected time to full fleet rotation?

**Database migration strategy.** The spec does not mention schema migrations, migration tooling, or how migrations are coordinated with application deploys. For a system with RLS policies, migration ordering matters: adding a new table without an RLS policy would be a security gap until the policy is applied.

**Rollback procedure.** There is no rollback procedure described for any component. If a management server deploy introduces a regression, what is the rollback process? For Temporal workflow version changes, rollback is particularly complex because `GetVersion` branches cannot be removed while old workflows exist.

### Recovery Procedures and Time-to-Recovery

**Pod crash recovery is well-defined.** The circuit breaker (3 consecutive crashes -> `crash_loop` state) with clear user recovery actions is good operational design. The auto-resurrect behavior (send message to idle instance) provides a simple recovery path.

**Postgres recovery relies on RDS Multi-AZ** with 60-120s failover. During this window, all API calls fail. The spec should quantify the expected user impact: how many in-flight requests will fail? Is there connection retry logic in the management server's database driver configuration?

**Redis failover.** ElastiCache automatic failover is mentioned but the failover duration is not specified. During failover, kani-agent output buffers locally (good), but SSE clients see a stall. The spec does not describe whether SSE clients receive any indication that streaming is degraded, or if they just see silence between pings.

**Tenant deletion workflow.** The 9-step deletion process is well-specified but has no timeout or partial-failure handling described. If step 5 (delete EFS Access Points) fails, does the workflow retry? Roll back steps 1-4? Leave the tenant in a partially deleted state? The spec should clarify whether this is a Temporal workflow (with retry policies) or an ad-hoc sequence.

**No disaster recovery plan.** The spec does not address full cluster recovery, region failover, or multi-region deployment. While this may be acceptable for v1, the RPO/RTO requirements in the filesystem provider section (RPO 4 hours, RTO 1 hour) imply an expectation of recoverability that is not backed by a documented procedure.

### Observability Gaps

The metrics and alerting tables are comprehensive and well-chosen. The distributed tracing span from API request through to SSE delivery is exactly right. Specific gaps:

1. **No alert on error budget burn rate.** Alerts exist for instantaneous error rates (>5% 5xx over 5 minutes) but not for SLO burn rate. A sustained 4% error rate would not trigger the critical alert but would exhaust the monthly error budget in ~18 hours. Multi-window burn rate alerting (per the Google SRE book) is the standard approach.

2. **No alert on Postgres connection pool exhaustion.** The spec defines pool size 25 per replica but no alert when pool utilization approaches saturation. Connection pool exhaustion manifests as request timeouts, which are hard to diagnose without the specific metric.

3. **No alert on kani-agent output buffer utilization.** The 64MB buffer is a critical fallback during Redis outages. If buffers are filling across the fleet, that is an early indicator of Redis problems. There is no metric for buffer utilization.

4. **No dashboard specification.** Metrics and alerts are defined, but there is no mention of operational dashboards. An on-call engineer at 3 AM needs a pre-built dashboard to triage: instance lifecycle health, per-tenant resource consumption, infrastructure dependency health, and message flow rates. Without dashboards, the observability instrumentation exists but is not operationally useful.

5. **No mention of log aggregation or search infrastructure.** Structured JSON logging is specified, but where do the logs go? ELK? CloudWatch? Loki? An on-call engineer needs to correlate logs across management server, Temporal worker, and kani-agent during an incident. The tooling is unspecified.

6. **Missing metric for Temporal workflow execution latency.** The spec tracks task queue depth but not end-to-end workflow execution time. A workflow that takes 60s to create a pod should be visible as a latency outlier.

### Dependency Health and Circuit Breaking

**Instance-level circuit breaker** (3 consecutive crashes -> `crash_loop`) is well-designed. Clear user recovery action (update config, then restart).

**Missing: tenant-level circuit breaker.** If a single tenant is creating hundreds of failing pods (misconfigured agent_config), the platform creates and destroys pods rapidly, consuming cluster resources. The per-instance circuit breaker helps, but a tenant creating many instances with the same bad config would still cause significant churn. A tenant-level failure rate threshold that triggers temporary suspension of pod creation for that tenant would limit blast radius.

**Missing: dependency circuit breaker for EFS.** The filesystem health pre-check runs before each pod creation, but if EFS is degraded (responding slowly but not failing), every CreatePod activity will block on the TCP health check. There is no circuit breaker that says "EFS has failed N times in the last M minutes, skip the health check and fail fast."

**Redis dependency is not circuit-broken.** If the management server cannot write to Redis Streams, it is unclear whether it retries indefinitely, drops the output, or backs off. The `kani_redis_publish_errors_total` metric exists, but the behavior on sustained failure is not described.

### Resource Limits, Quotas, and Back-Pressure

**Per-tenant ResourceQuota** (pod count, CPU, memory) provides good blast radius containment at the Kubernetes level.

**Message queue depth limit** (100 pending inbound) with 429 response provides explicit back-pressure to clients. This is well-designed.

**Storage quota enforcement** is application-level (reconciliation loop polls usage every 5 minutes). The gap between 100% and 110% (where pods are stopped) means a tenant could consume 10% extra storage (5GB at default 50GB quota) during the polling interval. For a shared EFS filesystem, this is acceptable but should be monitored.

**Missing: per-tenant rate limiting on pod creation churn.** The API rate limit on pod creation is 10/minute, but the auto-resurrect mechanism (send message -> start pod) bypasses the API rate limit since it is triggered by Temporal, not an API call. A tenant could trigger rapid pod creation/destruction cycles by sending messages to a misconfigured instance that immediately crashes.

### Data Durability and Backup/Restore

**EFS backup** via AWS Backup with daily minimum is specified. RPO of 24 hours is relatively long for "the source of truth." Quarterly restore tests are mentioned but not described procedurally.

**Postgres backup** via RDS automated backups with point-in-time recovery and 7-day retention is solid.

**Redis persistence** (RDB + AOF) is specified. Given that Redis holds output streams with 4-hour retention, losing Redis data means losing recent output history but not source-of-truth data.

**No backup for Kubernetes Secrets.** Tenant credentials stored as K8s Secrets in etcd are backed up only if etcd backup is configured. The spec mentions etcd encryption but not etcd backup. If the EKS control plane is lost, all credentials are lost. This is mitigated by the fact that credential values are externally sourced (users can re-upload), but the recovery procedure is manual.

### Graceful Degradation

The degraded mode section demonstrates strong thinking about partial failure. The hot-path/cold-path split is the key architectural decision that enables graceful degradation: running instances continue working even when Temporal or Postgres is down.

**Gap: no load shedding strategy.** Under extreme load (10x target), the management server will accept requests until Postgres connections are exhausted, then return errors. There is no admission control or load shedding that prioritizes message delivery to running instances (the most time-sensitive operation) over instance creation (less time-sensitive). A priority queue or separate thread pool for fast-path message delivery would protect the critical path.

**Gap: no tenant isolation under overload.** If one tenant sends a burst of traffic, all tenants share the same management server connection pool, Redis pipeline, and Temporal task queue. A noisy tenant could degrade the platform for everyone. Per-tenant resource isolation at the management server level (e.g., per-tenant connection pool limits or weighted fair queuing) is not described.

## Assumptions

- The spec is a pre-implementation design document; no code, infrastructure, or deployment artifacts exist yet.
- Temporal Cloud's own availability SLA is assumed to be at least 99.9% to support the platform's 99.9% API availability SLO.
- RDS Multi-AZ failover of 60-120s is based on AWS documentation and assumed to be accurate for the chosen instance type.
- The 500 concurrent instance target is a capacity planning estimate, not a hard requirement, and the system is expected to scale beyond this with additional infrastructure.
- The "management server" replicas are deployed as a Kubernetes Deployment with a standard rolling update strategy unless otherwise specified.
- There is a companion API specification document (`kani-api-spec.md`) that may contain additional operational detail not reviewed here.
- EFS Elastic Throughput mode provides sufficient IOPS for 500 concurrent instances based on typical AI coding agent workloads (primarily sequential reads/writes, not random I/O).

## Recommendations

### P0 -- Must fix before proceeding

1. **Define a deployment rollout strategy.** The spec must describe how management server updates, kani-agent image updates, and Temporal worker updates are deployed. At minimum: rolling update with health check gates, deployment sequence (workers before management server or vice versa), and maximum unavailable/surge parameters. A bad deploy with no canary or progressive rollout to a multi-tenant platform is the highest-risk operational scenario.

2. **Define a rollback procedure for each component.** Management server, Temporal workers, kani-agent images, and database migrations each need a documented rollback path. For Temporal workflow version changes, document the constraints (`GetVersion` branches cannot be removed while old workflows exist) and the rollback procedure (redeploy old code with both version branches intact).

3. **Add error budget burn rate alerting.** Replace or supplement the instantaneous 5xx rate alert with multi-window burn rate alerts (e.g., 1-hour and 6-hour windows). The current alert (>5% over 5 minutes) misses slow-burn reliability degradation that exhausts the monthly budget.

### P1 -- Should fix before production

1. **Add a cold-start SLO.** Cold-start latency is the user's first impression of reliability for idle instances. Promote the <30s target from the success metrics table to a formal SLO with an error budget, or explicitly document why it is excluded and how cold-start degradation will be detected.

2. **Specify database migration strategy and tooling.** Document the migration tool (goose, golang-migrate, etc.), the migration ordering relative to application deploys, and how RLS policies are applied to new tables. Include rollback migrations.

3. **Add Postgres connection pool exhaustion alerting and capacity planning.** Define the expected management server replica count range and verify that `pool_size * max_replicas < max_connections` with headroom. Add a metric and alert for pool utilization approaching saturation.

4. **Address the Temporal-down-plus-pod-crash scenario.** Document the expected behavior when a running pod crashes while Temporal is unavailable. The Postgres cache will show `running` for a dead pod, and neither the fast-path fallback nor the Temporal signal path can recover. Options: (a) add a health-check based mechanism in the management server that detects dead pods independently of Temporal, or (b) document this as an accepted risk with expected recovery time (Temporal recovery).

5. **Add per-tenant circuit breaker or pod creation throttle at the Temporal level.** Prevent a single misconfigured tenant from consuming cluster resources through rapid pod creation/crash cycles that bypass API rate limits.

6. **Specify the kani-agent output buffer drain rate and failure behavior.** Quantify how long the 64MB buffer lasts under typical and peak output rates. Document what happens to in-flight agent work when the buffer fills (agent stalls? messages dropped? pod killed?).

7. **Add operational dashboard requirements.** Define the key dashboards needed for on-call triage: instance lifecycle health, per-tenant resource consumption, infrastructure dependency status, message flow rates, and error budget burn. Dashboards are as important as alerts for incident response.

### P2 -- Consider improving

1. **Add an SLO for streaming output delivery latency.** Measure time from kani-agent output emission to SSE delivery to client. This covers the Redis Streams pipeline, which is the primary user-facing data flow during agent execution.

2. **Consider a short-lived API key hash cache for Postgres outage resilience.** A 60-second in-memory cache of validated API key hashes would allow read-only operations (GET status, SSE token refresh) to continue during brief Postgres blips, reducing the blast radius of Postgres failover.

3. **Add EFS latency metrics and alerting.** Monitor NFS operation latency at the pod level. Alert on elevated latency (e.g., p95 > 100ms) as an early indicator of EFS degradation, rather than waiting for the 300-second stall timeout.

4. **Specify log aggregation infrastructure and retention.** On-call engineers need to know where to search logs and how to correlate across components. Specify the log pipeline (e.g., CloudWatch Logs, Loki, ELK) and the retention period.

5. **Add a Temporal workflow execution latency metric and alert.** Track end-to-end time for CreatePod, DestroyPod, and full lifecycle transitions. Alert when CreatePod latency exceeds the 120s startup timeout threshold.

6. **Consider load shedding and priority queuing under overload.** Separate thread pools or priority queues for fast-path message delivery (latency-sensitive) versus instance creation (less time-sensitive) would protect the critical path under extreme load.

7. **Document the tenant deletion workflow as a Temporal workflow with retry policies.** The 9-step deletion process has the same failure characteristics as tenant provisioning (which is a Temporal workflow) and should have equivalent retry and rollback guarantees.

8. **Add Kubernetes etcd backup to deployment requirements.** K8s Secrets (tenant credentials) are stored in etcd. If etcd is lost without backup, all credentials must be manually re-uploaded by every tenant.

## Sign-Off

**conditional-approve** -- The specification demonstrates strong reliability thinking across failure modes, degraded behavior, and observability instrumentation. The gaps in deployment strategy, rollback procedures, and SLO burn rate alerting are addressable before production launch but must not be deferred past initial deployment. The architecture (hot-path/cold-path split, per-namespace isolation, Temporal for durable state) is fundamentally sound for reliable operations.
