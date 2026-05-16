# Getting Started

## What ThoughtStream Is

ThoughtStream has two entry points:

- `ThoughtStreamApp`
  - the macOS overlay for capture and lightweight retrieval
- `thought`
  - the CLI for query, export, and automation

## Build

```bash
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product ThoughtStreamApp
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product thought
```

## Run the App

For development:

```bash
./.build/debug/ThoughtStreamApp
```

To build a native app bundle:

```bash
./scripts/build_app.sh
open ./dist/ThoughtStream.app
```

To build, install to `/Applications`, and launch in one step:

```bash
./scripts/install_app.sh
```

## First Run

Unsigned or ad hoc local builds may require one manual approval on first launch.

If that happens:

1. drag `ThoughtStream.app` to `/Applications`
2. in Finder, right-click `ThoughtStream.app` and choose `Open`
3. confirm `Open` again in the system prompt

If that still fails:

1. open `System Settings -> Privacy & Security`
2. then use `Open Anyway`

Signed and notarized releases should not need this extra step.

## Overlay Basics

Open the overlay with:

```text
Shift + Command + Space
```

Basic keys:

- `Enter` saves
- `Shift+Enter` inserts a newline
- `Esc` cancels or exits the current lightweight mode
- `↓` opens recent notes
- `Tab` switches between input and result browsing

## In-App Help

The overlay includes two built-in help entry points:

- `/help` shows the available slash commands
- `/keys` shows the available keyboard shortcuts

## Result Browsing

When the result panel is open:

- `↑/↓` move through results
- `Enter` reuses the selected note as a new draft
- `Cmd+C` copies the selected note content
- `Cmd+D` deletes the selected note
- `Cmd+P` toggles pin
- `Cmd+Delete` toggles archive
- `Cmd+E` edits the selected note

## Editing an Existing Note

From result browsing:

1. select a note
2. press `Cmd+E`

Editing behavior:

- `Enter` saves the update
- `Esc` cancels editing and returns to result browsing

## Next Docs

- [CLI Guide](cli.md)
- [Tags](tags.md)
- [Storage](storage.md)
- [Distribution](distribution.md)
