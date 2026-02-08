# Analysis Schema

This document defines the required output format for all persona reviews and the
synthesis document. Every subagent MUST follow this schema exactly.

## Output Location

All analysis output is written to:

```
.subagent-analysis/{topic}/
├── {persona-name}.md        # One per dispatched persona
└── synthesis.md             # Generated after all reviews collected
```

`{topic}` is a kebab-case slug derived from the artifact being reviewed (e.g.,
`kani-tech-spec`, `auth-redesign-rfc`).

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

## Sign-Off
Restate the sign-off value from frontmatter with a one-sentence justification.
```

## Synthesis Document Format

The synthesis document (`.subagent-analysis/{topic}/synthesis.md`) is generated
after all persona reviews are collected.

### Frontmatter

```yaml
---
topic: <topic slug>
date: <YYYY-MM-DD>
personas: [<list of persona names that contributed>]
overall-status: <approve | conditional-approve | reject>
---
```

`overall-status` is the most restrictive sign-off across all personas. If any
persona rejects, overall is reject. If any conditionally approves, overall is
conditional-approve.

### Required Sections

```markdown
## Overall Status
One paragraph summarizing the combined assessment.

## Consensus
Bullet list of findings that all personas agree on.

## Conflicts
For each disagreement between personas:
- **Topic**: What the disagreement is about
- **Positions**: What each persona said
- **Resolution**: Which persona has domain authority over this topic and
  therefore whose recommendation takes precedence
- **Rationale**: Why that persona has authority

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

## Next Steps
Concrete, actionable items derived from the consolidated recommendations.
Ordered by priority.
```
