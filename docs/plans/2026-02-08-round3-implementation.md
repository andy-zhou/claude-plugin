# Round 3 Analysis Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement all 23 accepted recommendations from the round 3 multi-persona analysis of the subagent-analysis skill.

**Architecture:** Direct edits to SKILL.md, analysis-schema.md, README.md, CLAUDE.md, and the agent-teams design doc. Remove old analysis runs. No new files created except state.md schema addition.

**Tech Stack:** Markdown editing, git

---

### Task 1: Fix README file-structure tree (P0 #1)

**Files:**
- Modify: `README.md:62-63`

**Step 1: Add the missing design doc to the tree**

In `README.md`, the `docs/plans/` listing shows only one file. Add the second:

```markdown
│   └── plans/
│       ├── 2026-02-08-agent-teams-migration-design.md
│       └── 2026-02-08-sign-off-rubrics-design.md
```

**Step 2: Verify the fix**

Run: `grep -A2 "plans/" README.md`
Expected: Both design doc filenames appear.

**Step 3: Commit**

```bash
git add README.md
git commit -m "fix: add missing sign-off-rubrics-design.md to README tree"
```

---

### Task 2: Remove old analysis runs (P2 #22 — user decision: delete)

**Files:**
- Delete: `.subagent-analysis/kani-tech-spec/` (flat format, pre-schema)
- Delete: `.subagent-analysis/subagent-analysis-skill/20260208-085411/` (round 1, no rubrics.md)
- Delete: `.subagent-analysis/subagent-analysis-skill/20260208-090851/` (round 2, no rubrics.md)
- Keep: `.subagent-analysis/subagent-analysis-skill/20260208-103356/` (round 3, current)

**Step 1: Remove old runs**

```bash
git rm -r .subagent-analysis/kani-tech-spec/
git rm -r .subagent-analysis/subagent-analysis-skill/20260208-085411/
git rm -r .subagent-analysis/subagent-analysis-skill/20260208-090851/
```

**Step 2: Verify only round 3 remains**

```bash
ls .subagent-analysis/subagent-analysis-skill/
```
Expected: Only `20260208-103356/`

**Step 3: Commit**

```bash
git commit -m "chore: remove old analysis runs (pre-schema and pre-rubric formats)"
```

---

### Task 3: Update agent-teams migration design doc (P1 #9)

**Files:**
- Modify: `docs/plans/2026-02-08-agent-teams-migration-design.md`

**Step 1: Add Status field and update stale step names**

Replace the entire file content with:

```markdown
# Design: Migrate subagent-analysis to Agent Teams

**Status:** Implemented

> **Note:** Step names and numbers in this document reflect the pre-rubric-hardening
> workflow. See `2026-02-08-sign-off-rubrics-design.md` for the subsequent renumbering
> that introduced Step 5 (Rubric Hardening) and shifted later steps.

## Summary

Update the subagent-analysis skill to use Claude Code's experimental agent teams feature instead of Task-tool subagents. Add an inter-persona debate phase where teammates challenge each other's findings before synthesis.

## Changes

### SKILL.md — 8 steps become 9

Steps 1-4 unchanged (scope, clarify, select, align).

- **Step 5**: Create agent team — spawn one teammate per persona with lead in delegate mode
- **Step 6**: Collect reviews — teammates write review files, lead validates schema
- **Step 7 (NEW)**: Debate — teammates read each other's reviews, challenge findings via direct messaging, optionally update their reviews with a Debate Notes section
- **Step 8**: Synthesize — incorporates debate outcomes; conflicts tagged with resolution-source (debate, domain-authority, escalated)
- **Step 9**: Act — present summary, commit, clean up agent team

Additional:
- Prerequisites section: check for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var
- Fallback: if agent teams unavailable, fall back to Task-tool subagent dispatch (no debate phase)
- Updated Common Mistakes table with agent-team pitfalls

### analysis-schema.md

Per-persona review format gains:
- `## Debate Notes` section (required after debate, even if "No challenges received")

Synthesis format gains:
- `Resolution-source` field on each conflict: `debate | domain-authority | escalated`

### README.md

- Note that the skill uses agent teams (experimental) with Task-tool fallback

## Files to modify

1. `skills/subagent-analysis/SKILL.md`
2. `skills/subagent-analysis/analysis-schema.md`
3. `README.md`
```

**Step 2: Commit**

```bash
git add docs/plans/2026-02-08-agent-teams-migration-design.md
git commit -m "docs: add Status field and staleness note to agent-teams design doc"
```

---

### Task 4: Update CLAUDE.md (P2 #23)

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add design docs to Historical Context**

Replace the Historical Context section:

```markdown
## Historical Context

`docs/implementation-plan.md` is the original build plan from initial development. It is archived and should not be treated as a live spec.

`docs/plans/` contains design documents for subsequent changes:
- `2026-02-08-agent-teams-migration-design.md` — migration from Task-tool subagents to agent teams
- `2026-02-08-sign-off-rubrics-design.md` — per-persona sign-off rubrics with guided override model

Both are marked `Status: Implemented` and describe the rationale behind their respective features.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: mention design docs in CLAUDE.md Historical Context"
```

---

### Task 5: Make Step 6 mode-aware with rubric re-injection (P1 #3)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:296-316`

**Step 1: Replace Step 6 opening paragraph**

Current (lines 298-300):
```
After rubrics are locked (or after Step 4 in fallback mode), instruct each
teammate to write their review using their finalized rubric. Each teammate
writes to their output path from Step 3.
```

Replace with:
```
**Agent team mode:** After rubrics are locked in Step 5, instruct each teammate
to write their review. Include the teammate's finalized rubric criteria in the
message so the rubric is in their recent context (it may have drifted out of
attention after the multi-round hardening process). Each teammate writes to
their output path from Step 3.

**Fallback mode:** Teammates received their review instructions and rubric
criteria in the dispatch prompt (Step 4). Step 6 for the orchestrator consists
only of waiting for all Task-tool subagents to complete and then validating
their output — there are no follow-up instructions to send.
```

**Step 2: Update Step 6 validation item for fallback (P2 #12)**

Current (line 310):
```
   - Rubric Assessment criteria match the finalized rubric from Step 5?
```

Replace with:
```
   - Rubric Assessment criteria match the finalized rubric from Step 5 (or the rubric included in the dispatch prompt in fallback mode)?
```

**Step 3: Add Debate Notes temporal note to validation (P2 #16)**

After the validation checklist (after line 310), add:
```
   Note: Debate Notes section is not expected at this stage — it will be added
   during Step 7. Do not flag its absence as a validation failure.
```

**Step 4: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "fix: make Step 6 mode-aware with rubric re-injection and validation clarifications"
```

---

### Task 6: Add fallback rubrics.md instruction (P1 #4)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:504-507`

**Step 1: Add rubrics.md instruction to fallback section**

After line 505 (`- **Step 5 is skipped**: No rubric debate. Lead assigns rubrics directly.`), add:
```
  After dispatch, write a simplified `rubrics.md` with the assigned rubrics and
  any user context from brainstorming, following the Rubrics Document Format in
  the analysis schema with `mode: fallback`. No Decisions or Rubric Challenges
  sections needed — just the Final Rubrics.
```

**Step 2: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "fix: add rubrics.md generation instruction for fallback mode"
```

---

### Task 7: Add explicit wait gate at Step 4→5 transition (P1 #5)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:188-190`

**Step 1: Add wait gate**

Current (line 189):
```
After all teammates submit their draft rubrics, facilitate a rubric hardening
```

Replace with:
```
**Wait for all teammates to message their draft rubrics before proceeding.**
If a teammate has not responded after a reasonable period, message them to
check status. Once all draft rubrics are in, facilitate a rubric hardening
```

**Step 2: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "fix: add explicit wait gate at Step 4→5 rubric submission transition"
```

---

### Task 8: Add orchestrator state tracking via state.md (P1 #6)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md` (add after Step 3, before Step 4)
- Modify: `skills/subagent-analysis/analysis-schema.md` (add state.md to output location tree)

**Step 1: Add state tracking instruction to SKILL.md**

After Step 3 (Align Output), before Step 4 heading, add:

```markdown
**State tracking:** Throughout the workflow, maintain a running state file at
`.subagent-analysis/{topic}/{run-id}/state.md` to track orchestration progress.
Update this file after each step transition. Format:

```markdown
## Orchestration State
- **Mode**: agent-team | fallback
- **Step**: <current step number and name>
- **Teammates dispatched**: <list of persona names>
- **Rubrics submitted**: <list of personas who have submitted> / <total>
- **Reviews written**: <list of personas with completed reviews> / <total>
- **Debate status**: not-started | in-progress (round N/3) | complete
- **Pending**: <what the orchestrator is waiting for>
```

This file serves as a re-grounding mechanism — before advancing to any step,
read state.md to verify prerequisites are met. Teammates can also read this file
to understand where the workflow stands.
```

**Step 2: Add state.md to analysis-schema.md output tree**

In analysis-schema.md, update the output location tree (lines 11-16):
```
.subagent-analysis/{topic}/{run-id}/
├── state.md                # Orchestration state tracker (updated each step)
├── rubrics.md               # Rubric hardening decisions and final rubrics
├── {persona-name}.md        # One per dispatched persona
├── synthesis.md             # Generated after all reviews collected
└── decisions/               # One document per decision made during review
    └── {decision-slug}.md   # Individual decision documents
```

**Step 3: Commit**

```bash
git add skills/subagent-analysis/SKILL.md skills/subagent-analysis/analysis-schema.md
git commit -m "feat: add state.md orchestration tracker for re-grounding in long sessions"
```

---

### Task 9: Update README fallback description with loss inventory (P1 #7)

**Files:**
- Modify: `README.md:34`

**Step 1: Replace fallback description**

Current (line 34):
```
Without agent teams enabled, the skill falls back to Task-tool subagent dispatch (no debate phase).
```

Replace with:
```
Without agent teams enabled, the skill falls back to Task-tool subagent dispatch.
You still get parallel expert reviews, a synthesis with conflict resolution, and
decision documents — but rubric hardening and inter-persona debate are skipped,
so reviews use pre-assigned rubrics and conflicts are resolved by the lead rather
than through reviewer discussion.
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add loss inventory to README fallback mode description"
```

---

### Task 10: Add "just go" confirmation guidance (P1 #8)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:63-66`

**Step 1: Expand "just go" guidance**

Current (lines 63-66):
```
**If the user says "just go":** Infer appropriate personas from the artifact
type and content. For example, a tech spec likely needs architecture, security,
and operability perspectives. A pure API design doc likely needs design and
security but not operability.
```

Replace with:
```
**If the user says "just go":** Infer appropriate personas from the artifact
type and content. For example, a tech spec likely needs architecture, security,
and operability perspectives. A pure API design doc likely needs design and
security but not operability.

When presenting inferred personas for confirmation, briefly explain why each
was chosen for this artifact type and note any major angles that are not
covered (e.g., "I did not include a security persona because this is a pure
UI spec — add one if security is relevant"). This makes the confirmation step
an effective quality gate rather than a rubber stamp.
```

**Step 2: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "feat: add confirmation guidance for 'just go' persona inference"
```

---

### Task 11: Add TeamCreate/dispatch failure handling to Step 4 (P2 #10)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md` (after line 133, before dispatch mode tracking)

**Step 1: Add failure handling**

After line 133 (`dispatch, monitor, facilitate debate, and synthesize`), add:

```markdown

**Handling dispatch failures:**
- If TeamCreate fails, fall back to Task-tool dispatch mode and proceed with
  the fallback workflow (skip Steps 5 and 7).
- If individual teammate spawns fail, proceed with the teammates that were
  successfully spawned and note the missing personas in the synthesis.
```

**Step 2: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "feat: add TeamCreate/dispatch failure handling to Step 4"
```

---

### Task 12: Add fallback decision gates to Diagrams 2 and 3 (P2 #11)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:250-294` (Diagram 2)
- Modify: `skills/subagent-analysis/SKILL.md:368-398` (Diagram 3)

**Step 1: Add decision gate to Diagram 2 (Step 5 rubric hardening)**

Replace the current Diagram 2 opening:
```
┌──────────────────────┐
│  Teammates spawned   │
│  (Step 4 complete)   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Draft rubrics:      │
```

With:
```
┌──────────────────────┐
│  Teammates spawned   │
│  (Step 4 complete)   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐     ┌──────────────────────┐
│  Agent team mode?    │─No─▶│  Skip to Step 6      │
│  (TeamCreate called) │     │  (fallback mode)     │
└──────────┬───────────┘     └──────────────────────┘
           │ Yes
           ▼
┌──────────────────────┐
│  Draft rubrics:      │
```

**Step 2: Add decision gate to Diagram 3 (Step 7 debate)**

Replace the current Diagram 3 opening:
```
┌──────────────────────┐
│  Reviews written     │
│  (Step 6 complete)   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Cross-review:       │
```

With:
```
┌──────────────────────┐
│  Reviews written     │
│  (Step 6 complete)   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐     ┌──────────────────────┐
│  Agent team mode?    │─No─▶│  Skip to Step 8      │
│  (TeamCreate called) │     │  (fallback mode)     │
└──────────┬───────────┘     └──────────────────────┘
           │ Yes
           ▼
┌──────────────────────┐
│  Cross-review:       │
```

**Step 3: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "docs: add fallback decision gates to Diagrams 2 and 3"
```

---

### Task 13: Define "one round" in Step 5 (P2 #13)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:234`

**Step 1: Add round definition**

Current (line 234):
```
4. **Finalization**: After one round of challenges and any clarifications, each
```

Replace with:
```
4. **Finalization**: After one round of challenges and any clarifications, each
```

And add a definition after "any clarifications, each" — the full replacement of lines 234-236:
```
4. **Finalization**: After one round of challenges (one cycle where each persona
   has had the opportunity to challenge and respond — same definition as Step 7)
   and any clarifications, each
```

**Step 2: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "docs: define 'one round' in Step 5 rubric hardening"
```

---

### Task 14: Add Step 1 artifact access failure handling (P2 #14)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:36-42`

**Step 1: Add failure handling to Step 1**

After line 42 (`- Derive a {TOPIC} slug in kebab-case`), add:
```

If the artifact path is invalid or the file cannot be read, inform the user
and ask for a corrected path using AskUserQuestion.
```

**Step 2: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "feat: add artifact access failure handling to Step 1"
```

---

### Task 15: Consolidate placeholder substitution checklist (P2 #15)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:150-159`

**Step 1: Add verification checklist**

After line 159 (`before sending — do not send literal placeholder strings`), add:

```markdown

**Pre-send verification checklist:** Before sending each teammate's spawn
prompt, verify ALL of the following tokens have been replaced with actual values:
- [ ] `{ARTIFACT_CONTENT}` → full artifact text from Step 1
- [ ] `{ARTIFACT_TYPE}` → type identified in Step 1
- [ ] `{TOPIC}` → topic slug from Step 1
- [ ] `{OUTPUT_PATH}` → persona output path from Step 3
- [ ] `{REVIEW_CONTEXT}` → summary of user concerns from Step 2
```

**Step 2: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "docs: consolidate placeholder substitution into explicit checklist"
```

---

### Task 16: Rename "domain-authority" to "scope-based" (P2 #19)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md` (all occurrences)
- Modify: `skills/subagent-analysis/analysis-schema.md` (all occurrences)
- Modify: `CLAUDE.md` (line 19)

**Step 1: Replace in SKILL.md**

Replace all occurrences of `domain-authority` with `scope-based` in SKILL.md:
- Line 418: `Resolution-source: domain-authority` → `Resolution-source: scope-based`
- Line 427: `via scope-based authority` (already correct phrasing — just check the Resolution-source value)

**Step 2: Replace in analysis-schema.md**

Replace all occurrences:
- Line 167-168: `domain-authority` → `scope-based`

**Step 3: Verify CLAUDE.md**

Line 19 already says "scope-based authority" — no change needed, but verify.

**Step 4: Commit**

```bash
git add skills/subagent-analysis/SKILL.md skills/subagent-analysis/analysis-schema.md
git commit -m "refactor: rename 'domain-authority' resolution source to 'scope-based'"
```

---

### Task 17: Add superpowers:brainstorming graceful degradation note (P2 #20)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:442`

**Step 1: Add degradation note**

Current (line 442):
```
Use the `superpowers:brainstorming` skill to walk through the synthesis findings
```

Replace with:
```
Use the `superpowers:brainstorming` skill (if available; otherwise, conduct the
collaborative review as a standard brainstorming conversation) to walk through the synthesis findings
```

**Step 2: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "docs: note superpowers:brainstorming graceful degradation"
```

---

### Task 18: Clarify README file structure tree (P2 #18)

**Files:**
- Modify: `README.md:77-84`

**Step 1: Add separator between plugin tree and runtime output tree**

Current (line 77):
```

# Runtime output (in the project where the skill is invoked):
```

Replace with:
```

# When you run the skill in another project, it creates the following output:
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: clarify two-part file structure tree in README"
```

---

### Task 19: Note per-persona review density (P2 #21)

**Files:**
- Modify: `README.md:49`

**Step 1: Add density note after output description**

Current (line 49):
```
directory, with one file per reviewer plus a `synthesis.md`.
```

Replace with:
```
directory, with one file per reviewer plus a `synthesis.md`. Per-persona review
files are detailed and structured for synthesis processing; the `synthesis.md`
is the primary document for decision-making.
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: note per-persona review density in README"
```

---

### Task 20: Note convergence trade-offs (P2 #17)

**Files:**
- Modify: `skills/subagent-analysis/SKILL.md:347-355`

**Step 1: Add design rationale note after convergence conditions**

After line 355 (`Individual messages do not count as rounds.`), add:

```markdown

   **Design note:** This multi-condition protocol is intentional. Simplifying to
   a single "wait for all, allow one round, call time" approach would force
   unnecessary full rounds when no challenges exist and lose the ability to
   distinguish a silent teammate (possible crash) from an explicit "no
   challenges" response. The structured state file (state.md) helps the
   orchestrator track per-participant status reliably.
```

**Step 2: Commit**

```bash
git add skills/subagent-analysis/SKILL.md
git commit -m "docs: note convergence detection design trade-offs in Step 7"
```

---

### Task 21: Final verification and squash commit

**Step 1: Verify all files are consistent**

Read SKILL.md, analysis-schema.md, README.md, CLAUDE.md, and the design doc to verify:
- No broken cross-references
- Step numbering consistent
- "domain-authority" fully replaced with "scope-based"
- All diagram changes render correctly
- Fallback mode described consistently

**Step 2: Run a final git status and log**

```bash
git status
git log --oneline -20
```

Expected: Clean working directory, 20 commits since the analysis commit.
