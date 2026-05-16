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
./.build/debug/thought export --from 7d --json
./.build/debug/thought stats --json
./.build/debug/thought days --limit 14 --json
./.build/debug/thought get <id>
./.build/debug/thought update <id> --content "updated text" --tag work
./.build/debug/thought delete <id>
```

## Command Groups

Query:

- `list`
- `tail`
- `search`
- `export`
- `stats`
- `days`
- `get`

Write and update:

- `add`
- `update`
- `delete`

## Archive Filters

Most query commands support archive filtering:

```bash
./.build/debug/thought list --archived --json
./.build/debug/thought tail --unarchived --json
./.build/debug/thought search planning --archived --json
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

Inspect day summaries:

```bash
./.build/debug/thought days --from 30d --json
```

## Notes

- `thought add` exists for testing and automation
- the primary capture path is still the GUI
- the CLI is the better place for heavier review and downstream workflows
