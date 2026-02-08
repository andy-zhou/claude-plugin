# Analysis Schema

This document defines the required output format for all persona reviews and the
synthesis document. Every teammate MUST follow this schema exactly.

## Output Location

All analysis output is written to:

```
.subagent-analysis/{topic}/{run-id}/
├── {persona-name}.md        # One per dispatched persona
└── synthesis.md             # Generated after all reviews collected
```

`{topic}` is a kebab-case slug derived from the artifact being reviewed (e.g.,
`kani-tech-spec`, `auth-redesign-rfc`). `{run-id}` is a `YYYYMMDD-HHMMSS`
timestamp so that subsequent runs on the same artifact don't overwrite each other.

## Per-Persona Review Format

Each persona review file MUST contain YAML frontmatter followed by markdown sections.

### Frontmatter

```yaml
---
persona: <persona name, e.g. "security-engineer">
date: <YYYY-MM-DD>
artifact: <name or path of the artifact reviewed>
scope: <one-line description of what this review covers>
sign-off: <approve | conditional-approve | reject>
confidence: <high | medium | low>
---
```

- `sign-off` values:
  - `approve` — No blocking issues found. Safe to proceed.
  - `conditional-approve` — Acceptable if P0/P1 recommendations are addressed.
  - `reject` — Blocking issues found. Do not proceed without resolution.
  Sign-off is determined by the persona's sign-off rubric (see below). If the
  actual sign-off differs from what the rubric produces, the Rubric Assessment
  section must include an override justification.

### Sign-Off Rubric Structure

Each persona defines a sign-off rubric with 3-5 criteria per level, specific to
their domain. The rubric is defined during brainstorming (Step 2) or in the
persona template. Evaluation logic:

- If **any** reject criterion is triggered → derived sign-off is `reject`
- If **any** conditional criterion is triggered (and no reject) → derived sign-off is `conditional-approve`
- If **all** approve criteria hold (and no reject/conditional triggers) → derived sign-off is `approve`

The rubric is the default. If context warrants a different sign-off, the persona
must explicitly justify the override in the Rubric Assessment section.

```yaml
sign-off-rubric:
  reject:        # Any triggered → default reject
    - "Criterion description"
  conditional:   # Any triggered (no reject) → default conditional-approve
    - "Criterion description"
  approve:       # All must hold (no reject/conditional triggers)
    - "Criterion description"
```
- `confidence` — Self-assessed confidence in the review. `low` means the reviewer
  lacked sufficient context or the artifact was ambiguous in areas relevant to scope.

### Required Sections

```markdown
## Summary
One paragraph: what was reviewed, from what angle, and the headline finding.

## Analysis
Detailed findings organized by sub-topic. Use ### subsections as needed.
Each finding should state: what was observed, why it matters, and the evidence.

## Assumptions
Bullet list of assumptions made during the review. Things the reviewer could not
verify and instead assumed to be true/false. This section is REQUIRED even if
empty (write "None" if no assumptions were made).

The instruction is: "Document, don't guess." If you had to assume something,
list it here rather than silently building analysis on top of it.

## Recommendations

### P0 — Must fix before proceeding
Numbered list. These are blocking issues. If none, write "None identified."

### P1 — Should fix before production
Numbered list. These are significant issues that don't block progress but must
be resolved before production use.

### P2 — Consider improving
Numbered list. These are suggestions for improvement that are not blocking.

## Rubric Assessment
Evaluate each criterion from the persona's sign-off rubric against the findings.

### Criteria Evaluated
| Criterion | Level | Triggered | Evidence |
|-----------|-------|-----------|----------|
| <criterion text> | reject | Yes/No | <reference to finding or "N/A"> |
| <criterion text> | conditional | Yes/No | <reference to finding or "N/A"> |
| <criterion text> | approve | Yes/No | <reference to finding or "N/A"> |

### Derived Sign-Off: <value produced mechanically from the rubric>
### Actual Sign-Off: <value the persona is assigning>
### Override Justification: <required ONLY if Derived ≠ Actual; omit if they match>

## Debate Notes
Added after the debate phase (Step 6). Documents challenges received from other
personas, whether positions changed, and rationale. This section is REQUIRED
after debate, even if no challenges were received (write "No challenges received").

If debate was not conducted (Task-tool fallback mode), omit this section entirely.

## Sign-Off
Restate the actual sign-off value from the Rubric Assessment with a one-sentence
justification. This must match the Actual Sign-Off in the Rubric Assessment.
```

## Synthesis Document Format

The synthesis document (`.subagent-analysis/{topic}/{run-id}/synthesis.md`) is generated
after all persona reviews are collected (and after debate, if conducted).

### Frontmatter

```yaml
---
topic: <topic slug>
date: <YYYY-MM-DD>
personas: [<list of persona names that contributed>]
overall-status: <approve | conditional-approve | reject>
# overall-status rule: use the most restrictive sign-off across all personas.
# If any persona rejects → reject. If any conditionally approves → conditional-approve.
---
```

### Required Sections

```markdown
## Overall Status
One paragraph summarizing the combined assessment. State which persona produced
the most restrictive sign-off and which rubric criteria drove it.

## Consensus
Bullet list of findings that all personas agree on.

## Conflicts
For each disagreement between personas:
- **Topic**: What the disagreement is about
- **Positions**: What each persona said
- **Resolution**: Which persona's position takes precedence and why
- **Resolution-source**: How the conflict was resolved:
  - `debate` — personas resolved it themselves during the debate phase
  - `domain-authority` — unresolved in debate, resolved by the lead based on
    which persona's scope most directly covers the topic
  - `escalated` — unresolved, moved to Open Questions for human input
- **Rationale**: Why that resolution was chosen

If debate was not conducted (Task-tool fallback), omit the Resolution-source
field and resolve all conflicts via scope-based authority.

If no conflicts, write "No conflicts identified."

## Consolidated Recommendations

### P0
Merged, deduplicated P0s from all personas. Attribute each to its source persona.

### P1
Merged, deduplicated P1s from all personas. Attribute each to its source persona.

### P2
Merged, deduplicated P2s from all personas. Attribute each to its source persona.

## Open Questions
Items that could not be resolved by any persona and require human input.
Includes conflicts with Resolution-source: escalated.

## Next Steps
Concrete, actionable items derived from the consolidated recommendations.
Ordered by priority.
```
