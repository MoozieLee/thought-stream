---
name: thoughtstream-cli
description: "Use when working with ThoughtStream local notes through the `thought` CLI in this repository: querying notes, exporting slices, inspecting stats or day summaries, finding entries by time/tag/text, or updating and deleting thoughts. Trigger for requests like 'search my thoughts', 'show today's captures', 'export the last 7 days', 'find notes tagged work', 'update this thought', or 'use the ThoughtStream terminal workflow'."
---

# ThoughtStream CLI

Use the `thought` executable in this repo as the query-first interface to local ThoughtStream data.

## Workflow

1. Prefer an existing built binary:
   - `./.build/debug/thought`
   - `./.build/release/thought`
2. If the CLI is not built, compile it with:

```bash
env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build --product thought
```

3. Default to `--json` when results will be summarized, filtered further, or consumed by another tool.
4. Read `docs/cli.md` if command syntax or filter behavior is unclear.
5. Read `docs/storage.md` before changing `THOUGHT_STREAM_HOME`, clearing data, or running isolated experiments.

## Command Patterns

- Recent notes: `thought tail 100 --json`
- Search text: `thought search "query" --json`
- Show today's notes: `thought today --json`
- Filtered listing: `thought list --from 7d --source human --channel gui --json`
- Day summaries: `thought days --from 30d --json`
- Global stats: `thought stats --json`
- Export a slice: `thought export --from 7d --json`
- Fetch one note: `thought get <id> --json`
- Update one note: `thought update <id> --content "..." --tag work`
- Delete one note: `thought delete <id>`

## Query Guidance

- Prefer `tail` for recent-history review.
- Prefer `search` for free-text retrieval.
- Prefer `today` when the user asks for the current day's captures.
- Prefer `days` or `stats` for aggregation instead of reconstructing counts manually.
- Use `--archived` or `--unarchived` when archive state matters.
- Use `--source` and `--channel` to distinguish GUI captures from CLI or automation writes.

## Storage and Safety

- Normal local storage lives under `~/Library/Application Support/ThoughtStream`.
- For repeatable tests or scripted runs, set `THOUGHT_STREAM_HOME` to an isolated directory first.
- Do not clear or rewrite the main store unless the user explicitly asks.
- Treat `delete` as destructive and narrow to an exact thought id before using it.
