# Chameleon Elementor WordPress/WooCommerce Plugin – Rules & Conventions

**Purpose:** Reusable prompt for creating and maintaining **Chameleon**-branded WordPress plugins that provide Elementor widgets and integrate with WooCommerce.  
**Audience:** Cursor (AI) and developers.  
**Author (all Chameleon plugins):** Lee Carter | Author URI: https://chameleoncodewing.co.uk

When building or extending a Chameleon Elementor plugin, follow this document. If anything here conflicts with default Cursor behaviour, **this document takes precedence**.

---

## 1. Chameleon branding and naming

- **Plugin name format:** `Woo <Feature> (Chameleon)` or similar (e.g. *Woo Product Gallery (Chameleon)*). Use “Chameleon” in the plugin title for recognition.
- **Widget title format:** `<Feature> (Chameleon)` (e.g. *Product Gallery (Chameleon)*).
- **Admin menu:** When the plugin has a settings page and WooCommerce is active, add it under **WooCommerce** with the same label as the plugin (e.g. *Woo Product Gallery (Chameleon)*). If WooCommerce is inactive, add under **Settings**.
- **Author:** All plugins must use **Author: Lee Carter** and **Author URI: https://chameleoncodewing.co.uk** in the plugin header.
- **Text domain:** Use a consistent, slug-style text domain (e.g. `woo-product-gallery-images`). Use it in every `__()`, `esc_html__()`, etc.

---

## 2. Project structure (mandatory)

- **Deployable code** lives only in a top-level **`/plugin`** directory. Nothing that gets deployed to `wp-content/plugins/<slug>/` may sit outside `/plugin`.
- **Outside `/plugin`** (project root) allow only non-deployable items: `/docs`, **`/prompts`** (mandatory: all prompt files live here for reuse and copy to new projects), `/scripts`, `/tests`, README, CHANGELOG, `.gitignore`, `.code-workspace`.
- **Prompts (mandatory):** All prompt files must be stored in **`/prompts`** at project root, using the format `prompt-<description>.md`. The `/prompts` folder can be copied to a new project for reuse.
- **Docs:**  
  - **`/docs`** (project root): architecture, installation, configuration, hooks, third-party, changelog.  
  - **`/plugin/docs`** (optional): user-facing docs (usage, widget controls, FAQs).
- **Git:** The Git repository root must be the **project root** (the folder that contains `/plugin`). Open this folder (or its `.code-workspace`) in Cursor so Source Control and Git apply to this plugin only.

---

## 3. Versioning and Git (mandatory)

- **Semantic-style:** MAJOR.MINOR.PATCH (e.g. 1.0.0).
- **On every change:**  
  - Bump the version (PATCH for fixes/cleanup, MINOR for new features, MAJOR for milestones/breaking changes).  
  - Update the version in the main plugin file header and in any `WPGI_VERSION`-style constant (or equivalent).  
  - Add or update the corresponding entry in **CHANGELOG.md**.  
  - **Commit** the change with a clear, descriptive message.
- **One logical change per commit.** Do not leave uncommitted work at the end of a session.
- **Commit message:** Short summary line; optional body with bullet points.

---

## 4. WordPress plugin baseline

- **Guard:** Every PHP file must start with an `ABSPATH` check (or equivalent) and must not run in unintended contexts.
- **Namespaces:** Use a consistent PHP namespace (e.g. `ChameleonCodewing\WooProductGalleryImages`). Keep class and file names aligned (e.g. `class-widget-product-gallery.php` → `Widget_Product_Gallery`).
- **No globals:** Avoid global variables; use classes and dependency injection.
- **Activation/deactivation:** Use `register_activation_hook` for install (default options, etc.). Use `register_deactivation_hook` only if needed; do not remove data on deactivation. Data removal is via admin cleanup and/or `uninstall.php`.

---

## 5. Elementor widget rules

### 5.1 Registration and dependencies

- **Register the widget only when both Elementor and WooCommerce are active.** If either is missing, show an **admin notice** (e.g. “Woo Product Gallery (Chameleon) requires Elementor and WooCommerce…”) and do **not** register the widget. No fatal errors.
- **Custom category:** Register a **Chameleon** category so all Chameleon widgets appear in one section:
  - Hook: `elementor/elements/categories_registered`.
  - `$elements_manager->add_category( 'chameleon', [ 'title' => __( 'Chameleon', 'your-text-domain' ), 'icon' => 'eicon-folder' ] );`
  - In each widget, `get_categories()` must return `['chameleon']` (or `['chameleon', 'woocommerce']` if it should appear in both).

### 5.2 Widget class

- Extend `\Elementor\Widget_Base`.
- Implement at least: `get_name()`, `get_title()`, `get_icon()`, `get_categories()`, `get_keywords()`, `register_controls()`, `render()`.
- Use **`get_settings_for_display()`** (not `get_settings()`) when reading settings for front-end and editor output so responsive and dynamic values are correct.

### 5.3 Controls

- Use **sections** (`start_controls_section` / `end_controls_section`) and **tabs** where it improves clarity (e.g. Content vs Style; Normal vs Hover).
- Prefer **responsive controls** (`add_responsive_control`) for layout and styling so desktop/tablet/mobile can be set from one control with the breakpoint switcher.
- Use **separators** (`'separator' => 'before'`) and **headings** to group related controls and keep the panel legible.
- Provide sensible **defaults** and **descriptions** where the intent is not obvious.

### 5.4 Output and assets

- **Escape all output:** Use `esc_attr()`, `esc_html()`, `esc_url()` as appropriate. Use `wp_json_encode()` for JSON in data attributes, then escape the attribute.
- **Conditional enqueue:** Load widget CSS/JS only when the widget is actually rendered (e.g. from `render()` or a check that the widget is in use). Do not enqueue Elementor widget assets globally.
- **Editor vs front-end:** Widget must render correctly in the Elementor editor and on the front-end (and in Theme Builder when relevant). Avoid JS errors when the widget is added, removed, or updated.

---

## 6. WooCommerce integration

- **Product context:** When used on a single product (e.g. Single Product template), support “current product” as the default data source. Optionally support “Select by ID” and “Select by SKU” for landing pages or other contexts.
- **Editor preview:** When editing in Elementor, allow choosing a “preview product” (e.g. dropdown) so the widget can be configured and previewed even without a real product context.
- **Variation switching:** If the widget shows product gallery/media, ensure that when the user selects a variation, the gallery updates (e.g. main image and thumbs) to match the variation. Use WooCommerce APIs (e.g. variation image) and avoid legacy or non–HPOS-compatible code.
- **HPOS:** All WooCommerce-related code must be compatible with High-Performance Order Storage. Do not rely on legacy order tables or APIs unless explicitly required and documented.

---

## 7. Admin and settings

- **Settings page:** If the plugin has options, expose them under **WooCommerce → <Plugin Name>** (or **Settings → <Plugin Name>** when WooCommerce is inactive).
- **Capability:** Use `manage_options` for settings and cleanup. Check `current_user_can( 'manage_options' )` before rendering or saving.
- **Nonce:** Use `wp_nonce_field` and `wp_verify_nonce` for all forms. Sanitize and validate inputs before saving.
- **Cleanup:** Provide an explicit “Data cleanup” (or equivalent) action that removes all plugin data (options, transients, logs, etc.) with confirmation. Document what is deleted. Do not remove data on deactivation; use cleanup and/or `uninstall.php`.

---

## 8. Logging and observability

- Use a **centralised logger** (e.g. one Logger class) and configurable verbosity (e.g. error, warning, info, debug).
- **Debug off by default.** Logs must be production-safe and must not expose secrets or personal data.
- Provide a way for admins to **view or download logs** from the plugin’s settings area.

---

## 9. Documentation

- **`/docs`:** Overview, installation, configuration, architecture, hooks, third-party libraries/APIs. Keep these in sync with the code.
- **`/plugin/docs`** (if present): Usage, widget controls, FAQs for end users.
- **CHANGELOG.md:** At project root; updated for every version change.
- **Code comments:** Accurate and concise; no dead or misleading comments.

---

## 10. Security and data

- **Escaping:** All user- or database-derived output must be escaped for the context (HTML, attribute, URL).
- **Sanitization:** Sanitize and validate all inputs before saving or using in queries.
- **Options/tables:** If the plugin adds options or tables, use **install/upgrade routines**: set defaults on activation; run migrations only when the plugin version changes (store last version in an option). Do not run schema or migration logic on every page load.

---

## 11. Load only where needed (mandatory)

The plugin must load code only on the pages and contexts where it is actually used. Unused pages must have zero functional overhead.

- **Bootstrap / every request:** Load only the minimum required for dependency checks and upgrade (e.g. Dependencies, Installer, Plugin). Do **not** require admin or widget class files on frontend requests.
- **Admin:** Require and run admin code (Logger, settings, logs, cleanup) only when `is_admin()` is true. Prefer loading settings/logs/cleanup only when the user is on the plugin’s settings page (e.g. by checking `$_REQUEST['page']` before instantiating those components). Do not load full admin classes on every admin request if they are only needed on one screen.
- **Elementor widget:** Require the widget class, source, and assets helper only when registering the widget (e.g. inside the `elementor/widgets/register` callback). Do not load them in the main plugin bootstrap.
- **Front-end assets (CSS/JS):** Enqueue gallery (or widget) scripts and styles only when the widget is actually rendered on the page (e.g. from the widget’s `render()` method). Do not enqueue widget assets globally; pages without the widget must not load them.
- **Hooks:** Register widget and category only when Elementor and WooCommerce are active. Document the loading strategy in `/docs/architecture.md` (e.g. a “Loading strategy” or “Conditional loading” section).

---

## 12. Third-party libraries and APIs

- Prefer **permissively licensed** libraries (e.g. MIT). Do not bundle commercial-licence code unless the licence clearly allows redistribution in a WordPress plugin.
- **Document** all third-party libraries and external APIs in `/docs/third-party.md` (and `/docs/third-party-apis.md` if you distinguish server-side APIs). Include name, version, licence, and how they are loaded (e.g. CDN, bundle). Keep all prompts in **`/prompts`** at project root for reuse.

---

## 13. Extensibility

- Provide **filters and actions** so developers can modify data, inject content, or override behaviour (e.g. product ID, media list, options).
- Document every hook in **`/docs/hooks.md`** with: name, parameters, return value, and a short example.

---

## 14. Checklist for a new Chameleon Elementor plugin

Before considering the plugin “done” for a release, ensure:

- [ ] Plugin name and widget title follow Chameleon naming; author is Lee Carter.
- [ ] All deployable code is under `/plugin`; project root has only non-deployable files.
- [ ] **.gitignore** at project root excludes IDE, OS, vendor, logs, secrets.
- [ ] Git repo is at project root; every change is committed with version bump and CHANGELOG update.
- [ ] Elementor widget is registered only when Elementor and WooCommerce are active; admin notice if either is missing.
- [ ] Custom **Chameleon** category is registered; widget is in that category.
- [ ] Widget uses `get_settings_for_display()`, proper escaping, and conditional asset loading.
- [ ] Settings (if any) are under WooCommerce (or Settings); use `manage_options`, nonce, and sanitization.
- [ ] Data cleanup is available with confirmation; logs are viewable/downloadable; debug off by default.
- [ ] `/docs` (and optionally `/plugin/docs`) are present and accurate; CHANGELOG is up to date.
- [ ] No fatal errors when WooCommerce or Elementor is inactive; variation switching (if applicable) works correctly.
- [ ] **Load only where needed:** Admin/logger classes load only when `is_admin()`; widget/source/assets only when registering the widget; frontend CSS/JS only when the widget is rendered on the page. Architecture docs describe the loading strategy.
- [ ] **Prompts:** All prompt files are in **`/prompts`** at project root (format: `prompt-<description>.md`); folder can be copied to new projects for reuse.
- [ ] **Cursor rules:** Where this prompt defines mandatory or long-lived rules, create or update `.cursor/rules/*.mdc` files so Cursor maintains them (see `prompts/README.md` → Cursor rules (.mdc)).

---

## Cursor rules (.mdc)

When applying this prompt, create or update **Cursor rule files** (`.cursor/rules/*.mdc`) so that Cursor continues to enforce the rules without re-invoking the prompt. For example:

- **Commit and versioning** → already in `commit-on-change.mdc`; keep it in sync with section 3.
- **Load only where needed** → add or update a rule that restates section 11 (conditional loading).
- **Project structure** → add or update a rule that restates section 2 (/plugin, /prompts, /docs).

Use YAML frontmatter (`description`, optional `alwaysApply: true`) and markdown content. See `prompts/README.md` and `.cursor/rules/commit-on-change.mdc` for format.

---

## End of prompt

Use this document when creating or modifying any Chameleon Elementor WordPress/WooCommerce plugin. For project-specific feature lists (e.g. gallery parity, video support), add a separate prompt or spec file and reference this document as the base rule set.
