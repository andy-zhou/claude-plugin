---
persona: developer-experience
date: 2026-02-08
artifact: subagent-analysis skill (SKILL.md + analysis-schema.md + persona examples + README + CLAUDE.md)
scope: Ease of invocation, documentation clarity, brainstorming UX, output readability, onboarding friction, naming conventions
sign-off: conditional-approve
confidence: high
---

## Summary

Reviewed the subagent-analysis skill from the perspective of a developer who has never seen it before, evaluating invocation ergonomics, documentation clarity, onboarding friction, output readability, and naming conventions across SKILL.md, analysis-schema.md, three example persona templates, CLAUDE.md, and README.md. The headline finding is that the skill is well-documented and the workflow is clearly articulated, but a first-time user faces significant onboarding friction from the experimental agent-teams prerequisite, an unclear invocation path, and a SKILL.md that conflates orchestrator instructions with user-facing documentation.

## Analysis

### Invocation Experience

The skill is declared `user-invocable: true` with `argument-hint: "[artifact-path]"`, which means a user can type `/subagent-analysis path/to/spec.md` to invoke it. This is clean and discoverable once the user knows the command exists. However, the README does not show this invocation syntax anywhere. The README documents installation (`/plugin marketplace add`, `/plugin install`) but never shows the actual usage command. A user who successfully installs the skill has no documented path to "now what?" The README's job is not done until it shows `Usage: /subagent-analysis <artifact-path>`.

Additionally, the `argument-hint` uses square brackets (`[artifact-path]`), which conventionally means "optional." But the skill requires an artifact to review. If invoked without an argument, the SKILL.md says "If `$ARGUMENTS` is provided, treat it as the artifact path to review" -- but never says what happens when it is NOT provided. The user must presumably be asked, but this fallback is not specified.

### Onboarding Friction

The most significant onboarding friction is the agent-teams experimental requirement. A new user must:

1. Clone the repo
2. Register the marketplace
3. Install the plugin
4. Discover they need `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
5. Figure out where to set it (settings JSON? environment variable? which settings file?)
6. Restart Claude Code (presumably)

Steps 4-6 are where most users will get stuck. The README mentions the env var and shows a JSON snippet, but does not say WHERE to put that JSON. Is it `~/.claude/settings.json`? A project-level `.claude/settings.json`? An environment variable export in `.bashrc`? The SKILL.md's prerequisite section mentions "in settings or environment" but this is ambiguous. For an experimental feature, handholding here is especially important because the user cannot look this up in stable documentation.

The fallback to Task-tool dispatch partially mitigates this -- the skill works without agent teams, just without debate. But the README frames agent teams as the primary mode ("requires agent teams"), making the fallback feel like a degraded experience rather than a legitimate mode.

### SKILL.md Audience Confusion

SKILL.md serves two audiences simultaneously, and this creates confusion:

1. **The orchestrating LLM agent** -- which reads SKILL.md to know what steps to execute
2. **A human developer** -- who might read SKILL.md to understand what the skill does

The document is primarily written for audience #1 (e.g., "Use AskUserQuestion tool for each question," "Enter delegate mode (Shift+Tab)," "Create a task for each teammate"). This is correct -- SKILL.md is an agent instruction set. But there is no separate human-readable "how this works" document. A developer who opens SKILL.md looking for a quick understanding must parse detailed agent orchestration instructions to piece together the workflow.

The ASCII diagrams in Steps 2 and 6 partially address this by providing visual flow summaries. These are genuinely helpful and one of the strongest developer-experience features of the document.

### Brainstorming UX (Step 2)

The brainstorming step is well-designed from a UX perspective:

- ONE question at a time (prevents wall-of-text fatigue)
- Maximum 5 questions (bounded interaction)
- "Just go" escape hatch (respects user's time)
- User confirms personas before dispatch (no surprise charges to context budget)

One concern: the instruction to "pick the most relevant, not all" from the suggested questions is good guidance, but the questions themselves are somewhat generic. For a first invocation, a user who says "just go" will get the most generic output, while a user who engages with all 5 questions will get a tailored review but may feel the questions are repetitive. The tradeoff is reasonable.

A missing UX consideration: there is no guidance on what happens if the user wants to ADD a persona after seeing the proposed set, or REMOVE one. The instruction says "present for confirmation" but does not specify handling "these three are good but also add a performance reviewer" or "drop the security one, this is internal-only."

### Output Readability

The analysis-schema.md defines a clean, consistent output format. The per-persona review format is well-structured: frontmatter for machine-parseable metadata, then human-readable sections in a logical order (Summary for the headline, Analysis for depth, Assumptions for transparency, Recommendations for action, Sign-Off for the decision).

The P0/P1/P2 priority tiering is intuitive and matches industry convention. The requirement for "None identified." when a tier is empty prevents ambiguity between "I found nothing" and "I forgot to look."

The synthesis document format is also clean. The Conflicts section with Resolution-source metadata is particularly well-designed -- it makes the conflict resolution process auditable.

One readability concern: the output directory structure `.subagent-analysis/{topic}/{run-id}/` uses a leading dot, making the output hidden by default on Unix systems. A user running `ls` after analysis completes will not see the output unless they know to use `ls -a` or were told the path. The skill does present a summary in Step 8, but if the user wants to browse the files later (or share them), the hidden directory is a minor stumbling block. This is a deliberate convention choice (keeping analysis artifacts out of the main project tree), so it is a tradeoff rather than a bug.

### Naming Conventions

Naming is generally consistent and intuitive:

- **Persona names**: kebab-case slugs (`security-engineer`, `principal-engineer`) -- clear, predictable, filesystem-safe
- **Topic slug**: kebab-case, derived from the artifact -- good
- **Run ID**: `YYYYMMDD-HHMMSS` -- sortable, prevents collisions, human-readable
- **File structure**: `{persona-name}.md` + `synthesis.md` -- simple and discoverable

One minor inconsistency: the schema refers to persona name as `<persona name, e.g. "security-engineer">` using a hyphenated slug, but the frontmatter field is just `persona:` with no specification that it must match the filename. If a persona writes `persona: Security Engineer` (title case) instead of `persona: security-engineer` (kebab-case), it would pass casual validation but break any automated tooling that correlates filenames to frontmatter.

### Common Mistakes Table

The Common Mistakes table at the end of SKILL.md is an excellent developer-experience feature. It is concise, tabular (scannable), and covers the most impactful failure modes. The three-column format (Mistake / Why it's wrong / What to do instead) is pedagogically effective.

The table's value is primarily for the orchestrating LLM, not a human developer. But it also serves as a diagnostic reference if a human is troubleshooting why a run produced poor results -- they can scan the table for likely causes.

One weakness: the table lacks an entry for "User invokes skill without an artifact path." This is arguably the most common first-time mistake.

### Documentation Completeness

- **README.md**: Covers installation, file structure, and modification guidance. Missing: usage example, example output, what to expect when running the skill.
- **CLAUDE.md**: Appropriately concise for session instructions. The pointer to README is good. The "Modifying or Creating Skills" section references `superpowers:writing-skills`, which is useful governance.
- **analysis-schema.md**: Complete and well-structured. The only gap is that the Debate Notes section references "Step 7" when it should reference "Step 6" (the debate is Step 6; synthesis is Step 7). This is a minor documentation bug that could confuse a reader cross-referencing SKILL.md.
- **Persona examples**: All three follow an identical structure, which is exactly what examples should do. They are effective as templates. However, they reference `analysis-schema.md` by name in the Output Requirements section without including its content -- which contradicts Step 4's instruction to paste the full schema into the spawn prompt. The examples show what the LLM should reference, but in practice the schema will be inlined. This could confuse someone trying to understand how examples map to actual dispatch.

### Fallback Experience

The Task-tool fallback is documented in a dedicated section at the bottom of SKILL.md. It is brief and clear: Step 4 changes, Step 6 is skipped, Step 8 simplifies. This is good.

However, the fallback is framed as an afterthought ("If agent teams are not available..."). Given that agent teams are experimental and many users will not have them enabled, the fallback may actually be the PRIMARY experience for most users. The documentation should acknowledge this more prominently. Consider noting at the top of the workflow that "the full workflow includes debate (Steps 6); users without agent teams get a streamlined version that skips debate."

Additionally, the fallback section does not address what specific error or signal tells the skill that agent teams are unavailable. Does it check the environment variable? Does it try and fail? Does it ask the user? The Prerequisites section says "If not enabled, inform the user how to enable it and fall back" but the mechanism is unspecified.

## Assumptions

- The user is familiar with Claude Code plugins and the `/plugin` command system.
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is a real environment variable that Claude Code checks (not verified independently).
- The `$ARGUMENTS` variable is populated by Claude Code's skill invocation system when the user provides an argument after the skill name.
- `${CLAUDE_PLUGIN_ROOT}` resolves correctly to the plugin's installation directory at runtime.
- The `superpowers:writing-skills` skill referenced in CLAUDE.md exists and is available to users of this repo (not verified).

## Recommendations

### P0 -- Must fix before proceeding

None identified.

### P1 -- Should fix before production

1. **Add usage example to README.md.** The README covers installation but not invocation. Add a "Usage" section showing `/subagent-analysis path/to/my-spec.md` and briefly describe what happens (brainstorming, parallel review, synthesis). A first-time user should not need to read SKILL.md to know how to run the skill.

2. **Specify where to configure the agent-teams environment variable.** The README shows the JSON `{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }` but does not say which file this JSON belongs in. Add the file path (e.g., `~/.claude/settings.json` or project-level equivalent) so users do not have to guess.

3. **Document the no-argument invocation behavior.** SKILL.md says "If `$ARGUMENTS` is provided, treat it as the artifact path" but is silent on what happens without arguments. Specify: "If no argument is provided, ask the user for the artifact path using AskUserQuestion."

4. **Fix the Debate Notes step reference in analysis-schema.md.** Line 75 of analysis-schema.md says "Added after the debate phase (Step 7)" but the debate phase is Step 6 in SKILL.md. The synthesis is Step 7. This should read "Added after the debate phase (Step 6)."

### P2 -- Consider improving

1. **Reframe the fallback as a first-class mode, not a degraded experience.** Many users will run without agent teams. Consider renaming the section from "Fallback" to "Modes of Operation" with two subsections: "With Agent Teams (full workflow)" and "Without Agent Teams (streamlined)." This sets appropriate expectations.

2. **Add a "What to expect" section to the README or SKILL.md preamble.** Briefly describe: "The skill will ask you a few questions, propose reviewer personas, dispatch parallel reviews, optionally facilitate debate, and produce a synthesis. Typical output is 3-5 review files and a synthesis document in `.subagent-analysis/`."

3. **Specify that the persona frontmatter `persona:` field must match the filename slug.** This prevents drift between filenames and metadata, which could break tooling or confuse readers.

4. **Add a Common Mistakes entry for no-argument invocation.** The table is otherwise comprehensive, but the most common first-time error (invoking without specifying an artifact) is missing.

5. **Consider making the output directory non-hidden.** The `.subagent-analysis/` directory is invisible by default in file listings. If the intent is to keep analysis out of the project tree, a `.gitignore` entry would accomplish the same without hiding the directory. If the hidden-by-default behavior is intentional, document it explicitly so users know to look for it.

6. **Clarify persona modification flow in Step 2.** After presenting proposed personas, note that the user can add, remove, or modify personas before confirming. The current text says "present for confirmation" which implies an accept/reject binary, not an iterative refinement.

7. **Add a brief note in persona examples explaining that the `analysis-schema.md` reference will be replaced with inline content at dispatch time.** This prevents confusion when someone reads an example and then reads Step 4's instruction to paste the full schema.

## Sign-Off

**conditional-approve** -- The skill is well-designed and the workflow is clearly documented for the orchestrating agent, but the P1 items (missing usage example in README, ambiguous env-var configuration location, undefined no-argument behavior, and a step-number documentation bug) should be addressed before the skill is promoted to other users. None are blocking for an author who already knows the skill, but they will cause confusion for first-time users.
