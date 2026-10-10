# gray-stamp

A per-session timing ledger. Port of pi's `stamp` extension: `pre_tool`,
`post_tool`, and `turn_end` events append timestamped entries to a JSONL
ledger, and `/stamps` renders the table. `prompt/context` adds a one-line
annotation (`[stamp] last turn 42.1s · 3 tool calls`) to every turn so the
timing signal is visible in the transcript/context.

## What gets stamped

| event        | ledger entry                                        |
|--------------|-----------------------------------------------------|
| `pre_tool`   | opens a pending call (per session)                  |
| `post_tool`  | `{kind:"tool", name, at, ms}` — pre→post duration   |
| `turn_end`   | `{kind:"turn", at, ms, tools}` — turn wall time     |

Ledgers live at `~/.gray/stamps/<session-key>.jsonl` — one file per
session, append-only, durable across sidecar restarts.

## Commands

- `/stamps` — timing table (UTC `HH:MM:SS`, duration, per-turn tool count)
- `/stamps clear` — wipe this session's ledger
- `/stamps path` — print the ledger file path

## Wire

`plugin/manifest`, `command/run`, `prompt/context`, `plugin/shutdown`, plus
`event/notify` for `pre_tool`/`post_tool`/`turn_start`/`turn_end`. Protocol
1.1; pure observation — it never answers `allow`/`deny` or rewrites calls.

## Install

```sh
cargo build --release
gray plugin install ./target/release/gray-stamp
```

## Limits

Turn duration is measured from the first observed event of the turn to
`turn_end` — a turn with no tool calls stamps ~0ms unless the host emits
`turn_start`. Timestamps render in UTC. `post_tool` without a matching
`pre_tool` (e.g. sidecar restarted mid-call) is skipped.
