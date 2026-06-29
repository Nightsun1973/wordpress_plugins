# WordPress Plugin Audit Report

Audit date: 2026-06-29  
Workspace audited: `/workspace`  
Requested output: `dev/Plugin-Audit-Report.md`  
Audit mode: read-only advisory review; no plugin code was modified.

## Executive Summary

This workspace is an umbrella `wordpress_plugins` repository containing shared build/publish tooling, Cursor rules, helper templates, `plugins-live/index.json`, and plugin catalog metadata. The individual plugin source checkouts expected under `plugins-dev/` are not present in this checkout. The root `README.md` states that per-product development repositories live under ignored `plugins-dev/` paths, and the filesystem currently contains no `plugins-dev/`, `plugins/`, or `chameleon/` plugin source trees.

Because plugin source code and install ZIPs are absent, this audit cannot truthfully certify source-level controls such as nonce coverage, output escaping, SQL preparation, WooCommerce HPOS code paths, REST/AJAX handlers, or database indexes for each plugin. The report therefore separates:

- Confirmed findings in the available shared tooling, templates, manifests, and documentation.
- Plugin-by-plugin risk recommendations inferred from the visible plugin inventory, descriptions, shortcodes, and categories.
- Follow-up source-audit requirements that should be completed before production rollout or major WordPress/WooCommerce/PHP upgrades.

Current compatibility baseline used for this audit:

- WordPress: 7.0 current release, with 7.0.1 scheduled as a maintenance release.
- WooCommerce: 10.9.1 current stable release.
- PHP: supported branches are 8.2, 8.3, 8.4, and 8.5; PHP 8.1 and below are end-of-life. Target PHP 8.4+ for production where host support allows.
- Database: WordPress 7.0 hosting guidance indicates MySQL 8.0+ or MariaDB 10.6+ minimum, with MySQL 8.4 LTS or MariaDB 11.4 LTS preferred.

## Overall Risk Rating

Overall risk rating: **High until plugin source repositories are audited**.

Reasoning:

- Several confirmed tooling issues can publish malformed or stale packages, leak local path metadata, or allow dependency guards to behave inconsistently.
- All live manifest plugin entries have `text_domain: null`, reducing visibility into i18n/header compliance from the central metadata.
- WooCommerce, ERP/reporting, booking, redirect, login, file/media, and import/export plugins have higher inherent security and compatibility risk, but their source code is not present for direct verification.
- Managed-hosting deployment targets introduce additional risk around object caching, WP-Cron reliability, OPcache, file permissions, server cache, and database version heterogeneity.

## Scope and Evidence

### Files and metadata reviewed

- `README.md` lines 1-17, 19-42
- `.docs/README.md`
- `.docs/REPO-AND-PUBLISH-LAYOUT.md`
- `plugins-live/index.json`
- `plugins-live/README.md`
- `.tools/live-plugin-catalog.json`
- `.tools/chameleon-plugin-manifest.json`
- `.tools/templates/chameleon-require-admin.php`
- `.tools/templates/chameleon-require-erp.php`
- `.tools/templates/chameleon-upgrader-ajax.php`
- `.tools/scripts/*.ps1`
- `scripts/*.ps1`
- `.cursor/rules/*.mdc`

### Source availability limitation

The following expected source paths are absent from this checkout:

- `/workspace/plugins-dev/`
- `/workspace/plugins/`
- `/workspace/chameleon/`

No plugin PHP source files are present apart from shared templates under `.tools/templates/`. No local `plugins-live/*.zip` packages are present to unzip and inspect. The plugin inventory below is therefore derived from `plugins-live/index.json`, `.tools/live-plugin-catalog.json`, and `.tools/chameleon-plugin-manifest.json`.

## Visible Plugin Inventory

| Plugin | Version | Category | Evidence |
|---|---:|---|---|
| `chameleon-admin` | 1.1.22 | Utility/update hub | `plugins-live/index.json` lines 5-18; `.tools/chameleon-plugin-manifest.json` lines 2-5 |
| `complete-address` | 0.6.3 | Woo/utility | `plugins-live/index.json` lines 19-32; manifest lines 129-133 |
| `cron-monitor` | 1.5.5 | Utility/cron | `plugins-live/index.json` lines 33-46; manifest lines 6-9 |
| `customer-reports` | 1.1.22 | ERP/reporting | `plugins-live/index.json` lines 47-95; catalog lines 22-35 |
| `custom-online-diary` | 2.0.3 | Booking | `plugins-live/index.json` lines 96-120; manifest lines 134-138 |
| `demo-gate` | 0.0.20 | Utility/demo | `plugins-live/index.json` lines 121-134; catalog lines 16-18 |
| `email-send-and-log` | 1.1.10 | Email/logging | `plugins-live/index.json` lines 135-148; manifest lines 16-19 |
| `engineer-move-serials` | 2.1.18 | ERP/tooling | `plugins-live/index.json` lines 149-162; manifest lines 36-39 |
| `erp-connector` | 0.2.9 | ERP/database connector | `plugins-live/index.json` lines 163-176; manifest lines 20-23 |
| `erp-job-search` | 1.2.6 | ERP/search | `plugins-live/index.json` lines 177-197; manifest lines 24-27 |
| `fleet-trak-dashboard` | 0.0.102 | Dashboard/reporting | `plugins-live/index.json` lines 198-211; manifest lines 96-99 |
| `hello-elementor-demo` | 0.1.3 | Test/demo | `plugins-live/index.json` lines 212-225 |
| `hello-update-test` | 0.1.11 | Test/update | `plugins-live/index.json` lines 226-239; manifest lines 28-31 |
| `knowles-booking` | 2.0.11 | Booking/ERP | `plugins-live/index.json` lines 240-256; manifest lines 88-91 |
| `knowles-data-dashboard` | 1.5.9 | Dashboard/reporting | `plugins-live/index.json` lines 257-273; manifest lines 92-95 |
| `kore-sim-manager` | 1.1.44 | Woo/subscriptions/SIM | `plugins-live/index.json` lines 274-287; manifest lines 32-35 |
| `lightfoot-job-search` | 1.1.8 | ERP/search | `plugins-live/index.json` lines 288-304; manifest lines 100-103 |
| `lightfoot-reports` | 1.0.7 | ERP/reporting | `plugins-live/index.json` lines 305-329 |
| `lkq-reports` | 1.0.6 | ERP/reporting | `plugins-live/index.json` lines 330-386; catalog lines 67-76 |
| `mask-login` | 0.1.16 | Login/security | `plugins-live/index.json` lines 387-400; manifest lines 40-43 |
| `media-cleanup` | 1.1.26 | Media/file admin | `plugins-live/index.json` lines 401-414; manifest lines 124-128 |
| `php-reports` | 0.1.102 | ERP/SQL reports | `plugins-live/index.json` lines 415-428; manifest lines 44-47 |
| `redirects` | 1.0.23 | Redirect management | `plugins-live/index.json` lines 429-442; manifest lines 10-15 |
| `responsive-viewer` | 0.1.7 | Admin utility | `plugins-live/index.json` lines 443-456; manifest lines 120-123 |
| `simple-booking` | 0.0.41 | Booking | `plugins-live/index.json` lines 457-473; catalog lines 10-15 |
| `woo-central-manager-hub` | 1.0.62 | Woo/multi-store | `plugins-live/index.json` lines 474-487; manifest lines 56-59 |
| `woo-central-manager-satellite` | 1.0.29 | Woo/multi-store | `plugins-live/index.json` lines 488-501; manifest lines 60-63 |
| `woo-complete-and-dispatch` | 1.0.6 | Woo/ERP orders | `plugins-live/index.json` lines 502-515; manifest lines 64-67 |
| `woo-erp-stock-sync` | 0.1.29 | Woo/ERP stock | `plugins-live/index.json` lines 516-529; manifest lines 68-71 |
| `woo-export-import-customer-order-details` | 0.5.25 | Woo import/export | `plugins-live/index.json` lines 530-543; manifest lines 52-55 |
| `woo-mailer` | 1.3.20 | Woo/email/cron | `plugins-live/index.json` lines 544-557; manifest lines 48-51 |
| `woo-product-badges` | 1.3.19 | Woo/catalog UI | `plugins-live/index.json` lines 558-571; manifest lines 84-87 |
| `woo-product-gallery-images` | 1.0.26 | Woo/Elementor UI | `plugins-live/index.json` lines 572-585; manifest lines 72-75 |
| `woo-product-search` | 1.0.1 | Woo/AJAX search | `plugins-live/index.json` lines 586-602; manifest lines 139-142 |
| `woo-region-stock-levels` | 0.6.8 | Woo/stock rules | `plugins-live/index.json` lines 603-616; manifest lines 76-79 |
| `woo-variation-manager` | 1.0.14 | Woo/product variations | `plugins-live/index.json` lines 617-630; manifest lines 80-83 |
| `chameleon_reports` | unknown | Legacy reporting | `.tools/live-plugin-catalog.json` lines 4-9 only |

## Plugin-by-Plugin Findings

The following plugin-by-plugin notes are advisory because source files are unavailable.

| Plugin(s) | Primary finding | Severity | Change priority |
|---|---|---:|---:|
| All visible plugins | Source code is absent from this checkout; complete WPCS/security/compatibility certification cannot be performed from available files. | Informational | Essential follow-up |
| All visible plugins | Live metadata has `text_domain: null`, and `plugin_name` values are slug-like rather than display names. Confirm main headers, text domains, `Requires PHP`, `Requires at least`, `Update URI`, Chameleon Admin requirements, and Settings links in source. | Low | Recommended |
| `chameleon-admin` | Confirm update-handler security: signed/hashed package validation, capability checks, nonces on settings/AJAX, safe remote fetching, timeout handling, and no sensitive URL leakage. | High | Essential |
| `erp-connector` | Confirm database/credential handling, encrypted or minimally exposed options, connection timeouts, least-privilege ERP database user, prepared PostgreSQL queries, and safe admin diagnostics. | High | Essential |
| `customer-reports`, `lightfoot-reports`, `lkq-reports`, `php-reports`, `knowles-data-dashboard`, `fleet-trak-dashboard` | Reporting plugins should be reviewed for SQL injection, unbounded result sets, pagination, export escaping, object-cache compatibility, cron locking, and data retention. | High | Essential |
| `erp-job-search`, `lightfoot-job-search` | Search shortcodes/AJAX should verify nonces where user-specific data is exposed, validate search terms, rate-limit expensive lookups, and avoid leaking attachments or job data across customers. | High | Essential |
| `engineer-move-serials` | Stock movement tools require strict capabilities, nonces, audit logs, idempotent operations, and transaction/integrity controls when moving serialized stock. | High | Essential |
| `knowles-booking`, `custom-online-diary`, `simple-booking` | Booking forms require nonce verification, spam/rate controls, server-side validation, escaped confirmation output, duplicate-submit protection, and caching-safe form handling. | Medium | Strongly Recommended |
| `woo-*`, `complete-address`, `kore-sim-manager` | Woo plugins require WooCommerce 10.9.1 compatibility checks, HPOS declarations/testing, CRUD API usage, subscription/payment-gateway compatibility where applicable, and Action Scheduler-safe background work. | High | Essential |
| `woo-export-import-customer-order-details` | Import/export plugin has elevated data-exposure risk; verify file type checks, CSV/Excel formula escaping, PII handling, nonces, capabilities, temporary file cleanup, and audit logging. | High | Essential |
| `woo-erp-stock-sync`, `woo-complete-and-dispatch`, `woo-region-stock-levels` | Stock/order mutation plugins require race-condition checks, HPOS-safe order/product access, background locking, retry/idempotency, and clear failure logging. | High | Essential |
| `woo-mailer`, `email-send-and-log` | Email plugins require safe API key storage, log redaction, retention controls, opt-out/compliance review, throttling, and WP-Cron/Action Scheduler reliability checks. | Medium | Strongly Recommended |
| `woo-product-search` | AJAX product search should validate and bound search terms, use nonces/capabilities where needed, cache results carefully, escape output, and avoid uncached full catalog scans. | Medium | Strongly Recommended |
| `woo-product-gallery-images`, `woo-variation-manager`, `woo-product-badges` | Frontend Woo UI plugins should load assets only on relevant product/catalog pages, respect accessibility and reduced-motion preferences, use CRUD APIs, and avoid layout shift. | Medium | Strongly Recommended |
| `media-cleanup` | Media/file admin tooling needs deletion confirmations, nonces, capability checks, dry-run/backup defaults, filesystem permission checks, and safe handling of missing files on shared hosting. | High | Essential |
| `redirects` | Redirect managers should guard against open redirects, regex ReDoS, redirect loops, unsafe imports, unescaped admin output, and cache/CDN invalidation gaps. | High | Essential |
| `mask-login` | Login masking should avoid locking out administrators, respect REST/AJAX/admin-post endpoints, integrate with security plugins, avoid cache poisoning, and document recovery steps. | Medium | Strongly Recommended |
| `cron-monitor` | Cron monitors should avoid spawning duplicate jobs, provide locking, avoid long requests in wp-admin, and handle hosts where WP-Cron is disabled in favour of real server cron. | Medium | Strongly Recommended |
| `demo-gate`, `hello-elementor-demo`, `hello-update-test`, `responsive-viewer` | Demo/test/admin utilities should be excluded from production update catalogs unless intentionally shipped; verify they cannot expose admin-only preview data or bypass authentication. | Medium | Strongly Recommended |

## Detailed Recommendations

### F-001: Complete source-level audit is blocked by absent plugin source

1. Plugin name: All visible plugins listed in the inventory.
2. File(s) affected: `README.md` lines 13-17 and 40-42 describe plugin source living in external ignored checkouts; absent paths include `/workspace/plugins-dev/`.
3. Line number(s): `README.md` lines 13-17, 40-42.
4. Issue description: The workspace does not contain the per-plugin source repositories required for direct review.
5. Why the issue exists: This is an umbrella repository; plugin repositories are intentionally ignored and not checked out here.
6. Potential impact: Security, WooCommerce HPOS, PHP upgrade, database, and performance compliance cannot be fully certified.
7. Security severity: Informational, but it blocks verification of potentially Critical/High issues.
8. Likelihood of exploitation: Unknown until source is reviewed.
9. Could this break functionality now / after updates / prevent installation: Yes, unknown source defects could break now or after WordPress, WooCommerce, PHP, or database upgrades.
10. Recommended solution: Check out every active plugin repository or provide current install ZIPs, then run source-level WPCS, PHPCS, PHPStan/Psalm where applicable, WooCommerce HPOS checks, database query review, and manual security review.
11. Estimated implementation complexity: Medium.
12. Priority: Essential.
13. Technical debt if delayed: Yes; every release without source certification increases unknown security and compatibility debt.

### F-002: ERP dependency guard can report satisfied without a connected connector API

1. Plugin name: ERP-dependent plugins, including `erp-job-search`, `lightfoot-job-search`, `customer-reports`, `lkq-reports`, `php-reports`, `engineer-move-serials`, `knowles-booking`, and related ERP-backed plugins.
2. File(s) affected: `.tools/templates/chameleon-require-erp.php`.
3. Line number(s): Lines 36-42 and 126-152.
4. Issue description: `chameleon_plugin_is_erp_connector_satisfied()` returns `is_plugin_active( $basename )` when `erp_connector()` is unavailable.
5. Why the issue exists: The helper treats plugin-active state as sufficient in one branch, even though the required runtime contract also requires `erp_connector()` and `erp_connector()->is_connected()`.
6. Potential impact: Dependent plugins may remain active while unable to query ERP data, causing front-end failures, blank reports, fatal errors, or inconsistent admin behaviour.
7. Security severity: High.
8. Likelihood of exploitation: Medium for availability/integrity issues; low-to-medium for direct security exploitation depending on dependent plugin error handling.
9. Could this break functionality now / after updates / prevent installation: Can break functionality now; can cause issues after plugin load-order or ERP Connector updates; unlikely to prevent installation but can leave broken active plugins.
10. Recommended solution: Return `false` when `erp_connector()` is missing at runtime. Only return true after verifying the function exists, returns an object, has `is_connected()`, and reports connected.
11. Estimated implementation complexity: Low.
12. Priority: Essential.
13. Technical debt if delayed: Yes; every ERP-dependent plugin inherits the ambiguity.

### F-003: Chameleon Admin activation guard bypasses dependency checks during upgrader AJAX

1. Plugin name: All `(Chameleon)` child plugins except `chameleon-admin`.
2. File(s) affected: `.tools/templates/chameleon-require-admin.php`; `.tools/templates/chameleon-upgrader-ajax.php`.
3. Line number(s): `chameleon-require-admin.php` lines 48-50 and 87-91; `chameleon-upgrader-ajax.php` lines 22-31.
4. Issue description: The Admin dependency guard returns early for `update-plugin`, `install-plugin`, and `upload-plugin` AJAX actions.
5. Why the issue exists: The bypass appears intended to prevent update interruptions, but it may also bypass activation enforcement during install/upload flows.
6. Potential impact: A child plugin may activate or continue loading without Chameleon Admin, contrary to dependency policy.
7. Security severity: Medium.
8. Likelihood of exploitation: Low-to-medium; requires admin/plugin-install access, but can cause broken dependency state.
9. Could this break functionality now / after updates / prevent installation: Can break functionality now and after WordPress plugin-upgrader flow changes.
10. Recommended solution: Narrow the bypass to update operations for already-installed active plugins, and keep activation dependency checks enforced for new installs/uploads. Add tests for missing Admin during upload-and-activate.
11. Estimated implementation complexity: Medium.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; dependency behaviour becomes harder to reason about as update flows evolve.

### F-004: PowerShell scripts may write UTF-8 BOM into plugin PHP or metadata on Windows PowerShell 5.1

1. Plugin name: All plugins touched by shared maintenance scripts.
2. File(s) affected: `scripts/normalize-chameleon-plugin-headers.ps1`, `scripts/add-chameleon-update-uri.ps1`, `scripts/wire-chameleon-admin-dependency.ps1`, `scripts/publish-chameleon-plugin-release.ps1`.
3. Line number(s): `normalize-chameleon-plugin-headers.ps1` lines 75 and 90; `add-chameleon-update-uri.ps1` lines 102, 112, and 133; `wire-chameleon-admin-dependency.ps1` lines 73 and 92; related writes in `publish-chameleon-plugin-release.ps1`.
4. Issue description: `Set-Content -Encoding UTF8` writes UTF-8 with BOM under Windows PowerShell 5.1.
5. Why the issue exists: The scripts use platform-dependent encoding semantics.
6. Potential impact: BOM bytes before `<?php` can break AJAX, REST API, media library responses, plugin updates, and JSON output.
7. Security severity: High for availability/integrity of admin actions; not usually direct data compromise.
8. Likelihood of exploitation: Medium if scripts are run from Windows PowerShell 5.1.
9. Could this break functionality now / after updates / prevent installation: Can break functionality now; can prevent clean plugin operation after PHP/WordPress changes that are stricter about output.
10. Recommended solution: Write using UTF-8 without BOM consistently, e.g. `[System.IO.File]::WriteAllText(..., [System.Text.UTF8Encoding]::new($false))`, or `utf8NoBOM` where available. Keep build-time BOM assertions.
11. Estimated implementation complexity: Low.
12. Priority: Essential.
13. Technical debt if delayed: Yes; every scripted header/version update can reintroduce a known failure mode.

### F-005: Publish pipeline copies ZIPs without validating WordPress install structure

1. Plugin name: All published plugins.
2. File(s) affected: `.tools/scripts/publish-live-plugins.ps1`.
3. Line number(s): Lines 24-36 and 88-102.
4. Issue description: Matching ZIPs are copied to `plugins-live` without asserting one top-level folder, POSIX paths, no BOM, and expected main plugin file.
5. Why the issue exists: Validation is performed by build helpers, but publish does not independently enforce it.
6. Potential impact: A malformed package can be published and served, causing install failures or "Plugin file does not exist" on Cloudways/SiteGround.
7. Security severity: Medium.
8. Likelihood of exploitation: Medium for accidental bad packages; low for malicious exploitation in trusted build environments.
9. Could this break functionality now / after updates / prevent installation: Yes, can prevent installation immediately and after future WordPress unzip/install behaviour changes.
10. Recommended solution: Call shared ZIP assertions before copying: single top-level folder equals slug, forward slashes, expected main file, no BOM, and optional hash generation after validation.
11. Estimated implementation complexity: Medium.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; build and publish invariants can drift.

### F-006: Publish pipeline chooses latest package by mtime rather than semantic version

1. Plugin name: All published plugins.
2. File(s) affected: `.tools/scripts/publish-live-plugins.ps1`.
3. Line number(s): Lines 63 and 88-89.
4. Issue description: The selected package per slug is the newest file by `LastWriteTimeUtc`, not the highest semantic version.
5. Why the issue exists: Sorting uses file timestamps for convenience.
6. Potential impact: Rebuilding an older package can publish a downgrade into the live update repository.
7. Security severity: Medium.
8. Likelihood of exploitation: Medium for operator error.
9. Could this break functionality now / after updates / prevent installation: Can break updates now by offering downgrades; can cause future update confusion.
10. Recommended solution: Sort by parsed semantic version first, using mtime only as a tie-breaker for duplicate versions.
11. Estimated implementation complexity: Low.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; release provenance and rollback behaviour remain fragile.

### F-007: Manifest generation failure is swallowed after package copy

1. Plugin name: All published plugins.
2. File(s) affected: `.tools/scripts/publish-live-plugins.ps1`.
3. Line number(s): Lines 105-116.
4. Issue description: Manifest regeneration is best-effort and failures only log a warning after packages may have changed.
5. Why the issue exists: The publish script intentionally avoids failing on manifest errors and invokes `powershell`, which may be unavailable on Linux/PowerShell Core hosts.
6. Potential impact: `plugins-live/index.json` can become stale or inconsistent with copied ZIPs; update clients may see missing or wrong versions.
7. Security severity: Medium.
8. Likelihood of exploitation: Medium operational likelihood.
9. Could this break functionality now / after updates / prevent installation: Can break update delivery now; can worsen after host shell/runtime changes.
10. Recommended solution: Treat manifest generation as required for successful publish. Use the current PowerShell executable or invoke the generator in-process. Roll back copied packages on failure.
11. Estimated implementation complexity: Medium.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; live metadata can diverge from shipped artifacts.

### F-008: Public live manifest exposes a local Windows filesystem path

1. Plugin name: All plugins in update manifest.
2. File(s) affected: `plugins-live/index.json`.
3. Line number(s): Line 3.
4. Issue description: `live_plugins_dir` includes a local Windows path with user/company context.
5. Why the issue exists: The manifest generator records local build path metadata.
6. Potential impact: Information disclosure in public update metadata.
7. Security severity: Medium.
8. Likelihood of exploitation: High if `index.json` is publicly served, because the data is directly accessible.
9. Could this break functionality now / after updates / prevent installation: Does not break functionality directly; could trigger security review failure.
10. Recommended solution: Remove `live_plugins_dir` from public manifests or replace it with a non-sensitive relative/public identifier.
11. Estimated implementation complexity: Low.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; sensitive build-environment metadata remains normalized in release artifacts.

### F-009: SFTP sync prunes remote ZIPs by default

1. Plugin name: All plugins mirrored to the public update repository.
2. File(s) affected: `scripts/sync-live-plugins-repo-ftp.ps1`; `plugins-live/README.md`.
3. Line number(s): `sync-live-plugins-repo-ftp.ps1` lines 191-204; README line 91.
4. Issue description: Remote ZIP files not present locally are deleted by default.
5. Why the issue exists: The script mirrors local `plugins-live` as the single source of truth.
6. Potential impact: Running from an incomplete or stale checkout can remove valid production packages.
7. Security severity: Medium.
8. Likelihood of exploitation: Medium operational risk.
9. Could this break functionality now / after updates / prevent installation: Yes, missing packages can break fresh installs and updates.
10. Recommended solution: Add dry-run output, remote sentinel/path verification, and explicit prune opt-in for production runs.
11. Estimated implementation complexity: Medium.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; release operations remain vulnerable to local-state mistakes.

### F-010: SFTP host-key bypass options weaken deployment integrity if used in production

1. Plugin name: All plugins mirrored by SFTP.
2. File(s) affected: `scripts/sync-live-plugins-repo-ftp.ps1`; `scripts/live-plugins-ftp.env.example`.
3. Line number(s): `sync-live-plugins-repo-ftp.ps1` lines 153-158.
4. Issue description: Environment flags can auto-accept or bypass strict host-key validation.
5. Why the issue exists: Convenience options are present for initial setup or troublesome host-key environments.
6. Potential impact: Increased man-in-the-middle risk during package publication.
7. Security severity: Low to Medium depending on production use.
8. Likelihood of exploitation: Low, but impact could be high if package uploads are intercepted.
9. Could this break functionality now / after updates / prevent installation: Does not break functionality; can compromise update supply chain if abused.
10. Recommended solution: Prefer pinned host fingerprints and fail closed. Keep bypass flags explicitly documented as non-production/development only.
11. Estimated implementation complexity: Low.
12. Priority: Recommended.
13. Technical debt if delayed: Yes; insecure deployment patterns can become habitual.

### F-011: Bulk publish discovery may miss `plugins/dist` trees

1. Plugin name: Multi-plugin repositories, including Knowles-style plugin trees.
2. File(s) affected: `scripts/publish-all-plugins-dev.ps1`.
3. Line number(s): Lines 27-32.
4. Issue description: `Get-ChildItem -Filter 'plugins\dist'` is unlikely to match nested path segments reliably.
5. Why the issue exists: `-Filter` applies to item names, not path patterns.
6. Potential impact: Multi-plugin distribution ZIPs can be skipped during bulk publishing.
7. Security severity: Low.
8. Likelihood of exploitation: Not security-related; medium operational likelihood.
9. Could this break functionality now / after updates / prevent installation: Can prevent updates from being published.
10. Recommended solution: Explicitly search both `**/dist` and `**/plugins/dist` using path-aware logic.
11. Estimated implementation complexity: Low.
12. Priority: Recommended.
13. Technical debt if delayed: Yes; bulk automation remains inconsistent across repo layouts.

### F-012: Live manifest metadata lacks text domains and display names

1. Plugin name: All live-index plugins.
2. File(s) affected: `plugins-live/index.json`.
3. Line number(s): Examples: `chameleon-admin` lines 12-15, `email-send-and-log` lines 142-145, `woo-product-search` lines 593-596; pattern applies to all entries.
4. Issue description: `text_domain` is `null` for every plugin, and `plugin_name` is slug-like.
5. Why the issue exists: Manifest generation either does not inspect headers or does not persist these fields.
6. Potential impact: Harder to audit i18n, header compliance, and display consistency centrally.
7. Security severity: Low.
8. Likelihood of exploitation: Not security-related.
9. Could this break functionality now / after updates / prevent installation: Can cause future update/admin UI consistency issues, not immediate install failure.
10. Recommended solution: Populate display names, text domains, `Requires PHP`, `Requires at least`, `Requires Plugins`, main file, and Update URI in the manifest from package headers.
11. Estimated implementation complexity: Medium.
12. Priority: Recommended.
13. Technical debt if delayed: Yes; central auditability remains weak.

### F-013: Demo/test plugins appear in the live update catalog

1. Plugin name: `hello-elementor-demo`, `hello-update-test`, `demo-gate`.
2. File(s) affected: `plugins-live/index.json`; `.tools/chameleon-plugin-manifest.json`.
3. Line number(s): `hello-elementor-demo` lines 212-225; `hello-update-test` lines 226-239; `demo-gate` lines 121-134.
4. Issue description: Test/demo-style plugins are visible in the live update manifest.
5. Why the issue exists: The live catalog includes packages beyond production products.
6. Potential impact: Accidental installation on customer sites, update clutter, and exposure of experimental functionality.
7. Security severity: Medium.
8. Likelihood of exploitation: Low-to-medium depending on access to the update repository and plugin install permissions.
9. Could this break functionality now / after updates / prevent installation: Can cause production misconfiguration now.
10. Recommended solution: Add a release channel/state field and exclude test/demo packages from production manifests unless intentionally supported.
11. Estimated implementation complexity: Low.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; production/test boundaries remain unclear.

### F-014: Legacy slug and naming inconsistencies increase tooling risk

1. Plugin name: `redirects`, `cc-url-redirects`, `chameleon_reports`, `simple-booking`, `woo-region-stock-levels`, Woo-related descriptions.
2. File(s) affected: `.tools/chameleon-plugin-manifest.json`, `.tools/live-plugin-catalog.json`, `plugins-live/index.json`.
3. Line number(s): Manifest lines 10-15, 76-79, 139-142; catalog lines 4-15; live index lines 429-442 and 457-473.
4. Issue description: Some entries use legacy slugs, underscore names, mixed-case shortcode tags, or product-facing "WooCommerce" wording where project standards prefer "Woo".
5. Why the issue exists: Historical plugin names have been carried forward alongside newer naming standards.
6. Potential impact: Update tooling, documentation, and user-facing labels can drift.
7. Security severity: Low.
8. Likelihood of exploitation: Not security-related.
9. Could this break functionality now / after updates / prevent installation: Slug mismatches can break updates/installs if not consistently mapped.
10. Recommended solution: Maintain explicit legacy mapping metadata and normalize display names/descriptions without changing install slugs unless a migration is planned.
11. Estimated implementation complexity: Medium.
12. Priority: Recommended.
13. Technical debt if delayed: Yes; naming exceptions compound across tools and docs.

### F-015: WooCommerce plugins require explicit HPOS and CRUD compatibility certification

1. Plugin name: `complete-address`, `kore-sim-manager`, `woo-central-manager-hub`, `woo-central-manager-satellite`, `woo-complete-and-dispatch`, `woo-erp-stock-sync`, `woo-export-import-customer-order-details`, `woo-mailer`, `woo-product-badges`, `woo-product-gallery-images`, `woo-product-search`, `woo-region-stock-levels`, `woo-variation-manager`.
2. File(s) affected: Source unavailable; visible metadata in `plugins-live/index.json` lines 474-630 and related manifest entries.
3. Line number(s): See inventory table.
4. Issue description: WooCommerce 10.9.1 compatibility, HPOS support, CRUD API use, subscription compatibility, and payment/order lifecycle behaviour cannot be verified from this checkout.
5. Why the issue exists: Woo plugin source repositories are absent.
6. Potential impact: Direct SQL against legacy order tables, deprecated hooks, or non-CRUD order access can break on HPOS or Woo updates.
7. Security severity: High for order/customer data plugins; Medium for display-only plugins.
8. Likelihood of exploitation: Unknown; likelihood of compatibility break is Medium.
9. Could this break functionality now / after updates / prevent installation: Yes, especially after WooCommerce updates, HPOS enforcement, or subscription/payment gateway changes.
10. Recommended solution: Review source for HPOS declarations, Woo CRUD APIs, Action Scheduler usage, nonce/capability checks, order status transitions, subscription APIs, and checkout/payment lifecycle hooks.
11. Estimated implementation complexity: Medium to High depending on plugin.
12. Priority: Essential.
13. Technical debt if delayed: Yes; Woo compatibility debt increases with every WooCommerce major/minor release.

### F-016: Shortcode/front-end plugins need conditional loading, nonce, cache, and escaping review

1. Plugin name: `customer-reports`, `custom-online-diary`, `erp-job-search`, `knowles-booking`, `knowles-data-dashboard`, `lightfoot-job-search`, `lightfoot-reports`, `lkq-reports`, `simple-booking`, `woo-product-search`.
2. File(s) affected: Source unavailable; shortcode metadata in `plugins-live/index.json`.
3. Line number(s): Examples: `customer-reports` lines 57-94, `custom-online-diary` lines 106-118, `erp-job-search` lines 187-195, `simple-booking` lines 467-471.
4. Issue description: Shortcode output and AJAX handlers cannot be verified for escaping, nonce/capability checks, conditional asset loading, or cache compatibility.
5. Why the issue exists: Only shortcode metadata is present.
6. Potential impact: XSS, CSRF, data leakage, uncached expensive queries, and broken behaviour behind server-side caches.
7. Security severity: Medium to High depending on whether customer/ERP data is exposed.
8. Likelihood of exploitation: Unknown; public shortcode forms/searches commonly have Medium exposure.
9. Could this break functionality now / after updates / prevent installation: Can break now under caching; may break after WordPress or PHP updates if deprecated APIs are used.
10. Recommended solution: Audit render callbacks and AJAX/REST endpoints for `sanitize_*`, `esc_*`, `wp_verify_nonce`, capability checks, pagination, rate limits, and assets enqueued only when shortcode output is present.
11. Estimated implementation complexity: Medium.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; front-end exposure compounds security and performance risk.

### F-017: ERP/reporting plugins need database-query, indexing, and data-scope review

1. Plugin name: `erp-connector`, `customer-reports`, `engineer-move-serials`, `erp-job-search`, `fleet-trak-dashboard`, `knowles-data-dashboard`, `lightfoot-job-search`, `lightfoot-reports`, `lkq-reports`, `php-reports`, `woo-erp-stock-sync`, `woo-complete-and-dispatch`.
2. File(s) affected: Source unavailable; descriptions in manifests/catalog.
3. Line number(s): See inventory table.
4. Issue description: Database access patterns, SQL preparation, indexing, result limits, and data isolation cannot be verified.
5. Why the issue exists: Source repositories and database schema/migration files are not present.
6. Potential impact: SQL injection, slow reports, table locks, memory exhaustion, customer data leakage, and poor performance on shared managed hosting.
7. Security severity: High.
8. Likelihood of exploitation: Unknown; public/search/report inputs raise likelihood to Medium if not properly prepared.
9. Could this break functionality now / after updates / prevent installation: Can break now under large data volumes; may break after MySQL/MariaDB upgrades due to stricter SQL modes.
10. Recommended solution: Review every `$wpdb` and external database query; use prepared statements, explicit indexes, bounded pagination, read-only ERP credentials where possible, query timeouts, object-cache-aware transients, and export streaming for large datasets.
11. Estimated implementation complexity: Medium to High.
12. Priority: Essential.
13. Technical debt if delayed: Yes; data volume growth increases both performance and security risk.

### F-018: Cron/background workloads need locking and managed-host compatibility review

1. Plugin name: `cron-monitor`, `php-reports`, `woo-mailer`, `woo-erp-stock-sync`, reporting plugins, and any plugin sending scheduled emails or syncing ERP/Woo data.
2. File(s) affected: Source unavailable; visible plugin descriptions and categories.
3. Line number(s): Inventory table; `cron-monitor` live entry lines 33-46.
4. Issue description: Cron scheduling, duplicate-run prevention, and Action Scheduler/WP-Cron compatibility cannot be verified.
5. Why the issue exists: Source is absent.
6. Potential impact: Missed jobs on low-traffic portals, duplicate emails/syncs, long admin requests, and inconsistent behaviour when hosts disable visitor-triggered WP-Cron.
7. Security severity: Medium for integrity/availability.
8. Likelihood of exploitation: Not primarily security-related; operational likelihood Medium.
9. Could this break functionality now / after updates / prevent installation: Can break now on Cloudways/SiteGround if cron is disabled or delayed.
10. Recommended solution: Use Action Scheduler for Woo-related queues, transient/options locks with expiry, idempotent job design, server-cron documentation, and admin visibility into stuck/failed jobs.
11. Estimated implementation complexity: Medium.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; background reliability worsens as sites and catalogs grow.

### F-019: File, media, import, and export tools require hardened file-handling review

1. Plugin name: `media-cleanup`, `woo-export-import-customer-order-details`, `php-reports`, reporting/export plugins.
2. File(s) affected: Source unavailable.
3. Line number(s): `media-cleanup` live entry lines 401-414; export/import live entry lines 530-543.
4. Issue description: Upload/download/delete/export paths cannot be verified for file type restrictions, path traversal prevention, temporary file cleanup, and sensitive data protection.
5. Why the issue exists: Source and upload handlers are absent.
6. Potential impact: Unauthorized file deletion, PII exposure, formula injection in CSV/Excel, temporary file leakage, or broken permissions on managed hosts.
7. Security severity: High.
8. Likelihood of exploitation: Unknown; Medium if admin AJAX endpoints are exposed without strong checks.
9. Could this break functionality now / after updates / prevent installation: Can break now under restrictive file permissions; may break after PHP filesystem/security changes.
10. Recommended solution: Audit file operations for nonces, capabilities, `wp_handle_upload`, MIME checks, `realpath` containment, `WP_Filesystem` where appropriate, CSV formula escaping, and cleanup on shutdown.
11. Estimated implementation complexity: Medium.
12. Priority: Essential.
13. Technical debt if delayed: Yes; file-handling bugs tend to become high-impact incidents.

### F-020: Security-sensitive utility plugins require dedicated threat review

1. Plugin name: `mask-login`, `redirects`, `demo-gate`, `responsive-viewer`.
2. File(s) affected: Source unavailable.
3. Line number(s): `mask-login` live entry lines 387-400; `redirects` lines 429-442; `responsive-viewer` lines 443-456; `demo-gate` lines 121-134.
4. Issue description: Login masking, redirect management, demo gating, and responsive preview utilities affect authentication paths, routing, or page visibility.
5. Why the issue exists: Source is not available for endpoint and route review.
6. Potential impact: Open redirects, redirect loops, regex denial of service, admin lockout, cache poisoning, accidental disclosure of private previews, or bypassable gates.
7. Security severity: Medium to High.
8. Likelihood of exploitation: Medium for redirect/login routing bugs if public endpoints are present.
9. Could this break functionality now / after updates / prevent installation: Can break now under server caches and permalink changes; may break after WordPress routing/login changes.
10. Recommended solution: Review route hooks, canonical redirects, regex limits, recovery modes, nonces/capabilities, cache exclusions, and documentation for emergency disable steps.
11. Estimated implementation complexity: Medium.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; routing/security utilities carry operational risk across all hosts.

### F-021: Update supply-chain should verify package hashes at install/update time

1. Plugin name: `chameleon-admin` and all plugins distributed through `plugins-live`.
2. File(s) affected: `plugins-live/index.json`; `chameleon-admin` source unavailable.
3. Line number(s): SHA-256 values appear throughout `plugins-live/index.json`, e.g. lines 8-11 and 136-142.
4. Issue description: The manifest includes hashes, but this checkout does not include `chameleon-admin` source to confirm hashes are enforced before installation.
5. Why the issue exists: Update client source is absent.
6. Potential impact: If hashes are informational only, compromised transport/storage could deliver modified packages.
7. Security severity: High.
8. Likelihood of exploitation: Low with HTTPS/SFTP; impact high if supply chain is compromised.
9. Could this break functionality now / after updates / prevent installation: Hash enforcement can prevent compromised installs; absence may not break functionality but weakens assurance.
10. Recommended solution: Confirm Chameleon Admin verifies package SHA-256 after download and before install, fails closed on mismatch, uses TLS validation, and logs update provenance.
11. Estimated implementation complexity: Medium.
12. Priority: Essential.
13. Technical debt if delayed: Yes; update supply-chain assurance remains incomplete.

### F-022: Plugin headers and compatibility declarations need central verification

1. Plugin name: All visible plugins.
2. File(s) affected: Plugin main files unavailable; manifest/catalog reviewed.
3. Line number(s): Not available in source; live metadata spans `plugins-live/index.json` lines 5-630.
4. Issue description: Cannot confirm `Requires at least`, `Requires PHP`, `Requires Plugins`, `Update URI`, author, text domain, and Woo/Chameleon naming standards in plugin headers.
5. Why the issue exists: Package/header source is unavailable and live metadata is incomplete.
6. Potential impact: Incorrect update routing, future install blocks, missing dependency declarations, inconsistent admin UI, or unsupported PHP installs.
7. Security severity: Medium.
8. Likelihood of exploitation: Low; compatibility likelihood Medium.
9. Could this break functionality now / after updates / prevent installation: Yes, especially after WordPress dependency/header enforcement changes.
10. Recommended solution: Extend manifest generation to extract and validate headers from each package, including WP/PHP/Woo tested versions and dependencies.
11. Estimated implementation complexity: Medium.
12. Priority: Strongly Recommended.
13. Technical debt if delayed: Yes; header compliance remains manual and error-prone.

## Security Findings

Priority security concerns:

1. **Essential:** Complete source audit blocked by absent plugin repositories (F-001).
2. **Essential:** ERP dependency guard may allow broken active state (F-002).
3. **Essential:** BOM-writing scripts can break AJAX/REST output (F-004).
4. **Essential:** Woo, ERP, file/import/export, update-hub, and admin utilities need source review for nonces, capabilities, escaping, SQL preparation, file safety, and sensitive data handling (F-015 through F-022).
5. **Strongly Recommended:** Remove local path disclosure from public manifest (F-008).
6. **Strongly Recommended:** Separate demo/test plugins from production update catalog (F-013).

## Compatibility Findings

- WordPress 7.0 readiness cannot be confirmed without plugin headers and source.
- WooCommerce 10.9.1 readiness cannot be confirmed for Woo plugins; HPOS and CRUD usage are the top compatibility risks.
- PHP 8.4/8.5 readiness cannot be confirmed; source should be scanned for dynamic properties, deprecated functions, strict typing issues, nullable/internal function changes, and warning-to-exception-prone code paths.
- MySQL 8.0+/MariaDB 10.6+ readiness cannot be confirmed for custom SQL; source should be checked for strict SQL mode, reserved words, index usage, charset/collation handling, and prepared statements.
- Chameleon Admin and ERP dependency declarations should be enforced consistently across install, activation, update, and runtime paths.

## Performance Findings

- Shortcode-heavy and Woo frontend plugins need conditional asset loading and cache-safe rendering review.
- ERP/reporting plugins need bounded pagination, streamed exports, query timeouts, object-cache-aware caching, and background processing where reports are expensive.
- Woo stock/order sync plugins should avoid synchronous long-running admin or checkout hooks.
- Cron/email/report plugins should use idempotent jobs, locks, Action Scheduler where suitable, and server-cron documentation for managed hosts.
- Publish tooling should avoid stale manifests and accidental downgrade publication, because update performance and reliability depend on accurate metadata.

## Database Findings

- ERP/reporting plugins need source-level verification of prepared SQL and least-privilege credentials.
- Woo plugins must use WooCommerce CRUD APIs for orders/products/customers, especially where HPOS is active.
- Custom WordPress tables should use `dbDelta()` carefully, include proper indexes, and only migrate when stored schema version is lower than code version.
- Large report/export plugins should avoid loading entire result sets into PHP memory.
- Queries should be tested against MySQL 8.0/8.4 and MariaDB 10.6/11.4 with strict SQL modes and modern collations.

## Hosting-Specific Considerations

### Cloudways-managed WordPress hosting

- PHP: Target PHP 8.4+ where available; test PHP 8.5 before production adoption.
- Object cache: Redis is common; transients/options locks must work with persistent object cache and avoid stale locks.
- Server cache/Varnish: Front-end forms, booking flows, login masking, redirects, and AJAX search need cache exclusions or nonce-safe rendering.
- OPcache: Releases should bump plugin versions and avoid relying on mutable included files without cache invalidation.
- Cron: Configure real server cron for sites with scheduled reports, Woo mailers, ERP stock sync, and large queues.
- Filesystem: Media cleanup/export tools must handle restrictive permissions and avoid direct writes outside WordPress-approved paths.

### SiteGround-managed WordPress hosting

- PHP/MySQL: Confirm each site meets WordPress 7.0 floors and preferred PHP/database versions; shared plans may vary.
- Dynamic cache: Exclude booking/search/login-gate pages and Woo cart/checkout/account endpoints as needed.
- Object cache: Memcached or dynamic caching may affect transients and stale stock/report data; cache keys must include customer/site scope.
- Cron: Low-traffic customer portals may miss WP-Cron events; server cron is recommended for scheduled emails/reports/syncs.
- File permissions: Import/export/media cleanup should use WordPress filesystem APIs where possible and fail safely on permission errors.

### SiteGround-hosted customer portals

- Customer-specific reporting plugins must enforce tenant/customer scope server-side.
- Avoid public shortcode output that reveals ERP/customer data without authentication where portals are private.
- Use pagination and async exports to protect shared hosting CPU/memory limits.
- Log retention and PII minimisation are important for customer portals with reports, order data, mail logs, and import/export files.

## Prioritised Action Plan

1. Obtain all active plugin source repositories or current install ZIPs for direct audit.
2. Fix confirmed shared tooling/template issues before the next package publication cycle.
3. Audit `chameleon-admin` update-client integrity and dependency enforcement.
4. Audit Woo plugins for WooCommerce 10.9.1, HPOS, CRUD, subscriptions, and payment lifecycle compatibility.
5. Audit ERP/reporting/database plugins for SQL preparation, query cost, indexing, and customer data isolation.
6. Audit public shortcode/AJAX plugins for nonce, validation, escaping, rate limiting, and conditional assets.
7. Harden deployment metadata and live manifest generation.

## Quick Wins

- Remove `live_plugins_dir` from public `plugins-live/index.json`.
- Change PowerShell writes to UTF-8 without BOM.
- Select latest ZIPs by semantic version, not mtime.
- Fail publish when manifest generation fails.
- Validate ZIP structure before copying to `plugins-live`.
- Mark demo/test packages as non-production or remove them from the production live catalog.
- Populate live manifest metadata from package headers.

## Long-Term Improvements

- Add CI per plugin: PHPCS/WPCS, PHPStan/Psalm, PHP compatibility scan, no-BOM check, zip structure validation, and targeted PHPUnit/wp-env tests.
- Add WooCommerce test matrix for HPOS enabled/disabled and Woo latest.
- Add integration tests for Chameleon Admin updates, hash validation, and dependency handling.
- Add database performance tests for large ERP/report result sets.
- Add managed-host deployment checklist for Cloudways/SiteGround cache, cron, PHP, DB, OPcache, and permissions.
- Centralise plugin metadata so live manifest, package headers, changelogs, and docs stay aligned.

## Implementation Roadmap

### Immediate (Critical)

- Obtain and audit source for `chameleon-admin`, `erp-connector`, Woo order/customer plugins, ERP/reporting plugins, file/import/export plugins, and public shortcode/search plugins.
- Confirm Chameleon Admin verifies package hashes before install/update.
- Ensure ERP-dependent plugins cannot activate or remain active without connected ERP Connector.
- Review all public AJAX/REST/shortcode endpoints in source for nonces, capabilities, sanitisation, escaping, and data-scope checks.

### Next Release (High)

- Fix UTF-8 BOM risk in shared scripts.
- Validate package structure before publishing to `plugins-live`.
- Make manifest generation required and fail closed on error.
- Select publish candidates by semantic version.
- Remove local filesystem path disclosure from the public manifest.
- Certify WooCommerce 10.9.1/HPOS compatibility for all Woo plugins.

### Future Improvements (Medium)

- Add release channels to exclude demo/test plugins from production catalogs.
- Add full header metadata extraction to `plugins-live/index.json`.
- Add cron locking and Action Scheduler review for scheduled/reporting/email/sync plugins.
- Add cache-exclusion documentation for booking, login, redirect, search, and Woo dynamic pages.
- Add database index and query-plan review for reporting/dashboard plugins.

### Technical Debt (Low)

- Normalize legacy slug mappings and product-facing naming.
- Align `.docs/README.md` with `plugins-dev/` source-location guidance.
- Add consistent category/state metadata to plugin manifests.
- Document Cloudways/SiteGround deployment assumptions per plugin.
- Maintain a recurring audit checklist tied to current WordPress, WooCommerce, PHP, MySQL, and MariaDB releases.
