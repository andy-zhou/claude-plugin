---
name: subagent-analysis
description: Use when you need to dispatch multiple expert personas to review a technical artifact (spec, PRD, RFC, design doc, codebase) and produce a structured synthesis of their findings with conflict resolution.
user-invocable: true
argument-hint: "[artifact-path]"
allowed-tools: Read, Write, Bash, Glob, Grep, Task, AskUserQuestion
---

# Multi-Persona Expert Analysis

Dispatch parallel expert-persona teammates to review a technical artifact, collect
structured reviews, facilitate inter-persona debate, and synthesize findings with
debate-first conflict resolution.

## Prerequisites

Before starting, verify:
1. The `analysis-schema.md` file exists at `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/analysis-schema.md`
2. Example persona templates exist in `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/personas/examples/`
   (for reference only — personas are generated dynamically)
3. The target artifact is accessible (file path or inline content)
4. Agent teams are enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings or environment). If not enabled, inform the user how to enable it and fall back to Task-tool subagent dispatch (skip Step 6: Debate).

If `$ARGUMENTS` is provided, treat it as the artifact path to review.

## Workflow

### Step 1: Identify Scope

Determine what artifact is being reviewed and what kind of review is needed.

- Read the artifact fully. Do not summarize or truncate.
- Identify the artifact type (tech spec, PRD, RFC, code, design doc, etc.)
- Derive a `{TOPIC}` slug in kebab-case (e.g., `kani-tech-spec`)

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

**Persona definition output:** For each persona, define:
- **Name**: kebab-case slug (e.g., `security-engineer`, `data-architect`, `ml-reviewer`)
- **Role**: one-line description of who this reviewer is
- **Scope**: what's in-scope and out-of-scope for this reviewer
- **Analytical lens**: the core question this persona asks (e.g., "What can go
  wrong and what is the blast radius?" for security)

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
1. Create the output directory: `.subagent-analysis/{topic}/`
2. Determine each persona's output path: `.subagent-analysis/{topic}/{persona-name}.md`
3. Read the full artifact content — teammates receive the FULL TEXT, not a file path

### Step 4: Create Agent Team and Dispatch Reviews

Create an agent team with one teammate per persona defined in Step 2. The lead
operates in delegate mode, focusing on orchestration rather than implementing.

**Agent team setup:**
1. Ask Claude to create an agent team for multi-persona review
2. Spawn one teammate per persona
3. Enter delegate mode (Shift+Tab) so the lead coordinates without implementing

**For each teammate, construct a spawn prompt that includes:**
- The persona definition from Step 2 (role, scope, analytical lens), formatted
  following the structure of examples in `${CLAUDE_PLUGIN_ROOT}/skills/subagent-analysis/personas/examples/`
- The full analysis-schema.md content so the teammate has the schema without
  needing to read files
- The full artifact content with these context fields:
  - `{ARTIFACT_CONTENT}` → full text of the artifact
  - `{ARTIFACT_TYPE}` → type identified in Step 1
  - `{TOPIC}` → topic slug from Step 1
  - `{OUTPUT_PATH}` → path from Step 3
  - `{REVIEW_CONTEXT}` → any relevant context from the brainstorming conversation
- Instruction to write the review to the output path using the Write tool
- Instruction to mark their review task as complete when done

**Critical: Full text, not file paths.** Teammates have their own context windows.
Always paste the complete artifact content into the spawn prompt.

**Do NOT require plan approval for teammates.** Their task is to write a review,
not implement code. Plan approval adds friction with no benefit here.

### Step 5: Collect and Validate Reviews

After all teammates complete their review tasks:
1. Read each persona's output file
2. Validate against the schema:
   - YAML frontmatter present with all required fields?
   - All required sections present (Summary, Analysis, Assumptions, Recommendations, Sign-Off)?
   - Sign-off value is one of: approve, conditional-approve, reject?
   - Confidence value is one of: high, medium, low?
   - Assumptions section exists (even if "None")?
3. If a review fails validation, note the issues but proceed (do not re-dispatch)

### Step 6: Debate

**Skip this step if using Task-tool fallback (agent teams not available).**

After all reviews are written and validated, facilitate an inter-persona debate
where teammates challenge each other's findings.

**Debate protocol:**

1. **Cross-review tasks**: Create a task for each teammate: "Read the other
   personas' reviews in `.subagent-analysis/{topic}/` and identify findings you
   disagree with or want to challenge."

2. **Direct challenges**: Teammates message each other directly with challenges.
   Example: a security-focused reviewer messages an architecture reviewer —
   "Your recommendation to simplify the auth layer removes a defense-in-depth
   boundary."

3. **Convergence detection**: The lead monitors the exchange and calls time after
   either:
   - Each teammate has sent at least one round of challenges and responses, OR
   - Two broadcast rounds have occurred without new substantive disagreements

4. **Review updates**: After debate ends, each teammate gets a final task:
   "Update your review file if the debate changed any of your findings. Add a
   `## Debate Notes` section documenting what was challenged and whether you
   changed your position. This section is required even if no challenges were
   received — write 'No challenges received' in that case."

```
┌──────────────────────┐
│  Reviews written     │
│  (Step 5 complete)   │
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
│  Step 7: Synthesize  │
└──────────────────────┘
```

### Step 7: Synthesize

Generate `.subagent-analysis/{topic}/synthesis.md` following the synthesis schema.

**Conflict Resolution — Debate First:**

Conflicts are primarily resolved through the debate phase. When personas disagree:

1. **Debate resolution**: If the personas resolved the disagreement themselves
   during the debate phase, note it as resolved with `Resolution-source: debate`.
2. **Scope-based authority**: If the debate did not resolve the conflict, the lead
   determines which persona's defined scope most directly covers the disputed
   topic. That persona's position takes precedence. Note as
   `Resolution-source: domain-authority`.
3. **Escalation**: If the conflict doesn't clearly fall under any persona's scope,
   or if it involves a genuine trade-off between domains, list it in Open Questions
   for human resolution. Note as `Resolution-source: escalated`.

Do NOT use majority vote. A 2-1 outcome where the dissenting persona has the
most relevant expertise is wrong.

When debate was not conducted (Task-tool fallback), omit `Resolution-source` and
resolve all conflicts via scope-based authority.

### Step 8: Act

After synthesis:
1. Present a summary to the user with:
   - Overall status (from synthesis frontmatter)
   - Count of P0/P1/P2 across all personas
   - Any conflicts and their resolutions (noting which were resolved by debate vs. authority)
   - Open questions requiring human input
2. Stage and commit all files in `.subagent-analysis/{topic}/` with message:
   `Add {topic} multi-persona analysis`
3. Clean up the agent team: shut down all teammates, then ask the lead to clean up team resources
4. Ask the user if they want to take action on any recommendations

**Critical: Always clean up the agent team.** Shut down teammates before cleanup.
Do not leave orphaned teammates running.

## Fallback: Task-Tool Subagent Dispatch

If agent teams are not available (feature not enabled or user declines), fall back
to the original Task-tool approach:

- **Step 4 becomes**: Use the Task tool to dispatch one subagent per persona.
  ALL dispatches MUST happen in a single message (parallel execution).
  Use `subagent_type: "general-purpose"` for each.
- **Step 6 is skipped**: No debate phase. Proceed directly to synthesis.
- **Step 8**: No team cleanup needed.

All other steps remain the same.

## Common Mistakes

| Mistake | Why it's wrong | What to do instead |
|---------|---------------|-------------------|
| Using preset personas without brainstorming | Misses context-specific review angles | Always brainstorm personas from the artifact and user concerns |
| Passing file paths instead of full text | Teammates have their own context windows | Paste full artifact content into spawn prompt |
| Letting the lead implement instead of delegate | Lead should orchestrate, not review | Enter delegate mode after spawning teammates |
| Using majority vote for conflicts | A 2-1 vote where the dissenter has domain expertise is wrong | Use debate-first resolution, then scope-based authority |
| Skipping the Assumptions section | Silent assumptions hide risk | Require it even if "None" |
| Summarizing the artifact for teammates | Lossy; teammates need full context | Send complete, untruncated text |
| Re-dispatching on schema violation | Expensive and likely to produce similar issues | Note violations, proceed with synthesis |
| Committing before validation | May commit malformed reviews | Validate first, then commit |
| Requiring plan approval for teammates | Adds friction; teammates write reviews, not code | Do not require plan approval |
| Not cleaning up the agent team | Leaves orphaned teammates consuming resources | Always shut down teammates and clean up |
| Teammates editing each other's reviews | Each persona owns their own file only | Teammates challenge via messaging, update only their own file |
| Skipping Debate Notes after debate | Loses the record of what was challenged | Require the section even if "No challenges received" |
