---
description: Create git commits with user approval and no Claude attribution
---

# Commit Changes

You are tasked with creating git commits for the changes made during this session.

## Strict Requirements

### Atomic Commits

- You MUST strictly adhere to atomic commits
- Each commit MUST represent a single, logical unit of change
- The application MUST be fully functional after every commit
- Never combine unrelated changes into a single commit
- If changes span multiple concerns, split them into
  separate commits in the correct dependency order

### Conventional Commit Messages

- You MUST strictly adhere to conventional commit message
  structure: `type(scope): description`
- Valid types: feat, fix, refactor, chore, docs, style,
  test, perf, ci, build, revert
- Line width MUST NOT exceed 72 characters
- Use imperative mood in the subject line
- The body MUST use bullet points to describe changes
- If there is a BREAKING CHANGE, note it at the end of the
  commit message after the bullet points, separated by two
  blank lines (\n\n):

```
type(scope): subject line

- bullet point describing change
- another bullet point

BREAKING CHANGE: description of what breaks
```

## Process

1. **Analyze changes:**
    - Review conversation history and understand what was
      accomplished
    - Run `git status` to see current changes
    - Run `git diff` to understand the modifications
    - Determine how to split changes into atomic commits
      that each leave the application functional

2. **Plan your commit(s):**
    - Identify which files belong together as atomic units
    - Draft conventional commit messages with bullet-point
      bodies
    - Verify each planned commit leaves a working app
    - Focus on why the changes were made, not just what

3. **Present your plan to the user:**
    - List the files you plan to add for each commit
    - Show the commit message(s) you'll use
    - Ask: "I plan to create [N] commit(s) with these
      changes. Shall I proceed?"

4. **Execute upon confirmation:**
    - Use `git add` with specific files (never use `-A`
      or `.`)
    - Create commits with your planned messages
    - Show the result with `git log --oneline -n [number]`

## Important

- **NEVER add co-author information or Claude attribution**
- Commits should be authored solely by the user
- Do not include any "Generated with Claude" messages
- Do not add "Co-Authored-By" lines
- Write commit messages as if the user wrote them
- The user trusts your judgment - they asked you to commit
