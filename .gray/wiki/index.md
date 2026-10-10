# gray-stamp

A per-session **timing ledger** plugin (sidecar) for `gray`. Port of pi's
`stamp` extension: the host's `pre_tool` / `post_tool` / `turn_start` /
`turn_end` events are recorded as timestamped JSON-lines entries, the
`/stamps` command renders them as a timing table, and a `prompt/context`
hook adds a one-line annotation (`[stamp] last turn 42.1s · 3 tool calls`)
to every turn so the timing signal is visible in the transcript
(`README.md`, `src/lib.rs` doc comment).

The plugin is pure observation: it never answers `allow`/`deny` and never
rewrites tool calls (`README.md` → "Wire").

## Repository layout

Flat tree, one real source file:

- `src/lib.rs` — the entire plugin: manifest, JSON-lines protocol loop,
  per-session state, ledger I/O, `/stamps` rendering, `prompt/context`
  annotation, and unit tests. See [modules/lib.md](modules/lib.md).
- `src/main.rs` — 3-line binary shim calling `gray_stamp::run()`.
- `Cargo.toml` — package `gray-stamp` 0.1.0, edition 2024, rust ≥1.91;
  the only dependency is `serde_json = "1"`; release builds are stripped.
- `README.md` — user-facing doc (events stamped, commands, install, limits).

## Build, test, run

```sh
cargo build --release    # produces target/release/gray-stamp
cargo test               # 5 unit tests in src/lib.rs (mod tests)
```

Standalone protocol check — the binary speaks JSON lines on stdio:

```sh
./target/release/gray-stamp manifest   # prints the plugin/manifest JSON and exits
./target/release/gray-stamp            # serves requests on stdin until EOF or plugin/shutdown
```

Install into `gray` (`README.md` → "Install"):

```sh
gray plugin install ./target/release/gray-stamp
```

At runtime the host launches the binary as a sidecar and exchanges
`plugin/manifest`, `command/run`, `prompt/context`, `event/notify`, and
`plugin/shutdown` messages over stdio — see
[flows/sidecar-protocol.md](flows/sidecar-protocol.md).

## Data produced

One append-only ledger per session at
`~/.gray/stamps/<sanitized-key>-<hash>.jsonl` (or `$GRAY_HOME/stamps/`
when `GRAY_HOME` is set — `state_dir` in `src/lib.rs`). Entry shapes:

- `{"kind":"tool","name":<tool>,"at":<unix-secs>,"ms":<duration>}` — written on `post_tool`
- `{"kind":"turn","at":<unix-secs>,"ms":<duration>,"tools":<count>}` — written on `turn_end`

See [flows/tool-timing.md](flows/tool-timing.md) and
[flows/turn-timing.md](flows/turn-timing.md).

## Pages

- [architecture.md](architecture.md) — components, boundaries, dependencies
- [modules/lib.md](modules/lib.md) — the `gray_stamp` library module
- Flows
  - [flows/sidecar-protocol.md](flows/sidecar-protocol.md) — stdio request loop
  - [flows/tool-timing.md](flows/tool-timing.md) — `pre_tool`→`post_tool` → tool entry
  - [flows/turn-timing.md](flows/turn-timing.md) — `turn_start`→`turn_end` → turn entry
  - [flows/stamps-command.md](flows/stamps-command.md) — `/stamps`, `clear`, `path`
  - [flows/prompt-context.md](flows/prompt-context.md) — per-turn annotation
- [glossary.md](glossary.md) — terms and abbreviations
