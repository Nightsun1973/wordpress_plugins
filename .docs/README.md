# `wordpress_plugins` workspace docs

- **[REPO-AND-PUBLISH-LAYOUT.md](REPO-AND-PUBLISH-LAYOUT.md)** — Per-plugin Git repositories with a **single shared publish** workflow at this workspace root (`live-plugins`, manifest, SFTP).
- **New plugin wiring:** In Cursor, run **`@.tools/prompts/prompt-chameleon-new-plugin-wiring.md`** (or open that file) when scaffolding a plugin. Prefer creating the repo under **`plugins/`** (e.g. `plugins/chameleon/other/<slug>/`) so it sits in the shared dev bucket the umbrella Git ignores.
