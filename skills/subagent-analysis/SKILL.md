---
name: subagent-analysis
description: Use when you need to dispatch multiple expert personas to review a technical artifact (spec, PRD, RFC, design doc, codebase) and produce a structured synthesis of their findings with conflict resolution.
---

# Multi-Persona Expert Analysis

Dispatch parallel expert-persona subagents to review a technical artifact, collect
structured reviews, and synthesize findings with domain-authority conflict resolution.

## Prerequisites

Before starting, verify:
1. The `analysis-schema.md` file exists at `skills/subagent-analysis/analysis-schema.md`
   (relative to the plugin root)
2. Persona templates exist in `skills/subagent-analysis/personas/`
3. The target artifact is accessible (file path or inline content)

## Workflow

### Step 1: Identify Scope

Determine what artifact is being reviewed and what kind of review is needed.

- Read the artifact fully. Do not summarize or truncate.
- Identify the artifact type (tech spec, PRD, RFC, code, design doc, etc.)
- Derive a `{TOPIC}` slug in kebab-case (e.g., `kani-tech-spec`)

### Step 2: Clarify with User (Pre-Dispatch)

Before selecting personas or dispatching, clarify scope and priorities with the
user using a brainstorming-style conversation.

**Rules:**
- Ask ONE question at a time
- Maximum 5 clarification questions before proceeding
- Use AskUserQuestion tool for each question
- Stop early if the user says "just go" or provides enough context

**Questions to consider (pick the most relevant, not all):**
- What aspects of this artifact are you most concerned about?
- Are there known risks or areas of uncertainty?
- Is there prior review feedback to incorporate?
- What is the intended audience/use of this artifact?
- Are there specific personas you want or don't want?

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
│  Clarify    │     │  "just go"?  │
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
│  Step 3: Select Personas    │
└─────────────────────────────┘
```

### Step 3: Select Personas

Choose which personas to dispatch based on the artifact type and clarification
answers. You do NOT have to use all three — select only those relevant.

**Available personas:**
| Persona | Best for |
|---------|----------|
| `security-engineer` | Anything touching auth, isolation, secrets, data flow, compliance |
| `principal-engineer` | Architecture, API design, data models, abstractions, complexity |
| `reliability-engineer` | Failure modes, observability, SLOs, scaling, deployment, recovery |

**Selection rules:**
- Always provide reasoning for each persona included/excluded
- For a tech spec: all three are usually appropriate
- For a pure API design doc: principal + security, skip reliability
- For a runbook: reliability + security, skip principal
- User can override by requesting specific personas in Step 2

### Step 4: Align Output

Before dispatching:
1. Create the output directory: `.subagent-analysis/{topic}/`
2. Determine each persona's output path: `.subagent-analysis/{topic}/{persona-name}.md`
3. Read the full artifact content into a variable — subagents receive the FULL TEXT,
   not a file path

### Step 5: Dispatch Subagents in Parallel

Use the Task tool to dispatch one subagent per selected persona. ALL dispatches
MUST happen in a single message (parallel execution).

For each subagent:
- `subagent_type`: Use the appropriate agent type (typically `general-purpose`)
- Construct the prompt by reading the persona template and replacing placeholders:
  - `{ARTIFACT_CONTENT}` → full text of the artifact
  - `{ARTIFACT_TYPE}` → type identified in Step 1
  - `{TOPIC}` → topic slug from Step 1
  - `{OUTPUT_PATH}` → path from Step 4
  - `{REVIEW_CONTEXT}` → any relevant context from Step 2 clarification
- Include the full analysis-schema.md content in the prompt so the subagent has
  the schema without needing to read files
- Instruct the subagent to write its review to the output path using the Write tool

**Critical: Full text, not file paths.** Subagents cannot reliably read files from
the parent context. Always paste the complete artifact content into the prompt.

### Step 6: Collect and Validate Reviews

After all subagents complete:
1. Read each persona's output file
2. Validate against the schema:
   - YAML frontmatter present with all required fields?
   - All required sections present (Summary, Analysis, Assumptions, Recommendations, Sign-Off)?
   - Sign-off value is one of: approve, conditional-approve, reject?
   - Confidence value is one of: high, medium, low?
   - Assumptions section exists (even if "None")?
3. If a review fails validation, note the issues but proceed (do not re-dispatch)

### Step 7: Synthesize

Generate `.subagent-analysis/{topic}/synthesis.md` following the synthesis schema.

**Conflict Resolution — Domain Authority:**

When personas disagree, the persona whose explicit scope covers the topic has
authority. Do NOT use majority vote.

| Conflict Topic | Authority |
|----------------|-----------|
| Authentication, encryption, injection, audit logging | security-engineer |
| API contracts, data models, abstractions, naming | principal-engineer |
| Failure modes, SLOs, observability, recovery | reliability-engineer |
| Deployment security (e.g., secrets in CI) | security-engineer |
| Deployment mechanics (e.g., rollback strategy) | reliability-engineer |
| Performance (latency, throughput) | reliability-engineer |
| Complexity vs. security trade-off | Escalate — note as Open Question |

When the conflict doesn't clearly fall under one persona's scope, list it in
Open Questions for human resolution.

### Step 8: Act

After synthesis:
1. Present a summary to the user with:
   - Overall status (from synthesis frontmatter)
   - Count of P0/P1/P2 across all personas
   - Any conflicts and their resolutions
   - Open questions requiring human input
2. Stage and commit all files in `.subagent-analysis/{topic}/` with message:
   `Add {topic} multi-persona analysis`
3. Ask the user if they want to take action on any recommendations

## Common Mistakes

| Mistake | Why it's wrong | What to do instead |
|---------|---------------|-------------------|
| Passing file paths to subagents | Subagents may not have file access | Paste full artifact content |
| Dispatching subagents sequentially | Wastes time; they're independent | Use parallel Task tool calls in one message |
| Using majority vote for conflicts | A 2-1 vote on security by non-security personas is wrong | Use domain-authority table above |
| Skipping the Assumptions section | Silent assumptions hide risk | Require it even if "None" |
| Summarizing the artifact for subagents | Lossy; subagents need full context | Send complete, untruncated text |
| Dispatching all 3 personas always | Not all reviews need all perspectives | Select based on artifact type + user input |
| Re-dispatching on schema violation | Expensive and likely to produce similar issues | Note violations, proceed with synthesis |
| Committing before validation | May commit malformed reviews | Validate first, then commit |
