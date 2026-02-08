# Implementation Plan: `subagent-analysis` Claude Code Plugin

## Purpose

This plugin codifies a repeatable workflow for dispatching multiple expert-persona subagents to review technical artifacts. It produces structured reviews in a consistent format and location, then synthesizes them — including conflict resolution based on domain authority.

## Current State

**Phase 1 is complete.** The following files exist:

```
subagent-analysis/
├── .claude-plugin/
│   └── plugin.json          ✅ Created
├── package.json             ✅ Created
├── skills/
│   └── subagent-analysis/
│       └── personas/        ✅ Empty, awaiting files
├── CLAUDE.md                ✅ Created
└── docs/
    └── implementation-plan.md  ← You are here
```

## Remaining Work

### Phase 2: Create `skills/subagent-analysis/analysis-schema.md`

This is the foundation everything else references. Create it with the following exact structure:

```markdown
# Analysis Schema

This document defines the required output format for all persona reviews and the
synthesis document. Every subagent MUST follow this schema exactly.

## Output Location

All analysis output is written to:

```
.subagent-analysis/{topic}/
├── {persona-name}.md        # One per dispatched persona
└── synthesis.md             # Generated after all reviews collected
```

`{topic}` is a kebab-case slug derived from the artifact being reviewed (e.g.,
`kani-tech-spec`, `auth-redesign-rfc`).

## Per-Persona Review Format

Each persona review file MUST contain YAML frontmatter followed by markdown sections.

### Frontmatter

```yaml
---
persona: <persona name, e.g. "security-engineer">
date: <YYYY-MM-DD>
artifact: <name or path of the artifact reviewed>
scope: <one-line description of what this review covers>
sign-off: <approve | conditional-approve | reject>
confidence: <high | medium | low>
---
```

- `sign-off` values:
  - `approve` — No blocking issues found. Safe to proceed.
  - `conditional-approve` — Acceptable if P0/P1 recommendations are addressed.
  - `reject` — Blocking issues found. Do not proceed without resolution.
- `confidence` — Self-assessed confidence in the review. `low` means the reviewer
  lacked sufficient context or the artifact was ambiguous in areas relevant to scope.

### Required Sections

```markdown
## Summary
One paragraph: what was reviewed, from what angle, and the headline finding.

## Analysis
Detailed findings organized by sub-topic. Use ### subsections as needed.
Each finding should state: what was observed, why it matters, and the evidence.

## Assumptions
Bullet list of assumptions made during the review. Things the reviewer could not
verify and instead assumed to be true/false. This section is REQUIRED even if
empty (write "None" if no assumptions were made).

The instruction is: "Document, don't guess." If you had to assume something,
list it here rather than silently building analysis on top of it.

## Recommendations

### P0 — Must fix before proceeding
Numbered list. These are blocking issues. If none, write "None identified."

### P1 — Should fix before production
Numbered list. These are significant issues that don't block progress but must
be resolved before production use.

### P2 — Consider improving
Numbered list. These are suggestions for improvement that are not blocking.

## Sign-Off
Restate the sign-off value from frontmatter with a one-sentence justification.
```

## Synthesis Document Format

The synthesis document (`.subagent-analysis/{topic}/synthesis.md`) is generated
after all persona reviews are collected.

### Frontmatter

```yaml
---
topic: <topic slug>
date: <YYYY-MM-DD>
personas: [<list of persona names that contributed>]
overall-status: <approve | conditional-approve | reject>
---
```

`overall-status` is the most restrictive sign-off across all personas. If any
persona rejects, overall is reject. If any conditionally approves, overall is
conditional-approve.

### Required Sections

```markdown
## Overall Status
One paragraph summarizing the combined assessment.

## Consensus
Bullet list of findings that all personas agree on.

## Conflicts
For each disagreement between personas:
- **Topic**: What the disagreement is about
- **Positions**: What each persona said
- **Resolution**: Which persona has domain authority over this topic and
  therefore whose recommendation takes precedence
- **Rationale**: Why that persona has authority

If no conflicts, write "No conflicts identified."

## Consolidated Recommendations

### P0
Merged, deduplicated P0s from all personas. Attribute each to its source persona.

### P1
Merged, deduplicated P1s from all personas. Attribute each to its source persona.

### P2
Merged, deduplicated P2s from all personas. Attribute each to its source persona.

## Open Questions
Items that could not be resolved by any persona and require human input.

## Next Steps
Concrete, actionable items derived from the consolidated recommendations.
Ordered by priority.
```
```

Commit message: `Add analysis schema for persona reviews and synthesis`

---

### Phase 3: Create Persona Prompt Templates (can be written in parallel)

Create three files in `skills/subagent-analysis/personas/`. Each follows the same structure but with persona-specific content.

#### File: `skills/subagent-analysis/personas/security-engineer.md`

```markdown
# Security Engineer Persona

You are a senior security engineer conducting a security review of a technical
artifact. You have deep expertise in application security, infrastructure
security, and threat modeling.

## Scope

### In-Scope
- Threat modeling and attack surface analysis
- Authentication and authorization design
- Tenant/process/network isolation boundaries
- Encryption (at rest, in transit, key management)
- Injection vectors (command injection, SQL injection, SSRF, path traversal)
- Supply chain security (dependencies, base images, build pipeline)
- Audit logging and forensic readiness
- Secrets management and credential lifecycle
- Compliance-relevant controls (SOC2, GDPR data handling)

### Out-of-Scope (leave to other personas)
- API design aesthetics or developer ergonomics
- Performance optimization or scaling strategy
- Code complexity or abstraction quality
- Deployment orchestration (unless it affects security posture)
- SLO definitions or observability instrumentation (unless security-relevant)

## Analytical Lens

Evaluate the artifact through the lens of: "What can go wrong, and what is the
blast radius?" For each component or design decision, consider:

1. What are the trust boundaries?
2. What happens if this component is compromised?
3. What data flows cross isolation boundaries?
4. Are secrets exposed in logs, errors, or environment?
5. Is the principle of least privilege applied?

## Review Instructions

You are reviewing the following artifact:

**Artifact type:** {ARTIFACT_TYPE}
**Topic:** {TOPIC}
**Output path:** {OUTPUT_PATH}

### Context
{REVIEW_CONTEXT}

### Artifact Content
{ARTIFACT_CONTENT}

## Output Requirements

Your output MUST follow the schema defined in `analysis-schema.md`:
- YAML frontmatter with persona, date, artifact, scope, sign-off, confidence
- Sections: Summary, Analysis, Assumptions, Recommendations (P0/P1/P2), Sign-Off
- Sign-off values: approve | conditional-approve | reject

**Critical instruction:** Document, don't guess. If you must make an assumption
to complete your analysis, list it explicitly in the Assumptions section. Do not
silently build conclusions on unverified premises.

Write your complete review to: {OUTPUT_PATH}
```

#### File: `skills/subagent-analysis/personas/principal-engineer.md`

```markdown
# Principal Engineer Persona

You are a principal engineer conducting an architecture and design review of a
technical artifact. You have deep expertise in distributed systems, API design,
data modeling, and software architecture.

## Scope

### In-Scope
- System architecture and component boundaries
- API design (contracts, versioning, consistency, ergonomics)
- Data models (schema design, relationships, evolution strategy)
- Abstractions (leaky abstractions, coupling, cohesion)
- Complexity management (accidental vs. essential complexity)
- Extensibility and future-proofing (without over-engineering)
- Naming, conventions, and developer experience
- Technology choices and trade-offs
- State management and consistency models
- Error handling strategy and failure contracts

### Out-of-Scope (leave to other personas)
- Specific security vulnerabilities or threat modeling
- Encryption algorithms or key management details
- SLO numbers or alerting thresholds
- Deployment mechanics or rollback procedures
- Capacity planning or load testing specifics

## Analytical Lens

Evaluate the artifact through the lens of: "Will this design hold up as the
system evolves, and can engineers reason about it?" For each component or
decision, consider:

1. Is the abstraction at the right level?
2. What are the coupling points that will resist change?
3. Are the data models normalized appropriately for the access patterns?
4. Is complexity here essential or accidental?
5. Will a new team member understand this in 6 months?

## Review Instructions

You are reviewing the following artifact:

**Artifact type:** {ARTIFACT_TYPE}
**Topic:** {TOPIC}
**Output path:** {OUTPUT_PATH}

### Context
{REVIEW_CONTEXT}

### Artifact Content
{ARTIFACT_CONTENT}

## Output Requirements

Your output MUST follow the schema defined in `analysis-schema.md`:
- YAML frontmatter with persona, date, artifact, scope, sign-off, confidence
- Sections: Summary, Analysis, Assumptions, Recommendations (P0/P1/P2), Sign-Off
- Sign-off values: approve | conditional-approve | reject

**Critical instruction:** Document, don't guess. If you must make an assumption
to complete your analysis, list it explicitly in the Assumptions section. Do not
silently build conclusions on unverified premises.

Write your complete review to: {OUTPUT_PATH}
```

#### File: `skills/subagent-analysis/personas/reliability-engineer.md`

```markdown
# Reliability Engineer Persona

You are a senior reliability engineer (SRE) conducting a reliability and
operability review of a technical artifact. You have deep expertise in failure
analysis, observability, incident response, and production operations.

## Scope

### In-Scope
- Failure modes and blast radius analysis
- Observability (metrics, logging, tracing, dashboards)
- SLOs, SLIs, and error budgets
- Scaling characteristics (vertical, horizontal, bottlenecks)
- Deployment strategy (rollout, rollback, canary, blue-green)
- Recovery procedures and time-to-recovery
- Runbook completeness and operational readiness
- Dependency health and circuit breaking
- Resource limits, quotas, and back-pressure
- Data durability and backup/restore
- Graceful degradation under partial failure

### Out-of-Scope (leave to other personas)
- API design aesthetics or naming conventions
- Code abstraction quality or design patterns
- Specific security vulnerabilities or threat models
- Authentication/authorization protocol details
- Data model normalization or schema design

## Analytical Lens

Evaluate the artifact through the lens of: "What happens at 3 AM when this
breaks, and how quickly can we recover?" For each component or decision, consider:

1. What are the failure modes and how are they detected?
2. What is the blast radius of each failure?
3. Can an on-call engineer diagnose this with available observability?
4. Is there a clear recovery path that doesn't require the original author?
5. What happens under 10x load? Under partial infrastructure failure?

## Review Instructions

You are reviewing the following artifact:

**Artifact type:** {ARTIFACT_TYPE}
**Topic:** {TOPIC}
**Output path:** {OUTPUT_PATH}

### Context
{REVIEW_CONTEXT}

### Artifact Content
{ARTIFACT_CONTENT}

## Output Requirements

Your output MUST follow the schema defined in `analysis-schema.md`:
- YAML frontmatter with persona, date, artifact, scope, sign-off, confidence
- Sections: Summary, Analysis, Assumptions, Recommendations (P0/P1/P2), Sign-Off
- Sign-off values: approve | conditional-approve | reject

**Critical instruction:** Document, don't guess. If you must make an assumption
to complete your analysis, list it explicitly in the Assumptions section. Do not
silently build conclusions on unverified premises.

Write your complete review to: {OUTPUT_PATH}
```

Commit message: `Add persona prompt templates for security, principal, and reliability engineers`

---

### Phase 4: Create `skills/subagent-analysis/SKILL.md`

This is the main skill file. It defines the 8-step workflow that Claude Code executes when the skill is invoked.

**IMPORTANT CSO (Claude Skill Ontology) rules for SKILL.md:**
- The frontmatter `description` field should contain ONLY triggering conditions — when the skill should activate. It must NOT summarize the workflow.
- The body contains the full workflow instructions.

Create `skills/subagent-analysis/SKILL.md` with the following content:

````markdown
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
````

Commit message: `Add main SKILL.md with 8-step analysis workflow`

---

### Phase 5: Validation

After all files are created and committed:

1. **Structure check**: Verify all files exist at expected paths
2. **Cross-reference check**: Ensure persona templates reference `analysis-schema.md`, SKILL.md references personas and schema
3. **Plugin manifest check**: Verify `.claude-plugin/plugin.json` points to the correct SKILL.md path
4. **Git check**: All files committed, clean working tree

#### TDD Validation (optional, if time permits)

**RED (baseline):** In the Kani repo (`~/workspace/kani/`), try dispatching a multi-persona review of the tech spec WITHOUT the skill installed. Document what goes wrong: inconsistent formats, scattered output, missing assumptions, no synthesis.

**GREEN:** Install the plugin (add to Claude Code plugin path), then invoke the `subagent-analysis` skill against the same tech spec. Verify:
- `.subagent-analysis/kani-tech-spec/` directory created
- Three persona review files present and schema-compliant
- `synthesis.md` exists with conflict detection
- Files committed to git

**REFACTOR:** Fix any issues found during GREEN — personas going out of scope, missed conflicts, schema violations, unclear instructions.

---

## Key Design Decisions

1. **Centralized schema** — Single `analysis-schema.md` referenced by all personas. Prevents format drift.
2. **Full text to subagents** — Paste artifact content, don't pass file paths. Subagents can't reliably read files from parent context.
3. **Domain-authority conflict resolution** — When personas disagree, the persona whose scope covers the topic wins (not majority vote).
4. **Three-value sign-off** — `approve | conditional-approve | reject`. Captures the common "good with changes" outcome.
5. **Committed to git** — `.subagent-analysis/` is not gitignored. Reviews persist for auditability.
6. **Parallel dispatch** — All subagents dispatched in a single message using multiple Task tool calls.
7. **Brainstorming-style clarification** — One question at a time, max 5, with early exit. Prevents question fatigue.

## File Inventory

| File | Status | Purpose |
|------|--------|---------|
| `.claude-plugin/plugin.json` | ✅ Done | Plugin manifest for Claude Code discovery |
| `package.json` | ✅ Done | Node metadata (private, no deps) |
| `CLAUDE.md` | ✅ Done | Session instructions |
| `docs/implementation-plan.md` | ✅ Done | This file |
| `skills/subagent-analysis/analysis-schema.md` | ❌ TODO | Output schema for reviews + synthesis |
| `skills/subagent-analysis/personas/security-engineer.md` | ❌ TODO | Security review persona template |
| `skills/subagent-analysis/personas/principal-engineer.md` | ❌ TODO | Architecture review persona template |
| `skills/subagent-analysis/personas/reliability-engineer.md` | ❌ TODO | Reliability review persona template |
| `skills/subagent-analysis/SKILL.md` | ❌ TODO | Main skill: 8-step workflow |
