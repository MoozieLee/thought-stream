# ThoughtStream

Minimal macOS thought capture with a Spotlight-style overlay and a query-first CLI.

See [ROADMAP.md](/Users/liyipeng/Documents/GitHub/thought-stream/ROADMAP.md) for the current improvement plan.

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
./.build/debug/thought get <id>
./.build/debug/thought update <id> --content "updated text" --tag work
./.build/debug/thought delete <id>
```

`thought add` exists for testing and automation, but the primary capture flow is the GUI.

Useful agent filters:

```bash
./.build/debug/thought export --from 7d --source human --channel gui --json
./.build/debug/thought search "retrieval ranking" --offset 100 --limit 100 --json
./.build/debug/thought days --from 30d --json
```

## Tags

ThoughtStream treats inline tags as a capture-time shortcut, not as the long-term source of truth.

- It supports only single-token tags such as `#work`, `#thoughtstream`, or `#code-review`.
- Tags cannot contain spaces. For multi-word concepts, prefer kebab-case or snake_case, such as `#code-review` or `#weekly_review`.
- On `add`, inline tags are automatically extracted into the structured `tags` field.
- Extracted tags remain in the stored `content`.
- On `update --content`, inline `#tag` tokens are parsed again, but only to add newly detected tags.
- Updating `content` does not automatically remove existing tags.
- Tags remain structured metadata after capture; editing tags later should not depend on rewriting the original note text.

Examples:

```text
干完现在的活 #工作
```

Stored as:

- `content`: `干完现在的活 #工作`
- `tags`: `["工作"]`

```text
#生活 买一把香蕉
```

Stored as:

- `content`: `#生活 买一把香蕉`
- `tags`: `["生活"]`

## Storage

By default the app uses `~/Library/Application Support/ThoughtStream`.

For development or agent runs, you can override storage with:

```bash
export THOUGHT_STREAM_HOME="$PWD/.thought-stream"
```
