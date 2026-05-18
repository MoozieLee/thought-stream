# Troubleshooting

## The App Will Not Open

If ThoughtStream was built locally or downloaded as an unsigned build:

1. move `ThoughtStream.app` to `/Applications`
2. right-click it in Finder and choose `Open`
3. confirm again in the system prompt

If macOS still blocks it:

1. open `System Settings -> Privacy & Security`
2. look for the blocked app notice
3. choose `Open Anyway`

For more background, see [Distribution](distribution.md).

## The Hotkey Does Not Seem To Work

Check these in order:

1. make sure ThoughtStream is actually running in the menu bar
2. close and reopen the app
3. check whether another tool is already using `Shift+Command+Space`

ThoughtStream currently assumes that hotkey and does not expose a custom hotkey setting.

## `thought` Command Is Not Found

Try one of these:

1. run the bundled binary directly, for example `./.build/debug/thought`
2. rerun `./scripts/install_app.sh`
3. check whether `/usr/local/bin/thought` exists

The install flow tries to create a symlink there. If that step failed, you may need to create it manually.

## I Changed Storage Location And My Old Notes Disappeared

This usually means ThoughtStream is now pointing at a different database than before.

Check:

```bash
thought config show
```

Then compare that path against:

- your previous custom storage folder
- the default folder at `~/Library/Application Support/ThoughtStream`

Also remember:

- `Reset Storage Location` does not move data back automatically
- `--keep-destination` intentionally discards the current local database in favor of the destination one

See [Storage](storage.md) for the full model.

## I Am Unsure Which Migration Option To Pick

Use:

- `--overwrite` if your current database is the one you trust and you want it to replace the destination
- `--merge` if both databases contain useful data and duplicate ids should be skipped
- `--keep-destination` if the destination database is the source of truth and you only want to switch to it

## Search Returns Less Than I Expected

Check whether one of these filters is narrowing the result:

- `--from`
- `--to`
- `--source`
- `--channel`
- `--archived` or `--unarchived`

In the overlay, also make sure you are using the intended command:

- `/search <query>` for full-text search
- `/archive` for archived notes
- `/tag <tag>` for one tag token
