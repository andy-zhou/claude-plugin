---
topic: subagent-analysis-skill
date: 2026-02-08
personas: [workflow-architect, prompt-engineer, developer-experience]
overall-status: conditional-approve
---

## Overall Status

All three personas issued **conditional-approve** with **high confidence**. No persona identified P0 blocking issues that would prevent the skill from functioning. The skill's workflow design, prompt architecture, and documentation are solid foundations. However, 13 combined P1 items across the three reviews — particularly around debate-phase termination guarantees, schema-reference conflicts in persona templates, and missing user-facing documentation — should be addressed before promoting the skill to a wider audience. The findings are largely complementary rather than conflicting, reflecting genuine gaps rather than disagreements about approach.

## Consensus

All three personas agree on the following:

- The 8-step workflow is logically sound with correct step ordering and dependency chain
- The analysis-schema.md step-number reference for Debate Notes says "Step 7" but should say "Step 6" (identified by all three)
- The Common Mistakes table is one of the strongest elements of the skill — effective as both LLM guardrails and human diagnostic reference
- The persona template structure (role, scope, analytical lens, review instructions) is well-designed and consistent
- The P0/P1/P2 priority tiering with "None identified." fallback is intuitive and prevents ambiguity
- The fallback path (Task-tool dispatch without debate) is well-defined but under-documented for users
- The YAML frontmatter + markdown sections pattern provides good machine-parseability and human-readability
- The run-id timestamp prevents cross-run collisions effectively

## Conflicts

No direct conflicts were identified between personas. The reviews are complementary — each persona identified issues within their scope that do not contradict findings from other personas.

The closest to a tension point is between **prompt-engineer** and **developer-experience** regarding persona examples: prompt-engineer frames the schema file reference in examples as a P0 (agents receive dangling file references), while developer-experience frames it as a P2 documentation clarification. The underlying issue is the same — persona templates reference `analysis-schema.md` by filename, but teammates receive the schema inlined. The severity difference reflects their different lenses: prompt-engineer evaluates whether an LLM will fail (higher risk), developer-experience evaluates whether a human will be confused (lower risk). Since the issue affects runtime agent behavior, prompt-engineer's P0 classification takes precedence per scope-based authority.

## Consolidated Recommendations

### P0

1. **Inline the schema into persona templates or add explicit paste instruction.** The persona examples reference `analysis-schema.md` as a file, but teammates cannot read files they don't have. Either change templates to say "follow the schema provided below" with a `{SCHEMA_CONTENT}` placeholder, or add an explicit note that the file reference will be replaced with inline content. *(prompt-engineer)*

2. **Fix "Same schema as above" in reliability and security persona templates.** Each template is dispatched standalone — "same as above" references nothing. Copy the full Output Requirements into both templates. *(prompt-engineer)*

### P1

1. **Add a debate circuit breaker.** Introduce a maximum debate round count (e.g., 3 rounds) after which convergence is forced. Without this, the debate phase has no guaranteed termination. *(workflow-architect)*

2. **Define partial teammate failure handling.** Specify what happens when a teammate fails to produce output or becomes unresponsive. Suggested: after a reasonable wait, proceed with available reviews and note the missing persona in synthesis. *(workflow-architect)*

3. **Fix the Debate Notes step reference in analysis-schema.md.** Change "Step 7" to "Step 6" to match SKILL.md's numbering. *(workflow-architect, prompt-engineer, developer-experience — all three identified this)*

4. **Reorder Step 8 to ask about follow-up actions before team cleanup.** Currently the team is shut down before asking if the user wants to act on recommendations. Move cleanup to after all user interaction. *(workflow-architect)*

5. **Add explicit variable substitution instruction in Step 4.** After the context fields list, add: "Replace all `{PLACEHOLDER}` tokens in the persona prompt template with actual values before sending. Do not send literal placeholder strings." *(prompt-engineer)*

6. **Define `{REVIEW_CONTEXT}` more precisely.** Replace "any relevant context" with specific guidance: "A 2-3 sentence summary of the user's stated concerns and priorities, plus any specific instructions about review focus." *(prompt-engineer)*

7. **Remove or reframe "Enter delegate mode (Shift+Tab)."** This is a human-UI instruction an LLM cannot execute. Replace with an agent-actionable instruction like "The lead should not write review files directly." *(prompt-engineer)*

8. **Remove the duplicate `{ARTIFACT_TYPE}` line in Step 4.** Listed twice in the context fields — copy-paste error. *(prompt-engineer)*

9. **Add usage example to README.md.** Show `/subagent-analysis path/to/spec.md` and briefly describe what happens. First-time users should not need to read SKILL.md to invoke the skill. *(developer-experience)*

10. **Specify where to configure the agent-teams environment variable.** The README shows the JSON but not which file it belongs in. Add the settings file path. *(developer-experience)*

11. **Document the no-argument invocation behavior.** SKILL.md is silent on what happens without `$ARGUMENTS`. Specify: "If no argument is provided, ask the user for the artifact path." *(developer-experience)*

### P2

1. **Clarify "substantive disagreement" in convergence detection.** Provide guidance or examples to reduce variability in when the lead calls time. *(workflow-architect)*

2. **Add post-debate validation.** Re-validate review files after debate updates to catch schema violations introduced during debate-phase edits. *(workflow-architect)*

3. **Clarify the Step 3 artifact re-read instruction.** State explicitly that the purpose is to prepare content for embedding in spawn prompts, not to re-read from disk. *(workflow-architect)*

4. **Remove vestigial file-path schema reference from persona examples.** Replace with "follow the schema provided below" once P0-1 is addressed. *(workflow-architect)*

5. **Add compensating validation for the Task-tool fallback path.** Since fallback skips debate, the synthesis step could apply more aggressive cross-comparison to partially compensate. *(workflow-architect)*

6. **Disambiguate "broadcast round" in convergence criteria.** Step 6 uses direct messages but convergence refers to "broadcast rounds." Align terminology. *(workflow-architect)*

7. **Add Common Mistakes entry for generic/ungrounded analysis.** Prevent LLMs from writing unfalsifiable observations not citing the artifact. *(prompt-engineer)*

8. **Add a structured challenge template for debate.** Provide minimal structure for challenges to improve debate quality and consistency. *(prompt-engineer)*

9. **Document cross-run comparability trade-off.** Note that dynamic personas mean synthesis documents from different runs are not directly comparable. *(prompt-engineer)*

10. **Move synthesis `overall-status` computation rule adjacent to the frontmatter spec.** Currently in prose below the YAML block — place it immediately after for easier LLM parsing. *(prompt-engineer)*

11. **Consider providing a literal spawn-prompt template.** Reduce cross-run variability by giving the lead a fill-in-the-blank template instead of a bullet list to assemble. *(prompt-engineer)*

12. **Reframe the fallback as a first-class mode.** Rename "Fallback" to "Modes of Operation" with two subsections to set appropriate expectations for users without agent teams. *(developer-experience)*

13. **Add a "What to expect" section to README.** Briefly describe the workflow and typical output so users know what they're getting into. *(developer-experience)*

14. **Specify that persona frontmatter `persona:` field must match the filename slug.** Prevents drift between filenames and metadata. *(developer-experience)*

15. **Add a Common Mistakes entry for no-argument invocation.** The most common first-time error is missing. *(developer-experience)*

16. **Consider making the output directory non-hidden.** `.subagent-analysis/` is invisible by default. A `.gitignore` entry could keep it out of version control without hiding it. *(developer-experience)*

17. **Clarify persona modification flow in Step 2.** Note that users can add, remove, or modify personas before confirming — not just accept/reject. *(developer-experience)*

18. **Add a note in persona examples explaining the schema reference will be replaced with inline content at dispatch.** Prevents confusion when cross-referencing examples with Step 4. *(developer-experience)*

## Open Questions

1. **Should the fallback (Task-tool) path be the documented default?** Given that agent teams are experimental, the majority of users will experience the fallback path. Should the workflow be reframed so the non-debate path is the default and agent-teams debate is the enhancement?

2. **What is the intended behavior when no `$ARGUMENTS` is provided?** All three reviewers noted this gap. The answer should be documented in SKILL.md.

3. **Should persona templates be self-contained or reference external schemas?** The current design has templates referencing `analysis-schema.md` by name, but Step 4 inlines the schema. One approach must be canonical.

## Next Steps

1. **Fix the step-number reference** in analysis-schema.md ("Step 7" → "Step 6") — trivial edit, unanimous agreement.
2. **Resolve the persona template schema-reference issue** (P0-1 and P0-2) — decide on `{SCHEMA_CONTENT}` placeholder vs. explicit "schema provided below" note.
3. **Add debate circuit breaker** (P1-1) — add a max-rounds cap to Step 6.3.
4. **Add partial-failure handling** (P1-2) — add explicit instructions for teammate timeout/failure in Steps 4-6.
5. **Reorder Step 8** (P1-4) — move team cleanup after all user interaction.
6. **Update README** with usage example, env-var configuration path, and "what to expect" (P1-9, P1-10, P2-13).
7. **Clean up Step 4** — remove duplicate `{ARTIFACT_TYPE}`, add substitution instruction, define `{REVIEW_CONTEXT}`, fix Shift+Tab instruction (P1-5 through P1-8).
8. **Address remaining P2 items** as time permits, prioritizing those that affect output consistency (P2-7, P2-8, P2-11).
