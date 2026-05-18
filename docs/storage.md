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

## Migration Conflict Options

If the destination folder already contains a ThoughtStream database, you now have three choices:

- overwrite the destination with your current database
- merge your current database into the destination
- keep the destination database and discard your current local one

CLI examples:

```bash
thought config set-root /path/to/folder --overwrite
thought config set-root /path/to/folder --merge
thought config set-root /path/to/folder --keep-destination
```

## Important Reset Behavior

`Reset Storage Location` does not copy data back into the default folder.

It only clears the configured custom path and makes ThoughtStream resolve storage from the default location again. If the default folder already has a database, that database becomes active. If it does not, ThoughtStream starts with a fresh one there.

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

1. an explicit `baseDirectory` passed by the caller
2. `storage_root` from `~/.config/thoughtstream/config.json`
3. `~/Library/Application Support/ThoughtStream`

There is no environment variable or UserDefaults involved. The config file is the single source of truth.

## Backup And Sync Notes

If you want backup or sync behavior:

- point storage to a folder that is itself backed up or synced
- close ThoughtStream before doing manual copies of the database
- copy `thoughts.sqlite3` together with any `-wal` or `-shm` companion files when they exist

If you use a synced folder such as iCloud Drive, prefer one machine actively writing at a time. SQLite databases do not behave like merge-friendly text files.

## Why A Config File Instead Of Environment Variables

Environment variables are shell-dependent and split-brain prone:

- GUI apps do not read shell profiles reliably
- `export` in `.zshrc` does not cover bash or fish users
- it is too easy to set a different path in one terminal session

A config file is a single, predictable location that both the GUI app and CLI read consistently.

## Clearing Local Data

To clear the current database contents without deleting the whole file:

```bash
./scripts/clear_db.sh
```

This removes rows from both `thoughts` and `thoughts_fts` and resets the SQLite autoincrement counter for `thoughts`.
