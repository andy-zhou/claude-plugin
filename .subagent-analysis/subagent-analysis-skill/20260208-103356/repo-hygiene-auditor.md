---
persona: repo-hygiene-auditor
date: 2026-02-08
artifact: subagent-analysis skill (SKILL.md, analysis-schema.md, persona examples, README, CLAUDE.md, design docs)
scope: Cross-file reference integrity, filesystem consistency, source/cache divergence, staleness detection, step-numbering consistency
sign-off: conditional-approve
confidence: high
---

## Summary

Reviewed the subagent-analysis skill repository for cross-file reference integrity, README-to-filesystem accuracy, source-to-cache divergence, placeholder hygiene, step-numbering consistency, and design doc staleness. The repo has significant hygiene debt from three rounds of changes (original 8-step workflow, agent-teams migration, rubric hardening). One reject criterion is triggered: the README file-structure tree omits a design doc that exists on disk. The plugin cache contains a pre-rubric-hardening version of all runtime files, but debate established this is a deployment process gap rather than a skill design defect, so it is evaluated at conditional level. Multiple additional conditional criteria are triggered. Sign-off is conditional-approve via guided override (see Rubric Assessment).

## Analysis

### Filesystem Path References

All file and directory paths referenced in source files resolve correctly on disk:

- SKILL.md line 21: `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/analysis-schema.md` -- exists at `/Users/andy.zhou/workspace/andys-skills/skills/subagent-analysis/analysis-schema.md`
- SKILL.md line 22: `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/personas/examples/` -- exists at `/Users/andy.zhou/workspace/andys-skills/skills/subagent-analysis/personas/examples/` (7 files)
- SKILL.md lines 80, 146: same `personas/examples/` path -- resolves
- CLAUDE.md line 1: `README.md` -- exists at `/Users/andy.zhou/workspace/andys-skills/README.md`
- CLAUDE.md line 31: `docs/implementation-plan.md` -- exists at `/Users/andy.zhou/workspace/andys-skills/docs/implementation-plan.md`
- SKILL.md line 442: `superpowers:brainstorming` -- this is a skill reference, not a file path; not in scope for this criterion

No broken file/directory path references found. **Reject criterion #1: Not triggered.**

### README File-Structure Tree vs. Filesystem

The README (lines 53-85) enumerates the repo structure. Comparing against actual filesystem:

**Files listed in README that exist:** All listed files and directories exist on disk. No phantom entries.

**Files missing from README at enumerated depth:** The README tree (line 62-63) shows:
```
docs/
    ├── implementation-plan.md
    └── plans/
        └── 2026-02-08-agent-teams-migration-design.md
```

The actual `docs/plans/` directory contains two files:
- `2026-02-08-agent-teams-migration-design.md` (listed)
- `2026-02-08-sign-off-rubrics-design.md` (NOT listed)

The README tree enumerates `docs/plans/` at file level (shows one specific file), so omitting the second file at that same depth makes the tree incomplete. The sign-off rubrics design doc (`Status: Implemented`) documents the rationale behind the rubric hardening feature -- a significant part of the current 9-step workflow. It is also not mentioned in CLAUDE.md's Historical Context section, making it entirely undiscoverable from the repo's entry points.

**Reject criterion #2: TRIGGERED.** The README tree omits `2026-02-08-sign-off-rubrics-design.md` at a depth it already enumerates.

### Source/Cache Divergence on Runtime Files

The plugin cache at `/Users/andy.zhou/.claude/plugins/cache/andys-skills/subagent-analysis/0.2.0/` was created at Feb 8 08:33:10 as a point-in-time snapshot. The source SKILL.md was last modified at Feb 8 10:26:22. The cache predates the rubric hardening changes. Comparing source to cache:

**SKILL.md -- major divergence.** The cached version is the pre-rubric-hardening 8-step workflow. Key differences:
- Cache says "skip Step 6: Debate" (line 25); source says "skip Steps 5 and 7: Rubric Hardening and Findings Debate"
- Cache has no `$ARGUMENTS` handling or large-artifact note
- Cache Step 4 uses "delegate mode (Shift+Tab)" language; source uses "TeamCreate" and dispatch mode tracking
- Cache has no rubric generation task in dispatch instructions
- Cache has no Step 5 (Rubric Hardening) at all
- Cache has no decision gate pattern for Steps 5 and 7
- Cache has fewer Common Mistakes entries

**analysis-schema.md -- major divergence.** The cached version is missing:
- The entire `rubrics.md` entry in the output location tree
- The entire `decisions/` directory in the output location tree
- The Sign-Off Rubric Structure section
- The Rubric Assessment required section
- The Rubrics Document Format section (lines 196-261 of source)
- The Decision Document Format section (lines 263-327 of source)
- Rubric traceability language in the synthesis Overall Status section

**Persona examples -- structural divergence.** The cache has 3 persona examples (principal-engineer, security-engineer, reliability-engineer). The source has 7 (adds customer-advocate, product-manager, technical-writer, exec-communication-coach). Additionally, the 3 shared examples differ:
- Source versions include Sign-Off Rubric sections with calibration criteria; cache versions do not
- Source versions include HTML comment template notes; cache versions do not
- Source Output Requirements reference "schema provided below" (designed for inlining); cache versions reference `analysis-schema.md` by file path
- Source Required Sections list includes "Rubric Assessment"; cache versions do not

This means a user who installs the plugin from the cache gets a fundamentally different skill than what the source code describes. The cache runs an 8-step workflow without rubric hardening, without decision documents, and with only 3 persona examples.

**Note on severity (revised after debate):** The source/cache divergence is a deployment process gap -- the cache is a stale snapshot that needs republishing -- not a defect in the skill's design or documentation. The source files are internally consistent. See Debate Notes for the challenge that prompted this reclassification.

**Conditional criterion (reclassified from reject): TRIGGERED.** Source and cache diverge on all three categories of runtime files. The divergence represents a deployment process gap, not a skill design defect.

### Unreplaced Placeholders in Non-Template Files

Searched all non-template, non-instructional files for literal `{PLACEHOLDER}` tokens:

- SKILL.md: Contains `{TOPIC}`, `{ARTIFACT_CONTENT}`, `{ARTIFACT_TYPE}`, `{OUTPUT_PATH}`, `{REVIEW_CONTEXT}`, `{PLACEHOLDER}` -- all in instructional context (Step 4 dispatch instructions documenting what to substitute). Not triggered.
- analysis-schema.md: Contains `{topic}`, `{run-id}`, `{persona-name}`, `{decision-slug}` -- all in format documentation describing output path conventions. Not triggered.
- README.md: Contains `{topic}`, `{run-id}`, `{persona-name}`, `{decision-slug}` -- all in the runtime output tree comment block. Not triggered.
- CLAUDE.md: Contains `{skill-name}`, `{topic}`, `{run-id}` -- all in convention descriptions. Not triggered.
- Persona example templates (7 files): Contain `{ARTIFACT_TYPE}`, `{TOPIC}`, `{OUTPUT_PATH}`, `{REVIEW_CONTEXT}`, `{ARTIFACT_CONTENT}` -- these are template files by design; tokens are intentional.

No unreplaced placeholders found in non-template, non-instructional context. **Reject criterion #4: Not triggered.**

### Design Doc Staleness

**Agent-teams migration design doc** (`docs/plans/2026-02-08-agent-teams-migration-design.md`):

1. **No Status field.** The sibling design doc (`2026-02-08-sign-off-rubrics-design.md`) has `**Status:** Implemented` on line 4. The agent-teams doc has no status indicator despite being fully implemented.

2. **Stale step names and numbering.** Line 11 says "Steps 1-4 unchanged (scope, clarify, select, align)." In the current SKILL.md:
   - Step 2 is "Brainstorm Personas with User" (not "Clarify")
   - Step 3 is "Align Output" (not "Select" -- "Select Personas" was the old Step 3)
   - Step 4 is "Create Agent Team and Dispatch" (not "Align")

3. **Step descriptions reference superseded workflow.** Lines 13-17 describe Steps 5-9 as: Create team, Collect reviews, Debate, Synthesize, Act. The current SKILL.md Steps 5-9 are: Rubric Hardening, Write Reviews, Findings Debate, Synthesize, Review and Decide. Step 5 (Create team) was absorbed into Step 4 during the rubric hardening redesign.

**Conditional criterion #1: TRIGGERED.** The agent-teams design doc describes a superseded architecture with old step names and no Status field.

### Step-Number Consistency in Source Files

Checking step references in all source files against the canonical SKILL.md numbering (Step 1: Identify Scope, Step 2: Brainstorm, Step 3: Align, Step 4: Dispatch, Step 5: Rubric Hardening, Step 6: Write Reviews, Step 7: Findings Debate, Step 8: Synthesize, Step 9: Review and Decide):

- **analysis-schema.md line 52:** "Step 5 (Rubric Hardening)" -- correct
- **analysis-schema.md line 121:** "findings debate phase (Step 7)" -- correct
- **analysis-schema.md line 200:** "Step 5 (Rubric Hardening)" -- correct
- **analysis-schema.md line 266:** "collaborative review of the synthesis (Step 9)" -- correct
- **sign-off-rubrics-design.md lines 94-107:** References Step 5.1 through Step 5.5 -- consistent with SKILL.md Step 5 substeps
- **sign-off-rubrics-design.md lines 140-146:** Describes Steps 2, 4, 5, 6, 7, 8, 9 changes -- all match current SKILL.md numbering
- **CLAUDE.md line 9:** "9-step workflow" -- correct

All source file step references are consistent with the canonical SKILL.md numbering. The agent-teams design doc has stale step numbering, but that's already captured under conditional criterion #1. **Conditional criterion #2: Not triggered** (no inconsistency in active source files).

### Old Analysis Runs Tracked by Git

Git tracks the following analysis output:

1. **`.subagent-analysis/kani-tech-spec/`** -- 4 files (principal-engineer.md, reliability-engineer.md, security-engineer.md, synthesis.md) with NO run-id subdirectory. The current schema requires output under `.subagent-analysis/{topic}/{run-id}/`. This run also has no rubrics.md and no decisions/ directory. This is output from the original 8-step workflow before both the agent-teams migration and rubric hardening.

2. **`.subagent-analysis/subagent-analysis-skill/20260208-085411/`** (round 1) -- 4 files with run-id subdirectory. No rubrics.md, no decisions/ directory. This predates the rubric hardening feature.

3. **`.subagent-analysis/subagent-analysis-skill/20260208-090851/`** (round 2) -- 4 files with run-id subdirectory. No rubrics.md, no decisions/ directory. This also predates rubric hardening (or was a run that didn't produce these artifacts).

The kani-tech-spec run is the most notable: it uses the original flat directory structure (no run-id) that the current schema explicitly replaced with timestamped subdirectories. All three tracked runs lack rubrics.md and decisions/ which are now part of the standard output schema.

**Conditional criterion #3: TRIGGERED.** The kani-tech-spec run uses pre-schema format (no run-id subdirectory). All tracked runs lack rubrics.md and decisions/.

### Source/Cache Divergence on Non-Runtime Files

- **README.md:** Cache is missing the Usage section, file-structure tree has "8-step review workflow" (cache) vs. "9-step review workflow" (source), cache lists only 3 persona examples, cache has no runtime output tree comment.
- **CLAUDE.md:** Cache says "8-step workflow" (line 9); source says "9-step workflow."
- **docs/plans/:** Cache has only the agent-teams migration design doc. Source also has the sign-off rubrics design doc.
- **docs/implementation-plan.md:** Both source and cache have identical versions (this is the archived original plan, unchanged).

**Conditional criterion #4: TRIGGERED.** README, CLAUDE.md, and docs/plans/ all diverge between source and cache.

## Assumptions

- The plugin cache at `~/.claude/plugins/cache/andys-skills/subagent-analysis/0.2.0/` is a point-in-time snapshot from installation, confirmed by timestamp analysis (cache: Feb 8 08:33, source last modified: Feb 8 10:26). The cache is not auto-synced from source; it requires republishing to update.
- `${CLAUDE_PLUGIN_ROOT}` resolves to the root of the andys-skills repo at runtime. If it resolves to the cache directory instead, the path references are still valid (the cache has the same directory structure, just with fewer files).
- The `.subagent-analysis/` output tracked in git is intentionally committed (per the implementation plan's design decision #5: "`.subagent-analysis/` is not gitignored. Reviews persist for auditability."). The old format is therefore a conscious artifact, not an accidental commit.

## Recommendations

### P0 -- Must fix before proceeding

1. **Add `2026-02-08-sign-off-rubrics-design.md` to the README file-structure tree.** The `docs/plans/` directory is enumerated at file level in the README tree but only lists one of its two files. Add the missing entry:
   ```
   └── plans/
       ├── 2026-02-08-agent-teams-migration-design.md
       └── 2026-02-08-sign-off-rubrics-design.md
   ```

### P1 -- Should fix before production

1. **Republish the plugin to update the cache.** The cache at `~/.claude/plugins/cache/andys-skills/subagent-analysis/0.2.0/` is a stale snapshot from before rubric hardening. Users installing the plugin get an 8-step workflow without rubric hardening, decision documents, or 4 of the 7 persona examples. Republish to sync cache with source. Note: other personas' P1 findings (workflow-architect's fallback mode gaps, prompt-engineer's rubric re-injection) only become user-relevant once the cache is updated. (Reclassified from P0 after debate -- see Debate Notes.)

2. **Add a Status field to the agent-teams migration design doc.** The sibling design doc has `**Status:** Implemented`. Add the same to `2026-02-08-agent-teams-migration-design.md` for consistency. Consider also adding a note that the step names and numbers described in this doc have been superseded by the rubric hardening changes (the sign-off rubrics design doc describes the subsequent renumbering).

3. **Update stale step names in the agent-teams migration design doc.** Line 11 says "Steps 1-4 unchanged (scope, clarify, select, align)" but the current workflow has Steps 1-4 as (scope, brainstorm, align, dispatch). Either update the doc to reflect current naming or add a header note: "Note: Step names and numbers in this document reflect the pre-rubric-hardening workflow. See `2026-02-08-sign-off-rubrics-design.md` for the subsequent renumbering."

### P2 -- Consider improving

1. **Consider whether old analysis runs should remain in their original format.** The kani-tech-spec run in the flat directory structure (no run-id) and the round 1/2 runs without rubrics.md are historical artifacts. They're valid as audit records of what was produced at the time, but they don't conform to the current schema. Options: (a) leave them as-is with an understanding that old runs are snapshots of their era, (b) add a note to CLAUDE.md or README explaining that prior runs may not match the current schema, or (c) restructure the kani-tech-spec run into a run-id subdirectory for consistency.

2. **Consider mentioning the sign-off rubrics design doc in CLAUDE.md.** The Historical Context section mentions `docs/implementation-plan.md` as archived. It could also mention the two design docs in `docs/plans/` so future sessions know they exist. Currently, a session following the CLAUDE.md entry point would read README, find the tree, and discover the agent-teams doc -- but would not discover the rubrics design doc (since it's missing from the README tree, per P0 #1).

## Rubric Assessment

### Criteria Evaluated

| Criterion | Level | Triggered | Evidence |
|-----------|-------|-----------|----------|
| Broken file/directory path reference | reject | No | All referenced paths resolve; see "Filesystem Path References" section |
| README file-structure tree inaccurate at enumerated depth | reject | Yes | sign-off-rubrics-design.md omitted from docs/plans/ in README tree; see "README File-Structure Tree vs. Filesystem" section |
| Source/cache divergence on runtime files (reclassified to conditional after debate) | conditional | Yes | SKILL.md, analysis-schema.md, and persona examples all differ substantially between source and cache; reclassified because divergence is a deployment process gap, not a skill design defect; see "Source/Cache Divergence on Runtime Files" section and Debate Notes |
| Unreplaced placeholders in non-template, non-instructional files | reject | No | All placeholder tokens are in instructional or template context; see "Unreplaced Placeholders" section |
| Design docs describe stale status/architecture | conditional | Yes | Agent-teams design doc has old step names and no Status field; see "Design Doc Staleness" section |
| Step-number inconsistencies in source files | conditional | No | All source file step references match canonical SKILL.md numbering |
| Old analysis runs in pre-schema format tracked by git | conditional | Yes | kani-tech-spec uses flat directory (no run-id); all runs lack rubrics.md and decisions/; see "Old Analysis Runs" section |
| Source/cache divergence on non-runtime files | conditional | Yes | README, CLAUDE.md, docs/plans/ all differ between source and cache; see "Source/Cache Divergence on Non-Runtime Files" section |

### Derived Sign-Off: reject

One reject criterion triggered (R2: README tree inaccuracy). Per rubric logic, any reject trigger produces a derived sign-off of `reject`.

### Actual Sign-Off: conditional-approve

### Override Justification:

R2 is genuinely triggered -- the README file tree omits `2026-02-08-sign-off-rubrics-design.md` at a depth it enumerates. However, the impact is limited: the omitted file is a design rationale document, not a runtime file that would cause workflow failure. The fix is a one-line addition to the README tree. The finding is documented as P0 #1 (must fix before proceeding), but the defect does not indicate a structural or design-level problem that warrants reject-level sign-off for the skill as a whole. The skill's source files are internally consistent and the workflow is well-specified; the hygiene issues are correctable without redesign.

Additionally, R3 (source/cache divergence on runtime files) was reclassified from reject to conditional after debate with developer-experience, who correctly argued that the cache divergence is a deployment process gap rather than a skill design defect. With R3 at conditional level, the remaining reject trigger (R2) is a documentation completeness issue that conditional-approve more accurately characterizes.

## Debate Notes

### Challenges Received

**From developer-experience: R3 (source/cache divergence) severity too aggressive at reject level.**

Challenge argued that source/cache divergence is a deployment process gap, not a skill design defect. The artifact under review is the skill's design and documentation; the cache is a deployment artifact that reflects whether someone ran a publish step. If the cache is auto-rebuilt on install, the divergence is a non-issue; if it requires manual update, the gap is in deployment process, not skill quality.

**Position changed: Yes.** I verified via filesystem timestamps that the cache was created at 08:33 and source was last modified at 10:26, confirming the cache is a stale point-in-time snapshot. The source files are internally consistent -- SKILL.md, analysis-schema.md, persona examples, README, and CLAUDE.md all describe the same 9-step workflow. The divergence means the deployment process is broken, not that the skill artifact is defective.

**Changes made:**
- Reclassified R3 from reject to conditional in the Rubric Assessment table
- Moved P0 #1 (update cache) to P1 #1 (deployment action, not skill design fix)
- Applied guided override: Derived sign-off remains reject (R2 still triggered), but actual sign-off changed to conditional-approve with justification that R2's impact is limited to a missing design doc reference (one-line fix, not a structural defect)
- Updated summary and sign-off sections to reflect the revised assessment

### Challenges Sent

**To workflow-architect: P1 #2 (rubrics.md generation gap) relationship to cache divergence.** Flagged that this finding is correct for the source version but moot for the deployed cache version (which has no rubrics.md in the schema at all). Not a severity challenge -- a dependency observation for synthesis. Workflow-architect acknowledged.

**To prompt-engineer: P1 #1 (rubric re-injection) relationship to cache divergence.** Flagged that the rubric persistence gap only exists in the source version with Step 5's multi-round hardening; the cache version has no rubric hardening, so rubrics stay in recent teammate context. Not a severity challenge -- a dependency observation. Prompt-engineer acknowledged.

**To developer-experience: P1 #1 (README fallback loss inventory) overlap with staleness.** Flagged that the incomplete fallback description in README is both a staleness issue (my scope: description wasn't updated after rubric hardening was added) and a DX issue (their scope: even if updated, it should include a full loss inventory). Both findings point to the same fix. Developer-experience acknowledged the overlap.

## Sign-Off

**conditional-approve** -- One reject criterion is technically triggered (README tree omits a design doc at an enumerated depth), but the impact is limited to a one-line documentation fix and does not indicate a structural defect in the skill. Four conditional criteria are triggered: source/cache divergence on runtime files (deployment process gap, reclassified from reject after debate), design doc staleness, old analysis runs in pre-schema format, and source/cache divergence on non-runtime files. All are correctable without redesign; none block the skill's core workflow from functioning correctly.
