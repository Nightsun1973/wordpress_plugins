# `wordpress_plugins` workspace docs

- **[REPO-AND-PUBLISH-LAYOUT.md](REPO-AND-PUBLISH-LAYOUT.md)** — Per-plugin Git repositories with a **single shared publish** workflow at this workspace root (`live-plugins`, manifest, SFTP).
- **New plugin wiring:** In Cursor, run **`@.tools/prompts/prompt-chameleon-new-plugin-wiring.md`** (or open that file) when scaffolding a plugin under this tree so build → `live-plugins` → optional SFTP matches the shared workflow.
