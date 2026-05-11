Tidy, normalise, and document the project **without changing functionality**.

### Safety rule (mandatory)
- This task is a **non-functional cleanup only**.
- Do **not** change behaviour, outputs, logic, UI, data structures, or public APIs.
- Do **not** add new features or refactor logic in a way that alters behaviour.
- If any potential functional change is unavoidable, **stop and ask before proceeding**.

---

## Tasks

### 1. Code & project audit
- Audit the entire codebase and project tree.
- Remove all orphaned or unused:
  - Code
  - Files
  - Folders
  - Hooks
  - Classes
  - Assets
- Remove dead comments, commented-out code, and legacy remnants that are no longer referenced.
- Ensure there are:
  - No unused imports
  - No unused functions or classes
  - No unreachable code paths

### 2. Documentation
- Review all documentation under `/docs` or **`.docs/`** (and at project root). Ensure any references to prompt files use the **`/prompts`** path (all prompts live in `prompts/` at project root for reuse).
- Update documentation so it **accurately reflects current behaviour and architecture**.
- Remove stale, duplicated, or incorrect documentation.
- Ensure documentation covers:
  - Setup / installation
  - Configuration
  - Usage
  - Key architectural decisions

### 3. Code quality
- Ensure all remaining code is clearly and accurately commented where intent is not obvious.
- Comments must be:
  - Accurate
  - Concise
  - Up to date
- Ensure naming, structure, and formatting follow existing project standards.
- Do not introduce stylistic churn unrelated to clarity.

---

## Versioning & commits (mandatory)

- Increment the project version number **before committing**.
- Commit all changes with a clear, descriptive commit message (e.g. “Chore: project cleanup and documentation refresh”).
- Cursor must enforce the rule that **every change it makes requires a version bump and a Git commit**.
- Do not leave any uncommitted changes.

---

## Cursor self-audit checklist (must pass before committing)

Before committing, Cursor must verify and explicitly confirm:

- [ ] No functional behaviour has changed.
- [ ] No public APIs, hooks, outputs, or UI behaviour were altered.
- [ ] All removed code/files were truly unused or orphaned.
- [ ] There is no commented-out code remaining.
- [ ] All documentation matches the current implementation.
- [ ] Code comments are accurate and helpful.
- [ ] Project version number has been incremented.
- [ ] CHANGELOG (if present) reflects this cleanup.
- [ ] Git working tree is clean after commit.

If **any** checklist item cannot be confirmed, **stop and ask for clarification**.

**Cursor rules:** If cleanup or doc rules should persist, create or update `.cursor/rules/*.mdc` so Cursor maintains them. See `prompts/README.md` → Cursor rules (.mdc).

---

## Completion criteria

The task is complete only when:
- The project contains no orphaned or unused code.
- Documentation is accurate and current.
- The version number has been incremented.
- All changes are committed (and pushed if a remote exists).