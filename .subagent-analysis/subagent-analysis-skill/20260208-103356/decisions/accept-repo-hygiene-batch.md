---
decision: Accept all repo hygiene recommendations
date: 2026-02-08
status: accepted
source-recommendations: [P0 #1 README tree fix, P1 #2 republish cache, P1 #9 design doc updates, P2 #22 old analysis runs, P2 #23 CLAUDE.md mention]
source-personas: [repo-hygiene-auditor]
---

## Context

The repo-hygiene-auditor identified significant hygiene debt from three rounds of changes (original 8-step, agent-teams migration, rubric hardening). The README file tree omits a design doc at an enumerated depth (P0), the plugin cache is running a stale pre-rubric-hardening version (P1), and the agent-teams design doc has superseded step names and no Status field (P1). Two P2 items address old analysis run format and CLAUDE.md discoverability.

## Options Considered

- **Option**: Accept all 5 items as a batch
  - **Trade-offs**: Addresses all hygiene debt in one pass; no items deferred
  - **Advocated by**: user

## Decision

Accept all 5 repo hygiene recommendations. Fix the README tree (P0), republish the plugin cache (P1), update the agent-teams design doc with Status field and corrected step names (P1), decide on old analysis run format (P2), and add sign-off rubrics design doc to CLAUDE.md Historical Context (P2).

## Consequences

- README tree will accurately reflect filesystem at all enumerated depths
- Plugin cache will match source, making all other P1 fixes user-relevant
- Design docs will have consistent Status fields and accurate step references
- Old analysis runs will be addressed (format TBD — leave as-is with note, or restructure)
- CLAUDE.md will reference both design docs for future session discoverability
- Republishing the cache is the critical-path item — it unblocks P1 items #3-5

## Dissent

None — all personas aligned with this decision.
