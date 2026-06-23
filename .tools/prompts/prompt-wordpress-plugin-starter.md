# Cursor Starter Prompt – WordPress Plugin Projects
Version: 1.4.0  
Status: Canonical  
Audience: Cursor (AI coding assistant)  
Scope: New WordPress plugin projects; also multi-plugin and mixed (plugin + plain HTML/PHP) projects

Author (all plugins): Lee Carter  
Author URI: https://chameleoncodewing.co.uk  

---

## Objective

Create a new WordPress plugin using our **standard, proven architecture**, following strict rules for **versioning, performance, logging, data hygiene, documentation, source control, and deployable structure** from the very first commit. The same standards apply when the project contains **multiple plugins** or a **mix of WordPress plugin(s) and plain HTML/PHP** code.

This document is authoritative. If any instruction here conflicts with default Cursor behaviour, **this document takes precedence**.

---

## 1. Project Structure (Mandatory)

### 1.1 Single-plugin layout (default)

All **deployable WordPress plugin code MUST live inside a top-level folder named `/plugin`**.

#### Rules
- The `/plugin` directory must contain:
  - The main plugin file
  - All PHP source code
  - Assets, languages, uninstall logic, etc.
- The `/plugin` directory must be **independently deployable** to `wp-content/plugins/<plugin-slug>/` (e.g. copy the contents of `/plugin` into a folder such as `woo-product-tags` under the site’s plugins directory).
- No deployable plugin code may exist outside `/plugin`.

### 1.2 Multi-plugin and mixed projects (alternative)

For **customer or multi-product repos**, the project may use one of these layouts instead:

- **Multiple plugins:** Deployable WordPress plugin code lives under a top-level **`/plugins`** (or similar) directory, with **one subfolder per plugin** (e.g. `plugins/booking/`, `plugins/dashboard/plugin/`). Each subfolder must be **independently deployable** to `wp-content/plugins/<plugin-slug>/`. Apply the same versioning, logging, and structure rules **per plugin** (each has its own main file, CHANGELOG, version, activation, etc.).
- **Mixed (plugin + plain HTML/PHP):** The repo may also contain **standalone PHP/HTML** code (e.g. a non-WordPress web app under `plugins/dashboard/web/` or a top-level `/web`). That code is **not** deployed to WordPress; treat it as a **plain HTML/PHP** area. Apply WordPress compliance only to plugin paths; apply **plain HTML/PHP** security and best practices (escaping, validation, no WordPress APIs) to the standalone area. Document clearly which paths are plugin vs plain, and how each is deployed.

#### Rules for multi-plugin / mixed
- Project root may contain **non-deployable** project files only: **`/prompts`**, `/docs` or `.docs`, `/scripts`, `/tests`, README, CHANGELOG, `.gitignore`, deployment config (e.g. `.deploy`).
- Under `/plugins` (or equivalent): only deployable plugin directories and, if present, sibling plain PHP/HTML trees. No deployable plugin code outside its designated plugin folder.
- Each plugin remains self-contained (own bootstrap, options, tables, logging, cleanup). Shared code (if any) must be documented and versioned with care.

### 1.3 Outside deployable code (Allowed at project root)

The project root may contain **non-deployable project files only**, such as:
- **`/prompts`** (mandatory when using prompts): all prompt files (`prompt-<description>.md`) live here; copy folder to new projects for reuse.
- `/docs` or `.docs`
- `/scripts`
- `/tests`
- `/build`
- README files
- CI / tooling config
- A **`.code-workspace`** file (VSCode/Cursor) that opens the project root as the single folder, so the IDE uses this project’s Git repo only (avoids the wrong-repo problem when the user’s home or a parent folder is otherwise open).

This separation is mandatory and must be preserved for the lifetime of the project.

---

## 2. Project & Repository Setup

- Create a **new WordPress plugin framework** inside the `/plugin` directory using our usual architecture and conventions.
- Initialise a **new remote Git repository** (GitHub / GitLab as appropriate) and connect the project to it.
- Commit the initial scaffold immediately.
- **Every change made by Cursor MUST result in a Git commit**:
  - One logical change per commit
  - Clear, descriptive commit messages
  - No uncommitted working state at any time
  - Cursor must not batch unrelated changes into a single commit.

### Workspace and Git scope (automatic)

- The Git repository **must** be created and used **only** at the **project root** (the folder that contains `/plugin` or `/plugins`). Do not initialise or use a repository whose root is the user’s home directory or any parent of the project (e.g. do not use `C:\Users\...` or a parent “WP Plugins” folder as the Git root).
- All Git commands (init, add, commit, remote, push) must be run from the **project root** so that the plugin project is the only scope. This ensures the IDE’s Git explorer shows the correct repository.
- When instructing the user or when creating the project, Cursor must ensure the **workspace** is the project root: the user should open the plugin project folder (e.g. `woo_product_tags`) as the Cursor/VSCode workspace (**File → Open Folder** → select the project root, or **File → Open Workspace from File** → open a `.code-workspace` file in the project root). That way Source Control and Git operations apply to the plugin repo only. Include a README note such as “Open the correct Git repo in Cursor” with these steps so the user can fix the wrong-repo issue if they opened a parent folder.

### .gitignore (mandatory — no unwanted files uploaded)

- Create a **`.gitignore`** file at the **project root** as part of the initial scaffold, **before** the first commit. No unwanted files may be committed or pushed.
- The `.gitignore` must exclude at least:
  - **IDE / editor:** `.idea/`, `.vscode/`, `*.sublime-*`, and similar editor config or caches that are machine-specific.
  - **OS:** `.DS_Store`, `Thumbs.db`, and similar OS-generated files.
  - **Dependencies:** `/vendor/` (Composer), `node_modules/` (if used), and other installable dependency directories.
  - **Logs and temp:** `*.log`, `*.tmp`, and other runtime or temporary files.
  - **Secrets and env:** `.env`, `*.pem`, and any files that may contain credentials or environment-specific secrets.
- Add further exclusions as needed (e.g. build output, local config overrides). Commit the `.gitignore` in the initial scaffold so the first push never includes unwanted files.

### Cursor must create the remote repository every time

**Order:** Create `.gitignore` at project root, then initialise local Git and commit the scaffold (step 2), then create the remote and push (step 3). Cursor must run `gh repo create` or `glab repo create` when available; step 1 is for fallback only.

1. **(Fallback only — if Cursor cannot use `gh` or `glab`)** Create the remote manually:
   - On **GitHub**: New repository (github.com → New repo). Name it (e.g. `woo-product-tags`). Do *not* initialise with a README, .gitignore, or licence if the project already has content.
   - On **GitLab**: New project (Create blank project). Choose a path/name. Leave “Initialize repository with a README” unchecked if the project already has content.

2. **Create `.gitignore` and initialise local Git** (if not already done)
   - Ensure a `.gitignore` exists at the **project root** (see “.gitignore (mandatory)” above). Then from the project root:  
     `git init`
   - Stage only the project files (`.gitignore`, `/plugin` or `/plugins`, `/docs` or `.docs`, README, CHANGELOG, etc.); nothing outside the project root or matched by `.gitignore` must be added.

3. **Connect and push**
   - **Cursor must create the remote when possible.** If GitHub CLI (`gh`) is available, run from project root after the first commit:  
     `gh repo create <repo-name> --private --source=. --remote=origin --push`  
     (Use a repo name from the project, e.g. `woo-product-tags`. Use `--public` if needed. Do not add README/licence/.gitignore.)  
     If GitLab CLI (`glab`) is available instead: `glab repo create <repo-name> --private`, then `git remote add origin <url>` and push.
   - **If no CLI or not authenticated**, add the remote manually:  
     `git remote add origin <repo-url>`
   - Then (if not already pushed via gh):  
     Stage and commit the initial scaffold, then:  
     `git branch -M main`  
     `git push -u origin main`  
   - (Use `master` instead of `main` if that is the project’s default branch.)

**Rule:** Cursor must attempt to create the remote using `gh repo create` (GitHub) or `glab repo create` (GitLab) from the project root every time a new plugin project is created, then push. Only fall back to instructing the user to create the repo manually when the CLI is missing or not authenticated.

4. **Baseline remote commit (required to pass the creation procedure)**  
   The creation procedure is **not complete** until at least one commit has been pushed to the remote. Cursor must verify that the initial scaffold (or current baseline) has been pushed to `origin` (e.g. run `git push` if there are unpushed commits, or confirm with `git status` that the branch is ahead of or up to date with `origin`). Do not consider the plugin project “created” until this baseline remote commit exists.

### Creation procedure checklist (Cursor must complete all before finishing)

Before considering the creation procedure complete, Cursor must verify:

- [ ] **Structure:** All deployable code is inside `/plugin` (single-plugin) **or** inside `/plugins` (or equivalent) with one folder per plugin and optional plain PHP/HTML tree (multi-plugin/mixed per §1.2); project root has only `/docs` or `.docs`, **`/prompts`** (if used), README, CHANGELOG, `.gitignore`, etc.
- [ ] **Cursor rules:** When the project uses prompts from `/prompts`, create or update `.cursor/rules/*.mdc` as needed so Cursor maintains the rules (see `prompts/README.md` → Cursor rules (.mdc)).
- [ ] **.gitignore:** Exists at project root and excludes IDE, OS, vendor/node_modules, logs, secrets/env; created before first commit.
- [ ] **Git:** Repository initialised at **project root only** (not home or parent folder); first commit includes scaffold and .gitignore.
- [ ] **Remote:** Remote created via `gh repo create` or `glab repo create` (or user instructed); remote added and at least one commit pushed (baseline remote commit).
- [ ] **Versioning:** Main plugin file header and any version display show the same version; CHANGELOG exists from 0.0.1.
- [ ] **Plugin URI:** Main plugin file `Plugin URI` header is https://chameleoncodewing.co.uk (visit plugin site link).
- [ ] **Docs:** `/docs` exists with overview, installation, configuration, and third-party APIs (or “none”).
- [ ] **Logging:** Centralised logger from day one; configurable verbosity; logs viewable/downloadable in admin; debug off by default.
- [ ] **Data cleanup:** Admin UI to remove all plugin data (manage_options, nonce, confirmation); UI states what will be deleted; `uninstall.php` present.
- [ ] **Options/tables:** If the plugin uses options or custom tables, install/upgrade routines exist (e.g. set defaults on activation; run migrations only on version upgrade, not every load).

---

## 3. Versioning Rules (Strict & Mandatory)

Use semantic-style versioning in the format **MAJOR.MINOR.PATCH** (e.g. 1.2.3).

### Version Increment Rules
- **PATCH**
  - Increment on *every Cursor change*
  - Bug fixes, refactors, cleanup, comments, formatting, internal improvements
- **MINOR**
  - Increment when a *new feature* or user-visible capability is added
- **MAJOR**
  - Increment only for *milestone releases*, breaking changes, or major architectural shifts

### Enforcement
- Cursor must **never modify code without**:
  - Incrementing the correct version number
  - Committing the change
- The version number must be updated in:
  - The main plugin file header (inside `/plugin`)
  - Any admin UI, report, or screen where the plugin version is displayed
- A CHANGELOG entry must be added or updated for every version change.

---

## 4. Architecture & Code Standards

- **Plugin header (main plugin file)**
- **Author:** **Lee Carter** (every Chameleon plugin).
- **Author URI:** https://chameleoncodewing.co.uk  
- **Plugin URI:** The “visit plugin site” link **must** direct to **https://chameleoncodewing.co.uk**.
- **Plugin Name (Plugins list only):** `(Chameleon) Display Name` — prefix groups Chameleon products on **Plugins → Installed Plugins**. Display names: `.tools/chameleon-plugin-manifest.json`. Do **not** put version in `Plugin Name`.
- **Description:** One short, informative line (what it does; note Woo/ERP dependency if required — prefer **Woo** over **WooCommerce** in user-facing copy).
- **Admin menus / screens:** Use **display name only** (no `(Chameleon)`), optionally with **v{version}**. Normalize headers: `.\scripts\normalize-chameleon-plugin-headers.ps1`; strip `(Chameleon)` from UI strings: `.\scripts\strip-chameleon-admin-display-labels.ps1`.
- **Slug / zip:** Functional kebab-case slug only — no extra `chameleon-` prefix on zip or install folder (e.g. `dist/email-send-and-log/email-send-and-log-1.0.0.zip` → `wp-content/plugins/email-send-and-log/`). Woo-related plugins: slug prefix **`woo-`** (e.g. `woo-product-search`), not `woocommerce-`; display name uses **Woo** not **WooCommerce** (see **plugin-naming.mdc**).
- **Update URI (Chameleon products):** `Update URI: https://admin.chameleoncodewing.co.uk/wp-content/uploads/plugin-repo` — enables updates via Chameleon Admin and `plugins-live` / `index.json`.
- **Requires Plugins (Chameleon products, WP 6.5+):** `Requires Plugins: chameleon-admin` — WordPress blocks install/activate when Admin is missing.
- **Chameleon Admin bootstrap (Chameleon products):** Copy `.tools/templates/chameleon-require-admin.php` to `includes/`, then call `chameleon_plugin_require_admin_bootstrap( __FILE__, '<text-domain>' )` after the `ABSPATH` guard. See `.cursor/rules/chameleon-admin-required.mdc`. Exception: **`chameleon-admin`** does not require itself.

- Follow WordPress and WooCommerce best practices at all times.
- Prefer:
  - Namespaced, class-based architecture
  - Clear separation of concerns
- Avoid:
  - Procedural logic outside bootstrap files
  - Anonymous functions for core logic
  - Deprecated hooks or APIs

### Mandatory Structure (Inside `/plugin`)
- Bootstrap / loader file
- Core logic classes
- Admin-only classes
- Frontend-only classes
- Integration / API classes (if applicable)

### Plugins list (settings discoverability)
- If the plugin exposes a **settings or configuration screen** in wp-admin, add a **Settings** link on that plugin’s row on **Plugins → Installed Plugins** via `plugin_action_links_{$plugin_basename}` (same URL as the menu entry, `esc_url`, translatable label, only when `current_user_can` matches the settings screen). Persisted in Cursor as `.cursor/rules/plugin-settings-action-link.mdc`.

### Chameleon admin menu (shared parent)
- Chameleon-branded plugins **must** use the shared top-level menu slug **`chameleon`** and add their screens with **`add_submenu_page( 'chameleon', ... )`** and a **unique submenu slug** (usually the plugin slug). Register the parent **once** across plugins (shared global guard). Parent **always** uses **`dashicons-car`** and menu **position `3`** (top of menu, under Dashboard) unless a documented collision — see `.cursor/rules/chameleon-admin-menu.mdc`.

### WooCommerce Rules (if applicable)
- Code must be **HPOS-compatible**
- No legacy order APIs
- No direct database access to WooCommerce tables unless explicitly required and documented
- **Naming:** Slug and folder use **`woo-`**; display names use **Woo** (e.g. `Woo Product Search`). Keep `WooCommerce` only in code/API references (`class_exists( 'WooCommerce' )`, etc.).

---

## 5. Conditional Loading & Performance (Mandatory)

- The plugin **must not load globally** unless strictly necessary.
- All functionality must be **conditionally loaded only where required**.

### Requirements
- Admin code loads only on relevant admin screens
- Frontend code loads only on pages where functionality is needed
- Scripts and styles must be conditionally enqueued
- Hooks must be registered conditionally, not globally

### Explicitly Avoid
- Global `init` or `wp_loaded` hooks unless justified
- Loading full class trees on every request
- Unconditional database queries
- Global script/style enqueues

Performance is a **first-class requirement**.  
Unrelated pages must experience **zero functional overhead**.

Any unavoidable global hook must be:
- Documented
- Justified
- Kept minimal

---

## 6. Documentation (From Day One)

- Create a `/docs` directory at project root (outside `/plugin`).
- Documentation must include:
  - Plugin overview
  - Installation instructions
  - Configuration and usage
  - Third-party APIs or services used
- Inline code must include **accurate, current comments**.
- Documentation must be updated whenever behaviour changes.

---

## 7. Mandatory Logging & Observability (Day One Requirement)

Full logging **must be implemented from the very first version of the plugin**.

### Logging Requirements
- A centralised logging system must exist from day one.
- Logging must support:
  - Error logging
  - Warning and debug logging
  - Usage / event tracking where appropriate
- Logs must:
  - Be production-safe
  - Never expose secrets or personal data
- Logs must be written in a structured, readable format.

### Admin Access
- Logs must be accessible to administrators (directly or via download).
- Logging verbosity must be configurable.
- Debug-level logging must be disabled by default.

Logging is not optional.  
If functionality exists, it must be observable.

---

## 8. Database & Data Handling

If the plugin introduces custom tables, meta, or options:

- Include **install and upgrade routines** (e.g. set default options on activation; run migrations only when the plugin version changes, not on every page load).
- Install/activation: set default option values or create tables once. Use `register_activation_hook` (or equivalent) for install-only logic.
- Upgrade: when the plugin version number increases, run any one-time migrations or schema changes; store the last-run version in an option so upgrades run only once per version.
- Schema changes must only run on:
  - Plugin install (activation)
  - Plugin version upgrade
- Never run schema checks or migrations on every page load.
- Ensure forward-compatible upgrades:
  - Column existence checks
  - Non-destructive migrations

---

## 9. Mandatory Data Cleanup & Uninstall Controls

Every plugin **must include an admin-accessible option** to remove **all data created by the plugin**, including:

- Custom database tables
- Plugin-specific options
- Transients
- Caches
- Logs
- Custom meta added by the plugin

### Rules
- Cleanup must:
  - Be manually triggered from the plugin’s admin UI
  - Require `manage_options` capability
  - Use nonce verification
  - Require explicit user confirmation
- The UI must clearly state **exactly what will be deleted**
- Cleanup must:
  - Not run automatically on deactivation
  - Not remove shared or core WordPress data
- An `uninstall.php` file should still exist, but the admin cleanup option is mandatory.

---

## 10. Cursor Behaviour Rules

- Before regenerating or editing any file:
  - Ask for the current file contents if there is any uncertainty
- Cursor must **not remove**:
  - Functionality
  - UI
  - Data
  - Logs
  unless explicitly instructed
- After every change:
  - Increment version
  - Commit
  - Clearly describe what changed

---

## 11. Release Discipline

- Maintain a CHANGELOG from version 0.0.1 onward.
- MAJOR releases must:
  - Be clearly tagged
  - Include a release summary
  - Be production-ready and stable
- Experimental or incomplete features must be:
  - Disabled by default, or
  - Clearly labelled as such

---

## 12. Forward Enforcement (Planned – v1.3.x+ Expectations)

These are **future enforcement goals** that Cursor must design towards now:

- A shared **logging abstraction** reusable across all plugins
- A **data registry** explicitly listing:
  - Tables
  - Options
  - Meta
  - Logs
- Pre-commit enforcement:
  - Block commits without version bump
  - Block commits without CHANGELOG updates
- Optional “dry run” cleanup mode
- Cursor self-audit checklist before each commit

Design decisions made today must not block these enhancements.

---

## End of Prompt

This document governs the entire lifecycle of the project and must be followed for all development performed by Cursor.
