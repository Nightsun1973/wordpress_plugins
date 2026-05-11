# Prompts

All reusable prompt files for this project live in this folder. Use the naming format **`prompt-<description>.md`**.

**Chameleon standards version:** The prompts and Cursor rules (`.cursor/rules/`) are versioned **together** as one set. See **`VERSION`** in this folder. When copying to another project, compare that project’s `prompts/VERSION` with this one to see if you need to copy the latest. Bump `VERSION` (e.g. 1.0.0 → 1.1.0) whenever you change a prompt or rule and copy to other projects as needed.

## Purpose

- **Reuse:** Copy this **`/prompts`** folder to a new project to reuse the same prompts (e.g. Chameleon Elementor rules, optimisation, cleanup, WordPress starter).
- **Consistency:** Keeping prompts in one place at project root makes them easy to find and reference (e.g. `@prompts/prompt-chameleon-elementor-plugin.md` in Cursor).

## Mandatory convention

For any project that uses prompts: store all prompt files in **`/prompts`** at the project root. Do not place prompt files loose in the root or in `/docs`.

## Cursor rules (.mdc)

Prompts can create or update **Cursor rule files** (`.cursor/rules/*.mdc`) so that Cursor maintains the rules even when the prompt is not explicitly invoked.

- When a prompt defines **mandatory or long-lived rules** (e.g. commit-after-change, load-only-where-needed, project structure, **project-type analysis and compliance**), create or update a corresponding `.mdc` file in `.cursor/rules/` so those rules are always applied.
- **Format:** Use YAML frontmatter (`description`, optional `alwaysApply: true`) then markdown content. Example: see `.cursor/rules/commit-on-change.mdc`.
- **Naming:** Use a short, descriptive name (e.g. `commit-on-change.mdc`, `prompts-to-rules.mdc`). One rule file per concern is fine; one file can also summarise multiple rules from a prompt.
- **Sync:** When you change a prompt in `/prompts`, update the related `.cursor/rules/*.mdc` files if the rules changed, so Cursor and the prompts stay aligned.
- **Plugins list:** If a plugin has a settings screen, add a **Settings** link on its Plugins list row; see `.cursor/rules/plugin-settings-action-link.mdc`.
- **Chameleon menu:** Shared parent slug **`chameleon`**, icon **`dashicons-car`**, position **3** (top of sidebar); see `.cursor/rules/chameleon-admin-menu.mdc`.

## Project type and compliance

The project **README.md** (section “Run first: project analysis and compliance”) and the Cursor rule **`.cursor/rules/project-compliance.mdc`** define:

- **Run first:** Analyse the repo to determine project type:
  - **WordPress** (plugin/theme): deployable code for `wp-content/plugins/` or `wp-content/themes/`.
  - **Plain HTML/PHP**: standalone PHP/HTML with no WordPress bootstrap.
  - **Multi-plugin**: one repo with multiple plugins (e.g. under `/plugins`); treat each plugin as WordPress and apply WP compliance per plugin.
  - **Mixed**: repo contains both WordPress plugin(s) and plain HTML/PHP (e.g. plugin + standalone web app); apply WordPress compliance to plugin paths and plain PHP/HTML compliance to standalone paths; document which areas are which.
- **WordPress:** On every commit, check against latest WordPress, Elementor (if used), and PHP docs; ensure compliance; update files and docs with supported versions and security notes.
- **Plain HTML/PHP:** Ensure compliance with latest HTML and PHP security and best practices; update docs accordingly.

## Auto-run and full list of prompts and rules

The **README.md** (section “Chameleon project standards (auto-run)”) lists **all prompts** in `/prompts` and **all Cursor rules** in `.cursor/rules/`. The rule **`.cursor/rules/chameleon-standards.mdc`** is set to run automatically when the project is opened so that the README and Chameleon standards are applied every session. Keep the README table and this folder in sync when adding or renaming prompts or rules.

**Central location (dev root):** You can keep one set of prompts and rules in a **dev root** folder and open Cursor there so all Chameleon projects use the same files. See **docs/chameleon-dev-root.md** in the project repo.

## Files in this folder

- **`VERSION`** – Version of this prompts + rules set (e.g. 1.0.0). Bump when you change a prompt or rule; use to compare with other projects when copying.
- `prompt-chameleon-elementor-plugin.md` – Rules for Chameleon Elementor WordPress/WooCommerce plugins and widgets.
- `prompt-chameleon-new-plugin-wiring.md` – **Monorepo only:** wire a new plugin repo under `wordpress_plugins` into the shared **plugins-live / publish / SFTP** release pipeline (run when creating a new plugin here).
- `prompt-wordpress-plugin-starter.md` – WordPress plugin project structure, versioning, and setup.
- `prompt-project-clean-up.md` – Non-functional cleanup and documentation refresh.
- `prompt-optimisation.md` – Performance and efficiency improvements for any plugin.
