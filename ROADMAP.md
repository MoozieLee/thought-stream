# ThoughtStream Roadmap

Last updated: 2026-05-16

This document records the main improvement areas for ThoughtStream after the current MVP:

- macOS Spotlight-style capture overlay
- query-oriented CLI
- slash commands in the GUI:
  - `/tail`
  - `/search <query>`
  - `/today`
  - `/tag <tag>`
  - `/help`
  - `/exit`

## Current Focus

ThoughtStream should stay centered on one idea:

- capture must remain fast and low-friction
- retrieval inside the overlay should stay lightweight
- heavier review and analysis should continue to live in CLI or agent workflows

That means future changes should be evaluated against one question:

- does this reduce interruption, or does it turn the capture panel into a mini workspace?

## Highest Priority

### 1. Result Context Header
Status: done

The result panel should show which mode the user is currently in.

Examples:

- `Recent notes`
- `Search: onboarding`
- `Today`
- `Tag: #thoughtstream`
- `Commands`

Why this matters:

- the current result panel is visually clean but sometimes ambiguous
- users can lose track of whether they are seeing `/tail`, `/search`, or `/tag`
- a lightweight header improves clarity without making the overlay feel heavy

### 2. Inline Error Feedback
Status: done

Invalid commands currently fail too quietly in some cases.

Examples:

- invalid slash command
- `/search` with no query
- `/tag` with an invalid tag token
- malformed `/tail limit:...`

Why this matters:

- a system beep alone is not enough
- users need a short, local explanation near the input field or result panel

Recommended direction:

- keep errors short
- do not show blocking alerts
- clear the error automatically when the input becomes valid

### 3. Selected Result Action
Status: done

Current state:

- `Up` and `Down` can select results when the input is empty
- `Enter` reuses the selected note as a new draft
- `Cmd+C` copies the selected note content
- `Cmd+P` toggles pin on the selected note
- `Cmd+Delete` toggles archive on the selected note

### 4. Tests for Query and Slash Behavior
Status: done

The project now has enough stateful behavior that the lack of tests is becoming a real risk.

Covered now:

- slash command parsing
- slash inline error behavior
- tag parsing
- paged `/tail` and search query behavior
- result refresh after saving a new thought
- date-window behavior for `/today`

Primary test files:

- `Tests/ThoughtStreamCoreTests/CaptureQueriesTests.swift`
- `Tests/ThoughtStreamCoreTests/ThoughtTagParsingTests.swift`
- `Tests/ThoughtStreamCoreTests/ThoughtStoreQueryTests.swift`

## Medium Priority

### 5. Shared Query Presets
Status: done

GUI and CLI already share the same storage layer, but common query presets still live mostly in the UI controller.

Examples:

- recent thoughts
- today
- search query
- tag filter

Recommended direction:

- move reusable query presets into the core layer
- let GUI and CLI call the same semantic helpers

Why this matters:

- reduces drift between interfaces
- makes agent workflows more stable
- keeps command behavior consistent over time

Current state:

- reusable query presets now live in `ThoughtStreamCore`
- GUI retrieval uses shared preset builders instead of hand-rolled controller logic
- CLI `tail` and `search` also call the same shared query presets

### 6. Better `/help`
Status: done

`/help` is currently functional, but still looks like a plain result list.

Possible improvements:

- show a lightweight header
- include one-line examples
- allow selecting a command and pressing `Enter` to insert its template

This should still feel like a small command reference, not a full command palette.

### 7. Better Empty States and Mode Messaging
Status: done

The app already shows different empty states, but they can be improved.

Examples:

- `No notes yet`
- `No matching notes`
- `Nothing captured today`
- `No notes tagged #work`

Possible next step:

- add subtle mode-aware metadata such as result count or current filter context

## Longer-Term Improvements

### 8. Tag Storage Normalization

The current `tags_json` approach is good enough for the MVP, but it will eventually become a bottleneck.

Current limitations:

- tag lookup depends on `json_each(...)`
- autocomplete counts currently scan stored JSON arrays
- richer tag analytics will be expensive

Recommended future schema:

- `tag_catalog`
- `thought_tags`

Why this matters:

- faster tag filtering
- better autocomplete
- easier usage stats and future tag management

This is only worth doing once tag-centric workflows become common.

### 9. GUI Editing Flow
Status: done

The overlay now supports a minimal edit flow for existing thoughts without turning the capture surface into a full note editor.

Current state:

- select a result and press `Cmd+E` to enter editing
- the input shows `Editing note · Enter to save · Esc to cancel`
- `Enter` updates the existing thought
- `Esc` exits editing and returns to result browsing
- slash commands and normal reuse paths leave editing mode cleanly

### 10. Packaging and Distribution
Status: partial

The app is already usable locally, but publishing still needs real packaging work.

Current state:

- release packaging scripts now exist for:
  - signed app bundle preparation
  - ZIP release artifacts
  - drag-install DMG creation
  - bundle validation
- first-run guidance is now documented
- notarization is scriptable through `notarytool` when credentials are available

Still depends on real Apple distribution credentials for a fully signed and notarized public release.

## Guardrails

The following principles should remain stable:

- do not overload the capture surface with too many commands
- do not force organization during capture
- prefer query and review over in-panel management
- keep slash syntax lightweight and product-like, not CLI-like
- preserve a clear split between:
  - capture
  - retrieval
  - offline review or agent workflows

## Recommended Next Sequence

If work continues immediately, the best order is:

1. Add a lightweight result header
2. Add inline error feedback
3. Define `Enter` behavior for selected results
4. Add core and controller tests
5. Revisit tag storage only after tag usage becomes frequent
