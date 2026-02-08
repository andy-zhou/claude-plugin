---
persona: prompt-engineer
date: 2026-02-08
artifact: subagent-analysis skill (SKILL.md + analysis-schema.md + persona examples) -- post-fix revision
scope: Clarity of agent instructions, schema enforcement, persona prompt templates, drift/hallucination risk, output consistency
sign-off: conditional-approve
confidence: high
---

## Summary

Reviewed the updated subagent-analysis skill to evaluate whether the fixes from Round 1 effectively address the identified P0 and P1 issues. The headline finding is that all P0s and P1s have been resolved effectively. No new P0 or P1 issues remain after debate refinement. The skill is now significantly more reliable than the pre-fix version, moving from "realistic failure mode" to "production-ready with P2 polish items."

## Analysis

### Evaluation of P0 Fixes

**P0-1 (Schema file reference in persona templates): FIXED.** All three persona templates (principal-engineer.md:56-58, reliability-engineer.md:56-58, security-engineer.md:56-58) now read: "Your output MUST follow the schema provided below (the full schema will be inlined into your prompt at dispatch time -- do not attempt to read `analysis-schema.md` as a file)." This eliminates the dangling-file-reference failure mode. The parenthetical explanation is a good addition -- it tells the teammate *why* the schema is inlined rather than referenced, which reduces the chance of a teammate ignoring the instruction and trying to read the file anyway.

**P0-2 ("Same schema as above" in reliability and security templates): FIXED.** Both templates now have full Output Requirements sections identical in structure to the principal-engineer template. The three templates are now self-contained and can each serve as a standalone spawn prompt. This was the most critical fix and it is done correctly.

### Evaluation of P1 Fixes

**P1-1 (Explicit variable substitution instruction): FIXED.** SKILL.md Step 4 now includes (lines 144-145): "Replace all `{PLACEHOLDER}` tokens in the persona prompt with actual values before sending -- do not send literal placeholder strings." This is exactly the instruction that was missing. It is placed after the context-field list and before the output-path instruction, which is the correct position for a lead agent reading the instructions top-to-bottom.

**P1-2 ({REVIEW_CONTEXT} definition): FIXED.** The field is now defined as (lines 141-143): "a 2-3 sentence summary of the user's stated concerns and priorities from the brainstorming conversation, plus any specific instructions about review focus." This is substantially more specific than the original "any relevant context." The "2-3 sentence" constraint bounds the length, and "user's stated concerns and priorities" bounds the content. Good fix.

**P1-3 (Shift+Tab UI instruction): FIXED.** The "Enter delegate mode (Shift+Tab)" instruction has been removed entirely. The lead's role is now communicated through the existing instruction at lines 119-120: "The lead should NOT write review files directly -- the lead's role is to dispatch, monitor, facilitate debate, and synthesize." This is the correct approach -- it states the behavioral constraint without referencing a UI mechanism the agent cannot use.

**P1-4 (Debate Notes step number mismatch): FIXED.** The analysis-schema.md line 75 now correctly says "Added after the debate phase (Step 6)" matching SKILL.md's numbering. The step reference is consistent across both files.

**P1-5 (Duplicate {ARTIFACT_TYPE}): FIXED.** The context fields list in Step 4 (lines 137-143) now lists each field exactly once. No duplicate.

### Evaluation of New Common Mistakes Entries

Two new entries were added to the Common Mistakes table:

1. **"Creating agent team but skipping debate"** (line 319): This addresses a specific mode-confusion failure where the lead calls TeamCreate but then skips Step 6 because "I used the Task tool." The "What to do instead" column correctly explains the logic: "If TeamCreate was called, Step 6 is mandatory -- both paths use the Task tool, so 'I used Task' is not a reason to skip debate." This is well-constructed because it anticipates the exact reasoning chain an LLM would use to justify skipping the step and preemptively refutes it.

2. **"Writing generic observations not grounded in the artifact"** (line 320): This was a P2 suggestion from Round 1 and has been promoted to a table entry. The phrasing is direct: "Cite specific sections, decisions, or quotes from the artifact." This is effective anti-drift guidance.

Both additions strengthen the Common Mistakes table without bloating it.

### Remaining Issues

**Issue A: Persona templates contain raw placeholder tokens at rest.** The persona example files still contain literal `{ARTIFACT_TYPE}`, `{TOPIC}`, `{OUTPUT_PATH}`, `{REVIEW_CONTEXT}`, and `{ARTIFACT_CONTENT}` tokens in their Review Instructions sections (e.g., principal-engineer.md:44-49). SKILL.md Step 4 now correctly instructs the lead to replace these before sending. However, the persona templates are also referenced in Step 2 as examples for the lead to follow when defining personas: "Reference example personas in [...]/personas/examples/ for the expected structure and depth" (line 69). This creates a dual-use ambiguity: the templates are simultaneously (a) structural references for brainstorming and (b) fill-in-the-blank dispatch templates. The substitution instruction in Step 4 resolves the dispatch-time risk, but a lead agent reading the templates during Step 2 might be confused by the raw placeholders if it interprets them as instructions to act on immediately rather than templates to populate later. This is a low-probability issue because the Step 2 instruction says "for the expected structure and depth" (not "use these as dispatch prompts"), but it could be made unambiguous by adding a note to the persona templates: "Note: The `{PLACEHOLDER}` tokens below are replaced with actual values at dispatch time (Step 4)."

**Issue B: Debate challenge structure remains unspecified.** Round 1 P2-2 suggested a structured challenge template for the debate phase. The updated SKILL.md does include some structure in Step 6 line 191-193: "Each challenge should state: which finding is being challenged, the counter-argument, and what evidence supports the challenger's position." This is an improvement over the original, which had no structure at all. However, it is embedded in prose rather than formatted as a template or checklist, making it easier for an LLM to skim past. The debate phase remains the highest-variance part of the workflow. This is acceptable for now but is a known consistency risk.

**Issue C: Synthesis overall-status computation rule positioning.** Round 1 P2-4 noted that the `overall-status` computation rule ("most restrictive sign-off across all personas") appears in prose between the frontmatter block and the Required Sections in analysis-schema.md (lines 100-103). This has not been moved. The rule is still in a position where an LLM scanning the schema could miss it. This remains a minor parsing risk.

**Issue D: Spawn prompt assembly is still lead-constructed, not templated.** Round 1 P2-5 suggested providing a literal spawn-prompt template. SKILL.md Step 4 still uses a bulleted list of components the lead must assemble. The addition of the explicit substitution instruction (P1-1 fix) and the improved {REVIEW_CONTEXT} definition (P1-2 fix) reduce the variability of this assembly, but two different lead instances will still produce structurally different spawn prompts. The persona examples provide implicit structure, but the lead is not told "use the persona template as the base and append the schema and artifact." The assembly order and formatting remain unspecified. This is a cross-run consistency risk, though the schema enforcement and Common Mistakes table provide guardrails at the output level.

### Net Assessment of Changes

The Round 1 review identified 2 P0s, 5 P1s, and 5 P2s. Of these:

| Category | Fixed | Partially Addressed | Not Addressed |
|----------|-------|-------------------|---------------|
| P0 (2)   | 2     | 0                 | 0             |
| P1 (5)   | 5     | 0                 | 0             |
| P2 (5)   | 2 (generic-observations entry, challenge structure hint in prose) | 1 (cross-run comparability -- not documented but low priority) | 2 (overall-status positioning, spawn-prompt template) |

The critical fixes are all in place. The remaining issues are P2-level consistency improvements, not reliability blockers.

## Assumptions

- The `${CLAUDE_PLUGIN_ROOT}` variable is resolved before SKILL.md is presented to the lead agent, so file paths in the Prerequisites section are valid.
- The lead agent receives the full SKILL.md content as its instruction set, not a summary.
- Teammate agents have Write, Read, SendMessage, and TaskUpdate tool access.
- The persona example files are used as structural references during brainstorming and as template bases during dispatch, though this dual-use is not explicitly stated.

## Recommendations

### P0 -- Must fix before proceeding

None identified. Both P0s from Round 1 are resolved.

### P1 -- Should fix before production

None identified.

### P2 -- Consider improving

1. **Format the debate challenge structure as a checklist, not prose.** In Step 6, convert the challenge structure from the current sentence ("Each challenge should state: which finding...") into a bulleted template:
   - **Challenged finding:** [quote or cite the specific finding]
   - **Counter-argument:** [state the disagreement]
   - **Evidence:** [cite artifact sections or reasoning]
   This makes the structure scannable and harder for an LLM to skip.

2. **Move the `overall-status` computation rule into or immediately after the synthesis frontmatter YAML block.** Add it as a comment line or a bullet directly below the closing `---`, before the Required Sections heading. This positions it where an LLM parsing the frontmatter specification will encounter it.

3. **Add spawn-prompt assembly ordering guidance in SKILL.md Step 4.** Rather than a literal template (which risks ossification as the skill evolves), add ordering guidance: "Construct the spawn prompt in this order: (1) persona definition, (2) schema content, (3) review instructions with substituted context fields, (4) artifact content, (5) dispatch instructions (output path, task completion)." Prompt ordering affects LLM attention allocation -- placing the persona definition and analytical lens first ensures the teammate's role is established before the bulk content arrives. This gives structural consistency without rigidity.

4. **Clarify the dual-use nature of persona template files.** Add a brief note to each persona example file indicating that `{PLACEHOLDER}` tokens are replaced at dispatch time (Step 4) and that during brainstorming (Step 2), the lead should reference only the structure and depth of the file. This is low-priority because Step 2 already scopes the reference to "structure and depth" (line 69) and Step 4 has explicit substitution instructions (lines 144-145), so the risk of placeholder confusion during brainstorming is minimal.

## Debate Notes

### Challenge 1: P1-1 downgrade (from developer-experience)

**Challenged finding:** My P1-1 recommended clarifying the dual-use nature of persona template files (brainstorming reference in Step 2 vs. dispatch template in Step 4), arguing that a lead agent might be confused by raw placeholder tokens during brainstorming.

**Position: Accepted -- downgraded to P2-4.** Developer-experience made three points that I agree with: (1) Step 2 scopes template reading to "structure and depth" (line 69), directing the lead away from the placeholder-filled sections; (2) Step 4 already has an explicit substitution instruction (lines 144-145) that I myself assessed as effective -- I cannot simultaneously call this fix effective and flag a P1 for the scenario it prevents; (3) during brainstorming, there is no dispatch activity where placeholder confusion could manifest as a real error. The risk I described was theoretical with no mechanism to produce incorrect output. Downgraded to P2-4 with reduced urgency language.

### Challenge 2: P2-3 reframe (from workflow-architect)

**Challenged finding:** My P2-3 recommended providing a literal spawn-prompt assembly template in Step 4 to reduce cross-run structural variability.

**Position: Partially accepted -- reframed as ordering guidance.** Workflow-architect argued that a rigid template risks ossification: if the schema or persona structure changes, the template must be updated in lockstep, creating a maintenance burden. They also noted that output consistency is already enforced by the schema, so spawn-prompt structure is an implementation detail. I agree that a fully specified template is brittle. However, I maintain that *some* ordering guidance is needed because prompt ordering affects LLM attention allocation -- a spawn prompt that buries the persona definition after 500 lines of artifact content will produce worse results than one that leads with it. Reframed P2-3 to recommend ordering guidance (persona def first, then schema, then context, then artifact, then dispatch instructions) rather than a literal fill-in-the-blank template. This addresses the ossification concern while preserving the consistency benefit.

### Challenges I sent

1. **To workflow-architect (P1-1 convergence criterion):** Challenged their recommendation to require explicit "no challenges" confirmations from each teammate during debate. Argued this introduces prompt-engineering problems -- LLMs are more likely to manufacture low-quality challenges than produce clean confirmations -- and that the existing three-round hard cap plus their own P2-2 (defining "round") is sufficient. **Outcome: Partially accepted.** Workflow-architect conceded that the manufactured-challenge failure mode is real and dropped the confirmation requirement. They revised their P1-1 to use a time-based approach: "Each teammate has either sent at least one challenge or one full round has elapsed since they received the cross-review task." This is a better formulation than both the original and my counter-proposal -- it makes criterion 1 functional for all team compositions without adding tracking overhead.

2. **To developer-experience (P1-1 README usage example severity):** Challenged their classification of the missing README usage example as P1. Argued the README is not in the critical path for skill invocation since `argument-hint`, `description` frontmatter, and the interactive brainstorming step provide a complete user journey without the README. Suggested P2 instead. **Outcome: Accepted.** Developer-experience agreed that the README is on the "understanding path" not the "invocation path" and downgraded to P2 (highest-priority P2). They retained the env-var config location as their sole P1, which I agree with.

## Sign-Off

**conditional-approve** -- All P0 and P1 issues from Round 1 are resolved. No new P0 or P1 issues remain after debate -- the original P1-1 (persona template dual-use ambiguity) was downgraded to P2 following a valid challenge from developer-experience. The remaining P2 items (debate challenge structure, overall-status positioning, spawn-prompt ordering guidance, template dual-use note) are consistency improvements that would strengthen cross-run reliability but do not create realistic failure modes. The skill is production-ready; the conditional reflects that the P2 items collectively represent meaningful polish that should not be deferred indefinitely.
