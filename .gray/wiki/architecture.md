# Architecture

`gray-stamp` is a single-file Rust sidecar. The host (`gray`) spawns the
binary and talks to it over stdin/stdout with newline-delimited JSON
messages ("protocol 1.1" — `manifest()` in `src/lib.rs`). There is no
networking, no async runtime, and one dependency (`serde_json`).

## Components

All components live in `src/lib.rs`; `src/main.rs` only calls
`gray_stamp::run()`.

| Component | Code | Responsibility |
|-----------|------|----------------|
| Protocol loop | `run()`, `handle()` | Read JSON-lines requests from stdin, dispatch by `method`, write `{id, result}` / `{id, error}` replies to stdout; notifications (no `id`) get no reply; `plugin/shutdown` replies then exits the loop. |
| Manifest | `manifest()` | Static JSON: name `stamp`, protocol `1.1`, commands `["/stamps"]`, hooks `["prompt/context"]`, no tools. Also printable via the `manifest` argv shortcut in `run()`. |
| Session tracker | `Sess`, `State` | `State = Mutex<HashMap<String, Sess>>` keeps per-session in-flight state: `pending` tool calls `(name, Instant)`, `turn_start: Option<Instant>`, `tools_in_turn` count. Keyed by `session_key()`. |
| Ledger store | `ledger_append()`, `ledger_read()`, `ledger_path()`, `state_dir()`, `key_file()` | Append-only JSONL files under `$GRAY_HOME/stamps/` (or `~/.gray/stamps/`). One file per session; filename is a sanitized key plus a `DefaultHasher` suffix (`key_file`). Append errors go to stderr, never onto the wire. |
| Event recorder | `on_notify()` | Handles `event/notify`: `pre_tool` pushes a pending call (and lazily opens the turn), `post_tool` closes it and appends a `tool` entry, `turn_start` sets `turn_start`, `turn_end` appends a `turn` entry and resets the `Sess`. Pure observation — replies nothing. |
| Command surface | `run_command()`, `render_table()` | Implements `/stamps` (table), `/stamps clear` (delete file + drop session state), `/stamps path`. Formatting helpers `fmt_ms` and `fmt_clock` render durations and UTC `HH:MM:SS`. |
| Context annotator | `annotate()` | `prompt/context` hook: reads the ledger, finds the last `turn` entry, returns `{"text": "[stamp] last turn … · N tool calls · ledger …"}` or `{}` when no turn exists yet. |

## Dependency direction

```
main.rs ──▶ run() ──▶ handle() ──┬─▶ on_notify() ──▶ ledger_append()
                                 ├─▶ run_command() ─▶ ledger_read() / render_table()
                                 ├─▶ annotate() ────▶ ledger_read()
                                 └─▶ manifest()          (static)
                         all of the above use
                    session_key() → ledger_path() → state_dir()/key_file()
```

Everything flows through `handle()`, which is the single dispatch point.
The event path and the query paths (command, annotation) are independent
readers/writers of the same two stores: the in-memory `State` map and the
on-disk JSONL ledger.

## Boundaries and guarantees

- **Wire hygiene:** `event/notify` and any request without an `id` produce
  no stdout output (`handle` returns `(None, _)`); malformed JSON lines are
  skipped in `run()` (`src/lib.rs`).
- **Durability over perfection:** ledger writes never fail a request — I/O
  errors are printed to stderr and processing continues (`ledger_append`).
- **Resilience to gaps:** `post_tool` with no matching `pre_tool` falls
  back to the most recent pending call, and is dropped entirely if none is
  pending (`on_notify`); `turn_end` with no observed turn start stamps 0 ms
  (`README.md` → "Limits").
- **Concurrency:** sessions share one `Mutex`-guarded map; the guard is
  dropped before disk I/O so appends happen outside the lock (`on_notify`).
- **State vs. storage split:** `Sess` holds sub-second `Instant` timers
  (not serializable); the ledger holds only wall-clock `at`/`ms` values, so
  it survives sidecar restarts (`README.md`, `src/lib.rs` doc comment).
