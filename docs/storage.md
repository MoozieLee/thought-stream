# Storage

By default, ThoughtStream stores local data under:

```text
~/Library/Application Support/ThoughtStream
```

The SQLite database file is:

```text
~/Library/Application Support/ThoughtStream/thoughts.sqlite3
```

## Choosing a Different Storage Folder

The app can store its database somewhere else if you want to keep it in a folder such as iCloud Drive.

### GUI

In the menu bar app, open the ThoughtStream status item menu and use:

- `Reveal Data Folder`
- `Change Storage Location...`
- `Reset Storage Location`

### CLI

```bash
# Show current storage location
thought config show

# Set a custom storage root
thought config set-root /path/to/your/folder
```

Both GUI and CLI write to the same config file, so they always agree on the storage location.

## Config File

The storage root is persisted in a single JSON config file:

```text
~/.config/thoughtstream/config.json
```

Example content:

```json
{
  "storage_root": "/Users/you/iCloud Drive/ThoughtStream"
}
```

If the file does not exist or `storage_root` is absent, the default location is used.

## Resolution Order

ThoughtStream resolves its storage root in this order:

1. An explicit `baseDirectory` passed by the caller
2. `storage_root` from `~/.config/thoughtstream/config.json`
3. `~/Library/Application Support/ThoughtStream`

There is no environment variable or UserDefaults involved — the config file is the single source of truth.

## Why a Config File Instead of Environment Variables

Environment variables are shell-dependent and split-brain prone:

- GUI apps don't read shell profiles reliably
- `export` in `.zshrc` doesn't cover bash/fish users
- It's too easy to set a different path in one terminal session

A config file is a single, predictable location that both the GUI app and CLI read consistently.

## Clearing Local Data

To clear the current database contents without deleting the whole file:

```bash
./scripts/clear_db.sh
```

This removes rows from both `thoughts` and `thoughts_fts` and resets the SQLite autoincrement counter for `thoughts`.
