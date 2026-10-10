# Flow: `prompt/context` annotation

Before every turn, the host calls the `prompt/context` hook (declared in
`manifest()`); `annotate()` in `src/lib.rs` answers with a one-line
timing note that rides along in the transcript/context.

## Steps

1. `handle()` routes `method == "prompt/context"` (a request — it has an
   `id`) to `annotate(&params)`.
2. `annotate` resolves `session_key(params)` → `ledger_path(key)` and
   loads the file with `ledger_read`.
3. It scans entries in reverse for the last one with `kind == "turn"`.
   - **Found:** returns
     `{"text": "[stamp] last turn 42.1s · 3 tool calls · ledger /path/to/<key>.jsonl"}`
     — duration via `fmt_ms`, tool count from the entry's `tools` field,
     plus the ledger path.
   - **Not found** (fresh session, or after `/stamps clear`): returns
     `{}` — an empty result, i.e. no annotation is injected.
4. `run()` writes `{"id": <id>, "result": …}` to stdout.

## Result

Every turn after the first completed one carries a `[stamp] last turn …`
line in context, so the agent can see how long the previous turn and its
tool calls took. Cost: one file read per turn — the ledger is small
(append-only, one line per event) and parsed leniently.

## Related

- Turn entries are produced by [turn-timing.md](turn-timing.md).
- The annotation text is verified by the
  `tool_and_turn_events_write_ledger` and `annotation_empty_without_turns`
  tests in `src/lib.rs`.
