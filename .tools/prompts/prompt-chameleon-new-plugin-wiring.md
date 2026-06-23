# Cursor prompt — New Chameleon plugin: monorepo release wiring

**Version:** 1.2.0  
**Audience:** Cursor (AI coding assistant)  
**Scope:** A **new** or **newly imported** WordPress plugin repo that lives **under** the `wordpress_plugins` workspace (per-plugin Git repo, **shared** publish pipeline at the monorepo root).

**Companion:** Use **`prompt-wordpress-plugin-starter.md`** first (or in parallel) for `/plugin` layout, versioning, Git, headers, and Chameleon product rules. **This prompt** adds only what is required to wire the plugin into **`plugins-live`**, **`publish-live-plugins.ps1`**, and **optional SFTP** — not duplicate the starter.

**Authoritative docs:** `.docs/REPO-AND-PUBLISH-LAYOUT.md`, `plugins-live/README.md`, `.cursor/rules/live-plugins-latest.mdc`, `.cursor/rules/plugin-zip-on-change.mdc`, `.cursor/rules/plugin-install-zip-format.mdc`.

---

## 1. Information to confirm (ask the user if missing)

Ask for anything not already stated in the chat. Do not guess slug or dependency behaviour.

| # | Topic | What you need |
|---|--------|----------------|
| 1 | **Plugin slug** | Lowercase **kebab-case**; must equal deploy folder name, main PHP filename (`<slug>.php`), text domain, and zip prefix (`<slug>-<semver>.zip`). |
| 2 | **Display name** | Human-readable name for admin menus and UI (no `(Chameleon)`). **Plugins list** header uses `(Chameleon) {display name}`. Canonical names: `.tools/chameleon-plugin-manifest.json`. |
| 3 | **Filesystem path** | Path **under** `wordpress_plugins/` where the plugin repo root lives — **prefer** `plugins-dev/...` (e.g. `plugins-dev/chameleon/other/<slug>/`). Must be a descendant of the monorepo so `Run-AfterBuildLivePlugins.ps1` can find the root. |
| 4 | **Zip output layout** | Default: `dist/<slug>/<slug>-<version>.zip`. Alternative: `plugins/dist/<slug>/…` (Knowles-style). `publish-live-plugins.ps1` scans **both** `dist/` and `plugins/dist/` under **that plugin repo root**. |
| 5 | **Build script name** | e.g. `scripts/build-plugin-zip.ps1` or `scripts/build-<slug>-zip.ps1` — align with repo convention; document in plugin `README.md`. |
| 6 | **Hard dependencies** | WooCommerce, ERP connector, Elementor-only, etc. — drives activation checks and rules (see `.cursor/rules/erp-dependent-plugins.mdc` if ERP applies). |
| 7 | **Update server + Admin dependency** | **Mandatory** for all `(Chameleon)` plugins: **`Update URI:`** line (see `plugins-live/README.md`), **`Requires Plugins: chameleon-admin`**, and **`includes/chameleon-require-admin.php`** wired in the main file (see `.cursor/rules/chameleon-admin-required.mdc`). Sites must have **Chameleon Admin** active before this plugin can activate. |
| 8 | **Admin UI** | Any settings screen? If yes: shared **`chameleon`** parent menu, unique submenu slug, **`plugin_action_links_*` → Settings** (see `.cursor/rules/chameleon-admin-menu.mdc`, `plugin-settings-action-link.mdc`). |
| 9 | **Multiple deliverables** | Single zip only, or more than one slug (e.g. hub + satellite)? Each slug needs its own zip name pattern and usually its own build script tail calling `after-build-live-plugins.ps1`. |
| 10 | **Git remote** | GitHub repo URL or name under **`Nightsun1973/`** (for **`wire-plugin-git-workspace.ps1 -CreateRemote`** or **`-RemoteUrl`**). |

---

## 2. Mandatory wiring checklist (execute in order)

### 2.1 Monorepo location

- Confirm the plugin repo root contains **`README.md`** (publish and many scripts use this as the “run from here” anchor).
- Confirm an ancestor path is named **`wordpress_plugins`** containing:
  - `scripts/Run-AfterBuildLivePlugins.ps1`
  - `scripts/after-build-live-plugins.ps1`
  - `.tools/scripts/publish-live-plugins.ps1`  
  If not, **stop** and explain: automatic post-build publish will not run until the repo is placed under the umbrella (see `.docs/REPO-AND-PUBLISH-LAYOUT.md`).

### 2.2 Install zip build (POSIX-safe)

- Build script must **not** use `Compress-Archive` for the install zip.
- Resolve **`wordpress_plugins`** root from the plugin project root (walk parents until folder name is `wordpress_plugins`).
- Dot-source **`wordpress_plugins/.tools/scripts/build-plugin-install-zip.ps1`** and call:
  - `Build-PluginInstallZip -SourceDir <plugin source dir> -Slug <slug> -Version <version> -OutZip <path>`
  - `Assert-PluginInstallZipPosixPaths -ZipPath <path> -ExpectedSlug <slug>`
- Source directory is usually **`plugin/`** (starter layout). Zip internal root folder must be **exactly `<slug>/`**.

### 2.3 Zip retention

- Add **`scripts/cleanup-plugin-zips.ps1`** in the plugin repo as a **thin wrapper** that locates `wordpress_plugins` and invokes **`.tools/scripts/cleanup-plugin-zips.ps1`** (copy pattern from e.g. `plugins-dev/chameleon/other/email-send-and-log/scripts/cleanup-plugin-zips.ps1`, or the same path under legacy top-level `chameleon/other/...`).
- Call that wrapper from the build script **after** a successful zip build (before `plugins-live` publish).

### 2.4 Post-build: `plugins-live` + manifest + SFTP

- Add **`scripts/after-build-live-plugins.ps1`** at the plugin repo root’s `scripts/` folder using **exactly** this body (no local publish logic):

```powershell
$ErrorActionPreference = 'Stop'
$projectRoot = (Get-Item -LiteralPath (Join-Path $PSScriptRoot '..')).FullName
$repo = (Resolve-Path -LiteralPath $projectRoot).Path
$c = $repo
while ($true) {
  $run = Join-Path $c 'scripts\Run-AfterBuildLivePlugins.ps1'
  if (Test-Path -LiteralPath $run) {
    & $run -PluginProjectRoot $repo
    break
  }
  $p = Split-Path -Parent $c
  if (-not $p -or $p -eq $c) { break }
  $c = $p
}
```

- End the **build** script with:

```powershell
& (Join-Path $PSScriptRoot 'after-build-live-plugins.ps1')
```

(use the same `$PSScriptRoot` relative pattern as the rest of that script).

This triggers **`publish-live-plugins.ps1 -RepoRoot <plugin>`**, which copies the newest matching zip(s) into **`plugins-live/`**, regenerates **`index.json`**, and runs **SFTP** when `CHAMELEON_LIVE_PLUGINS_SFTP_*` (or legacy FTP-named aliases) are set — see `plugins-live/README.md`.

### 2.5 `.gitignore`

- Ensure plugin repo **`.gitignore`** excludes **`dist/**/*.zip`** (and any other generated artifacts per starter). Zips must not be committed in the plugin repo; **`plugins-live/*.zip`** are ignored at the monorepo per existing policy.

### 2.6 Git repository, remote, and IDE workspace

Every plugin under **`plugins-dev/`** must be its **own Git repo** with an **`origin`** remote (GitHub under **`Nightsun1973/`** unless the user specifies otherwise). The umbrella repo does **not** track plugin source.

From **`wordpress_plugins`** root, after the plugin scaffold exists:

```powershell
# Option A — existing empty GitHub repo URL
.\scripts\wire-plugin-git-workspace.ps1 -PluginPath plugins-dev/chameleon/other/<slug> -RemoteUrl https://github.com/Nightsun1973/<slug>.git

# Option B — create repo with GitHub CLI (gh auth login required)
.\scripts\wire-plugin-git-workspace.ps1 -PluginPath plugins-dev/chameleon/other/<slug> -CreateRemote -GitHubRepo <slug>
```

Then from the **plugin repo root**: commit scaffold if needed, **`git push -u origin master`** (or **`main`**).

This script **`git init`s** when missing, adds **`origin`**, and regenerates **`plugins-dev-active.code-workspace`** + **`wordpress_plugins.code-workspace`** so Cursor Source Control and **Git Graph** list the new repo.

**Verify remotes across all active plugins:**

```powershell
.\scripts\audit-plugins-dev-git.ps1 -ExcludeArchive
```

**Open the multi-root workspace** (not “Add Folder” on a parent tree):

**File → Open Workspace from File → `plugins-dev-active.code-workspace`**

For day-to-day work on one plugin only, open that plugin’s project root (**File → Open Folder**). See **`prompt-wordpress-plugin-starter.md`** for `.gitignore`, first commit, and baseline push.

### 2.7 Chameleon Admin dependency + Update URI

- Copy **`.tools/templates/chameleon-require-admin.php`** → **`plugin/includes/chameleon-require-admin.php`** (or `includes/` next to the main file).
- In the main plugin file, after the `ABSPATH` guard:

```php
require_once __DIR__ . '/includes/chameleon-require-admin.php';
chameleon_plugin_require_admin_bootstrap( __FILE__, '<text-domain>' );
```

- Add header lines (with other plugin headers): **`Update URI: https://admin.chameleoncodewing.co.uk/wp-content/uploads/plugin-repo`** and **`Requires Plugins: chameleon-admin`** (WP 6.5+).
- **`chameleon-admin`** itself is the exception — it does not require itself.

### 2.8 Version and changelog

- After wiring, bump **`plugin/VERSION`** (patch) and add a **`plugin/CHANGELOG.md`** entry describing the release pipeline wiring (per `.cursor/rules/plugin-version-bump.mdc`).

### 2.9 Verification

- From the **plugin repo root**, run the build script. Expect:
  - Zip under `dist/<slug>/` (or `plugins/dist/…`) with correct name.
  - Console output from publish (e.g. `PUBLISHED <slug> => …`) when a new zip is picked up.
  - SFTP lines only when env is loaded (`scripts/load-live-plugins-ftp-env.ps1` from `wordpress_plugins` root).
- If SFTP is not configured, local **`plugins-live/`** and **`index.json`** update still prove success.

---

## 3. Do not duplicate monorepo-only logic in the plugin repo

Keep **out** of the per-plugin repo (except thin wrappers above):

- Full `publish-live-plugins.ps1` copy
- SFTP implementation (`sync-live-plugins-repo-ftp.ps1`)
- Manifest generator (invoked from publish at monorepo)

---

## 4. Optional: Cursor rules sync

If this prompt introduces a **new long-lived** convention not already captured, add or update **`.cursor/rules/*.mdc`** per `.cursor/rules/prompts-to-rules.mdc`. For standard Chameleon plugins, existing **plugins-live** and **plugin-zip** rules usually suffice.

---

## 5. Completion criteria

The task is **done** when:

1. Build produces a **semver-named** zip: `<slug>-<major.minor.patch>.zip` under `dist/` or `plugins/dist/`.
2. **`scripts/after-build-live-plugins.ps1`** exists and matches the canonical snippet.
3. Build ends by invoking that script.
4. One **`README.md`** note explains “run build from repo root; publish uses shared `wordpress_plugins` scripts”.
5. **`plugin/VERSION`** and **`plugin/CHANGELOG.md`** updated for the wiring (or initial release).
6. Plugin has **`.git`**, **`origin`** remote, baseline pushed, and appears in **`plugins-dev-active.code-workspace`** after **`wire-plugin-git-workspace.ps1`** (or manual equivalent + **`discover-plugins-dev-workspace.ps1`**).

---

*End of prompt.*
