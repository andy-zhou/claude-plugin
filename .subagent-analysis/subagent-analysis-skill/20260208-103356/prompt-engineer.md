---
persona: prompt-engineer
date: 2026-02-08
artifact: subagent-analysis skill (SKILL.md, analysis-schema.md, persona examples, README, CLAUDE.md, design docs)
scope: Prompt construction quality, instruction clarity for LLM consumption, placeholder substitution reliability, schema compliance likelihood, context window management, and instruction consistency across files
sign-off: conditional-approve
confidence: high
---

## Summary

Reviewed the subagent-analysis skill from the lens of LLM behavior reliability: will an LLM orchestrator and its dispatched teammates consistently interpret and execute these instructions as intended? The headline finding is that the skill's prompt construction and schema design are strong — no instruction contradictions, well-specified output format, and good prompt ordering guidance — but several conditional-level concerns around context persistence, state tracking, and schema-instruction drift create reliability risks in long orchestration sessions that will occasionally produce degraded output.

## Analysis

### Instruction Consistency Across Files

Evaluated all instruction surfaces for contradictions: SKILL.md step instructions, analysis-schema.md format requirements, persona example templates, and the fallback mode specification. No contradictions found. The decision gates in Steps 5 and 7 are consistent and well-reinforced — "Did you call TeamCreate?" appears in Step 5 (line 184), Step 7 (line 320), the comparison table (lines 492-498), and the Common Mistakes table (line 527). The fallback section explicitly states "do NOT call TeamCreate. Do NOT set `team_name` on Task calls" (lines 489-490), which is unambiguous.

The agent-team vs. fallback distinction is the most complex branching logic in the skill, and it is handled well. The skill uses the same distinguishing criterion consistently (TeamCreate called or not) and never relies on ambiguous heuristics.

### Placeholder Substitution Clarity

Step 4 lists five context fields that must be substituted: `{ARTIFACT_CONTENT}`, `{ARTIFACT_TYPE}`, `{TOPIC}`, `{OUTPUT_PATH}`, and `{REVIEW_CONTEXT}` (lines 150-157). It then states: "Replace all `{PLACEHOLDER}` tokens in the persona prompt with actual values before sending — do not send literal placeholder strings" (lines 158-159).

**Finding: The substitution instruction is present but the token inventory is split across two locations.** The five named tokens appear in the bullet list (lines 150-157), but the general substitution instruction (line 158) uses the generic term "`{PLACEHOLDER}` tokens" rather than enumerating which tokens need replacement. The persona example templates contain additional tokens — `{ARTIFACT_TYPE}`, `{TOPIC}`, `{OUTPUT_PATH}`, `{REVIEW_CONTEXT}`, and `{ARTIFACT_CONTENT}` — in their Review Instructions section. These happen to match the five listed in Step 4, so there is no *missing* token. But an orchestrator that reads only the general instruction on line 158 without cross-referencing the example templates might not realize the persona templates contain tokens that need substitution.

The risk is mitigated by the instruction to format persona prompts "following the structure of examples" (line 146), which means the orchestrator will see the tokens in the templates. The instruction to paste the schema content rather than reference it by path (lines 147-149) further reduces the risk of missing context. Overall, the substitution machinery is adequate but not bulletproof — a consolidated checklist would be more reliable.

### Teammate Context Completeness

**Schema delivery**: Step 4 explicitly instructs the orchestrator to paste the full analysis-schema.md content into the teammate prompt and tell the teammate "follow the schema provided below" (lines 147-149). This is well-designed — the teammate doesn't need to read any files. The example templates reinforce this with "the full schema will be inlined into your prompt at dispatch time — do not attempt to read `analysis-schema.md` as a file" (e.g., principal-engineer.md lines 87-89).

**Artifact delivery**: The instruction "paste the complete artifact content into the spawn prompt" is stated explicitly (line 172) and reinforced in Common Mistakes ("Passing file paths instead of full text" on line 516, "Summarizing the artifact for teammates" on line 520). This is thorough.

**Rubric availability at review-writing time**: This is the most significant context gap. The workflow requires teammates to: (1) draft a rubric (Step 4 dispatch), (2) refine after reading artifact (Step 5.1), (3) cross-review and harden (Step 5.2-5.4), then (4) write a review using the finalized rubric (Step 6). The finalized rubric exists only in the teammate's messaging history — there is no instruction for the teammate to write it to a file, and no instruction for the orchestrator to re-inject the finalized rubric into the teammate's context before Step 6. Step 6 says "instruct each teammate to write their review using their finalized rubric" (lines 298-300), but "using their finalized rubric" assumes the rubric is still in the teammate's effective attention window.

In a long rubric-hardening session with multiple rounds of challenges, the finalized rubric criteria could be 20+ messages back in the teammate's conversation history by the time Step 6 begins. LLMs have degraded recall for content that appeared early in a long conversation. The Rubric Assessment table (analysis-schema.md lines 109-114) makes drift detectable after the fact — if the criteria evaluated don't match the locked rubric, the orchestrator can catch it during validation. But there is no preventive mechanism.

### Schema-Instruction Drift

Compared SKILL.md's instructions with analysis-schema.md's format definitions for three specific areas:

**Rubric Assessment section**: Analysis-schema.md defines a detailed structure including "Derived Sign-Off," "Actual Sign-Off," and "Override Justification" (lines 116-118). SKILL.md Step 6's validation checklist (lines 304-310) checks for "Rubric Assessment criteria match the finalized rubric from Step 5" but does not mention the Derived/Actual/Override structure. A teammate following only the Step 6 instruction might produce a Rubric Assessment that lists criteria but omits the sign-off derivation chain. However, this risk is low because the teammate receives the full schema in their spawn prompt (per Step 4), so they have both the schema's detailed structure and the step instruction. The schema is more specific and would take precedence.

**Debate Notes omission in fallback**: Analysis-schema.md states "If debate was not conducted (Task-tool fallback mode), omit this section entirely" (line 125). SKILL.md Step 6's validation checklist (lines 304-310) lists the required sections as "Summary, Analysis, Assumptions, Recommendations, Rubric Assessment, Sign-Off" — it does not include Debate Notes in this list, which is correct for fallback mode. But it also doesn't include Debate Notes for agent-team mode, where the section is required. The validation checklist is run after Step 6 (review writing), which happens before Step 7 (debate). So the omission is actually correct — Debate Notes don't exist yet at validation time. They are added during Step 7.4 (lines 357-361). This is not a drift issue on closer analysis, but the temporal ordering is non-obvious and could confuse an orchestrator that reads the validation checklist as exhaustive.

**rubrics.md format**: SKILL.md Step 5.5 (lines 238-248) describes what rubrics.md should capture in prose: "All clarifying questions, who asked them, how they were resolved, and what rubric criteria they affected; All cross-review challenges that changed criteria; The full final rubric for each persona." Analysis-schema.md's Rubrics Document Format (lines 197-261) defines a formal structure with Decisions, Rubric Challenges, and Final Rubrics sections. These are consistent — the prose description in SKILL.md maps directly to the formal sections in the schema. No drift found here.

### Prompt Ordering

Step 4 recommends: "Persona definition first, then schema content, then review context, then artifact content, then dispatch instructions (rubric generation task)" (lines 174-177). This places the task instruction at the END of the prompt, after potentially thousands of tokens of artifact content.

For the initial dispatch (rubric generation), this ordering has a specific risk: the teammate's actual task ("propose your sign-off rubric") appears after the full artifact text. In long artifacts, the task instruction may receive less attention than content that appeared earlier. However, three factors mitigate this:

1. The persona definition appears first, which frames the reviewer's lens and activates the relevant analytical mode before bulk content arrives.
2. The schema content appears second, which establishes the output format expectations early.
3. LLMs generally attend well to content at the beginning and end of prompts (the primacy-recency effect), so placing the task instruction last is actually not the worst position — the middle is.

The recommended ordering is reasonable and internally consistent. The skill does not contradict it elsewhere. This is a minor concern, not a significant reliability risk.

### Orchestrator State Tracking

The orchestrating LLM must track several pieces of state across a potentially long conversation:

1. **Dispatch mode** (agent team or fallback) — used for decision gates in Steps 5 and 7. This is a single binary decision made once in Step 4, and the skill reinforces it repeatedly. Low drift risk.

2. **Rubric submission status** — the orchestrator must know when all teammates have submitted their draft rubrics (Step 5), refined rubrics (Step 5.1), and final rubrics (Step 5.4). There is no instruction to maintain a checklist. The orchestrator must count incoming messages and compare against the known number of teammates.

3. **Debate round counting** — the orchestrator must track convergence in Step 7 using three conditions that require per-participant awareness (lines 348-355). This is the most demanding tracking task.

4. **Update confirmations** — the orchestrator must wait for all teammates to confirm review file updates before proceeding to synthesis (lines 363-366). Same counting challenge as rubric submissions.

None of these tracking requirements include an instruction for structured state management. The orchestrator is expected to maintain all of this in working memory across a conversation that could span 50+ messages in a 4-persona run. There is no instruction to summarize current state before decision points, maintain a running tracker, or use any external mechanism.

This is a real reliability risk. The most likely failure mode is the orchestrator proceeding to synthesis before all teammates have confirmed their updates (item 4), because confirmation messages may arrive interleaved with other conversation and be missed. The Common Mistakes entry "Reading review files before teammates confirm updates are done" (line 530) acknowledges this risk but addresses it with a prohibition rather than a mechanism.

### Debate Convergence Execution

Step 7.3 defines three convergence conditions (lines 348-352). The third — "Three total rounds have elapsed" — is a simple counter that an LLM can track reliably. The first two are more complex:

- "Each teammate has either sent at least one challenge or one full round has elapsed since they received the cross-review task" — requires tracking per-teammate challenge status
- "Two rounds have passed without new disagreements" — requires distinguishing "new disagreements" from responses to existing disagreements

The definition of "round" (line 354-355) is precise ("one cycle where each active participant has had the opportunity to send a challenge or response"), but operationalizing this in a multi-party async conversation is nontrivial for an LLM. Messages arrive asynchronously; the orchestrator must determine when a "cycle" is complete, which requires knowing which participants are "active" and whether each has had their "opportunity."

The 3-round hard cap is an effective safety valve — it guarantees termination regardless of tracking accuracy. The risk is that the earlier termination conditions are evaluated incorrectly (e.g., the orchestrator ends debate after one round thinking convergence was reached, when actually one teammate hadn't responded yet). The consequence is a slightly less thorough debate, not a workflow failure.

## Assumptions

- The orchestrating LLM reads the full SKILL.md as its playbook at the start of each run (it does not receive a summarized version).
- Teammates receive their spawn prompt as a single message, not split across multiple messages.
- The context window of the orchestrating LLM is large enough to hold the full SKILL.md + analysis-schema.md + the conversation history from a complete run. If it is not, the skill's instructions would degrade in unpredictable ways not covered by this review.
- The LLM models used for orchestrator and teammates are of similar capability (e.g., both frontier models). The analysis of reliability expectations assumes frontier-level instruction following.

## Recommendations

### P0 — Must fix before proceeding

None identified.

### P1 — Should fix before production

1. **Add rubric re-injection instruction to Step 6.** When the orchestrator instructs teammates to write reviews in Step 6, it should include the teammate's finalized rubric criteria in the message. Something like: "When instructing each teammate to write their review, include their finalized rubric criteria from Step 5.4 in the message so the rubric is present in their recent context." This prevents the rubric state persistence gap described in Analysis. (Addresses conditional criterion C1.)

2. **Add structured state tracking instruction for the orchestrator.** After Step 4, add an instruction: "Before proceeding to each subsequent step, summarize the current state: which teammates have been dispatched, which have completed their current task, and which mode (agent team or fallback) is active. Use this summary to verify readiness before advancing." This gives the orchestrator a re-grounding mechanism for long sessions. (Addresses conditional criterion C2.)

### P2 — Consider improving

1. **Consolidate the placeholder substitution instruction into an explicit checklist.** In Step 4, after the bullet list of context fields, add a consolidated block: "Before sending each teammate's spawn prompt, verify all of the following tokens have been replaced with actual values: `{ARTIFACT_CONTENT}`, `{ARTIFACT_TYPE}`, `{TOPIC}`, `{OUTPUT_PATH}`, `{REVIEW_CONTEXT}`." This makes the substitution step a discrete verification rather than a general instruction scattered across bullets.

2. **Add Debate Notes to the Step 6 validation checklist with a temporal note.** The current validation checklist (Step 6, lines 304-310) omits Debate Notes because they don't exist yet. Add a note: "Debate Notes section is not expected at this stage — it will be added during Step 7." This prevents an orchestrator from flagging its absence as a validation failure or, conversely, from adding it prematurely.

3. **Simplify debate convergence detection to reduce orchestrator tracking burden.** Consider replacing the three convergence conditions with a simpler protocol: "After dispatching cross-review tasks, wait for all teammates to respond (challenge or 'no challenges'). If any challenges were made, allow one round of responses. Then call time. Hard cap: 3 rounds regardless." This achieves the same outcome with less per-participant state tracking. **Trade-off note (from debate):** Simplification would increase user wait time (always runs at least one full round even if no challenges) and would lose the crash-detection signal (distinguishing a silent teammate from one that explicitly said "no challenges"). The preferred remedy may be P1 #2 (structured state tracking), which makes the existing convergence conditions evaluable without simplifying them.

## Rubric Assessment

### Criteria Evaluated

| Criterion | Level | Triggered | Evidence |
|-----------|-------|-----------|----------|
| Instruction contradiction that forces LLM to guess | reject | No | Analysis §Instruction Consistency: no contradictions found across SKILL.md, analysis-schema.md, and persona templates. Decision gates are consistent and well-reinforced. |
| Dispatch instructions lack explicit placeholder substitution checklist | reject | No | Analysis §Placeholder Substitution: tokens are listed and the substitution instruction exists (line 158). The instruction is adequate though not consolidated into a single checklist. Not a reject — substitution will work, just not bulletproof. |
| Missing critical context making teammate's task uncompletable | reject | No | Analysis §Teammate Context Completeness: schema delivery and artifact delivery are explicit and thorough. Rubric availability is a concern but does not make the task *uncompletable* — the rubric is in the teammate's conversation history, just at risk of attention degradation. Conditional, not reject. |
| Output format underspecified causing structural non-determinism | reject | No | Analysis-schema.md specifies frontmatter fields, required sections, sign-off values, criteria table structure, and the Derived/Actual/Override chain. The format is deterministic enough for mechanical validation. |
| Rubric state persistence gap across multi-turn interactions | conditional | Yes | Analysis §Teammate Context Completeness: finalized rubric exists only in messaging history with no re-injection instruction before Step 6. |
| Orchestrator state-tracking relies on conversation recall with no structured re-grounding | conditional | Yes | Analysis §Orchestrator State Tracking: four categories of state must be tracked with no structured mechanism. |
| Schema-instruction drift between SKILL.md and analysis-schema.md | conditional | No | Analysis §Schema-Instruction Drift: Rubric Assessment omission in Step 6 checklist is explained by temporal ordering; rubrics.md prose maps to schema structure; Debate Notes omission is correct. Minor non-obviousness but no actual drift. |
| Attention-order problem in teammate spawn prompts | conditional | No | Analysis §Prompt Ordering: task instruction at end is mitigated by persona-first ordering, schema-second, and primacy-recency effect. Reasonable trade-off. |
| Debate convergence detection requires per-participant round counting | conditional | Yes | Analysis §Debate Convergence Execution: first two convergence conditions require per-participant tracking that is unreliable in long conversations. 3-round hard cap mitigates but doesn't eliminate. |
| All placeholder tokens have defined substitution source | approve | Yes | All five tokens map to values produced in Steps 1-3, and the substitution instruction is explicit. |
| Prompt ordering recommendation consistent and sound | approve | Yes | Recommended ordering is internally consistent and follows attention best practices. |
| Schema deterministic enough for mechanical validation | approve | Yes | All required fields, sections, and values are specified precisely. |
| Teammate prompts self-contained for initial task | approve | Yes | Spawn prompt includes persona definition, schema, artifact, context, and task instructions. |
| Multi-step workflow has sufficient re-grounding points | approve | No | Phase transitions have explicit instructions, but the rubric re-injection gap (C1) and lack of state summaries (C2) weaken the re-grounding at the Step 5→6 and Step 7→8 transitions. |

### Derived Sign-Off: conditional-approve
Three conditional criteria triggered (C1: rubric persistence, C2: state tracking, C5: convergence detection). No reject criteria triggered. Not all approve criteria hold (A5: re-grounding points insufficient at two transitions).

### Actual Sign-Off: conditional-approve

## Debate Notes

### Challenges Received

1. **From repo-hygiene-auditor: P1 #1 (rubric re-injection) depends on cache update.**
   The repo-hygiene-auditor noted that the rubric state persistence gap (my C1 / P1 #1) only exists in the source version's multi-round Step 5 protocol. In the currently deployed cache (pre-rubric-hardening 8-step workflow), teammates receive rubric criteria in the initial dispatch and write reviews immediately — the rubric is always in recent context. My P1 #1 is therefore contingent on the cache being updated (repo-hygiene-auditor's P0 #1).
   **Position:** Maintained. P1 #1 is correct for the source version under review. Noted the dependency: repo-hygiene-auditor's P0 #1 (update cache) enables the workflow where my P1 #1 matters. The synthesis should present these as a chain.

2. **From developer-experience: P2 #3 (simplify convergence) may hurt debate quality and UX.**
   The developer-experience persona argued that my simplified convergence protocol would: (a) force at least one full round even when no challenges exist, increasing user wait time; (b) lose the distinction between a silent teammate (possible crash) and an explicit "no challenges" response. They suggested that P1 #2 (structured state tracking) is a better fix because it makes the existing conditions evaluable without simplifying them.
   **Position:** Accepted the trade-off. Updated P2 #3 with a note that simplification has costs and that P1 #2 is the preferred remedy for the underlying C5 concern. C5 finding and severity unchanged — the convergence tracking is still unreliable for LLMs; the debate was about the remedy, not the diagnosis.

### Challenges Sent

1. **To repo-hygiene-auditor: Both reject findings may be too aggressive.**
   Challenged reject criterion #3 (source/cache divergence) as a deployment process issue outside the skill artifact's scope, and reject criterion #2 (README tree omission) as too severe for a missing archived design doc entry. Suggested both should be conditional-level. Response pending at time of convergence.

2. **To workflow-architect: P1 #1 remediation should combine with my P1 #1.**
   Noted that the workflow-architect's fallback Step 6 mismatch finding and my rubric re-injection finding both target Step 6 and the combined remediation should address both. Workflow-architect confirmed the findings are complementary, not conflicting — both stand independently.

3. **To developer-experience: No severity challenges sent.** Findings well-scoped with no conflicts.

### Cross-Persona Coordination Notes

- **Step 6 findings (workflow-architect + prompt-engineer):** Two complementary P1s targeting Step 6 from different angles — workflow-architect addresses fallback mode specification (subagents can't receive follow-ups), prompt-engineer addresses agent-team mode reliability (rubric not in recent context). The synthesis should present these as related but distinct, with a combined remediation.
- **Convergence detection (workflow-architect + prompt-engineer):** Both personas flagged Step 7 convergence but from different lenses — workflow-architect evaluated specification clarity, prompt-engineer evaluated LLM execution reliability. These are complementary findings, not duplicates.
- **Cache dependency chain (repo-hygiene-auditor → prompt-engineer):** The repo-hygiene-auditor's P0 #1 (update cache) and my P1 #1 (rubric re-injection) form a dependency chain for synthesis.

## Sign-Off

**conditional-approve** — The skill's prompt architecture is fundamentally sound with no instruction contradictions or context completeness failures, but three reliability gaps in rubric state persistence, orchestrator state tracking, and debate convergence detection create a meaningful risk of degraded output in long orchestration sessions that should be addressed before production use.
