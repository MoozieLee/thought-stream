# Storage

By default, ThoughtStream stores local data under:

```text
~/Library/Application Support/ThoughtStream
```

The SQLite database file is:

```text
~/Library/Application Support/ThoughtStream/thoughts.sqlite3
```

## Development Override

For development or automation runs, you can override the storage root:

```bash
export THOUGHT_STREAM_HOME="$PWD/.thought-stream"
```

## Why This Matters

This is useful when you want to:

- isolate test data
- run repeatable local experiments
- avoid mixing development notes with your normal local store

## Clearing Local Data

To clear the current database contents without deleting the whole file:

```bash
./scripts/clear_db.sh
```
