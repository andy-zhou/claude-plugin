# Analysis Playbook

How to analyze experiment results and turn them into skill improvements. Distilled from 17 experiments building the `api-domain-modeling` skill.

## One Failure at a Time

Don't try to fix everything in one cycle. Pick the most impactful failure, understand it deeply, fix it, and test again. Fixing multiple things simultaneously makes it impossible to know which fix worked.

**Priority order:**
1. Failures where the skill didn't instruct the agent at all (missing guidance)
2. Failures where the skill's instructions were unclear or contradictory
3. Failures where the agent ignored clear instructions (may need stronger framing)
4. Edge cases that only matter in specific scenarios

## Chain of Whys

For each failure, trace from observation to root cause:

1. **Observation** — what happened? ("The agent didn't ask about the naming mismatch")
2. **Proximate cause** — what directly caused it? ("The agent moved on after the first question about /accounts")
3. **Root cause** — why did that happen? ("The skill doesn't instruct the agent to compare API names with domain names")
4. **Generalizability** — is this a pattern? ("The skill has no guidance on vocabulary, only structure")

The root cause determines the fix. A proximate-cause fix is a band-aid; a root-cause fix improves the skill generally.

## Failure Classification

### Skill failure
The skill didn't tell the agent to do something. The agent had no way to know.

**Fix:** Add or clarify skill instructions. This is the most common and most valuable failure type — it means the TDD process is working.

### Agent failure
The skill told the agent to do something but the agent ignored it or did it wrong.

**Fix options:**
- Rephrase the instruction (maybe it was ambiguous)
- Add emphasis or examples (maybe it was easy to miss)
- Restructure the skill (maybe the instruction was in the wrong place)
- Accept it (agents aren't perfect — if the instruction is clear, the failure may not recur)

### Scenario issue
The scenario didn't exercise the thing you wanted to test. The trap existed but the task didn't lead the agent through it.

**Fix:** Adjust the scenario. Modify the task, add a trigger, or redesign the trap to be more discoverable. This is not a skill problem.

### Infrastructure issue
Timing, permissions, message delivery, or other test harness problems caused the failure.

**Fix:** Adjust the harness, scripts, or agent prompts. Don't change the skill for infrastructure problems.

## Overfitting Watch

After every proposed fix, ask: "Does this improve the skill generally, or only for this specific scenario?"

**Signs of overfitting:**
- The fix references specific domain terms from the test scenario
- The fix adds a rule that only applies to one type of trap
- The fix would make the skill worse for other skill types
- The fix is very specific where a general principle would work

**Signs of healthy generalization:**
- The fix teaches a general principle that applies across domains
- The fix improves a process step that all scenarios would exercise
- The fix clarifies an instruction that was ambiguous regardless of context

## Fix Proposals

Present fixes as multiple choice with recommendations:

```
The agent missed the naming mismatch between /accounts and "Customer Organizations."

Root cause: The skill has no instruction to compare API endpoint names with domain terminology.

Options:
A. Add a "vocabulary check" step after bootstrap — compare every endpoint name
   with how the PM refers to the concept (recommended — general, lightweight)
B. Add a naming-specific trap detector — look for camelCase vs domain terms
   (too specific to this scenario)
C. Defer — test with a different scenario first to see if this is a pattern
   (safe but slower progress)
```

## Recording

### Experiment log format

Each experiment gets a file in `docs/experiment-log/experiment-{N}.md`:

1. **Setup** — what changed since last experiment (skill edits, scenario changes, harness updates)
2. **Observations** — rubric scorecard, notable behaviors, surprises
3. **Learnings** — why failures happened, what the results reveal about the skill's instructions
4. **Decisions** — what to change next, what to defer, what to test differently
5. **Changes Applied** — exact edits made to skill/harness/scenarios

### Commit discipline

- **Results first:** Commit experiment output, log entry, and README update together
- **Skill changes separate:** Commit skill or harness changes in a separate commit
- This makes it easy to see what was tested vs. what was changed

### README update

Add a row to `docs/experiment-log/README.md` with experiment number, date, scenario, score, and link to the log file.

## Iteration Pattern

```
Cycle 1:   Baseline — observe natural failures, identify what the skill must teach
Cycle 2:   First fixes — test targeted improvements
Cycle 3-4: Refinement — test edge cases on the same scenario
Cycle 5:   New scenario — test generalization in a different domain/context
Cycle 6+:  Repeat refinement + generalization
```

**The baseline is the most valuable experiment.** It shows what the agent does without guidance, revealing every gap the skill needs to fill. Don't skip it.

**Scenario rotation prevents overfitting.** After 3-4 consecutive improvements on one scenario, switch to a new one. If the skill's score drops on the new scenario, the fixes were too specific.

**Diminishing returns signal completion.** When you consistently score 80%+ across multiple scenarios, the skill is mature. Further improvements require harder scenarios or new trap categories.
