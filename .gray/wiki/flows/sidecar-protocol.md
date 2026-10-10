# Flow: sidecar request loop

How the process talks to the `gray` host. Entry point → dispatch → reply
or silence → exit.

## Steps

1. **Launch.** `src/main.rs` → `gray_stamp::run()` (`src/lib.rs`). The
   host spawns `gray-stamp` with no arguments.
   - Shortcut: `gray-stamp manifest` prints `manifest()` to stdout and
     returns immediately — used at install/inspection time.
2. **Serve.** `run()` creates the shared `State`
   (`Mutex<HashMap<String, Sess>>`) and iterates `stdin.lock().lines()`.
3. **Parse.** Each line is parsed with `serde_json::from_str::<Value>`;
   unparseable lines are skipped (`continue`) — the loop never dies on
   bad input.
4. **Dispatch.** `handle(req, &state)` inspects the request:
   - **No `id`** → notification: `event/notify` is forwarded to
     `on_notify`; any notification returns `(None, exit)`. Nothing is
     written back. `plugin/shutdown` without an `id` just sets `exit`.
   - **With `id`** → request, dispatched on `method`:
     | method | handler | result |
     |--------|---------|--------|
     | `plugin/manifest` | `manifest()` | manifest JSON |
     | `prompt/context` | `annotate(params)` | `{"text": …}` or `{}` |
     | `command/run` | `run_command(argv, params, state)` | `{"text": …}` |
     | `plugin/shutdown` | — | `{}` result **and** exit flag |
     | anything else | — | error `{"code": -32601, "message": "method not found"}` |
5. **Reply.** If `handle` returned `Some(reply)`, `run()` writes
   `{reply}\n` to stdout and flushes.
6. **Exit.** When the exit flag is set (or stdin hits EOF) the loop breaks
   and the process ends.

## Key facts

- Request/reply is JSON-RPC-shaped but minimal: `result` or `error`,
  no batching, no `jsonrpc` field (`src/lib.rs` → `handle`).
- Replies never contain ledger I/O errors — those go to stderr
  (`ledger_append`).
- One process serves many sessions concurrently; `session_key()` picks
  the `Sess` and ledger file per request.
