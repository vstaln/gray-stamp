# Glossary

Terms used by gray-stamp and its wiki pages.

| Term | Meaning |
|------|---------|
| **sidecar** | A helper process the `gray` host spawns and talks to over stdin/stdout with newline-delimited JSON. `gray-stamp` is one; `run()` in `src/lib.rs` is its loop. |
| **protocol 1.1** | Version string in the plugin manifest (`manifest()`). The wire set is `plugin/manifest`, `command/run`, `prompt/context`, `plugin/shutdown`, plus `event/notify`. |
| **`plugin/manifest`** | Request asking the plugin to describe itself — name, version, protocol, commands, hooks. Also printable via `gray-stamp manifest` (argv shortcut in `run()`). |
| **`event/notify`** | Fire-and-forget message (no `id`, no reply) carrying host events in `params.type`. gray-stamp consumes `pre_tool`, `post_tool`, `turn_start`, `turn_end`. |
| **`pre_tool` / `post_tool`** | Host events bracketing a tool call. gray-stamp measures the gap with `Instant` and stamps a `tool` entry. |
| **`turn_start` / `turn_end`** | Host events bracketing a turn. `turn_end` stamps a `turn` entry and resets the session state. |
| **`command/run`** | Request to run a plugin command. For gray-stamp: `/stamps` with argv `[]`/`["clear"]`/`["path"]`. |
| **`prompt/context`** | Hook the host calls each turn for extra context text; `annotate()` returns the `[stamp] last turn …` line or `{}`. |
| **`plugin/shutdown`** | Tells the sidecar to exit; gray-stamp replies (if it had an `id`) then breaks the stdin loop. |
| **turn** | One agent round-trip as seen by the host. Timed from the first observed event to `turn_end`; carries a `tools` count. |
| **ledger** | The append-only JSONL file holding all stamped entries for one session. Read fully by `/stamps` and by the `prompt/context` hook. |
| **JSONL** | JSON Lines — one JSON object per line; the on-disk format of every ledger entry (`{"kind":"tool"|"turn", …}`). |
| **session key** | String identifying a session: `params.session.id`, else `session.cwd`, else `"default"` (`session_key()`). |
| **`key_file`** | The ledger filename derived from the session key — sanitized to `[A-Za-z0-9.-]` (max 48 chars) plus a `DefaultHasher` hex suffix (`key_file()`). |
| **`Sess`** | In-memory per-session struct: `pending` tool calls, `turn_start`, `tools_in_turn` (`src/lib.rs`). Lives only in RAM — unlike the ledger it does not survive restarts. |
| **pending call** | A `pre_tool` not yet closed by `post_tool`; stored as `(name, Instant)` in `Sess.pending`. |
| **`GRAY_HOME`** | Env var overriding the state root; ledgers live at `$GRAY_HOME/stamps/`, default `~/.gray/stamps/` (`state_dir()`). Tests set it to a temp dir. |
| **`/stamps`** | The plugin's only command: timing table (default), `clear`, `path` (`run_command()`). |
| **pi's `stamp` extension** | The original extension this crate ports (`README.md`, `src/lib.rs` doc comment). |
