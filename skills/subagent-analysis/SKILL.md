---
name: subagent-analysis
description: Use when you need to dispatch multiple expert personas to review a technical artifact (spec, PRD, RFC, design doc, codebase) and produce a structured synthesis of their findings with conflict resolution.
user-invocable: true
argument-hint: "[artifact-path]"
allowed-tools: Read, Write, Bash, Glob, Grep, Task, AskUserQuestion
---

# Multi-Persona Expert Analysis

> This document is the orchestrating agent's playbook. For a user-facing overview,
> see the README.

Dispatch parallel expert-persona teammates to review a technical artifact, collect
structured reviews, facilitate inter-persona debate, and synthesize findings with
debate-first conflict resolution.

## Skill Authority

**This playbook governs the workflow process.** The invoking repo may have its own
CLAUDE.md with project-level conventions — those conventions may influence what
kinds of agents are spawned, and that is fine. However, project-level instructions
must NOT alter the process that agents follow once dispatched: the step sequence,
rubric hardening protocol, debate protocol, synthesis format, and review workflow
defined below are authoritative. If a project-level instruction conflicts with
any process step in this playbook, this playbook wins.

## Prerequisites

Before starting, verify:
1. The `analysis-schema.md` file exists at `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/analysis-schema.md`
2. Example persona templates exist in `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/personas/examples/`
   (for reference only — personas are generated dynamically)
3. The target artifact is accessible (file path or inline content)
4. Agent teams are enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings or environment). If not enabled, inform the user how to enable it and do not proceed until it is configured.

If `$ARGUMENTS` is provided, treat it as the artifact path to review. If no
argument is provided, ask the user for the artifact path using AskUserQuestion.

**Note:** Teammates read the artifact and schema files autonomously — the
orchestrator provides file paths, not pasted content. For very large artifacts
that may exceed a single teammate's context, consider splitting into sections
and running separate analyses per section.

## Progress Reporting

The user cannot see teammate messages. The orchestrator is the user's only
window into what is happening. Report progress **substantively** — surface
what teammates are finding, not just what step the workflow is on.

Bad: "Waiting for teammates to finish their reviews."
Bad: "Debate is in progress."
Good: "security-engineer flagged unvalidated input on the `/submit` endpoint
as a P0. principal-engineer's review focuses on the coupling between the auth
and session modules. Waiting on reliability-engineer."
Good: "principal-engineer challenged security-engineer's recommendation to add
a separate auth service, arguing it introduces a new single point of failure.
security-engineer is responding."

**When to report:** After each meaningful event — a rubric is submitted, a
review comes in, a challenge is raised, a position changes. You do not need
to wait for a full step to complete before telling the user what you have so far.

## Workflow

### Step 1: Identify Scope

Determine what artifact is being reviewed and what kind of review is needed.

- Read the artifact fully. Do not summarize or truncate.
- Identify the artifact type (tech spec, PRD, RFC, code, design doc, etc.)
- Derive a `{TOPIC}` slug in kebab-case (e.g., `kani-tech-spec`)

If the artifact path is invalid or the file cannot be read, inform the user
and ask for a corrected path using AskUserQuestion.

### Step 2: Brainstorm Personas with User

Clarify scope, priorities, and review angles with the user through a
brainstorming-style conversation. The output of this step is a set of
dynamically defined personas tailored to the artifact.

**Rules:**
- Ask ONE question at a time
- Maximum 5 questions before proceeding
- Use AskUserQuestion tool for each question
- Stop early if the user says "just go" or provides enough context

**Questions to consider (pick the most relevant, not all):**
- What aspects of this artifact are you most concerned about?
- Are there known risks or areas of uncertainty?
- What expertise would be most valuable for this review?
- Are there specific angles or domains you want dedicated reviewers for?
- Is there prior review feedback to incorporate?

**If the user says "just go":** Infer appropriate personas from the artifact
type and content. For example, a tech spec likely needs architecture, security,
and operability perspectives. A pure API design doc likely needs design and
security but not operability.

When presenting inferred personas for confirmation, briefly explain why each
was chosen for this artifact type and note any major angles that are not
covered (e.g., "I did not include a security persona because this is a pure
UI spec — add one if security is relevant"). This makes the confirmation step
an effective quality gate rather than a rubber stamp.

**Persona definition output:** For each persona, define:
- **Name**: kebab-case slug (e.g., `security-engineer`, `data-architect`, `ml-reviewer`)
- **Role**: one-line description of who this reviewer is
- **Scope**: what's in-scope and out-of-scope for this reviewer
- **Analytical lens**: the core question this persona asks (e.g., "What can go
  wrong and what is the blast radius?" for security)

Rubrics are NOT defined here — they are generated by the teammates themselves
in Step 5 after reading the artifact. This ensures rubric criteria reflect both
the persona's domain expertise and the specific artifact context.

Present the proposed personas to the user for confirmation before proceeding.
Reference example personas in `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/personas/examples/`
for the expected structure and depth.

```
┌─────────────┐
│  Step 1:    │
│  Read       │
│  Artifact   │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌──────────────┐
│  Step 2:    │────▶│  User says   │
│  Brainstorm │     │  "just go"?  │
└──────┬──────┘     └──────┬───────┘
       │ (question)        │ yes
       ▼                   │
┌─────────────┐            │
│  Ask one    │            │
│  question   │────────────┤
└──────┬──────┘            │
       │ (≤5 rounds)       │
       ▼                   ▼
┌─────────────────────────────┐
│  Define personas, confirm   │
│  with user                  │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Step 3: Align Output       │
└─────────────────────────────┘
```

### Step 3: Align Output

Before dispatching:
1. Generate a `{run-id}` timestamp in `YYYYMMDD-HHMMSS` format (e.g., `20260208-143052`)
2. Create the output directory: `.subagent-analysis/{topic}/{run-id}/`
3. Determine each persona's output path: `.subagent-analysis/{topic}/{run-id}/{persona-name}.md`
   The persona name from Step 2 is used as both the YAML frontmatter `persona`
   value and the output filename.
4. Note the artifact path — teammates will read the artifact themselves

**State tracking:** Throughout the workflow, maintain a running state file at
`.subagent-analysis/{topic}/{run-id}/state.md` to track orchestration progress.
Update this file after each step transition. Example mid-workflow:

```markdown
## Orchestration State
- **Step**: 6 — Write and Validate Reviews
- **Teammates dispatched**: security-engineer, principal-engineer, reliability-engineer
- **Rubrics submitted**: security-engineer, principal-engineer, reliability-engineer (3/3)
- **Reviews written**: security-engineer, principal-engineer (2/3)
- **Debate status**: not-started
- **Pending**: reliability-engineer review
```

This file serves as a re-grounding mechanism — before advancing to any step,
read state.md to verify prerequisites are met. Teammates can also read this file
to understand where the workflow stands.

### Step 4: Create Agent Team and Dispatch

Create an agent team with one teammate per persona defined in Step 2. The lead
focuses on orchestration — do not write review files directly.

**Agent team setup:**
1. Create an agent team using TeamCreate
2. Spawn one teammate per persona using the Task tool with `team_name` set to the team name
3. The lead should NOT write review files directly — the lead's role is to
   dispatch, monitor, facilitate debate, and synthesize

**Handling dispatch failures:**
- If TeamCreate fails, inform the user and do not proceed. Agent teams are
  required for this skill.
- If individual teammate spawns fail, proceed with the teammates that were
  successfully spawned and note the missing personas in the synthesis.

**For each teammate, construct a spawn prompt that includes:**
- The persona definition from Step 2 (role, scope, analytical lens), formatted
  following the structure of examples in
  `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/personas/examples/`
- File paths for the teammate to read autonomously:
  - **Schema path**: `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/analysis-schema.md`
    — tell the teammate to read this file and follow the schema it defines
  - **Artifact path**: the path to the artifact being reviewed
  - **Output path**: the persona's output path from Step 3
- Lightweight context (do NOT paste file contents):
  - `{ARTIFACT_TYPE}` → type identified in Step 1
  - `{TOPIC}` → topic slug from Step 1
  - `{REVIEW_CONTEXT}` → a 2-3 sentence summary of the user's stated concerns
    and priorities from the brainstorming conversation, plus any specific
    instructions about review focus
- **Initial task: generate a draft rubric.** Do NOT instruct teammates to write
  reviews yet. Their first task is to read the schema and artifact, then propose
  their sign-off rubric based on their persona definition and domain expertise.
  Tell them to message the orchestrator with their proposed rubric in this format:
  - **Reject criteria** (3-5): any triggered → default reject
  - **Conditional-approve criteria** (3-5): any triggered → default conditional-approve
  - **Approve criteria** (3-5): all must hold
- Reference the Sign-Off Rubric sections in example persona templates for
  calibration and depth

**Critical: File paths, not pasted content.** Teammates read the artifact and
schema files themselves. The orchestrator provides the persona, the goals, and
the paths — teammates do the reading. This keeps the spawn prompt focused and
avoids bloating it with content the teammate can read directly.

**Recommended prompt ordering:** Persona definition first, then review context,
then file paths and instructions (read schema, read artifact, generate rubric).
This ordering places role and constraints before task instructions.

**Do NOT require plan approval for teammates.** Their task is to write a review,
not implement code. Plan approval adds friction with no benefit here.

### Step 5: Rubric Hardening

**Wait for all teammates to message their draft rubrics before proceeding.**
If a teammate has not responded after a reasonable period, message them to
check status. As each draft rubric arrives, report the key criteria to the
user (e.g., "security-engineer proposes rejecting on unmitigated injection
vectors and missing audit logging"). Once all draft rubrics are in, facilitate
a rubric hardening process where teammates refine their criteria and challenge
each other.

**Rubric hardening protocol:**

1. **Artifact-informed refinement**: Once draft rubrics are submitted, instruct
   each teammate: "Now read the artifact in depth. Refine your rubric based on
   what you see — add criteria specific to this artifact's context, remove
   criteria that don't apply, and adjust severity levels if needed. Message the
   orchestrator with your refined rubric."

2. **Cross-review**: Share each persona's refined rubric with all other personas.
   Instruct teammates: "Review the other personas' rubrics. Challenge criteria
   that are too aggressive, too lenient, overlapping with your scope, or missing
   something obvious. Message the relevant persona directly with challenges."

3. **Clarifying questions**: If a teammate needs information to finalize their
   rubric, they message the orchestrator. The orchestrator either answers from
   available context or escalates to the user via AskUserQuestion.

   **Orchestrator answers directly when:**
   - The answer is stated in the artifact (e.g., "Is this API public-facing?"
     and the artifact specifies deployment context)
   - The answer was provided during brainstorming (e.g., "What's the main
     concern?" and the user stated it in Step 2)
   - The question is about factual content in the artifact that the teammate
     may have missed or not yet read

   **Orchestrator escalates to the user when:**
   - The question is about unstated intent or priorities (e.g., "Is backward
     compatibility a hard requirement or a nice-to-have?")
   - The question is about organizational context the artifact doesn't cover
     (e.g., "What compliance regime applies?" or "Is there an existing auth
     system this integrates with?")
   - The answer would significantly change rubric severity (e.g., "Should we
     treat missing encryption as a reject or conditional for an internal-only
     tool?")
   - The question involves a trade-off where user preference matters (e.g.,
     "Is speed-to-market more important than completeness?")
   - The orchestrator is unsure — when in doubt, escalate

   The goal is alignment: subagents should operate with the same understanding
   of user intent that the orchestrator has. If the orchestrator doesn't have
   that understanding either, it should ask rather than guess.

4. **Finalization**: After one round of challenges (one cycle where each persona
   has had the opportunity to challenge and respond — same definition as Step 7)
   and any clarifications, each teammate messages the orchestrator with their
   final rubric. The orchestrator confirms all rubrics are locked before
   proceeding to reviews.

5. **Write rubrics.md**: The orchestrator writes the rubric decision trail to
   `.subagent-analysis/{topic}/{run-id}/rubrics.md` following the Rubrics
   Document Format in the analysis schema. This captures:
   - All clarifying questions, who asked them, how they were resolved, and
     what rubric criteria they affected
   - All cross-review challenges that changed criteria
   - The full final rubric for each persona

   This file is written by the orchestrator (not by teammates) because the
   orchestrator has visibility into the full decision trail including user
   escalations.

```
┌──────────────────────┐
│  Teammates spawned   │
│  (Step 4 complete)   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Draft rubrics:      │
│  from domain         │
│  expertise           │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Read artifact,      │
│  refine rubrics      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Cross-review:       │
│  challenge rubrics   │
└──────────┬───────────┘
           │
           ├──→ Questions → Orchestrator → User (if needed)
           │
           ▼
┌──────────────────────┐
│  Finalize rubrics    │
│  (locked for review) │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Write rubrics.md    │
│  (decision trail)    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Step 6: Write       │
│  Reviews             │
└──────────────────────┘
```

### Step 6: Write and Validate Reviews

After rubrics are locked in Step 5, instruct each teammate to write their
review. Include the teammate's finalized rubric criteria in the message so the
rubric is in their recent context (it may have drifted out of attention after
the multi-round hardening process). Each teammate writes to their output path
from Step 3.

As each review arrives, report the headline to the user — the sign-off value,
confidence, and the most notable findings (e.g., "reliability-engineer:
conditional-approve (high confidence) — flagged no circuit breaker on the
payments dependency and no defined SLOs").

After all teammates complete their review tasks:
1. Read each persona's output file
2. Validate against the schema:
   - YAML frontmatter present with all required fields?
   - All required sections present (Summary, Analysis, Assumptions, Recommendations, Rubric Assessment, Sign-Off)?
   - Sign-off value is one of: approve, conditional-approve, reject?
   - Confidence value is one of: high, medium, low?
   - Assumptions section exists (even if "None")?
   - Rubric Assessment criteria match the finalized rubric from Step 5?
   Note: Debate Notes section is not expected at this stage — it will be added
   during Step 7. Do not flag its absence as a validation failure.
3. If a review fails validation, note the issues but proceed (do not re-dispatch)
4. If a teammate failed to produce any output (no file written, crash, timeout),
   proceed with available reviews and note the missing persona in synthesis.
   Do not block the workflow waiting indefinitely for a failed teammate.
   If the majority of dispatched personas failed to produce output, inform the
   user and ask whether to proceed with synthesis or re-run the analysis.

### Step 7: Findings Debate

After all reviews are written and validated, facilitate an inter-persona debate
where teammates challenge each other's findings.

**Debate protocol:**

1. **Cross-review tasks**: Create a task for each teammate: "Read the other
   personas' reviews in `.subagent-analysis/{topic}/{run-id}/` and identify findings you
   disagree with or want to challenge."

2. **Direct challenges**: Teammates message each other directly with challenges.
   Each challenge should include:
   - **Challenged finding:** cite the specific finding being disputed
   - **Counter-argument:** state the disagreement
   - **Evidence:** cite artifact sections or reasoning that supports the challenge

   Example: a security-focused reviewer messages an architecture reviewer —
   "Your recommendation to simplify the auth layer removes a defense-in-depth
   boundary."

   **Report each challenge to the user as it happens** — who challenged whom,
   what the dispute is about, and how it was received. If a persona changes
   their position, report that too. The user should be able to follow the
   debate in real time through your updates.

3. **Convergence detection**: The lead monitors the exchange and calls time after
   any of the following:
   - Each teammate has either sent at least one challenge or one full round has
     elapsed since they received the cross-review task, OR
   - Two rounds have passed without new disagreements, OR
   - **Three total rounds have elapsed** (hard cap — force convergence regardless)

   A **round** is one cycle where each active participant has had the opportunity
   to send a challenge or response. Individual messages do not count as rounds.

   **Design note:** This multi-condition protocol is intentional. Simplifying to
   a single "wait for all, allow one round, call time" approach would force
   unnecessary full rounds when no challenges exist and lose the ability to
   distinguish a silent teammate (possible crash) from an explicit "no
   challenges" response. The structured state file (state.md) helps the
   orchestrator track per-participant status reliably.

4. **Review updates**: After debate ends, each teammate gets a final task:
   "Update your review file if the debate changed any of your findings. Add a
   `## Debate Notes` section documenting what was challenged and whether you
   changed your position. This section is required even if no challenges were
   received — write 'No challenges received' in that case."

   **Wait for all teammates to confirm their review files are updated before
   proceeding to Step 8 (cleanup).** Do not read review files until every
   teammate has marked their update task as complete. Reading files mid-write
   risks capturing incomplete Debate Notes.

```
┌──────────────────────┐
│  Reviews written     │
│  (Step 6 complete)   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Cross-review:       │
│  read other reviews  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Direct challenges   │◄──┐
│  between teammates   │   │ (back-and-forth
└──────────┬───────────┘   │  until convergence)
           │               │
           ├───────────────┘
           │ converged
           ▼
┌──────────────────────┐
│  Update reviews with │
│  Debate Notes        │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Step 8: Clean up    │
│  agent team          │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Step 9: Synthesize  │
└──────────────────────┘
```

### Step 8: Clean Up Agent Team

Teammates are done after the debate phase. Clean up the team before synthesizing.

- Send a shutdown request to each teammate
- **Wait for each teammate to confirm shutdown** before proceeding — do NOT
  call TeamDelete until all teammates have terminated
- Only after all teammates have confirmed shutdown, call TeamDelete to
  clean up team resources

**Critical: Always clean up the agent team.** Send shutdown requests, wait for
confirmations, then delete. Do not call TeamDelete while teammates are still
running — this can orphan processes.

### Step 9: Synthesize

Generate `.subagent-analysis/{topic}/{run-id}/synthesis.md` following the synthesis schema.

The synthesis is not just a rollup of individual reviews — it identifies the
**themes** that emerged across personas, documents how **debate changed** those
themes, and distills concrete **action items**. Structure it accordingly:

1. **Themes**: What recurring patterns emerged across multiple personas? Group
   findings by theme rather than by persona. Each theme should cite which
   personas surfaced it and what evidence they found.
2. **Debate impact**: For each theme, document whether and how the debate phase
   changed the picture. Did a challenge cause a persona to revise their
   position? Did debate surface a nuance that no individual review captured?
   Did a theme survive debate intact, strengthening confidence in it?
3. **Action items**: Concrete, prioritized actions derived from the themes.
   These are the P0/P1/P2 recommendations, merged and deduplicated, but
   organized by theme rather than by source persona.

**Rubric traceability:** In the Overall Status section, state which persona
produced the most restrictive sign-off and which rubric criteria drove it. If
any persona used an override (Actual ≠ Derived), note this in the synthesis
so the reader can assess whether the override was justified.

**Conflict Resolution — Debate First:**

Conflicts are primarily resolved through the debate phase. When personas disagree:

1. **Debate resolution**: If the personas resolved the disagreement themselves
   during the debate phase, note it as resolved with `Resolution-source: debate`.
2. **Scope-based authority**: If the debate did not resolve the conflict, the lead
   determines which persona's defined scope most directly covers the disputed
   topic. That persona's position takes precedence. Note as
   `Resolution-source: scope-based`.
3. **Escalation**: If the conflict doesn't clearly fall under any persona's scope,
   or if it involves a genuine trade-off between domains, list it in Open Questions
   for human resolution. Note as `Resolution-source: escalated`.

Do NOT use majority vote. A 2-1 outcome where the dissenting persona has the
most relevant expertise is wrong.

### Step 10: Review and Decide

After synthesis, collaboratively review the findings with the user and produce
documented decisions.

**10a. Present synthesis directly in conversation:**
Do NOT just point the user at synthesis.md — present the substance of the
analysis as your response. This is the main deliverable of the skill. Include:
- Overall status and which persona/rubric criteria drove it
- The key themes discovered across personas, with brief evidence
- How debate changed the picture (positions revised, themes strengthened or
  weakened, nuances surfaced)
- The prioritized action items (P0 first, then P1, then P2) with source context
- Any conflicts and their resolutions (debate vs. scope-based vs. escalated)
- Open questions requiring human input

The written synthesis.md file is the archival record. The in-conversation
presentation is what the user actually reads and acts on — make it substantive.

**10b. Collaborative review using brainstorming:**
Use the `superpowers:brainstorming` skill (if available; otherwise, conduct the
collaborative review as a standard brainstorming conversation) to walk through the synthesis findings
with the user. Go through recommendations by priority (P0 first, then P1, then
P2), and for each one:
- Present the recommendation with its source persona(s) and evidence
- If there was a conflict or dissent, surface the competing positions
- Ask the user what they want to do: accept, reject, defer, or modify
- Explore trade-offs and alternatives as needed (this is a brainstorming
  conversation — one question at a time, multiple choice when possible)

The user may batch similar recommendations, skip low-priority items, or decide
to address entire categories at once. Follow their lead.

**10c. Write decision documents:**
For each decision made during the brainstorming session, write a decision
document to `.subagent-analysis/{topic}/{run-id}/decisions/{decision-slug}.md`
following the Decision Document Format in the analysis schema.

Create the `decisions/` directory before writing the first document. Name each
file with a kebab-case slug derived from the decision (e.g.,
`adopt-jwt-auth.md`, `defer-migration-strategy.md`).

Write decision documents as you go (after each decision is made), not all at
the end. This keeps the brainstorming session interactive — the user sees each
decision documented before moving to the next.

**10d. Commit:**
After all decisions are documented, ask the user if they want to commit. If yes,
stage and commit all files in `.subagent-analysis/{topic}/{run-id}/` with
message: `Add {topic} multi-persona analysis`

## Common Mistakes

| Mistake | Why it's wrong | What to do instead |
|---------|---------------|-------------------|
| Using preset personas without brainstorming | Misses context-specific review angles | Always brainstorm personas from the artifact and user concerns |
| Pasting full artifact/schema into spawn prompt | Bloats the prompt; teammates can read files themselves | Provide file paths and let teammates read autonomously |
| Letting the lead implement instead of delegate | Lead should orchestrate, not review | Enter delegate mode after spawning teammates |
| Using majority vote for conflicts | A 2-1 vote where the dissenter has domain expertise is wrong | Use debate-first resolution, then scope-based authority |
| Skipping the Assumptions section | Silent assumptions hide risk | Require it even if "None" |
| Summarizing the artifact for teammates | Lossy; teammates need full context | Give the file path and let them read the full artifact |
| Re-dispatching on schema violation | Expensive and likely to produce similar issues | Note violations, proceed with synthesis |
| Committing before validation | May commit malformed reviews | Validate first, then ask user |
| Requiring plan approval for teammates | Adds friction; teammates write reviews, not code | Do not require plan approval |
| Not cleaning up the agent team | Leaves orphaned teammates consuming resources | Always shut down teammates and clean up |
| Teammates editing each other's reviews | Each persona owns their own file only | Teammates challenge via messaging, update only their own file |
| Skipping Debate Notes after debate | Loses the record of what was challenged | Require the section even if "No challenges received" |
| Writing generic observations not grounded in the artifact | Reviews become unfalsifiable and useless | Cite specific sections, decisions, or quotes from the artifact |
| Calling TeamDelete before teammates confirm shutdown | Can orphan running processes | Send shutdown requests, wait for all confirmations, then call TeamDelete |
| Reading review files before teammates confirm updates are done | May capture incomplete Debate Notes or mid-write content | Wait for all teammates to mark their update task complete before reading files or starting synthesis |
