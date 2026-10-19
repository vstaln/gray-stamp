#!/bin/sh
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
sys="$(uname -s)"
case "$sys" in
MINGW* | MSYS* | CYGWIN*) rel="x86_64-pc-windows-msvc/gray-stamp.exe" ;;
Darwin*)
    case "$(uname -m)" in
    arm64) rel="aarch64-apple-darwin/gray-stamp" ;;
    *) rel="x86_64-apple-darwin/gray-stamp" ;;
    esac ;;
*)
    case "$(uname -m)" in
    aarch64 | arm64) rel="aarch64-unknown-linux-musl/gray-stamp" ;;
    *) rel="x86_64-unknown-linux-musl/gray-stamp" ;;
    esac ;;
esac
if [ -x "$here/$rel" ]; then exec "$here/$rel" "$@"; fi
for cand in "$here/target/release/gray-stamp.exe" "$here/target/release/gray-stamp" "$here/target/debug/gray-stamp.exe" "$here/target/debug/gray-stamp"; do
    if [ -x "$cand" ]; then exec "$cand" "$@"; fi
done
echo "gray-stamp binary not found in $here" >&2
exit 1
