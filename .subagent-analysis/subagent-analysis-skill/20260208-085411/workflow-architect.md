---
persona: workflow-architect
date: 2026-02-08
artifact: subagent-analysis skill (SKILL.md + analysis-schema.md + persona examples)
scope: 8-step workflow logic, step ordering, fallback paths, state transitions, convergence detection, edge case handling
sign-off: conditional-approve
confidence: high
---

## Summary

Reviewed the subagent-analysis skill's 8-step workflow (SKILL.md), its output schema contract (analysis-schema.md), and three example persona templates from the perspective of workflow correctness, state transitions, fallback path fidelity, convergence detection, and edge case handling. The workflow is well-structured with clear step ordering and a sound conflict resolution hierarchy (debate-first, then scope-based authority, then escalation). However, several gaps in failure handling, ambiguous convergence criteria, and a missing timeout/deadlock mechanism in the debate phase create risks that the workflow may not reliably reach a correct terminal state under partial failure conditions.

## Analysis

### Step Ordering and Dependencies

The 8-step linear sequence (Scope, Brainstorm, Align, Dispatch, Validate, Debate, Synthesize, Act) has a logical dependency chain where each step depends on the prior step's output. The ordering is sound: you cannot dispatch without personas (Step 2 before 4), you cannot debate without reviews (Step 5 before 6), and you cannot synthesize without debate completion (Step 6 before 7).

One implicit dependency is not fully documented: Step 3 ("Align Output") instructs the lead to "Read the full artifact content" for embedding in spawn prompts, but Step 1 already reads the artifact. The instruction in Step 3 ("teammates receive the FULL TEXT, not a file path") is a reminder, not a new read. This could cause confusion about whether the artifact should be re-read at Step 3 or carried forward from Step 1. In practice, the LLM will likely do the right thing, but the ambiguity is worth noting.

### Fallback Path Fidelity

The Task-tool fallback is well-defined: Step 4 changes from agent teams to parallel Task-tool dispatch, Step 6 (Debate) is skipped, and Step 8 omits team cleanup. The schema correctly documents that "Debate Notes" should be omitted entirely in fallback mode, and the synthesis should omit `Resolution-source` fields.

However, there is an asymmetry between the two paths that is not called out. In the agent-teams path, teammates can read each other's files during debate (Step 6.1: "Read the other personas' reviews"). In the Task-tool fallback, subagents complete independently with no cross-pollination. This means the fallback path produces strictly lower-quality output (no debate, no cross-review, no convergence). The workflow acknowledges this implicitly by skipping the debate, but doesn't provide any compensating mechanism. For instance, the synthesis step could apply more aggressive cross-validation when debate was skipped, but no such instruction exists.

### Convergence Detection in Debate Phase

The convergence criteria in Step 6.3 are the weakest part of the workflow. The two conditions are:

1. "Each teammate has sent at least one round of challenges and responses"
2. "Two broadcast rounds have occurred without new substantive disagreements"

Several issues:

**"Substantive" is undefined.** The lead must judge whether a disagreement is "substantive" or not, but there is no guidance on what constitutes substantive vs. non-substantive. This is a judgment call that will vary across executions. For a prompt-driven workflow, this kind of ambiguity can lead to premature convergence (lead calls time too early) or unnecessary debate prolongation.

**No maximum debate rounds.** There is no hard cap on debate duration. If two teammates keep finding new disagreements, the convergence condition ("two rounds without new substantive disagreements") may never be satisfied. The workflow lacks a circuit breaker such as "after N rounds total, force convergence regardless."

**"Round" is ambiguous.** The term "broadcast round" is used but teammates communicate via direct messages (Step 6.2 says "Teammates message each other directly"). It is unclear whether a "broadcast round" means a round where any teammate broadcasts, or simply a pass through all teammates. Since the protocol uses direct messages, referring to "broadcast rounds" is confusing.

### Partial Teammate Failure

Step 5 handles schema validation failures gracefully: "note the issues but proceed (do not re-dispatch)." This is pragmatic. However, the workflow does not address what happens if a teammate fails to produce any output at all:

- **Teammate crashes or times out during Step 4:** No detection mechanism is specified. The lead is told to wait for "all teammates complete their review tasks," but there is no timeout or fallback if a teammate never completes.
- **Teammate produces empty file or no file:** Step 5 says to read each persona's output file and validate. If the file doesn't exist, the workflow doesn't specify whether to skip that persona in synthesis or treat it as an error.
- **Teammate fails during debate (Step 6):** If a teammate crashes between writing their review and completing the debate, the workflow doesn't specify how to proceed. The convergence detection requires "each teammate has sent at least one round," which can't be satisfied if a teammate is dead.

These are not theoretical concerns. Agent teammates can fail due to context window exhaustion, tool errors, or infrastructure issues. The workflow needs explicit handling for partial teammate loss.

### Schema Contract Between SKILL.md and analysis-schema.md

The schema document and the SKILL.md are well-aligned. The SKILL.md references the schema's required fields in Step 5's validation checklist, and the schema defines the exact frontmatter and section structure. There is one inconsistency:

**Step numbering mismatch in schema.** The analysis-schema.md says "Debate Notes" are "Added after the debate phase (Step 7)." But in SKILL.md, the debate phase is Step 6 and synthesis is Step 7. This is a documentation error that could confuse teammates who receive the schema as context. It should say "Step 6" in the schema.

### State Machine Completeness

Mapping the workflow as a state machine:

```
START -> Step1 -> Step2 -> Step3 -> Step4 -> Step5 -> Step6 -> Step7 -> Step8 -> END
                                                        |
                                          (fallback: skip) ----> Step7 -> Step8 -> END
```

The happy path is clear. The fallback path is clear. What is missing:

1. **No backward transitions.** If Step 5 validation reveals that all reviews failed schema validation, the workflow proceeds to synthesis with invalid inputs. There is no option to go back to Step 4 (re-dispatch). The "Common Mistakes" table says not to re-dispatch, which is a reasonable cost/quality tradeoff, but the synthesis step has no guidance on how to handle structurally invalid inputs.

2. **No abort path.** There is no mechanism for the user or lead to abort the workflow mid-execution. If the user realizes during Step 2 brainstorming that the wrong artifact was loaded, there's no explicit "cancel and restart" path. This is minor since the user can always interrupt, but a well-defined abort state would be cleaner.

3. **Step 8 ordering.** Step 8 interleaves user interaction (present summary, ask about commit, ask about actions) with system operations (team cleanup). The ordering is: present summary, ask about commit, clean up team, ask about actions. This means the team is cleaned up before asking about actions. If the user wants a teammate to implement a recommendation, the team is already shut down. The cleanup should happen last, or the user should be asked about follow-up actions before cleanup.

### Commit Safety

Step 8 says to "stage and commit all files in `.subagent-analysis/{topic}/{run-id}/`" after user confirmation. However, validation happens in Step 5, and the debate phase (Step 6) and review updates may modify files after validation. The workflow doesn't specify re-validating files after debate updates. A teammate could introduce a schema violation in their "Debate Notes" update that wasn't caught by Step 5's validation.

### Persona Example Templates

The three example personas (principal-engineer, reliability-engineer, security-engineer) use placeholder variables (`{ARTIFACT_TYPE}`, `{TOPIC}`, `{OUTPUT_PATH}`, `{ARTIFACT_CONTENT}`, `{REVIEW_CONTEXT}`) that must be substituted by the lead during Step 4. The SKILL.md documents these variables clearly. The examples serve as structural references and are well-constructed.

One minor observation: the examples include the instruction "Your output MUST follow the schema defined in `analysis-schema.md`" but the SKILL.md's Step 4 says to include "the full analysis-schema.md content" in the spawn prompt. If the teammate receives both the schema inline AND a reference to a file they can't access, the inline content takes precedence. This works but the reference in the example templates to a file path is vestigial.

## Assumptions

- Agent teams are an experimental feature that may have its own failure modes (teammate crashes, message delivery failures) not documented in this skill's artifact.
- The LLM executing this workflow (the "lead") has sufficient context window to hold the full artifact content, all persona definitions, the schema, and orchestration state simultaneously.
- The `SendMessage` and task management primitives used in Steps 4 and 6 are reliable and ordered (messages arrive in send order, tasks update atomically).
- The `CLAUDE_PLUGIN_ROOT` variable is reliably set in all execution environments where this skill is invoked.
- "Delegate mode" (Shift+Tab) is a feature of the Claude Code UI that constrains the lead's behavior as described, preventing it from implementing instead of orchestrating.

## Recommendations

### P0 — Must fix before proceeding

None identified.

### P1 — Should fix before production

1. **Add a debate circuit breaker.** Introduce a maximum debate round count (e.g., 3 rounds) after which convergence is forced regardless of whether new disagreements emerge. Without this, the debate phase has no guaranteed termination. (SKILL.md, Step 6.3)

2. **Define partial teammate failure handling.** Add explicit instructions for what happens when a teammate fails to produce output (no file written) or becomes unresponsive during debate. Suggested approach: after a reasonable wait, proceed with available reviews and note the missing persona in synthesis. (SKILL.md, Steps 4-6)

3. **Fix the step number reference in analysis-schema.md.** The Debate Notes description says "Step 7" but should say "Step 6" to match SKILL.md's numbering. (analysis-schema.md, line 74-76 area)

4. **Reorder Step 8 to ask about follow-up actions before team cleanup.** Currently the team is shut down before asking the user if they want to act on recommendations. If a user wants a teammate to help implement a fix, the team is already gone. Move cleanup to after all user interaction is complete. (SKILL.md, Step 8)

### P2 — Consider improving

1. **Clarify "substantive disagreement" in convergence detection.** Provide guidance or examples of what constitutes a substantive vs. non-substantive disagreement to reduce variability in when the lead calls time. (SKILL.md, Step 6.3)

2. **Add post-debate validation.** After teammates update their reviews with Debate Notes (Step 6.4), re-validate the modified files before proceeding to synthesis. This prevents debate-phase edits from introducing schema violations that get committed. (SKILL.md, between Steps 6 and 7)

3. **Clarify the Step 3 artifact re-read instruction.** Either remove the "Read the full artifact content" instruction from Step 3 (since it was already read in Step 1) or explicitly state that the purpose is to prepare the content for embedding in spawn prompts, not to re-read from disk. (SKILL.md, Step 3.4)

4. **Remove vestigial file-path schema reference from persona examples.** The example templates say "Your output MUST follow the schema defined in `analysis-schema.md`" but teammates receive the schema inline per Step 4. Either remove the file reference from examples or add a note that it will be replaced with inline content. (personas/examples/*.md)

5. **Add compensating validation for the Task-tool fallback path.** Since the fallback path skips debate, the synthesis step could apply more aggressive cross-comparison of findings to partially compensate for the missing cross-review. Document this as an explicit instruction in Step 7 when debate was not conducted. (SKILL.md, Step 7)

6. **Disambiguate "broadcast round" in convergence criteria.** Step 6 describes teammates using direct messages but convergence refers to "broadcast rounds." Align the terminology, or define what constitutes a "round" in the context of direct-message-based debate. (SKILL.md, Step 6.3)

## Sign-Off

**conditional-approve** — The workflow is well-designed with sound step ordering, a principled conflict resolution hierarchy, and a reasonable fallback path. However, the absence of a debate circuit breaker (P1-1) and undefined partial-failure handling (P1-2) mean the workflow cannot guarantee termination and correct completion under all realistic execution paths. These should be addressed before production use.
