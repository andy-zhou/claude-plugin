## Subagent Spawning (Test Mode)

**Team lead name:** `team-lead` (via SendMessage, for subagent lifecycle only)

When the skill instructs you to spawn a subagent, do NOT use the Task tool directly. Instead, route all subagent lifecycle through the team lead via SendMessage. The team lead spawns the agent with exactly the prompt you provide.

### Spawning

1. **Write the subagent's prompt** to `{{SPAWN_DIR}}/<name>.md`, then **send a `spawn_request`** to `team-lead` — both in the same turn, file first:

   ```json
   {
     "type": "spawn_request",
     "name": "billing",
     "prompt_file": "<spawn-dir>/billing.md"
   }
   ```

   - `name` — short identifier for the subagent
   - `prompt_file` — absolute path to the prompt file you just wrote

   Write the prompt exactly as you would for a Task tool call — include the agent's role, task, any context it needs, communication instructions (who to message, how to report back), and output paths.

2. **STOP after sending** — same turn discipline as other messages. Do not make any more tool calls that turn.

3. The team lead will respond with a `spawn_response`:

   ```json
   {
     "type": "spawn_response",
     "name": "sub-billing",
     "status": "spawned"
   }
   ```

   The returned `name` is the subagent's address — use it for all subsequent SendMessage calls to that subagent. The team lead adds a `sub-` prefix to prevent name collisions with other agents.

   If the name is already in use, the response will have `"status": "error"` with a `reason` field. Choose a different name and retry.

### Shutting down

You are responsible for shutting down your subagents when you no longer need them. Send a `terminate_request` to `team-lead`:

```json
{
  "type": "terminate_request",
  "name": "sub-billing"
}
```

Use the namespaced name from the `spawn_response`. STOP after sending. The team lead will respond:

```json
{
  "type": "terminate_response",
  "name": "sub-billing",
  "status": "terminated"
}
```

Shut down all active subagents before you finish your work.

### Output

Subagent reports are written to `{{OUTPUT_DIR}}/subagent-reports/`. You may read files there for detailed findings, but do not write to that directory.
