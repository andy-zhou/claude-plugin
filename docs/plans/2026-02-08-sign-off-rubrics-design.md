# Sign-Off Rubrics Design

**Date:** 2026-02-08
**Status:** Draft
**Scope:** subagent-analysis skill — sign-off standards and rubric assessment

## Problem

The current sign-off system has three values (approve, conditional-approve, reject) with one-line definitions and no criteria for what constitutes each level. This creates two problems:

1. **Agent decision-making is uncalibrated.** Each persona interprets "blocking issue" differently. A security engineer and a technical writer have no shared framework for what reject means within their domain.
2. **Output is not actionable for the reader.** When the synthesis says "conditional-approve," the reader doesn't know which specific criteria weren't met or what they need to do before proceeding.

## Design

### Rubric Structure

Each persona defines 3-5 criteria per sign-off level, specific to their domain:

```yaml
sign-off-rubric:
  reject:        # Any triggered → default reject
    - "Criterion description"
  conditional:   # Any triggered (no reject) → default conditional-approve
    - "Criterion description"
  approve:       # All must hold (no reject/conditional triggers)
    - "Criterion description"
```

Evaluation logic:
- If **any** reject criterion is triggered → derived sign-off is `reject`
- If **any** conditional criterion is triggered (and no reject) → derived sign-off is `conditional-approve`
- If **all** approve criteria hold → derived sign-off is `approve`

### Guided Override Model

The rubric is the default, not a straitjacket. If context warrants a different sign-off than the rubric would mechanically produce, the agent **must** explicitly justify the override. This keeps decisions structured without being brittle.

- Derived sign-off matches actual → Override Justification omitted
- Derived sign-off differs from actual → Override Justification **required**

### Rubric Assessment Section (New Output Section)

A new required section in each persona review, placed between Recommendations and Debate Notes:

```markdown
## Rubric Assessment

### Criteria Evaluated
| Criterion | Level | Triggered | Evidence |
|-----------|-------|-----------|----------|
| <criterion text> | reject | Yes/No | <reference to finding or "N/A"> |
| <criterion text> | conditional | Yes/No | <reference to finding or "N/A"> |
| <criterion text> | approve | Yes/No | <reference to finding or "N/A"> |

### Derived Sign-Off: <value derived mechanically from rubric>
### Actual Sign-Off: <value the persona is assigning>
### Override Justification: <required only if derived ≠ actual>
```

### Per-Persona Rubric Criteria

Rubrics are per-persona, not universal. Each persona defines criteria appropriate to their domain. Example calibrations:

**Security engineer — reject criteria:**
- Unmitigated remote code execution or injection vector
- Secrets exposed in plaintext outside a secrets manager
- No authentication/authorization on a public-facing endpoint
- Trust boundary violated with no compensating control
- Data exfiltration path with no audit logging

**Technical writer — reject criteria:**
- Critical ambiguity that could cause the reader to take the wrong action
- Key term used with contradictory definitions in different sections
- Missing section that the stated audience would need to make a decision
- Instructions that, if followed literally, would produce the wrong outcome

**Product manager — reject criteria:**
- No stated success metric for the primary use case
- Requirements that contradict each other with no resolution
- Critical dependency identified but not addressed or mitigated
- Scope defined so broadly that it's not actionable

**Exec communication coach — reject criteria:**
- No executive summary or buried lead (key ask not in first paragraph)
- Business impact not quantified or concretely described
- No clear ask — document presents information without requesting a decision
- Risk framing that would cause a busy exec to defer rather than act

### Rubric Lifecycle

**Static personas (examples/):** Rubric criteria are defined in the template in a `## Sign-Off Rubric` section between Analytical Lens and Review Instructions.

**Dynamic personas (brainstorming):** The lead generates rubric criteria as part of persona definition in Step 2, tailored to the artifact. The user confirms or adjusts the rubric alongside the persona definition before dispatch.

**Dispatch (Step 4):** The rubric is included in the spawn prompt so the agent has its decision framework before starting the review.

## Changes Required

### analysis-schema.md

1. Add rubric structure definition in a new section after the frontmatter spec
2. Add `## Rubric Assessment` to the required sections list (between Recommendations and Debate Notes)
3. Define the table format and the Derived/Actual/Override fields
4. Clarify that Override Justification is required only when derived ≠ actual

### Persona templates (all 7 examples)

1. Add `## Sign-Off Rubric` section between Analytical Lens and Review Instructions
2. 3-5 criteria per level (reject, conditional-approve, approve)
3. Criteria calibrated to each persona's defined scope

### SKILL.md

1. **Step 2:** Add sign-off rubric to persona definition output (name, role, scope, analytical lens, **sign-off rubric**). Present rubrics to user for confirmation alongside persona definitions.
2. **Step 4:** Include rubric criteria in the spawn prompt sent to each teammate.
3. **Step 7 (Synthesis):** Add rubric traceability to overall-status — note which persona triggered the most restrictive level and which criteria drove it.

### Not changing

- The three sign-off values (approve, conditional-approve, reject)
- The overall-status computation rule (most restrictive wins)
- The confidence field (orthogonal to rubric — confidence is about the reviewer's certainty, rubric is about the decision criteria)
