# Module: `gray_stamp` (`src/lib.rs`)

The whole plugin lives in one library module (~420 lines); `src/main.rs`
is a 3-line shim that calls `gray_stamp::run()`. See
[../architecture.md](../architecture.md) for how the pieces fit together.

## Public surface

| Item | Signature | Notes |
|------|-----------|-------|
| `run` | `pub fn run() -> std::io::Result<()>` | Sidecar entry point. With argv `manifest` it prints the manifest and exits; otherwise it serves the JSON-lines loop until EOF or `plugin/shutdown`. |

Everything else is private — the host only ever talks to the process over
stdio, so no other API is exported.

## Internal types

| Type | Definition | Purpose |
|------|-----------|---------|
| `Sess` | `struct { pending: Vec<(String, Instant)>, turn_start: Option<Instant>, tools_in_turn: usize }` | In-flight state for one session: open tool calls with their start `Instant`s, the open turn's start, and the per-turn tool counter. Reset to `Default` on `turn_end`. |
| `State` | `Mutex<HashMap<String, Sess>>` | All sessions, keyed by session key. |

## Function map (by role)

**Protocol & dispatch**
- `manifest() -> Value` — static plugin manifest (`protocol: "1.1"`,
  command `/stamps`, hook `prompt/context`).
- `handle(req, &State) -> (Option<Value>, bool)` — one request → optional
  reply + exit flag. Routes `plugin/manifest`, `prompt/context`,
  `command/run`, `plugin/shutdown`; unknown methods get JSON-RPC error
  `-32601`. Requests with no `id` are notifications → `on_notify`.
- `on_notify(&State, params)` — records `pre_tool` / `post_tool` /
  `turn_start` / `turn_end` into `Sess` and appends ledger entries.

**Session identity & paths**
- `session_key(params) -> String` — `session.id`, else `session.cwd`,
  else `"default"`.
- `state_dir() -> PathBuf` — `$GRAY_HOME/stamps`, else `~/.gray/stamps`,
  else `./stamps`.
- `key_file(key) -> String` — filename-safe key: alnum/`.`/`-` kept
  (max 48 chars, dots trimmed), rest → `_`, plus a `DefaultHasher`
  hex suffix to prevent collisions.
- `ledger_path(key) -> PathBuf` — `state_dir()/key_file(key).jsonl`.
- `now_unix() -> u64` — current unix seconds.

**Ledger I/O**
- `ledger_append(key, entry)` — creates the dir if needed, appends one
  JSON line; failures go to stderr only.
- `ledger_read(path) -> Vec<Value>` — parses each line, silently skipping
  unparseable ones; missing file → empty vec.

**Command & annotation**
- `run_command(argv, params, &State) -> String` — `/stamps` subcommands:
  none → `render_table`, `clear`, `path`, else usage string.
- `render_table(entries, path) -> String` — the `/stamps` table:
  `HH:MM:SS  tool <name>  <dur>` / `… turn … · N tools` rows and an
  `N entries` footer; `(empty — …)` when there is nothing.
- `annotate(params) -> Value` — `prompt/context` hook; `{"text": …}` built
  from the last `turn` entry, or `{}` when none exists.

**Formatting**
- `fmt_ms(ms) -> String` — `Nms` < 1 s, `N.Ns` < 60 s, else `NmNNs`.
- `fmt_clock(unix) -> String` — `HH:MM:SS` in UTC (unix mod 86400; a
  timing table, not a calendar — see the comment in `src/lib.rs`).

## Tests (`mod tests`, same file)

Serialized via a static `Mutex` + `with_home` helper that points
`GRAY_HOME` at a fresh temp dir (the env var is process-global).
- `manifest_shape` — manifest fields.
- `tool_and_turn_events_write_ledger` — end-to-end: notify → ledger file →
  `/stamps` text → `prompt/context` annotation.
- `annotation_empty_without_turns` — `{}` result when no turn stamped.
- `stamps_clear_resets` — `clear` deletes entries and reports the count.
- `shutdown_replies_then_exits` — `plugin/shutdown` replies and sets the
  exit flag.
