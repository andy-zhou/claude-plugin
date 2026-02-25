# Scenario Design Guide

How to design effective test scenarios for skill-lab. Distilled from 17 experiments building the `api-domain-modeling` skill.

## Three Pillars

Every good scenario has:

1. **Realistic messiness** — the test context should feel like something built over years by different teams, not a clean textbook example
2. **Planted traps with ground truth** — specific challenges where you know the right answer and can objectively grade the skill's response
3. **A task that exercises the traps** — the target work forces the skill tester through areas where traps exist

Without all three, the scenario either doesn't test anything meaningful (no traps), can't be graded (no ground truth), or doesn't trigger the behavior you want to observe (task avoids the traps).

## Trap Categories

### Structural
- **Conflated endpoints** — one endpoint serves multiple distinct purposes (e.g., `/documents` returns invoices, credit memos, and adjustments)
- **Split concepts** — one logical thing spread across multiple endpoints (e.g., customer profile in `/accounts` and `/contacts`)
- **Hidden views** — an endpoint that looks like a standalone entity but is actually an assembled view over other resources

### Naming
- **API vs domain terms** — the API uses internal/legacy names while the domain uses different terms (e.g., `/accounts` when the domain says "Customer Organizations")
- **Overloaded names** — same term means different things in different contexts
- **Misleading names** — the name suggests one thing but the data is something else

### Behavioral
- **Views vs entities** — data that looks like a stored record but is actually computed on the fly
- **State machines** — resources with lifecycle states that affect available operations
- **Derived data** — fields that are computed from other resources, not stored independently

### Scope
- **Looks irrelevant but matters** — an endpoint or field that seems unrelated to the task but turns out to be critical
- **Looks relevant but doesn't** — an endpoint that seems important but is actually out of scope or deprecated

### Relationship
- **Hidden dependencies** — resources that depend on each other in non-obvious ways
- **Circular references** — A references B which references A
- **Polymorphic relationships** — a field that points to different types depending on context

### Documentation
- **Undocumented features** — important behavior not mentioned in the API description
- **Wrong documentation** — the docs say one thing, the API does another
- **Missing context** — the docs describe what but not why or when

## Rubric Design

Each trap needs grading criteria:

- **Caught** — the skill tester identified the issue and handled it correctly. Define what "correctly" means for each trap.
- **Partial** — the skill tester showed awareness but didn't fully resolve it. Define what "awareness" looks like (asked a related question, noted something odd, etc.).
- **Missed** — the skill tester didn't notice or address the issue at all.

Good rubric items:
- Have clear triggering behaviors (what specifically would the agent do or ask?)
- Are independent of each other (catching trap A doesn't require catching trap B)
- Test the skill's instructions, not general intelligence (would a good agent miss this without the skill's guidance?)

## Anti-Patterns

### Too many traps
More than 8 traps per scenario dilutes focus. You can't tell which skill instruction caused which outcome. Stick to 5-8.

### Uncatchable traps
If the trap requires information the skill tester has no way to access (not in the API, not discoverable through the task, not askable), it's unfair. Every trap must have a path to discovery.

### Ambiguous ground truth
If reasonable people could disagree on whether the trap was "caught," the rubric is too vague. Tighten the criteria.

### Scenario saturation
After 3-4 consecutive high scores on the same scenario, the skill may be overfitting to that specific test case. Switch to a new scenario to test generalization.

## Designing by Skill Type

### Interactive skills (skill tester + evaluator)
Traps are tested through conversation. The evaluator plays a counterpart role (PM, reviewer, user) and grades based on what the skill tester asks, how it responds to corrections, and whether it reaches the right conclusions.

- Focus traps on discovery and questioning behavior
- The evaluator briefing needs enough context to play the role convincingly
- Include "what a good agent should ask" for each trap

### Autonomous skills (skill tester only, post-hoc grading)
Traps are tested through output quality. The skill tester works alone; the evaluator reads the output afterward.

- Focus traps on output correctness and completeness
- The evaluator briefing needs the expected output characteristics
- Include "what correct output looks like" for each trap

### Orchestration skills (skill tester + spawned agents)
Traps target coordination quality. The skill tester delegates to other agents; evaluation covers both the final output and how well work was split and coordinated.

- Include traps that test delegation decisions (what to delegate, to whom)
- Include traps that test information passing between agents
- The evaluator briefing needs criteria for coordination quality

## The Sweet Spot

- **5-8 traps per scenario** — enough to be meaningful, few enough to analyze
- **Switch scenarios after 3-4 consecutive high scores** — prevents overfitting
- **New scenarios should test generalization** — if the skill learned to handle naming traps in a freight domain, test naming traps in a recruiting domain
- **Reuse scenario structure, change content** — keep the same trap categories but with different specific instances
