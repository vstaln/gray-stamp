# Flow: tool-call timing

`pre_tool` opens a pending call; `post_tool` closes it and appends one
`tool` line to the session ledger. All of this happens inside
`on_notify()` in `src/lib.rs`, triggered by `event/notify` messages —
notifications, so the host never waits on a reply.

## Steps

1. `event/notify` with `params.type == "pre_tool"` and `params.name`
   arrives (no `id`).
2. `on_notify` resolves the session with `session_key()` and locks
   `State`, fetching-or-creating `Sess`.
3. `sess.turn_start.get_or_insert_with(Instant::now)` — the first
   observed event of a turn opens the turn timer even if no `turn_start`
   event was seen.
4. `(name, Instant::now())` is pushed onto `sess.pending`. `name` falls
   back to `"?"` when absent.
5. Later, `post_tool` arrives with the tool `name`.
6. The matching pending entry is found by
   `rposition(|(n, _)| n == name)` — most recent pending call with that
   name; if none matches, it falls back to the *last* pending entry
   (`pending.len().checked_sub(1)`). If `pending` is empty the event is
   skipped entirely — this covers a sidecar restart mid-call
   (`README.md` → "Limits").
7. The entry is removed, `sess.tools_in_turn += 1`, and the mutex guard
   is dropped **before** disk I/O.
8. `ledger_append` writes one JSON line to
   `~/.gray/stamps/<key_file>.jsonl`:

   ```json
   {"kind":"tool","name":"bash","at":1760000000,"ms":1234}
   ```

   `at` is `now_unix()` (wall clock, unix seconds); `ms` is
   `t0.elapsed().as_millis()` — the pre→post duration measured with
   `Instant`, immune to wall-clock adjustments.

## Result

The entry is rendered by `/stamps` as
`HH:MM:SS  tool bash          1.2s` (see
[stamps-command.md](stamps-command.md)) and counted in the next `turn`
entry's `tools` field (see [turn-timing.md](turn-timing.md)).
