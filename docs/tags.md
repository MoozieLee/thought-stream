# Tags

ThoughtStream treats inline tags as a capture-time shortcut, not as the long-term source of truth.

## Supported Tag Format

ThoughtStream supports single-token inline tags such as:

- `#work`
- `#thoughtstream`
- `#code-review`
- `#weekly_review`

Tags cannot contain spaces.

For multi-word concepts, prefer:

- kebab-case
- snake_case

## Capture Semantics

On `add`:

- inline `#tag` tokens are automatically extracted into the structured `tags` field
- extracted tags remain in the stored `content`

On `update --content`:

- inline `#tag` tokens are parsed again
- newly detected tags are added
- existing tags are not automatically removed

This means inline tags help with capture, but later tag management does not depend on rewriting original note text.

## Examples

Input:

```text
干完现在的活 #工作
```

Stored as:

- `content`: `干完现在的活 #工作`
- `tags`: `["工作"]`

Input:

```text
#生活 买一把香蕉
```

Stored as:

- `content`: `#生活 买一把香蕉`
- `tags`: `["生活"]`

## Why It Works This Way

This project prefers:

- low-friction capture
- simple inline tagging
- structured metadata after capture

It intentionally avoids forcing users to manage tags during the capture moment.
