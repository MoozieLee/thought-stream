# CLI Guide

The `thought` CLI is the query-oriented interface for ThoughtStream.

It is intended for:

- quick local inspection
- scripts
- automation
- agent workflows

## Build

```bash
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product thought
```

## Common Commands

```bash
./.build/debug/thought list --json
./.build/debug/thought tail 100 --json
./.build/debug/thought search clustering --json
./.build/debug/thought today --json
./.build/debug/thought export --from 7d --json
./.build/debug/thought stats --json
./.build/debug/thought days --limit 14 --json
./.build/debug/thought add --tag work --pinned "important note"
./.build/debug/thought get <id>
./.build/debug/thought update <id> --content "updated text" --tag work
./.build/debug/thought delete <id>
./.build/debug/thought config show
./.build/debug/thought config set-root /path/to/folder
```

## Command Groups

Query:

- `list`
- `tail`
- `search`
- `today`
- `export`
- `stats`
- `days`
- `get`

Write and update:

- `add`
- `update`
- `delete`

Config:

- `config`

## Config

The CLI reads and writes the same config file as the GUI app. Both always agree on the storage location.

```bash
# Show current storage root
thought config show

# Set storage root (migrates data automatically)
thought config set-root /path/to/folder

# Overwrite or merge if destination already has a database
thought config set-root /path/to/folder --overwrite
thought config set-root /path/to/folder --merge
```

When you change the storage root, the existing database (including `-wal` and `-shm` files) is automatically migrated to the new location, and the old files are cleaned up.

## Write Operations

Create a note:

```bash
./.build/debug/thought add "idea to revisit"
./.build/debug/thought add --tag work --tag cli --pinned "important note"
printf 'captured from stdin\n' | ./.build/debug/thought add --channel cli
```

Update a note:

```bash
./.build/debug/thought update <id> --content "updated text"
./.build/debug/thought update <id> --tag work --tag review --pinned
./.build/debug/thought update <id> --clear-tags --unarchived --unpinned
```

Delete a note:

```bash
./.build/debug/thought delete <id>
```

## Archive Filters

Most query commands support archive filtering:

```bash
./.build/debug/thought list --archived --json
./.build/debug/thought tail --unarchived --json
./.build/debug/thought search planning --archived --json
./.build/debug/thought today --unarchived --json
./.build/debug/thought days --archived --json
```

## Agent-Oriented Examples

Export recent human GUI captures:

```bash
./.build/debug/thought export --from 7d --source human --channel gui --json
```

Query older slices:

```bash
./.build/debug/thought search "retrieval ranking" --offset 100 --limit 100 --json
```

Inspect today's captures:

```bash
./.build/debug/thought today --source human --channel gui --json
```

Inspect day summaries:

```bash
./.build/debug/thought days --from 30d --json
```

## Notes

- `thought add` exists for testing and automation
- the primary capture path is still the GUI
- the CLI is the better place for heavier review and downstream workflows
- `thought update` supports `--clear-tags`, `--archived|--unarchived`, and `--pinned|--unpinned`
