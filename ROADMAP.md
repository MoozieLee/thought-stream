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

The overlay already supports moving through results with `Up` and `Down`, but selected items still do not have a strong action model.

Recommended next action:

- `Enter` on a selected result should perform one simple action

Good first options:

- copy note content
- paste note content back into the input field
- open a lightweight detail view

This should stay simple. The goal is quick reuse, not full note editing inside the capture surface.

### 4. Tests for Query and Slash Behavior

The project now has enough stateful behavior that the lack of tests is becoming a real risk.

Most important areas:

- slash command parsing
- tag parsing
- paged `/tail` and search loading
- result refresh after saving a new thought
- date-window behavior for `/today`

Priority files:

- `Sources/ThoughtStreamCore/ThoughtStore.swift`
- `Sources/ThoughtStreamCore/ThoughtTagParsing.swift`
- `Sources/ThoughtStreamApp/CapturePanelController.swift`

## Medium Priority

### 5. Shared Query Presets

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

### 6. Better `/help`

`/help` is currently functional, but still looks like a plain result list.

Possible improvements:

- show a lightweight header
- include one-line examples
- allow selecting a command and pressing `Enter` to insert its template

This should still feel like a small command reference, not a full command palette.

### 7. Better Empty States and Mode Messaging

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

The data model already includes `updatedAt`, but GUI editing of existing thoughts is still missing.

Current state:

- CLI can update existing thoughts
- GUI is still optimized for capture and lightweight retrieval

Decision to make later:

- either keep GUI as capture-only on purpose
- or add a minimal edit flow without turning it into a full note app

### 10. Packaging and Distribution

The app is already usable locally, but publishing still needs real packaging work.

Future needs:

- signed app bundle
- notarization
- cleaner installation flow
- clearer first-run guidance

This becomes important once the project is shared more broadly.

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
