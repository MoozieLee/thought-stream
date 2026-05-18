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

## Command Reference

`list`

- General-purpose query command
- Supports `--limit`, `--offset`, `--from`, `--to`, `--source`, `--channel`, `--archived`, `--unarchived`, `--desc`, `--json`

`tail`

- Returns recent notes
- Accepts either `tail 100` or `tail --limit 100`
- Supports archive and source/channel filters

`search`

- Full-text search
- Query can be passed positionally, for example `thought search onboarding`
- Supports paging with `--limit` and `--offset`

`today`

- Restricts results to the current calendar day
- Supports `--limit`, `--offset`, archive filters, and source/channel filters

`export`

- Same filter model as `list`
- Always outputs JSON

`stats`

- Returns total count, active days, and first/last timestamps

`days`

- Returns per-day summaries instead of individual notes

`add`

- Creates a new note
- Reads from stdin if stdin is present, otherwise uses positional text
- Supports `--tag`, `--source`, `--channel`, `--archived`, and `--pinned`

`update`

- Updates an existing note by id
- Supports `--content`, repeated `--tag`, `--clear-tags`, `--archived|--unarchived`, and `--pinned|--unpinned`

`delete`

- Deletes a note by id

`get`

- Fetches a single note by id
- Supports `--json`

`config show`

- Prints the resolved storage root and whether it came from config or the default location

`config set-root`

- Changes the storage root and migrates the database if needed
- Supports `--overwrite`, `--merge`, and `--keep-destination` when the target already contains a database

## Date Formats

Date-aware commands such as `list`, `search`, `export`, and `days` accept:

- absolute dates such as `2026-05-12`
- absolute local timestamps such as `2026-05-12 09:30`
- ISO timestamps such as `2026-05-12T09:30:00+08:00`
- relative durations such as `30m`, `24h`, and `7d`

Examples:

```bash
thought list --from 7d
thought search planning --from 2026-05-01 --to 2026-05-08
thought export --from "2026-05-12 09:30" --json
```

## Archive And Filter Semantics

Most query commands support:

- `--archived` for only archived notes
- `--unarchived` for only active notes
- `--source <value>`
- `--channel <value>`

Examples:

```bash
thought list --archived --json
thought tail --unarchived --json
thought search planning --source human --channel gui --json
thought today --source human --channel gui --json
thought days --archived --json
```

## Config

The CLI reads and writes the same config file as the GUI app. Both always agree on the storage location.

```bash
# Show current storage root
thought config show

# Set storage root (migrates data automatically)
thought config set-root /path/to/folder

# Overwrite, merge, or keep the destination if it already has a database
thought config set-root /path/to/folder --overwrite
thought config set-root /path/to/folder --merge
thought config set-root /path/to/folder --keep-destination
```

Conflict behavior:

- `--overwrite`: replace the destination database with your current one
- `--merge`: merge source rows into the destination and keep both sets of entries
- `--keep-destination`: keep the destination database and discard your current local database

When you change the storage root, the existing database, including `-wal` and `-shm` files, is migrated or cleaned up as part of the move.

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

- `thought add` exists mainly for testing and automation
- the primary capture path is still the GUI overlay
- the CLI is the better place for heavier review and downstream workflows
- if `thought` is not on your `PATH`, use `./.build/debug/thought` or reinstall the app bundle
