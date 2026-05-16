# Changelog

All notable changes to ThoughtStream will be documented in this file.

## [0.2.0] — 2026-05-16

### Changed
- **Storage config unified**: single `~/.config/thoughtstream/config.json` replaces UserDefaults + `THOUGHT_STREAM_HOME`. GUI and CLI always agree on the storage location.
- GUI `Change Storage Location`, `Reset Storage Location`, and `Reveal Data Folder` in menu bar

### Added
- `thought config show` — display current storage root and its source
- `thought config set-root <path> [--overwrite|--merge]` — set storage root with automatic data migration
- Automatic data migration when changing storage: handles `thoughts.sqlite3`, `-wal`, and `-shm` files with cleanup
- Merge strategy via SQLite `ATTACH` + `INSERT OR IGNORE` with UUID deduplication
- Overwrite strategy for replacing existing destination databases
- Conflict resolution dialog in GUI (Overwrite / Merge / Cancel)
- `PRAGMA wal_checkpoint(TRUNCATE)` before migration to ensure WAL consistency

### Removed
- `THOUGHT_STREAM_HOME` environment variable override
- `UserDefaults` storage root persistence key

## [0.1.0-b1] — 2026-05-16

### Added
- Spotlight-style macOS capture overlay (`Shift+Command+Space`)
- Slash commands: `/tail`, `/search`, `/today`, `/tag`, `/archive`, `/hide`, `/help`, `/exit`
- Result browsing: select, reuse, copy, pin, archive, edit (`Cmd+E`)
- `thought` CLI: `list`, `tail`, `search`, `today`, `export`, `stats`, `days`, `add`, `update`, `get`, `delete`
- Inline `#tag` extraction and structured tag storage
- SQLite3 local storage with FTS5 full-text search
- Schema migration: `updated_at`, `tags_json`, `archived`, `pinned` columns
- Embedded CLI binary in `.app` bundle with auto-symlink on first launch
- `curl | sh` installer with SHA256 checksum verification
- ZIP + DMG release packaging with GitHub Release automation
- Uninstall script
- Bilingual documentation (English / Simplified Chinese)
- Apple ad-hoc code signing

### Fixed
- `package_release.sh` tag push order to prevent `untagged-xxx` releases
- `install.sh` kill running app before replacing
- `install.sh` dead `PREFERRED_FORMAT` variable removed
- `validate_release.sh` now checks embedded CLI binary
- DMG upload uses precise filename instead of fragile `ls|head` glob

### Tests
- Slash command parsing and inline error feedback
- Tag extraction, deduplication, and invalid tag rejection
- Database query behavior (pagination, search, `/today` date window, `pinnedFirst` ordering)
