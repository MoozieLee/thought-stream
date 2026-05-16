<p align="center">
  <a href="./README.zh-Hans.md">🇨🇳 简体中文</a>
  &nbsp;&bull;&nbsp;
  <strong>🇬🇧 English</strong>
</p>

# ThoughtStream

ThoughtStream is a local-first thought inbox for macOS.

It is built for a simple workflow:

- stay in flow while working
- capture a thought instantly
- come back later to review it
- use CLI and AI at the review stage, not the capture stage

Most note tools ask you to organize too early.

ThoughtStream is designed around a different idea:

1. capture without context switching
2. keep working
3. review later
4. summarize what mattered with modern AI tools

## Who It Is For

ThoughtStream is best for:

- Mac power users
- developers and CLI users
- writers, researchers, and note-heavy knowledge workers
- people who want something lighter than a full PKM app

It is not trying to be a full notes workspace.

## What It Includes

- `ThoughtStreamApp`
  - a Spotlight-style macOS overlay
  - global hotkey: `Shift+Command+Space`
  - low-friction capture, lightweight slash commands, and quick review
- `thought`
  - a CLI for querying, exporting, updating, and deleting thoughts
  - intended for scripting, automation, agent workflows, and AI-assisted review

## Quick Start

### One-liner install (requires macOS 13+)

```bash
curl -fsSL https://raw.githubusercontent.com/liyipeng/thought-stream/main/scripts/install.sh | sh
```

This downloads the latest release DMG from GitHub, installs the app to `/Applications`, and creates the `thought` CLI symlink.

If the latest release is unsigned, macOS may block first launch until you right-click the app in Finder and choose `Open`. See [Distribution](docs/distribution.md) for the exact first-run steps.

### Build from source

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

## Why It Exists

ThoughtStream is not trying to be a full notes app.

The goal is to keep capture friction very low while you are working, then let retrieval, review, and summarization happen later against a stable local store.

That means the project intentionally favors:

- append-first capture
- minimal interruption
- lightweight in-panel retrieval
- local storage
- explicit CLI access for downstream review and AI workflows

And it intentionally avoids:

- heavy organization during capture
- turning the overlay into a workspace
- pushing AI into the capture moment

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
- `/keys`
- `/help`
- `/exit`

Use `/keys` in the overlay to see the available keyboard shortcuts.

## Docs

- [Getting Started](docs/getting-started.md)
- [CLI Guide](docs/cli.md)
- [Tags](docs/tags.md)
- [Storage](docs/storage.md)
- [Distribution](docs/distribution.md)
- [Roadmap](ROADMAP.md)

## Current Status

The current build already supports:

- native macOS overlay capture
- query-oriented CLI
- slash commands in the overlay
- lightweight result reuse, keyboard help, and GUI editing
- release packaging scripts for `.app`, `.zip`, and `.dmg`

## License

License is not set yet.
