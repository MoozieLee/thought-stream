# Getting Started

## What ThoughtStream Is

ThoughtStream has two entry points:

- `ThoughtStreamApp`
  - the macOS overlay for capture and lightweight retrieval
- `thought`
  - the CLI for query, export, and automation

The typical workflow is:

1. capture quickly in the overlay
2. keep working
3. come back later with search, filters, and summaries

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

That install script also tries to create `/usr/local/bin/thought`.

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

- `Enter` saves the current input
- `Shift+Enter` inserts a newline
- `Esc` returns, cancels editing, hides state, or closes the panel depending on context
- `↓` opens recent notes from an empty input
- `Tab` switches between the input and result browsing

## First Commands To Try

Inside the overlay, try:

- `/tail`
- `/tail 20`
- `/search onboarding`
- `/today`
- `/tag work`
- `/archive`
- `/keys`
- `/help`

Use `/help` for the command list and `/keys` for the shortcut list.

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
3. edit the note in the input field
4. press `Enter` to save or `Esc` to cancel

## Where Data Lives

By default, ThoughtStream stores its database at:

```text
~/Library/Application Support/ThoughtStream/thoughts.sqlite3
```

You can change that later from the menu bar app or with `thought config set-root`.

## Next Docs

- [Overlay Guide](overlay.md)
- [CLI Guide](cli.md)
- [Tags](tags.md)
- [Storage](storage.md)
- [Distribution](distribution.md)
- [Troubleshooting](troubleshooting.md)
