---
topic: subagent-analysis-skill
date: 2026-02-08
personas: [workflow-architect, prompt-engineer, developer-experience, repo-hygiene-auditor]
mode: agent-team
---

## Decisions

### Q1: Placeholder token scope split
- **Question**: "Should unreplaced `{PLACEHOLDER}` tokens in SKILL.md's dispatch instructions (Step 4) — which document substitution targets — trigger repo-hygiene-auditor's reject criterion?"
- **Asked by**: prompt-engineer (challenge to repo-hygiene-auditor)
- **Resolved by**: orchestrator (from context — SKILL.md Step 4 lists tokens as instructions to the orchestrator, not as unreplaced values)
- **Answer**: No. Tokens in instructional context (documenting what the orchestrator must substitute) are excluded. Repo-hygiene-auditor owns static file checks; prompt-engineer owns runtime substitution risk.
- **Impact**: Repo-hygiene-auditor reject #4 sharpened to exclude "non-instructional" files. Prompt-engineer reject #2 reworded to focus on substitution instruction clarity.

### Q2: Cross-reference scope split between workflow-architect and repo-hygiene-auditor
- **Question**: "Who owns cross-reference validation — filesystem path resolution or semantic correctness?"
- **Asked by**: workflow-architect (proactive scope alignment with repo-hygiene-auditor)
- **Resolved by**: orchestrator (scope-based — each persona's defined scope covers a different aspect)
- **Answer**: Repo-hygiene-auditor checks that referenced file/directory paths exist on disk. Workflow-architect checks that resolved references are semantically correct (the referenced section describes the right thing).
- **Impact**: Repo-hygiene-auditor reject #1 narrowed to filesystem paths. Workflow-architect reject #4 reworded to "semantic cross-reference mismatch."

### Q3: superpowers:brainstorming as a prerequisite
- **Question**: "Is the `superpowers:brainstorming` skill reference in Step 9b a user-facing prerequisite that should be documented in README?"
- **Asked by**: developer-experience (raised as conditional criterion C5)
- **Resolved by**: repo-hygiene-auditor challenge — it's an LLM-internal skill invocation, not a user-installed dependency
- **Answer**: No. It's an agent behavior instruction, not a user prerequisite. Developer-experience accepted and removed C5, will note as P2 observation.
- **Impact**: Developer-experience C5 removed from rubric. Will appear as P2 observation in DX review.

## Rubric Challenges

### Challenge 1: Prose/diagram inconsistency severity (prompt-engineer → workflow-architect)
- **Challenger**: prompt-engineer
- **Target**: workflow-architect reject #3 (prose/diagram inconsistency)
- **Challenge**: Diagrams are visual aids for human readers, not authoritative specs for the LLM orchestrator. A diagram that doesn't perfectly match prose is not a workflow correctness issue — it's a readability issue. Reject is too aggressive.
- **Outcome**: Accepted. Downgraded to conditional #6. Replaced at reject level with "prose-to-prose contradiction" which captures the actual correctness risk.

### Challenge 2: README tree mismatch scope (developer-experience → repo-hygiene-auditor)
- **Challenger**: developer-experience
- **Target**: repo-hygiene-auditor reject #2 (README tree doesn't match filesystem)
- **Challenge**: A README tree that stops at a directory level without enumerating contents shouldn't be penalized for omissions below that level. Only omissions at depths the tree already enumerates are misleading.
- **Outcome**: Partially accepted. Added "at a depth the tree already enumerates" qualifier.

### Challenge 3: Output format scope (prompt-engineer → developer-experience)
- **Challenger**: prompt-engineer
- **Target**: developer-experience conditional #2 (output serves system not user)
- **Challenge**: Per-persona review files are system-intermediate artifacts consumed by the synthesis step, not primary user outputs. Evaluating their readability at the same severity as synthesis.md conflates audiences.
- **Outcome**: Accepted. C2 narrowed to user-facing outputs (synthesis.md, decision documents). Per-persona reviews noted as P2 only.

### Challenge 4: Progressive disclosure reframe (workflow-architect → developer-experience)
- **Challenger**: workflow-architect
- **Target**: developer-experience conditional #3 (progressive disclosure violated)
- **Challenge**: SKILL.md's internal complexity is appropriate — it's an orchestrator playbook. The criterion should target user touchpoints that leak internals, not the document's own detail level.
- **Outcome**: Accepted. C3 reframed from "9-step details exposed" to "user touchpoints leak orchestration internals."

### Challenge 5: "Just go" inference vs. confirmation UX (prompt-engineer → developer-experience)
- **Challenger**: prompt-engineer
- **Target**: developer-experience conditional #4 ("just go" inference guidance thin)
- **Challenge**: Thin inference guidance is an intentional prompt design choice — over-specifying inference rules would ossify persona selection. The real DX issue is whether the confirmation step gives the user enough context to decide.
- **Outcome**: Accepted. C4 reframed from inference quality to confirmation UX decision-support.

### Challenge 6: brainstorming dependency severity (repo-hygiene-auditor → developer-experience)
- **Challenger**: repo-hygiene-auditor
- **Target**: developer-experience conditional #5 (superpowers:brainstorming dependency)
- **Challenge**: This is an LLM-internal skill reference, not a user-installed prerequisite. It's like referencing a prompt pattern, not a package dependency.
- **Outcome**: Accepted. C5 removed from rubric, will appear as P2 observation.

### Challenge 7: Orchestrator state-tracking scope (workflow-architect + developer-experience → prompt-engineer)
- **Challengers**: workflow-architect, developer-experience
- **Target**: prompt-engineer conditional #2 (implicit capability assumption about orchestrator state tracking)
- **Challenge**: As worded, this criterion bleeds into workflow design (workflow-architect's scope) and user-visible progress (developer-experience's scope). Should be scoped purely to prompt/attention scaffolding.
- **Outcome**: Accepted. Reframed to "orchestrator state-tracking relies on conversation recall with no structured re-grounding." Focuses on attention-drift risk, not workflow design or user experience.

No rubric criteria were changed during cross-review that are not listed above.

## Final Rubrics

### workflow-architect

**Reject (any triggered → default reject)**
1. Unreachable terminal state (agent-team completion, fallback completion, or graceful degradation on majority failure)
2. Undefined behavior on step failure
3. Prose-to-prose contradiction between SKILL.md instructions or between SKILL.md and analysis-schema.md
4. Semantic cross-reference mismatch (resolved reference describes wrong data/format/behavior)

**Conditional-Approve (any triggered, no reject → default conditional-approve)**
1. Implicit ordering dependency between steps
2. Fallback mode behavior gap without acknowledgment
3. Ambiguous convergence/termination condition
4. Fallback-to-primary instruction mismatch (follow-up instructions to one-shot subagents)
5. rubrics.md generation gap between modes
6. Prose/diagram inconsistency (structural, not cosmetic)

**Approve (all must hold, no reject/conditional triggers)**
1. All terminal states reachable
2. Every step has defined failure behavior
3. All 3 diagrams structurally consistent with prose
4. Cross-references semantically correct (persona reviews, rubrics.md, synthesis.md, decision docs)
5. Both modes fully specified per-step (1-9)

### prompt-engineer

**Reject (any triggered → default reject)**
1. Instruction contradiction forcing LLM to guess (no resolution rule)
2. Dispatch instructions lack explicit placeholder substitution checklist or verification step
3. Missing critical context making teammate task uncompletable (schema not pasted, rubric not in context, artifact truncated)
4. Output format underspecified to point of structural non-determinism

**Conditional-Approve (any triggered, no reject → default conditional-approve)**
1. Rubric state persistence gap across multi-turn teammate interactions
2. Orchestrator state-tracking relies on conversation recall with no structured re-grounding
3. Schema-instruction drift between SKILL.md and analysis-schema.md
4. Attention-order problem in teammate spawn prompts (task at end after bulk content)
5. Debate convergence detection requires per-participant round counting unreliable for LLMs

**Approve (all must hold, no reject/conditional triggers)**
1. All placeholder tokens have defined substitution source with unambiguous instruction
2. Prompt ordering recommendation consistent and sound
3. Output schema deterministic enough for mechanical validation
4. Teammate prompts self-contained for initial task
5. Multi-step workflow has sufficient re-grounding points

### developer-experience

**Reject (any triggered → default reject)**
1. First-run path broken or undocumented
2. Output incomprehensible without reading source
3. Critical user-facing terminology contradictory (scoped to user-visible surfaces)
4. No feedback when things go wrong (env var, artifact size, teammate crash, majority failure)

**Conditional-Approve (any triggered, no reject → default conditional-approve)**
1. Prerequisite friction undisclosed or scattered (README-only test)
2. User-facing output prioritizes structure over utility (synthesis.md, decision docs)
3. User touchpoints leak orchestration internals
4. "Just go" confirmation step lacks decision-support context

**Approve (all must hold, no reject/conditional triggers)**
1. E2E path documented in README alone
2. Output self-contained and actionable (findings, disagreements, next steps)
3. User touchpoints clearly signposted (input needed vs. autonomous)
4. Terminology consistent across all user-visible surfaces
5. Degraded mode communicated with loss inventory

### repo-hygiene-auditor

**Reject (any triggered → default reject)**
1. Broken file/directory path reference in SKILL.md, analysis-schema.md, README, or CLAUDE.md
2. README file-structure tree inaccurate at enumerated depth
3. Source/cache divergence on runtime files (SKILL.md, analysis-schema.md, persona examples)
4. Unreplaced placeholders in non-template, non-instructional files

**Conditional-Approve (any triggered, no reject → default conditional-approve)**
1. Design docs describe stale status/architecture
2. Step-number inconsistencies in source files
3. Old analysis runs in pre-schema format tracked by git
4. Source/cache divergence on non-runtime files

**Approve (all must hold, no reject/conditional triggers)**
1. Every file/directory path reference resolves
2. README tree matches filesystem at enumerated depths
3. Source/cache identical on runtime files or divergence documented
4. No unreplaced placeholders in non-template, non-instructional files
5. Step numbering consistent across source files
