# Flow: turn timing

`turn_start` (or the first tool event) opens a turn timer; `turn_end`
appends one `turn` line and resets the session. Implemented in
`on_notify()` in `src/lib.rs`.

## Steps

1. **Open.** Either of these sets `sess.turn_start = Some(Instant::now())`:
   - `event/notify` with `type == "turn_start"` (explicit — `src/lib.rs`
     `on_notify`, `"turn_start"` arm), or
   - the first `pre_tool` of the turn, via
     `turn_start.get_or_insert_with(Instant::now)` (implicit fallback).
2. **Accumulate.** During the turn, each completed `post_tool` bumps
   `sess.tools_in_turn` (see [tool-timing.md](tool-timing.md)).
3. **Close.** `event/notify` with `type == "turn_end"`:
   - `ms = turn_start.elapsed()` if a start exists, else `0` — a turn
     with no tool calls and no `turn_start` event stamps ~0 ms
     (`README.md` → "Limits").
   - Builds `{"kind":"turn","at":<unix>,"ms":<u64>,"tools":<count>}`.
   - `*sess = Sess::default()` — pending calls, turn timer and tool
     counter are all cleared, so the next turn starts clean.
   - The mutex guard is dropped, then `ledger_append` writes the line to
     `~/.gray/stamps/<key_file>.jsonl`.

## Result

- `/stamps` renders it as `HH:MM:SS  turn              42.1s · 3 tools`
  (`render_table` in `src/lib.rs`).
- `prompt/context` surfaces it as `[stamp] last turn 42.1s · 3 tool
  calls · ledger <path>` (see [prompt-context.md](prompt-context.md)).

## Notes

- Turn duration is *first observed event of the turn → `turn_end`*, not
  necessarily the host's true turn start (`README.md` → "Limits").
- `turn_end` is the only event that wipes `Sess`; a `post_tool` straggler
  after it lands in the *next* turn's state (or is dropped if `pending`
  is empty).
