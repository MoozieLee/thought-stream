# ThoughtStream

Minimal macOS thought capture with a Spotlight-style overlay and a query-first CLI.

## Targets

- `ThoughtStreamApp`: background macOS app with a global hotkey (`Shift+Command+Space`)
- `thought`: CLI for list/search/export/stats, intended for agent queries

## Build

```bash
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product ThoughtStreamApp
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product thought
```

## Run

```bash
./.build/debug/ThoughtStreamApp
```

Or build a native app bundle:

```bash
./scripts/build_app.sh
open ./dist/ThoughtStream.app
```

Or build, install to `/Applications`, and launch in one step:

```bash
./scripts/install_app.sh
```

Press `Shift+Command+Space` to open the capture overlay.

- `Enter` saves
- `Shift+Enter` inserts a newline
- `Esc` cancels

## CLI

```bash
./.build/debug/thought list --json
./.build/debug/thought tail 100 --json
./.build/debug/thought search clustering --json
./.build/debug/thought export --from 7d --json
./.build/debug/thought stats --json
./.build/debug/thought days --limit 14 --json
```

`thought add` exists for testing and automation, but the primary capture flow is the GUI.

Useful agent filters:

```bash
./.build/debug/thought export --from 7d --source human --channel gui --json
./.build/debug/thought search "retrieval ranking" --offset 100 --limit 100 --json
./.build/debug/thought days --from 30d --json
```

## Storage

By default the app uses `~/Library/Application Support/ThoughtStream`.

For development or agent runs, you can override storage with:

```bash
export THOUGHT_STREAM_HOME="$PWD/.thought-stream"
```
