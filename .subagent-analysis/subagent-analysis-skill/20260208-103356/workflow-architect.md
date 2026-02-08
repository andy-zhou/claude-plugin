---
persona: workflow-architect
date: 2026-02-08
artifact: subagent-analysis skill (SKILL.md, analysis-schema.md, persona examples, README, CLAUDE.md, design docs)
scope: End-to-end workflow correctness — step sequencing, decision gates, error handling, state management, fallback mode consistency, termination guarantees, and cross-reference integrity between SKILL.md and analysis-schema.md
sign-off: conditional-approve
confidence: high
---

## Summary

Reviewed the subagent-analysis skill as a workflow specification, evaluating whether every defined path reaches a terminal state, whether each step handles failure, whether the two execution modes (agent-team and Task-tool fallback) are fully and consistently specified, and whether cross-references between SKILL.md and analysis-schema.md are semantically correct. The headline finding is that the primary agent-team workflow is well-structured with clear decision gates, convergence bounds, and failure handling, but the fallback mode has several under-specified behaviors — most notably, Step 6's "instruct each teammate" language assumes an interactive execution model that Task-tool subagents do not support, and rubrics.md generation is mandated by the schema but not instructed in the SKILL.md fallback section.

## Analysis

### Terminal State Reachability

The workflow defines three terminal states: (1) successful completion via agent-team mode (Steps 1-9e), (2) successful completion via fallback mode (Steps 1-4, 6, 8-9d), and (3) graceful degradation when the majority of teammates fail (Step 6, lines 315-316: "If the majority of dispatched personas failed to produce output, inform the user and ask whether to proceed with synthesis or re-run the analysis").

All three are reachable from valid starting configurations:

- **Agent-team mode**: Prerequisite check at line 25 confirms agent teams are enabled, then the workflow proceeds linearly through Steps 1-9e. Every step has a defined successor. Step 9e terminates with TeamDelete after shutdown confirmations.
- **Fallback mode**: Prerequisite check at line 25 detects agent teams are not enabled, workflow enters fallback. The fallback section (lines 486-509) explicitly marks Steps 5 and 7 as skipped and Step 9 cleanup as not needed. The remaining steps (1-4, 6, 8, 9a-d) form a complete path to synthesis and decision documents.
- **Majority failure**: Step 6 (lines 314-316) handles this by asking the user whether to proceed or re-run. Both user choices lead to a terminal state (synthesis with reduced input, or workflow restart).

No unreachable terminal state found.

### Step Failure Behavior

Evaluated each step for defined failure behavior:

| Step | Failure behavior specified? | Evidence |
|------|---------------------------|----------|
| 1 (Identify Scope) | Partial | The artifact might not be accessible (line 27: "If no argument is provided, ask the user"). But no guidance on what happens if the artifact path is invalid or the file cannot be read. |
| 2 (Brainstorm) | Yes | Max 5 questions (line 51), "just go" escape hatch (line 54), user confirmation gate (line 79). |
| 3 (Align Output) | Yes | Deterministic — generate timestamp, create directory, determine paths. No external dependencies that could fail unpredictably. |
| 4 (Dispatch) | Partial | No guidance on what happens if TeamCreate fails or if a Task dispatch fails to spawn a teammate. The instructions assume all dispatches succeed. |
| 5 (Rubric Hardening) | Yes | Finalization after "one round of challenges" (line 234). Clarifying questions have an escalation path (lines 209-228). |
| 6 (Write Reviews) | Yes | Schema violations noted but not blocking (line 311). Missing personas noted in synthesis (lines 312-313). Majority failure triggers user prompt (lines 315-316). |
| 7 (Findings Debate) | Yes | Three convergence conditions including a hard cap at 3 rounds (line 352). |
| 8 (Synthesize) | Yes | Conflict resolution has a three-tier fallback: debate → domain-authority → escalation (lines 413-421). |
| 9 (Review/Decide) | Yes | User-driven; brainstorming skill handles the interaction. Cleanup has explicit ordering (lines 475-479). |

Steps 1 and 4 have partial failure coverage. Step 1's gap is minor (an LLM will naturally report file-not-found). Step 4's gap is more significant: if TeamCreate fails or a teammate spawn fails, there is no instruction for how to proceed (retry? fall back to Task-tool mode? abort?).

### Fallback Mode Specification Completeness

The fallback section (lines 486-509) specifies behavior for Steps 4, 5, 7, and 9 under fallback mode. For Steps 1, 2, 3, 6, and 8, it states "All other steps remain the same" (line 509). This is mostly correct but creates two problems:

**Finding 1: Step 6 instruction mismatch.** Step 6 (line 298) says: "instruct each teammate to write their review using their finalized rubric." In agent-team mode, this works because teammates are persistent agents that can receive follow-up messages. In fallback mode, teammates are Task-tool subagents that execute once and exit — you cannot send them follow-up instructions after dispatch.

The fallback section at line 500-504 partially addresses this for Step 4 by saying "Include rubric criteria in the spawn prompt," implying the review instructions must also be in the spawn prompt. But Step 6's "instruct each teammate" language is not overridden for fallback, and the connection between "include rubric criteria in spawn prompt" (Step 4 fallback) and "instruct each teammate to write their review" (Step 6) is only inferable, not stated. A strict reader of Step 6 in fallback mode would attempt to send instructions to already-completed subagents.

**Finding 2: rubrics.md generation gap.** The analysis-schema.md (lines 197-205) specifies: "In fallback mode (no agent teams), write a simplified version with just the assigned rubrics and any user context from brainstorming." SKILL.md's Step 5 (lines 238-248) only instructs rubrics.md generation as part of the rubric hardening protocol, which is skipped in fallback. The fallback section (lines 505) says "Step 5 is skipped: No rubric debate. Lead assigns rubrics directly" — but does not instruct the lead to write rubrics.md with the assigned rubrics. The schema mandates this file; the workflow does not instruct it.

**Finding 3: Step 6 validation in fallback mode.** Step 6's validation checklist (lines 305-310) includes "Rubric Assessment criteria match the finalized rubric from Step 5?" (line 310). In fallback mode, Step 5 was skipped, and rubrics were assigned by the lead in the dispatch prompt (Step 4). The reference to "Step 5" is misleading in fallback mode — it should say "the finalized rubric from Step 5 (or the rubric assigned in the dispatch prompt in fallback mode)."

### Cross-Reference Semantic Correctness

Verified all semantic cross-references between SKILL.md and analysis-schema.md:

| Reference in SKILL.md | Target in analysis-schema.md | Resolves? | Semantically correct? |
|----------------------|----------------------------|-----------|----------------------|
| Step 5.5: "Rubrics Document Format in the analysis schema" (line 239) | "Rubrics Document Format" section (line 197) | Yes | Yes — format matches what Step 5 produces |
| Step 6: validation checklist (lines 305-310) | "Per-Persona Review Format" / "Required Sections" (lines 76-130) | Yes | Yes — checklist items map to schema sections |
| Step 8: "following the synthesis schema" (line 402) | "Synthesis Document Format" (line 132) | Yes | Yes — synthesis instructions align with schema |
| Step 9c: "Decision Document Format in the analysis schema" (line 457) | "Decision Document Format" (line 263) | Yes | Yes — format matches |
| Step 8: "Rubric traceability" instruction (lines 404-407) | "Overall Status" section (lines 153-155) | Yes | Yes — schema says "State which persona produced the most restrictive sign-off" |

All cross-references resolve and are semantically correct. No mismatches found.

### Diagram-to-Prose Consistency

**Diagram 1 (Steps 1-3, lines 83-112):** Shows Step 1 → Step 2 (with brainstorming loop and "just go" branch) → persona definition → Step 3. Matches prose. The brainstorming loop shows "≤5 rounds" which matches the "Maximum 5 questions" rule at line 51. The "just go" branch correctly bypasses the question loop. No structural inconsistency.

**Diagram 2 (Steps 4-6, lines 250-294):** Shows teammates spawned → draft rubrics → refine → cross-review → (questions branch) → finalize → write rubrics.md → Step 6. Matches prose of Step 5. However, the diagram does not show the agent-team vs. fallback decision gate that opens Step 5 (lines 184-187). A reader following only the diagram would not know that this entire sequence is skipped in fallback mode. This is a minor omission — the decision gate is clearly stated in prose — but the diagram does not represent the full branching logic.

**Diagram 3 (Steps 6-8, lines 368-398):** Shows reviews written → cross-review → direct challenges (with loop) → convergence → debate notes → Step 8. Matches Step 7 prose. The loop correctly shows back-and-forth until convergence. Same observation as Diagram 2: the agent-team vs. fallback decision gate is not shown.

Both Diagrams 2 and 3 omit the decision gates that conditionally skip the depicted sequences in fallback mode. This is a clarity issue, not a structural contradiction — the prose is unambiguous about the decision gates.

### Convergence and Termination Analysis

**Step 2 brainstorming:** Terminates at max 5 questions or when user says "just go." Well-bounded.

**Step 5 rubric hardening:** The protocol has 4 sub-steps: refinement, cross-review, clarifying questions, finalization. Finalization (line 234) says "After one round of challenges and any clarifications." The cross-review (line 200-203) does not explicitly limit the number of challenge rounds, but the finalization sub-step implicitly bounds it to one round by stating "after one round." However, "one round" is not defined as precisely as in Step 7 (where "round" gets a formal definition at line 355). It is inferable but could be interpreted as "one round of challenge messages" or "one complete cycle where every persona has responded."

**Step 7 debate:** Three termination conditions (lines 349-352), including a hard cap at 3 rounds. "Round" is formally defined (line 355). The first termination condition ("Each teammate has either sent at least one challenge or one full round has elapsed") uses an OR, meaning a teammate who chooses not to challenge does not block convergence. Well-specified overall, though the interaction between the three conditions could be slightly clearer — the first condition could terminate debate after a single round even if active disagreements are ongoing, which may be premature. The 3-round hard cap mitigates this.

### Implicit Ordering Dependencies

**Step 4 → Step 5 state transfer:** Step 4 dispatches teammates with instructions to generate draft rubrics. Step 5 begins "After all teammates submit their draft rubrics" (line 189). The dependency is implicit — there is no explicit instruction for the orchestrator to wait for all rubric submissions before proceeding. In practice, the LLM orchestrator will naturally wait for messages, but the workflow does not state a gate like "Wait for all N teammates to message their draft rubrics before proceeding to Step 5."

This contrasts with Step 7.4 (line 363), which explicitly states: "Wait for all teammates to confirm their review files are updated before proceeding to Step 8." The same explicit wait instruction is missing at the Step 4→5 transition.

### Prose-to-Prose Consistency

No contradictions found between textual instructions within SKILL.md or between SKILL.md and analysis-schema.md. The fallback table (lines 492-498) is consistent with the inline decision gates at Steps 5 and 7. The Common Mistakes table (lines 513-530) is consistent with the workflow instructions. The schema's description of rubric lifecycle (analysis-schema.md lines 50-55) is consistent with SKILL.md's Step 5 protocol.

## Assumptions

- I assume that "Task-tool subagents" (fallback mode) execute once and exit — they cannot receive follow-up messages after their initial dispatch. This is consistent with how the artifact describes them but is not explicitly stated in SKILL.md itself; it is implied by the distinction between persistent agent-team teammates and Task-tool subagents.
- I assume that the LLM orchestrator processes steps sequentially as written, not in parallel, unless the instructions explicitly say otherwise (e.g., "ALL dispatches MUST happen in a single message" at line 501).
- I assume that TeamCreate, TeamDelete, and the Task tool with `team_name` are reliable primitives — the workflow's correctness is evaluated assuming the underlying platform works as expected.

## Recommendations

### P0 — Must fix before proceeding

None identified.

### P1 — Should fix before production

1. **Add explicit fallback-mode override for Step 6.** Step 6 says "instruct each teammate to write their review" (line 298), which cannot be executed in fallback mode where subagents have already completed. Add a note to the fallback section or to Step 6 itself: "In fallback mode, teammates receive review instructions as part of the dispatch prompt in Step 4. Step 6 for the orchestrator consists only of waiting for task completion and validating outputs — there is no follow-up instruction to send." (Triggers conditional criterion C4.)

2. **Add rubrics.md generation instruction for fallback mode.** The analysis-schema.md (lines 202-205) requires a simplified rubrics.md in fallback mode. Add to the fallback section: "After dispatch, write a simplified rubrics.md with the assigned rubrics and user context from brainstorming, following the Rubrics Document Format in the analysis schema with `mode: fallback`." (Triggers conditional criterion C5.)

3. **Add explicit wait gate at Step 4→5 transition.** Step 5 begins "After all teammates submit their draft rubrics" but does not instruct the orchestrator to wait. Add: "Wait for all teammates to message their draft rubrics before proceeding. If a teammate has not responded after a reasonable period, message them to check status." This matches the explicit wait pattern used at Step 7→8 (line 363). (Triggers conditional criterion C1.)

### P2 — Consider improving

1. **Add failure handling for TeamCreate/dispatch failures in Step 4.** Currently, if TeamCreate fails or a teammate spawn fails, there is no recovery path specified. Consider adding: "If TeamCreate fails, fall back to Task-tool dispatch mode. If individual teammate spawns fail, proceed with successfully spawned teammates and note missing personas."

2. **Add fallback decision gate to Diagrams 2 and 3.** Both diagrams depict sequences that are skipped in fallback mode but do not show the decision gate. Adding a "Fallback? Skip" branch would make the diagrams self-contained. (Triggers conditional criterion C6.)

3. **Clarify Step 6 validation reference for fallback mode.** Line 310 says "Rubric Assessment criteria match the finalized rubric from Step 5?" In fallback mode, Step 5 was skipped. Consider: "...match the finalized rubric from Step 5 (or the rubric included in the dispatch prompt in fallback mode)."

4. **Define "one round" in Step 5 rubric hardening.** Step 7 formally defines "round" (line 355) but Step 5 uses "one round of challenges" (line 234) without definition. Consider reusing the Step 7 definition or cross-referencing it.

5. **Add failure handling for Step 1 artifact access.** If the artifact path is invalid or the file cannot be read, there is no explicit instruction. Consider: "If the artifact cannot be read, inform the user and ask for a corrected path using AskUserQuestion."

## Rubric Assessment

### Criteria Evaluated

| Criterion | Level | Triggered | Evidence |
|-----------|-------|-----------|----------|
| Unreachable terminal state | reject | No | All three terminal states (agent-team success, fallback success, majority failure degradation) are reachable. See "Terminal State Reachability" analysis. |
| Undefined behavior on step failure | reject | No | All steps have at least partial failure handling. Steps 1 and 4 have minor gaps (artifact access, TeamCreate failure) but these are edge cases with natural LLM behavior as a backstop, not undefined states. |
| Prose-to-prose contradiction | reject | No | No contradictions found between textual instructions. See "Prose-to-Prose Consistency" analysis. |
| Semantic cross-reference mismatch | reject | No | All cross-references resolve and are semantically correct. See cross-reference table in analysis. |
| Implicit ordering dependency | conditional | Yes | Step 4→5 transition lacks explicit wait gate for rubric submissions. See "Implicit Ordering Dependencies" finding. |
| Fallback mode behavior gap | conditional | Yes | rubrics.md generation mandated by schema but not instructed in fallback mode. See Finding 2. |
| Ambiguous convergence/termination | conditional | No | Step 2 has clear bounds (5 questions max). Step 5 has "one round" which is slightly imprecise but bounded. Step 7 has formal definitions and a hard cap. No condition risks hanging. |
| Fallback-to-primary instruction mismatch | conditional | Yes | Step 6 "instruct each teammate" cannot be executed with Task-tool subagents. See Finding 1. |
| rubrics.md generation gap between modes | conditional | Yes | Schema mandates fallback rubrics.md; SKILL.md does not instruct it. See Finding 2. |
| Prose/diagram inconsistency | conditional | Yes | Diagrams 2 and 3 omit fallback decision gates. Minor clarity issue, not structural. |
| All terminal states reachable | approve | Yes | Confirmed. See analysis. |
| Every step has defined failure behavior | approve | No | Steps 1 and 4 have minor gaps. See step failure table. |
| Diagrams and prose structurally consistent | approve | Yes | No structural contradictions. Diagrams omit fallback gates but do not contradict prose. |
| Cross-references semantically correct | approve | Yes | All verified. See cross-reference table. |
| Both modes fully specified end-to-end | approve | No | Fallback mode has three gaps: Step 6 instruction mismatch, rubrics.md generation, Step 6 validation reference. |

### Derived Sign-Off: conditional-approve

Five conditional criteria triggered (C1: implicit ordering, C2: fallback behavior gap, C4: instruction mismatch, C5: rubrics.md gap, C6: diagram inconsistency). No reject criteria triggered. Two approve criteria not fully met (A2: step failure behavior, A5: both modes fully specified).

### Actual Sign-Off: conditional-approve

## Debate Notes

### Challenges Received

**1. From prompt-engineer: P1 #1 (fallback Step 6 instruction mismatch) — combined remediation.**
Prompt-engineer noted that their P1 #1 (rubric re-injection at Step 6 in agent-team mode) and my P1 #1 (fallback Step 6 instruction mismatch) both target Step 6 from different angles. They proposed a combined remediation that makes Step 6 mode-aware: in agent-team mode, include finalized rubric criteria in the follow-up instruction; in fallback mode, explicitly state that Step 6 is wait-and-validate only. **Accepted.** The combined fix is better than either in isolation. No change to severity or sign-off — this refines the remediation, not the finding.

**2. From developer-experience: P1 #1 (fallback Step 6 instruction mismatch) — user-impact calibration.**
Developer-experience agreed with the finding but argued the user-facing risk is lower than the specification gap suggests. A competent LLM orchestrator would recognize that fallback subagents have already completed and skip the instruction step. The practical failure mode (orchestrator tries to message exited subagents) is unlikely. **Acknowledged but position maintained.** I agree the runtime risk is low, but the specification is inconsistent with itself: the fallback section overrides Steps 4, 5, 7, and 9 but says "all other steps remain the same" for Step 6, which does not actually remain the same. This is a specification completeness issue that matters for future implementors and less capable models. The fix is also trivial (one sentence), supporting P1 severity. I will note in the synthesis that user-facing risk is lower than spec-risk.

**3. From repo-hygiene-auditor: P1 #2 (rubrics.md generation gap) — dependency on cache update.**
Repo-hygiene-auditor pointed out that my fallback-mode findings are moot for the currently deployed version because the cache runs the pre-rubric-hardening 8-step workflow with no Rubrics Document Format section. My P1s only become actionable once their P0 #1 (update cache to match source) is resolved. **Acknowledged.** This is correct — my findings evaluate the source artifact, and their practical urgency is gated on the cache being updated. No change to severity (the source is the authoritative spec), but the synthesis should present this as an ordered dependency: fix cache first, then address fallback specification gaps.

### Challenges Sent

**1. To repo-hygiene-auditor: Reject #3 (source/cache divergence) severity.**
I argued that source/cache divergence is a deployment process issue, not a skill artifact defect. The source files (SKILL.md, analysis-schema.md, persona templates) are internally consistent and correct. The cache is a downstream snapshot that was not republished after rubric hardening changes. Suggested reclassifying as P0 without triggering reject on the skill specification. Response pending at time of convergence call.

**2. To repo-hygiene-auditor: Reject #2 (README tree omission) severity.**
I argued that a missing entry in a documentation tree is P1/conditional-level, not reject-level. The file exists and is discoverable; SKILL.md does not reference it; the workflow is unaffected. Response pending at time of convergence call.

**3. To prompt-engineer: Conditional #2 and #5 overlap with workflow-architect scope (rubric cross-review).**
During rubric cross-review, I challenged two conditional criteria that overlapped with my workflow state management scope. Prompt-engineer accepted both and reframed to focus on LLM attention/execution reliability rather than workflow specification. Resolved during rubric hardening.

### Overlap Notes for Synthesis

- **Step 6 findings**: My P1 #1 (fallback instruction mismatch) and prompt-engineer's P1 #1 (rubric re-injection) are complementary, not duplicative. Different modes (fallback vs. agent-team), different failure mechanisms (instruction model vs. attention drift), but the remediation should be combined into a single mode-aware Step 6 instruction.
- **Convergence/termination**: My conditional #3 (ambiguous convergence) and prompt-engineer's conditional #5 (LLM execution of convergence detection) evaluate the same Step 7 text from different lenses. Neither triggered a finding in my review (the specification is adequately bounded), but if prompt-engineer's triggers, the synthesis should present them as related.
- **rubrics.md gap**: My conditional #5 (workflow gap) and developer-experience's approve #5 (output completeness) are complementary. Root cause attribution belongs to my finding; user-impact attribution belongs to theirs.
- **Fallback P1s gated on cache update**: My P1 #1 and P1 #2 are practically gated on repo-hygiene-auditor's P0 #1 (update cache). The synthesis should present this dependency.

### Position Changes

No findings, severity ratings, or sign-off changed as a result of debate. All challenges either reinforced existing positions or refined remediation approaches without affecting the underlying assessment.

## Sign-Off

**conditional-approve** — The primary agent-team workflow is well-structured with clear decision gates, bounded convergence, and robust failure handling. The fallback mode has several under-specified behaviors (Step 6 instruction model mismatch, missing rubrics.md generation instruction, implicit Step 4→5 wait gate) that should be addressed before the skill is considered production-complete, but none represent blocking structural defects.
