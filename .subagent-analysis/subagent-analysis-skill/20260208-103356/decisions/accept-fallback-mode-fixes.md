---
decision: Accept all fallback mode specification fixes
date: 2026-02-08
status: accepted
source-recommendations: [P1 #3 Step 6 mode-aware, P1 #4 fallback rubrics.md, P1 #5 wait gate, P2 #11 diagram gates, P2 #12 validation reference, P2 #13 round definition]
source-personas: [workflow-architect, prompt-engineer]
---

## Context

The workflow-architect identified three P1 gaps in the fallback mode specification: Step 6 uses "instruct each teammate" language that doesn't apply to one-shot Task-tool subagents, rubrics.md generation is mandated by the schema but not instructed in fallback, and the Step 4→5 transition lacks an explicit wait gate. The prompt-engineer's P1 on rubric re-injection was combined with the Step 6 fix after debate. Three P2 items address diagram completeness, validation reference clarity, and terminology definition.

## Options Considered

- **Option**: Accept all 6 items as a batch
  - **Trade-offs**: Comprehensively addresses fallback specification; no items deferred
  - **Advocated by**: user

## Decision

Accept all 6 fallback mode specification recommendations. Make Step 6 mode-aware with rubric re-injection (combined P1), add fallback rubrics.md instruction (P1), add Step 4→5 wait gate (P1), add fallback gates to Diagrams 2-3 (P2), clarify Step 6 validation for fallback (P2), and define "one round" in Step 5 (P2).

## Consequences

- Fallback mode will be fully specified for every step (1-9)
- Step 6 will handle both modes explicitly instead of relying on "all other steps remain the same"
- Rubric re-injection in agent-team mode prevents attention-drift on finalized rubric criteria
- Diagrams will be self-contained with decision gates shown
- Dependent on P1 #2 (cache republish) to reach users

## Dissent

None — all personas aligned. developer-experience noted the user-facing risk is low (LLM would naturally adapt) but agreed the specification should be explicit.
