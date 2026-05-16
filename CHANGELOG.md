# Changelog

All notable changes to ThoughtStream will be documented in this file.

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
