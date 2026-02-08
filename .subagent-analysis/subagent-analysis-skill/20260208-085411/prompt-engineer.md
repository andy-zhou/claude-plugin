---
persona: prompt-engineer
date: 2026-02-08
artifact: subagent-analysis skill (SKILL.md + analysis-schema.md + persona examples)
scope: Clarity of agent instructions, schema enforcement, persona prompt templates, drift/hallucination risk, output consistency
sign-off: conditional-approve
confidence: high
---

## Summary

Reviewed the subagent-analysis skill from the perspective of LLM prompt engineering: will agents following these instructions produce the intended output reliably, or are there ambiguities that invite divergence? The headline finding is that the prompt architecture is well-structured overall -- the persona templates, schema definition, and Common Mistakes table form a strong instruction set -- but there are several specific ambiguities in variable substitution, schema cross-referencing, and debate-phase instructions that create realistic drift risks across runs.

## Analysis

### Instruction Clarity and Specificity

The SKILL.md workflow is organized as a numbered-step recipe, which is the correct structure for LLM instruction-following. The steps are ordered correctly from a dependency perspective, and critical constraints are called out with bold emphasis and "Critical:" prefixes. This is effective.

However, the instructions mix two audiences in a single document: the **lead agent** (who orchestrates the workflow) and the **teammate agents** (who write reviews). SKILL.md is addressed to the lead, but the lead must extract and reformat instructions for teammates. The document does not provide a literal spawn-prompt template -- it says "construct a spawn prompt that includes" followed by a bulleted list. This requires the lead to synthesize a prompt on the fly, which introduces variability across runs. Two different lead instances could construct meaningfully different spawn prompts from the same bullet list, leading to inconsistent teammate behavior.

### Variable Substitution Pattern

Step 4 lists five context fields: `{ARTIFACT_CONTENT}`, `{ARTIFACT_TYPE}`, `{TOPIC}`, `{OUTPUT_PATH}`, `{REVIEW_CONTEXT}`. The example persona templates use these same placeholders in their "Review Instructions" sections. This is a sound pattern -- the persona templates serve as fill-in-the-blank templates.

**Issue 1: Duplicate line.** Step 4 lists `{ARTIFACT_TYPE}` twice (lines 127-128 of SKILL.md). This is a copy-paste error that could confuse an LLM parsing the instructions, though in practice it is unlikely to cause behavioral divergence.

**Issue 2: No explicit substitution instruction.** The SKILL.md tells the lead to "construct a spawn prompt that includes" these fields, but does not explicitly say "replace the {PLACEHOLDER} tokens in the persona template with actual values." The persona examples contain literal `{ARTIFACT_CONTENT}` etc., but the lead is never told to perform string substitution on those templates. An LLM would likely infer this, but "likely infer" is not "will reliably do." This is a prompt-engineering gap -- explicit is always better than implicit for LLM instructions.

**Issue 3: `{REVIEW_CONTEXT}` is under-defined.** The field is described as "any relevant context from the brainstorming conversation." This is vague. It could mean: the raw transcript of the Q&A, a summary of user concerns, the persona-specific scope rationale, or all of the above. Different lead instances will interpret this differently, leading to inconsistent context provided to teammates.

### Schema Enforcement

The analysis-schema.md is well-structured and uses both a formal YAML frontmatter specification and markdown section templates. The enumerated values for `sign-off` and `confidence` are clearly defined with explanations of what each means. The "REQUIRED even if empty" instruction for Assumptions is correctly emphasized.

**Issue 4: Schema is referenced, not inlined, in persona examples.** The persona templates say "Your output MUST follow the schema defined in `analysis-schema.md`" -- but this is a file reference. SKILL.md Step 4 correctly instructs the lead to paste the full analysis-schema.md content into the spawn prompt. However, the persona template itself still contains the file reference. If a lead agent pastes the persona template into the spawn prompt without also pasting the schema, the teammate receives a dangling reference to a file it cannot read. The SKILL.md instruction and the persona template instruction are in tension. The persona template should say something like "Your output MUST follow the schema provided below" (assuming the schema is pasted below it), not reference a file path.

**Issue 5: Debate Notes section reference mismatch.** The analysis-schema.md says Debate Notes are "Added after the debate phase (Step 7)" but the debate phase is Step 6 in SKILL.md. This is a minor inconsistency, but for an LLM agent following step numbers literally, it could cause confusion about when to add this section.

### Persona Prompt Templates

The three example personas (principal-engineer, reliability-engineer, security-engineer) are well-structured and consistent in format. Each has: role statement, In-Scope/Out-of-Scope lists, Analytical Lens with numbered questions, Review Instructions with placeholder fields, and Output Requirements. This consistency is a strength -- it provides a clear pattern for the lead to follow when generating new personas dynamically.

**Issue 6: "Same schema as above" in two templates.** The reliability-engineer and security-engineer templates say "Same schema as above. Write to: {OUTPUT_PATH}" in their Output Requirements section. The principal-engineer template spells out the schema requirements explicitly. "Same schema as above" is a reference to something earlier in the same document -- but when each persona is dispatched as a separate teammate, there is no "above." Each template is the entire prompt for that teammate. The reliability and security templates are under-specified compared to the principal-engineer template. They should each contain the full schema reference, not a relative one.

### Drift and Hallucination Risk

**Issue 7: Debate phase instructions are the highest-risk area for drift.** Step 6 relies on teammates reading each other's files, messaging each other with challenges, and then updating their own reviews. This is a multi-turn, multi-agent interaction with loose convergence criteria ("new substantive disagreements" is subjective). The lead must make judgment calls about when to "call time." Different lead instances will call time at different points, producing different debate outcomes.

The debate instructions are also the least constrained in terms of output format. Challenges are sent as free-form messages. There is no template for a challenge, no required structure. This means the quality and specificity of debate will vary significantly across runs.

**Issue 8: "Enter delegate mode (Shift+Tab)" is a UI instruction, not a prompt instruction.** SKILL.md includes the instruction "Enter delegate mode (Shift+Tab) so the lead coordinates without implementing." This is an instruction for a human user interacting with a GUI, not an instruction an LLM agent can follow. An LLM reading this prompt cannot press Shift+Tab. This instruction should either be removed (if the lead is an agent) or clearly marked as a human-operator instruction. Its presence in the agent's instruction stream is noise that could confuse the agent about its role.

### Common Mistakes Table Effectiveness

The Common Mistakes table is one of the strongest prompt-engineering elements in the skill. Anti-pattern tables are highly effective for LLMs because they give the model explicit "don't do this" constraints with explanations. The table covers 12 mistakes, each with a clear "why it's wrong" and "what to do instead." This is well-calibrated.

**Issue 9: The table lacks an entry for a common LLM failure mode: generating placeholder content.** LLMs sometimes produce reviews with generic observations like "the architecture could be improved" without citing specific evidence from the artifact. Adding a mistake like "Writing generic observations not grounded in the artifact" / "Reviews become unfalsifiable and useless" / "Cite specific sections, decisions, or quotes from the artifact" would strengthen the table against a real drift pattern.

### Output Consistency Across Runs

The combination of schema enforcement + persona templates + Common Mistakes table creates a strong consistency foundation. The run-id timestamp prevents collision between runs. The frontmatter structure constrains the metadata to enumerated values.

The main source of cross-run inconsistency is the persona brainstorming step (Step 2). Since personas are generated dynamically, different runs on the same artifact will produce different persona sets, leading to different review angles and findings. This is by design ("context-specific review angles") but means that synthesis documents are not directly comparable across runs. This is a trade-off, not a bug, but it should be documented.

### Synthesis Schema Gaps

**Issue 10: The synthesis schema does not define `overall-status` computation rules inline.** The rule "most restrictive sign-off across all personas" appears in the schema file, but only in prose between the frontmatter block and the Required Sections. An LLM scanning for the frontmatter specification might miss this rule. It should be inside or immediately adjacent to the frontmatter specification, possibly as a comment in the YAML block.

**Issue 11: The Conflicts section schema in analysis-schema.md is inside a markdown code block.** This means an LLM reading the schema sees it as example text, not as a live instruction. If the schema is pasted into a spawn prompt as-is, the code fences create an ambiguity: is this a template to fill in, or an example to reference? The SKILL.md persona templates also use this pattern (code blocks for schema). For maximum reliability, the schema constraints should be stated as direct instructions outside code blocks, with code blocks used only for examples.

## Assumptions

- The lead agent is a Claude-family model with tool-use capabilities, operating in a Claude Code environment with agent-team support.
- Teammate agents have the same tool-use capabilities as the lead (specifically: Write, Read, SendMessage, TaskUpdate).
- The `${CLAUDE_PLUGIN_ROOT}` variable is resolved before the SKILL.md is presented to the lead agent.
- The lead agent receives SKILL.md as its primary instruction set (not a summary of it).
- "Delegate mode" is a Claude Code feature that restricts the lead from using implementation tools, not a prompt-level constraint.

## Recommendations

### P0 -- Must fix before proceeding

1. **Inline the schema into persona templates or add explicit paste instruction.** The persona examples reference `analysis-schema.md` as a file, but teammates cannot read files they don't have. SKILL.md Step 4 says to paste the schema, but the persona template says "follow the schema defined in analysis-schema.md." These instructions conflict. Either: (a) change persona templates to say "follow the schema provided below" and add a `{SCHEMA_CONTENT}` placeholder, or (b) add an explicit instruction in the persona template: "The full schema has been provided to you above. Do not attempt to read analysis-schema.md."

2. **Fix the "Same schema as above" in reliability and security persona templates.** Each persona template is dispatched as a standalone prompt. "Same schema as above" references nothing. Copy the full Output Requirements from the principal-engineer template into both, or use a placeholder like `{SCHEMA_CONTENT}`.

### P1 -- Should fix before production

1. **Add an explicit variable substitution instruction.** In SKILL.md Step 4, after the bullet list of context fields, add: "Replace all `{PLACEHOLDER}` tokens in the persona prompt template with the actual values before sending to the teammate. Do not send literal placeholder strings."

2. **Define `{REVIEW_CONTEXT}` more precisely.** Replace "any relevant context from the brainstorming conversation" with something like: "A 2-3 sentence summary of the user's stated concerns and priorities from the brainstorming conversation, plus any specific instructions the user gave about review focus."

3. **Remove or reframe the "Enter delegate mode (Shift+Tab)" instruction.** This is a human-UI instruction that an LLM agent cannot execute. Either mark it clearly as a note for human operators (`> **Note for human operators:** ...`) or replace it with an agent-actionable instruction like "The lead should not write review files directly. The lead's role is to dispatch, monitor, and synthesize."

4. **Fix the Debate Notes step reference.** Change analysis-schema.md from "Added after the debate phase (Step 7)" to "Added after the debate phase (Step 6)" to match SKILL.md's numbering.

5. **Remove the duplicate `{ARTIFACT_TYPE}` line in Step 4.** Lines 127-128 of SKILL.md list `{ARTIFACT_TYPE}` twice. Remove the duplicate.

### P2 -- Consider improving

1. **Add a Common Mistakes entry for generic/ungrounded analysis.** Something like: "Writing generic observations not citing the artifact" / "Reviews become unfalsifiable" / "Cite specific sections, decisions, or quotes."

2. **Add a structured challenge template for the debate phase.** Currently, debate challenges are free-form messages. Providing a minimal structure (e.g., "State which finding you challenge, your counter-argument, and what evidence supports your position") would improve debate quality and consistency.

3. **Document the cross-run comparability trade-off.** Note somewhere (perhaps in analysis-schema.md) that because personas are generated dynamically, synthesis documents from different runs on the same artifact are not directly comparable.

4. **Move synthesis `overall-status` computation rule adjacent to the frontmatter spec.** Currently it appears in prose below the YAML block. Place it as a bullet immediately after the frontmatter code block for easier LLM parsing.

5. **Consider providing a literal spawn-prompt template.** Instead of requiring the lead to assemble the spawn prompt from bullet points, provide a fill-in-the-blank template that the lead populates. This reduces cross-run variability in how teammates are instructed.

## Sign-Off

**conditional-approve** -- The prompt architecture is sound and the persona/schema pattern is effective, but the schema-reference conflicts between SKILL.md and persona templates (P0 items) create a realistic failure mode where teammates receive dangling file references instead of actionable schema instructions. These must be resolved before the skill can reliably produce schema-conformant output across runs.
