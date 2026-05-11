# Plugin optimisation prompt

**Purpose:** Run this prompt against any WordPress plugin to identify and apply performance and efficiency improvements.  
**Location:** Store in **`/prompts`** at project root (e.g. `prompts/prompt-optimisation.md`). The `/prompts` folder can be copied to new projects for reuse.  
**Scope:** Any WordPress plugin (standalone, WooCommerce, Elementor, etc.).  
**Rule:** Prefer changes that reduce load, latency, and resource use without changing visible behaviour. If behaviour or APIs must change, document and get approval first.

---

## 1. Conditional loading (load only where needed)

- **Bootstrap:** On every request, load only what is required for dependency checks, upgrade logic, and routing. Do not `require` or instantiate admin-only or frontend-only code on the wrong context.
- **Admin:** Load admin classes (settings, logs, menus, assets) only when `is_admin()` is true. Where possible, load heavy admin logic (e.g. settings UI, log viewer) only when the user is on the plugin’s own admin page (e.g. check `$_REQUEST['page']` or `get_current_screen()`) before requiring or instantiating.
- **Frontend:** Load frontend code and enqueue scripts/styles only when the plugin’s output is actually present (e.g. shortcode rendered, widget on page, block in content). Do not enqueue plugin CSS/JS globally unless the plugin runs on every page by design.
- **Third-party integrations:** Load integration code (e.g. Elementor widget, WooCommerce hooks) only when the integration is active and in use. Register widgets/hooks from a callback that runs when the host is loaded, not from the main plugin bootstrap.
- **Document:** In `/docs` or architecture notes, describe what loads when (e.g. “Loading strategy” table: every request / admin / frontend with feature).

---

## 2. Scripts and styles

- **Enqueue only when needed:** Enqueue assets only on pages that use the feature. If the plugin uses shortcodes, blocks, or widgets, detect presence before enqueuing or use a flag set when the output is rendered.
- **Dependencies:** Declare correct script/style dependencies so WordPress can combine and order them. Avoid duplicate or redundant enqueues of the same handle.
- **Footer:** Enqueue non‑critical JS in the footer (`true` as 5th argument for `wp_enqueue_script`) where possible.
- **Versioning:** Use version strings (plugin version, filemtime, or asset version) so cache busting works after updates. Avoid `null` or no version.
- **Size:** Prefer minimal, scoped CSS. Remove unused rules or split into per‑feature files when it reduces payload on the majority of pages.
- **Third‑party assets:** Prefer CDN or conditional load for large libraries; document in `/docs/third-party.md`. Do not load heavy libraries on every page if the feature is used only in a few places.

---

## 3. Database and queries

- **No queries on every load:** Avoid running non‑cached queries on every request (e.g. options that never change, or counts). Use transients, object cache, or in‑memory defaults where appropriate.
- **Options:** Use `get_option()` with defaults; avoid repeated updates. Batch option updates where possible (e.g. on save only).
- **Queries:** Use indexed columns in `WHERE`/`JOIN`; avoid `SELECT *` when only a few columns are needed. Prefer core APIs (e.g. `WP_Query`, `get_posts`) over raw SQL unless necessary.
- **Transients:** Use transients for expensive or external data that can be stale for a short time. Set reasonable expiration and clear or refresh when the source data changes.
- **Upgrade/install:** Run schema changes or one‑time migrations only on activation or version upgrade, not on every page load. Store a “last upgraded version” option and run upgrade logic only when it changes.

---

## 4. Hooks and execution

- **Priority and context:** Register hooks at the latest appropriate priority. Prefer hooks that run only in the right context (e.g. `admin_init` vs `init`, `wp` vs `template_redirect`) so callbacks do not run when they are not needed.
- **Conditional registration:** Register hooks only when the feature is active (e.g. after checking that a dependency is loaded, or that the user is on a relevant screen).
- **Single responsibility:** Keep callbacks small. Defer heavy work to later hooks or to the moment when output is actually required.

---

## 5. Caching and object reuse

- **Reuse objects:** Where the same object or result is needed multiple times in a request, create or fetch it once and reuse (e.g. pass a shared service or result into functions instead of refetching).
- **Transients / object cache:** Cache expensive computations, remote API responses, or heavy queries with a short TTL. Invalidate when the underlying data changes.
- **Static or singleton:** Use static variables or a single instance for services that have no request‑specific state, so they are not recreated unnecessarily.

---

## 6. Frontend performance

- **Lazy load:** Use native `loading="lazy"` for images below the fold where appropriate; defer or async for non‑critical JS if the plugin injects scripts.
- **Inline and critical path:** Avoid blocking the main thread with large inline scripts. Prefer one or a few small, focused scripts over one large bundle if only a subset of pages need the full bundle.
- **No layout shift:** Reserve space for dynamic content (e.g. aspect ratio, min‑height) to avoid layout shift (CLS).
- **Accessibility:** Respect `prefers-reduced-motion`; avoid or tone down animations when the user prefers reduced motion.

---

## 7. Security and correctness (efficiency‑aware)

- **Escaping:** Escape all dynamic output for the correct context (HTML, attribute, URL, JS). Missing escaping can also lead to invalid output and re‑parsing.
- **Sanitization:** Validate and sanitize input once, then use the sanitized value. Avoid repeated sanitization of the same input in the same request.
- **Nonce and capability:** Use nonces and capability checks only where needed (e.g. form submission, admin actions). Do not run heavy checks on every request if the action is rare.

---

## 8. Code and asset audit

- **Dead code:** Remove unused functions, classes, files, and hooks. Remove commented‑out code and obsolete conditionals.
- **Duplication:** Consolidate repeated logic into shared functions or services. Avoid duplicate asset handles or duplicate enqueue logic.
- **Dependencies:** Remove unused PHP dependencies, JS libraries, or CSS files. If a library is only used in one place, load it only there.

---

## 9. Documentation and versioning

- **Docs:** Update `/docs` (or equivalent) so they reflect the current loading strategy, enqueue behaviour, and any new options or hooks introduced by the optimisation.
- **Changelog:** Record optimisation work in the project changelog (e.g. “Conditional loading”, “Enqueue only when shortcode present”, “Reduce queries on frontend”).
- **Version:** Bump the plugin version appropriately (e.g. PATCH for performance‑only changes) and commit with a clear message.

---

## 10. Checklist before finishing

- [ ] Code and assets load only in the context where they are used (admin vs frontend, specific page vs global).
- [ ] Scripts and styles are enqueued only when the plugin’s output is present (or when explicitly required).
- [ ] No new queries or heavy logic run on every request without caching or necessity.
- [ ] No dead code, duplicate enqueues, or redundant hooks remain.
- [ ] Documentation and changelog are updated; version is bumped and changes are committed.

---

## Cursor rules (.mdc)

If optimisation rules (e.g. “enqueue only when needed”, “no queries on every load”) should be enforced ongoing, create or update `.cursor/rules/*.mdc` files so Cursor maintains them. See `prompts/README.md` → Cursor rules (.mdc).

---

## End of prompt

Run this prompt against a plugin when you want a systematic optimisation pass. Prefer small, verifiable changes. If a change could alter behaviour or break compatibility, document it and confirm before applying.
