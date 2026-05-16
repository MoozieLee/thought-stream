<p align="center">
  <a href="./README.zh-Hans.md">🇨🇳 简体中文</a>
  &nbsp;&bull;&nbsp;
  <strong>🇬🇧 English</strong>
</p>

# ThoughtStream

ThoughtStream is a local-first macOS capture tool for short thoughts, plus a query-first CLI for later retrieval.

It is designed around one constraint:

- capture should stay fast
- retrieval inside the overlay should stay lightweight
- heavier review should happen later, through CLI or agent workflows

## What It Includes

- `ThoughtStreamApp`
  - a Spotlight-style macOS overlay
  - global hotkey: `Shift+Command+Space`
  - fast capture, lightweight slash commands, and result reuse
- `thought`
  - a CLI for querying, exporting, updating, and deleting thoughts
  - intended for scripting, automation, and agent workflows

## Quick Start

Build the app and CLI:

```bash
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product ThoughtStreamApp
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product thought
```

Install and launch the macOS app:

```bash
./scripts/install_app.sh
```

Or run the app directly:

```bash
./.build/debug/ThoughtStreamApp
```

## Basic Usage

Open the overlay with `Shift+Command+Space`.

- `Enter` saves a new thought
- `Shift+Enter` inserts a newline
- `Esc` cancels or exits the current lightweight mode
- `↓` opens recent notes
- `Tab` moves between input and result browsing

Some built-in slash commands:

- `/tail`
- `/search <query>`
- `/today`
- `/tag <tag>`
- `/archive`
- `/help`
- `/exit`

## Docs

- [Getting Started](docs/getting-started.md)
- [CLI Guide](docs/cli.md)
- [Tags](docs/tags.md)
- [Storage](docs/storage.md)
- [Distribution](docs/distribution.md)
- [Roadmap](ROADMAP.md)

## Why This Project Exists

ThoughtStream is not trying to be a full notes app.

The goal is to keep capture friction very low, then let retrieval, review, and agent workflows happen later against a stable local store.

That means the project intentionally favors:

- append-first capture
- lightweight in-panel retrieval
- local storage
- explicit CLI access for downstream workflows

And it intentionally avoids:

- heavy organization during capture
- turning the overlay into a workspace
- pushing all workflows into the GUI

## Current Status

The current build already supports:

- native macOS overlay capture
- query-oriented CLI
- slash commands in the overlay
- lightweight result reuse and GUI editing
- release packaging scripts for `.app`, `.zip`, and `.dmg`

## License

License is not set yet.
