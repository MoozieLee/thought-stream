# Overlay Guide

## What The Overlay Is For

The overlay is the primary capture surface in ThoughtStream.

It is designed for:

- adding a thought quickly
- searching or reviewing without opening a full workspace
- reusing an old note as the starting point for a new one

## Opening The Overlay

Use:

```text
Shift + Command + Space
```

The panel opens in the center of the screen and focuses the input immediately.

## Slash Commands

ThoughtStream currently supports these in the overlay:

- `/tail`
  - show recent notes
- `/tail 20`
  - show a specific number of recent notes
- `/search <query>`
  - full-text search
- `/today`
  - notes from today
- `/tag <tag>`
  - filter by one tag token
- `/archive`
  - archived notes
- `/keys`
  - keyboard shortcut reference
- `/hide`
  - collapse the current result panel
- `/help`
  - command list
- `/exit`
  - close the panel

Notes:

- `/tag` accepts a single token, such as `/tag work`
- `/search` requires a query
- `/tail` accepts either no number or a positive number

## Keyboard Shortcuts

Core input shortcuts:

- `Shift+Command+Space`: open the capture panel
- `Enter`: save input or reuse the selected note
- `Shift+Enter`: insert newline
- `Tab`: switch between input and result browsing
- `Down Arrow`: open recent notes from an empty input
- `Escape`: return, cancel edit, collapse results, or close

Result actions:

- `Up/Down Arrow`: move through results
- `Cmd+C`: copy selected note
- `Cmd+E`: edit selected note
- `Cmd+D`: delete selected note
- `Cmd+P`: toggle pin on selected note
- `Cmd+Delete`: toggle archive on selected note

## Result Browsing Semantics

When a result panel is visible:

- selecting a note and pressing `Enter` copies its content into the input as a new draft
- editing works in-place through the main input field
- pin and archive act as toggles
- delete removes the selected note immediately

## Editing Mode

To edit an existing note:

1. open a result list
2. select a note
3. press `Cmd+E`
4. update the text in the main input area
5. press `Enter` to save or `Esc` to cancel

## Built-In Help

The overlay includes two self-describing help surfaces:

- `/help` for available slash commands
- `/keys` for available keyboard shortcuts
