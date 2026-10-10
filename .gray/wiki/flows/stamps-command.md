# Flow: `/stamps` command

Renders the session ledger — or clears it, or prints its path. Triggered
when the host sends a `command/run` request; handled by `run_command()`
in `src/lib.rs`.

## Steps

1. `handle()` sees a request (has `id`) with `method == "command/run"`,
   extracts `params.argv` (array of strings → `Vec<&str>`), and calls
   `run_command(&argv, &params, state)`.
2. `run_command` resolves `session_key(params)` → `ledger_path(key)`.
3. Dispatch on `argv.first()`:

   | argv | Action | Output (`result.text`) |
   |------|--------|------------------------|
   | *(none)* | `ledger_read(path)` → `render_table(entries, path)` | Table described below |
   | `clear` | count entries via `ledger_read`, `remove_file(path)`, drop `state[…]` | `cleared N ledger entries` |
   | `path` | — | ledger file path |
   | other | — | `usage: /stamps [clear\|path]` |

4. The text is wrapped as `{"id": <id>, "result": {"text": …}}` and
   written to stdout by `run()`.

## Table format (`render_table`)

```
stamp ledger — /home/u/.gray/stamps/s1-1a2b3c4d5e6f7a8b.jsonl
12:03:41  tool bash            1.2s
12:03:55  tool read            420ms
12:04:02  turn                 42.1s · 2 tools
3 entries
```

- Header shows the ledger path; an empty ledger prints
  `(empty — no turns or tool calls stamped yet)` instead of rows.
- Each row: `at` rendered as UTC `HH:MM:SS` (`fmt_clock`), then
  `tool <name>` or `turn`, then the right-aligned duration (`fmt_ms` —
  `Nms` / `N.Ns` / `NmNNs`), and for turns `· N tool(s)`.
- Footer counts total ledger lines (`N entries`) — including entry kinds
  the renderer doesn't display.

## Notes

- `clear` also removes the in-memory `Sess` for the session
  (`state.lock().remove(&key)`), so a subsequent `turn_end` from a stale
  in-flight turn can't recreate entries with half state.
- Reading is forgiving: corrupt lines in the JSONL file are skipped by
  `ledger_read`, so the table renders whatever parses.
