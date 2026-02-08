---
persona: developer-experience
date: 2026-02-08
artifact: subagent-analysis skill (SKILL.md, analysis-schema.md, persona examples, README, CLAUDE.md, design docs)
scope: Usability, first-run experience, output comprehensibility, documentation completeness, terminology consistency, and user mental model alignment
sign-off: conditional-approve
confidence: high
---

## Summary

Reviewed the subagent-analysis skill from the perspective of a new user who invokes `/subagent-analysis`, interacts with the brainstorming and decision-review phases, and reads the generated output. The skill has a well-structured README that covers the end-to-end path from installation to first output, consistent terminology across user-visible surfaces, and a synthesis output format designed around decision-making. However, the skill triggers conditional-approve due to two issues: the "just go" fast-path's persona confirmation step lacks guidance on what information the user needs to evaluate the auto-inferred personas, and the README's fallback mode description omits a concrete inventory of what the user loses versus retains.

## Analysis

### First-Run Experience (README as sole guide)

The README (lines 9-49) provides a complete installation and usage path: clone, register marketplace, install plugin, enable env var, invoke with `/subagent-analysis path/to/my-spec.md`. The three-step installation (clone, marketplace add, plugin install) is presented in order with code blocks. The env var requirement is documented immediately after installation with the specific JSON to add to settings.

The Usage section (lines 38-49) concisely describes what happens after invocation: 1-5 brainstorming questions, persona confirmation, parallel dispatch, optional debate, synthesis. The "just go" shortcut is mentioned. Output location (`.subagent-analysis/{topic}/{run-id}/`) is stated with a description of what files appear.

**Finding:** The README's Installation section references `<repo-url>` as a placeholder (line 15: `git clone <repo-url>`). This is standard for a private/internal repo README, but a user copying this literally would get a git error. Minor friction, not a blocker -- any developer would recognize the placeholder.

**Finding:** The README does not mention that the file structure tree in lines 53-85 shows the *plugin repo* structure separately from the *runtime output* structure (lines 78-85, shown as comments). This two-part tree is clear on close reading but could be missed by a skimmer who sees one `tree` block and assumes it's all in one place.

### Output Comprehensibility

The synthesis document format (analysis-schema.md lines 132-195) is structured for decision-making: Overall Status, Consensus, Conflicts (with resolution source), Consolidated Recommendations by priority, Open Questions, Next Steps. A reader who was not present during the analysis can follow this structure to answer: (a) what's the overall verdict, (b) where did reviewers agree/disagree, (c) what should I do next.

The decision document format (analysis-schema.md lines 263-326) is similarly user-oriented: Context, Options Considered, Decision, Consequences, Dissent. Each decision is self-contained and references back to the synthesis.

**Finding:** The synthesis schema uses terms like `Resolution-source: debate`, `Resolution-source: domain-authority`, and `Resolution-source: escalated` (analysis-schema.md lines 165-169). These are clear in context but "domain-authority" is jargon that a non-participant reader might not immediately parse. The phrase "resolved by the lead based on which persona's scope most directly covers the topic" (line 167-168) is clear, but the shorthand label `domain-authority` is less so. This is a minor readability issue, not a blocker -- the explanation accompanies the label.

**Finding:** The per-persona review format includes a Rubric Assessment table with Derived Sign-Off, Actual Sign-Off, and Override Justification (analysis-schema.md lines 107-118). For a reader of the synthesis, this internal rubric machinery is not needed -- the synthesis already states which persona drove the most restrictive sign-off (analysis-schema.md line 155). The per-persona files are intermediate artifacts, and their structural density is appropriate for system consumption. The user-facing synthesis abstracts the relevant conclusions. This is well-designed.

### Terminology Consistency

I checked the following key terms across README, SKILL.md, analysis-schema.md, and persona example templates:

- **Sign-off values** (`approve`, `conditional-approve`, `reject`): Used consistently across SKILL.md (Step 6 validation, line 307), analysis-schema.md (frontmatter definition, lines 35-46), and persona templates (Output Requirements sections). No contradictions.
- **Priority levels** (P0, P1, P2): Defined identically in analysis-schema.md (lines 96-105) and referenced consistently in SKILL.md Step 9a (line 437) and synthesis schema (lines 177-186).
- **Mode names** ("agent team mode" and "Task-tool fallback"): Used consistently in SKILL.md (comparison table lines 492-498) and README (line 34: "falls back to Task-tool subagent dispatch"). The README uses "Task-tool subagent dispatch" while SKILL.md uses "Task-tool fallback" -- these are compatible phrasings in their respective contexts (user-facing vs. orchestrator-facing), not contradictory.
- **Topic and run-id**: Defined in SKILL.md Steps 1 and 3, referenced in analysis-schema.md output location, and documented in README Usage section. Consistent.
- **"Debate"**: README says "debate each other's findings" (line 45). SKILL.md uses "Findings Debate" (Step 7 heading) and "debate phase" (Step 8 line 411). Analysis-schema.md uses "debate phase" (line 121). All refer to the same concept without contradiction.

**Finding:** No contradictory terminology identified across user-visible surfaces.

### Failure Communication

SKILL.md documents several failure modes with user-facing communication:

- **Missing env var** (Prerequisites item 4, line 25): "inform the user how to enable it and fall back to Task-tool subagent dispatch." The user is told what happened and the system degrades gracefully.
- **Artifact too large** (line 30-32): "For very large artifacts that may exceed context limits, consider splitting into sections and running separate analyses per section." This is guidance to the orchestrator; the user would be told by the orchestrator if splitting is needed.
- **Teammate failure** (Step 6, lines 313-316): "If a teammate failed to produce any output... proceed with available reviews and note the missing persona in synthesis." If majority failed, "inform the user and ask whether to proceed with synthesis or re-run."
- **Schema validation failure** (Step 6, lines 312): "Note the issues but proceed (do not re-dispatch)."

**Finding:** The failure paths are defined for the orchestrator but are not explicitly scripted for the user. The orchestrator is told *what to do* (fall back, proceed, inform) but not *what to say* to the user. For example, if the env var is missing, the instruction is "inform the user how to enable it" -- but the specific message is left to the LLM. This is appropriate for an LLM orchestrator (it can generate clear messages) but means the error communication quality depends on LLM behavior, not documentation. This is not a gap in the artifact -- it's an inherent characteristic of LLM-orchestrated tools. I do not trigger R4 on this.

### Degraded Mode Communication

README line 34 states: "Without agent teams enabled, the skill falls back to Task-tool subagent dispatch (no debate phase)." This tells the user what's different (no debate) but not what's preserved. The SKILL.md fallback section (lines 486-509) provides a detailed comparison table, but this is orchestrator-facing, not user-facing.

**Finding:** The README's fallback description is incomplete as a user communication. It says "no debate phase" but doesn't mention that rubric hardening (Step 5) is also skipped, nor does it state what is preserved (parallel reviews, synthesis, decision documents). A user reading only the README would know they lose debate but not know about the rubric hardening loss or what they still get. The SKILL.md comparison table (lines 492-498) is comprehensive but lives in an orchestrator document the user doesn't read.

### "Just Go" Fast-Path Experience

Step 2 (SKILL.md lines 63-66) says: "If the user says 'just go': Infer appropriate personas from the artifact type and content. For example, a tech spec likely needs architecture, security, and operability perspectives."

Step 2 also requires (line 79): "Present the proposed personas to the user for confirmation before proceeding." This applies to both the brainstorming path and the "just go" path -- the user always sees the proposed personas before dispatch.

**Finding:** The confirmation step exists, which is good. However, the skill does not specify what the user should see at confirmation time beyond the persona definition output (name, role, scope, analytical lens -- lines 68-73). It does not instruct the orchestrator to explain *why* these personas were chosen for this artifact, what angles are *not* covered, or how the user should evaluate whether the set is sufficient. For a user who said "just go" and skipped brainstorming, the confirmation is their only quality gate. Without context on the reasoning behind the selection, the user must evaluate the personas based solely on their names and one-line roles, which may not be enough to catch a missing perspective.

### Progressive Disclosure at User Touchpoints

Step 9a (SKILL.md lines 434-439) instructs the orchestrator to present: overall status, P0/P1/P2 counts, conflicts and their resolutions, open questions. This is well-structured for user consumption -- it leads with the verdict and then provides detail.

Step 9b (lines 441-452) describes the decision-review conversation: go through recommendations by priority, surface conflicts and dissent, ask the user what to do. The user is given agency (accept, reject, defer, modify) and can batch or skip items.

**Finding:** The Step 9a summary format is appropriately user-facing. It does not expose step numbers, internal mode names, or schema terminology. The instructions reference "which were resolved by debate vs. authority" (line 438), which uses the `Resolution-source` vocabulary from the schema. If the orchestrator passes through terms like "domain-authority" verbatim, the user would encounter jargon. However, a competent LLM would paraphrase these ("resolved based on which reviewer had the most relevant expertise"). This is a minor risk that depends on LLM behavior, not a gap in the artifact's instructions.

### superpowers:brainstorming Dependency

Step 9b (line 442) references `superpowers:brainstorming` as the method for collaborative review. This is an internal skill invoked by the orchestrating LLM, not a user-installed dependency. If the skill is unavailable, the orchestrator would conduct the decision review as a regular conversation, which is a graceful degradation the user would not notice (they'd still get asked questions one at a time). This is not a conditional-level concern.

## Assumptions

- The Claude Code plugin marketplace commands (`/plugin marketplace add`, `/plugin install`) work as documented in the README. I have not verified these commands against the actual Claude Code CLI.
- The `superpowers:brainstorming` skill is an LLM-internal skill that the orchestrator invokes, not a separately installed plugin that the user must set up.
- The user's primary consumption path is: README for setup, then the generated output files (synthesis.md, decision documents) for results. Users do not need to read SKILL.md, analysis-schema.md, or CLAUDE.md to use the skill.
- A "competent LLM" orchestrator will paraphrase schema jargon (e.g., "domain-authority") into plain language when presenting to the user. The quality of user-facing communication depends on LLM behavior, which is outside the scope of this documentation review.

## Recommendations

### P0 — Must fix before proceeding

None identified.

### P1 — Should fix before production

1. **Add loss inventory to README fallback description.** README line 34 says "no debate phase" but omits that rubric hardening is also skipped and doesn't state what is preserved. Suggested revision: "Without agent teams enabled, the skill falls back to Task-tool subagent dispatch. You still get parallel expert reviews, a synthesis with conflict resolution, and decision documents -- but rubric hardening and inter-persona debate are skipped, so reviews use pre-assigned rubrics and conflicts are resolved by the lead rather than through reviewer discussion." This gives the user a complete mental model of both modes.

2. **Specify confirmation-step content for the "just go" path.** Step 2 requires persona confirmation but doesn't instruct the orchestrator on what to present beyond name/role/scope/lens. Add guidance such as: "When presenting inferred personas for confirmation, briefly explain why each was chosen for this artifact type and note any major angles that are not covered (e.g., 'I did not include a security persona because this is a pure UI spec -- add one if security is relevant')." This makes the confirmation step an effective quality gate rather than a rubber stamp.

### P2 — Consider improving

1. **Clarify the two-part file structure tree in README.** The README's File Structure section (lines 53-85) shows the plugin repo tree followed by a runtime output tree in comments. Consider adding a brief label or separator (e.g., a sentence between the two saying "When you run the skill in another project, it creates the following output structure:") to help skimmers distinguish plugin structure from runtime output.

2. **Consider plain-language alternatives for Resolution-source labels.** The synthesis schema uses `debate`, `domain-authority`, and `escalated` as resolution-source values. `debate` and `escalated` are self-explanatory, but `domain-authority` could be replaced with something like `scope-based` or `expertise-based` for readability. This is minor -- the explanation accompanies the label in every use.

3. **Note superpowers:brainstorming graceful degradation.** Step 9b references this skill without indicating what happens if it's unavailable. A parenthetical note like "(if unavailable, conduct the collaborative review as a standard brainstorming conversation)" would make the fallback explicit rather than relying on the LLM to improvise.

4. **Per-persona review readability for optional human readers.** The per-persona review files are system-intermediate artifacts, but some users will read them for detail beyond the synthesis. The Rubric Assessment table format (Derived/Actual/Override) is dense but functional. No change required, but consider noting in the README's output description that per-persona files are "detailed reviewer reports (structured for synthesis processing; readable but dense)."

## Rubric Assessment

### Criteria Evaluated

| Criterion | Level | Triggered | Evidence |
|-----------|-------|-----------|----------|
| First-run path is broken or undocumented | reject | No | README documents complete install-to-invoke path (lines 9-49). `<repo-url>` placeholder is standard, not a blocker. |
| Output is incomprehensible without reading source | reject | No | Synthesis schema (analysis-schema.md lines 132-195) and decision doc format (lines 263-326) are self-contained and decision-oriented. User does not need to read SKILL.md or schema to understand output. |
| Critical user-facing terminology is contradictory | reject | No | All key terms (sign-off values, priority levels, mode names, topic/run-id, debate) are used consistently across user-visible surfaces. See Analysis: Terminology Consistency. |
| No feedback when things go wrong | reject | No | SKILL.md documents failure paths with user-communication instructions for missing env var (line 25), teammate failure (lines 313-316), and majority failure (lines 315-316). Communication quality depends on LLM behavior, but the instructions are present. |
| Prerequisite friction undisclosed or scattered | conditional | No | README documents all user prerequisites (clone, marketplace, plugin install, env var) in a single Installation section (lines 9-32). No critical setup step is scattered or missing. |
| User-facing output prioritizes structure over utility | conditional | No | Synthesis.md schema leads with Overall Status, then Consensus, Conflicts, Consolidated Recommendations, Open Questions, Next Steps. This serves decision-making. Decision documents are similarly user-oriented. |
| User touchpoints leak orchestration internals | conditional | No | Step 9a summary format (lines 434-439) presents user-relevant information (status, counts, conflicts, open questions) without exposing step numbers or mode names. Minor risk of schema jargon leaking depends on LLM behavior, not artifact instructions. |
| "Just go" confirmation step lacks decision-support context | conditional | Yes | Step 2 requires persona confirmation (line 79) but does not instruct the orchestrator on what context to present: why these personas were chosen, what angles are not covered. See Analysis: "Just Go" Fast-Path Experience. |
| E2E path documented in README alone | approve | Yes | README covers clone to first output without requiring the user to consult SKILL.md, CLAUDE.md, or analysis-schema.md. |
| Output is self-contained and actionable | approve | Yes | Synthesis answers: (a) findings via Overall Status and Consensus, (b) disagreements via Conflicts with resolution, (c) next steps via Consolidated Recommendations and Next Steps. Decision documents are self-contained. |
| User touchpoints are clearly signposted | approve | Yes | User provides input at brainstorming (Step 2) and decision review (Step 9). Autonomous phases (dispatch, rubric hardening, debate, synthesis) do not require user action. No ambiguous waiting states in the documented workflow. |
| Terminology is consistent across all user-visible surfaces | approve | Yes | See Analysis: Terminology Consistency. No contradictions found. |
| Degraded mode is communicated with loss inventory | approve | No | README line 34 says "no debate phase" but omits rubric hardening loss and does not state what is preserved. The loss inventory is incomplete. See Analysis: Degraded Mode Communication. |

### Derived Sign-Off: conditional-approve

Two conditional criteria evaluated. One triggered ("Just go" confirmation step lacks decision-support context). One approve criterion not met (degraded mode loss inventory incomplete). No reject criteria triggered.

### Actual Sign-Off: conditional-approve

## Debate Notes

### Challenges Received

**1. repo-hygiene-auditor challenged P1 #1 (README fallback loss inventory) -- overlap with staleness finding.**
The auditor noted that the incomplete fallback description at README line 34 is both a staleness issue (their scope -- the line was not updated when rubric hardening was added) and a DX issue (my scope -- even if updated, it should include a full loss inventory). We agreed on attribution: root cause is staleness (their finding), remedy is a full loss inventory (my recommendation). No change to my finding or severity -- the recommended fix addresses both issues simultaneously.

**2. No other direct challenges received on my findings or severity ratings.**

### Challenges Sent

**1. Challenged repo-hygiene-auditor's reject severity on source/cache divergence (P0 #1, reject criterion R3).**
Argued that the cache at `~/.claude/plugins/cache/` is a deployment artifact, not a skill design defect. The auditor's own Assumptions section acknowledges uncertainty about whether the cache is auto-built or static. If R3 were downgraded, the auditor's sign-off would move from reject to conditional-approve. Response pending at time of convergence call.

**2. Provided calibration context to workflow-architect on P1 #1 (fallback Step 6 instruction mismatch).**
Noted that while the specification gap is real, the user-facing risk is minimal -- a competent LLM would skip the instruction step and proceed to validation. The workflow-architect agreed on the user-impact calibration but maintained P1 for specification completeness, noting the fix is trivial (one sentence). Position: complementary, not conflicting. The synthesis should weight the spec gap (their finding) separately from the user impact (low).

**3. Challenged prompt-engineer's P2 #3 (simplify debate convergence detection).**
Argued that the current three-condition design serves users better than the simplified alternative: early termination saves user wait time, and the silence-vs-"no challenges" distinction provides a crashed-teammate detection signal. The prompt-engineer accepted the trade-off framing and will note it in their Debate Notes. Both agreed that P1 #2 (structured state tracking) is the preferred fix because it makes the existing conditions evaluable without simplifying them.

### Position Changes

No changes to my findings, severity ratings, or sign-off. The debate confirmed the calibration of both P1 findings and all P2 observations. The overlap with the repo-hygiene-auditor on the fallback loss inventory was clarified with clean attribution, not a severity change.

## Sign-Off

**conditional-approve** -- The skill provides a complete first-run path, consistent terminology, and a well-structured synthesis output, but the "just go" fast-path's confirmation step lacks guidance on what context to present to the user, and the README's fallback mode description needs a concrete loss inventory to give users a complete mental model of both operating modes.
