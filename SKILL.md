---
name: thoughtstream-cli
description: "Use when working with ThoughtStream local notes through the `thought` CLI in this repository: querying notes, exporting slices, inspecting stats or day summaries, finding entries by time, tag, or text, or updating and deleting thoughts. Trigger for requests like 'search my thoughts', 'show today's captures', 'export the last 7 days', 'find notes tagged work', 'update this thought', or 'use the ThoughtStream terminal workflow'."
---

# ThoughtStream CLI

Use the `thought` executable in this repo as the query-first interface to local ThoughtStream data.

## Workflow

1. Prefer a repo-local built binary in this order:
   - `./.build/debug/thought`
   - `./.build/release/thought`
2. Use the plain `thought` command only if the CLI is already available on `PATH` and you do not need to force the repo-local binary.
3. If the CLI is not built, compile it with:

```bash
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product thought
```

4. Default to `--json` when results will be summarized, filtered further, piped into another tool, or compared programmatically.
5. Read `docs/cli.md` if command syntax, filters, or date formats are unclear.
6. Read `docs/storage.md` before changing storage roots, clearing data, or reasoning about where notes live.

## Command Patterns

Prefer repo-local forms such as:

- Recent notes: `./.build/debug/thought tail 100 --json`
- Search text: `./.build/debug/thought search "query" --json`
- Show today's notes: `./.build/debug/thought today --json`
- Filtered listing: `./.build/debug/thought list --from 7d --source human --channel gui --json`
- Day summaries: `./.build/debug/thought days --from 30d --json`
- Global stats: `./.build/debug/thought stats --json`
- Export a slice: `./.build/debug/thought export --from 7d --json`
- Fetch one note: `./.build/debug/thought get <id> --json`
- Update one note: `./.build/debug/thought update <id> --content "..." --tag work`
- Delete one note: `./.build/debug/thought delete <id>`
- Show storage root: `./.build/debug/thought config show`
- Change storage root: `./.build/debug/thought config set-root /path/to/folder`

If `thought` on `PATH` is known to point at this repo's binary, the shorter forms are also acceptable.

## Query Guidance

- Prefer `tail` for recent-history review.
- Prefer `search` for free-text retrieval.
- Prefer `today` when the user asks for the current day's captures.
- Prefer `days` or `stats` for aggregation instead of reconstructing counts manually.
- Use `--archived` or `--unarchived` when archive state matters.
- Use `--source` and `--channel` to distinguish GUI captures from CLI or automation writes.
- Use `--from` and `--to` when the user gives a time window rather than a keyword.

## Storage and Safety

- Normal local storage lives under `~/Library/Application Support/ThoughtStream`.
- ThoughtStream uses a config file, not `THOUGHT_STREAM_HOME`, as the primary storage-root control mechanism.
- Inspect the active store with `thought config show` before assuming where data lives.
- Change storage locations with `thought config set-root ...`, and understand the conflict modes:
  - `--overwrite`
  - `--merge`
  - `--keep-destination`
- Do not clear, migrate, or rewrite the main store unless the user explicitly asks.
- Treat `delete` as destructive and narrow to an exact thought id before using it.
- Treat `update --content` as user-data modification and make sure the target thought id is unambiguous before editing it.
- Treat `config set-root` as high-impact because it can switch the active database or discard one side of a migration conflict.

## When To Pause And Confirm

Pause for confirmation before:

- deleting a thought
- updating a thought when the intended target is ambiguous
- changing the storage root
- clearing local data
- choosing between `--overwrite`, `--merge`, and `--keep-destination` on behalf of the user
