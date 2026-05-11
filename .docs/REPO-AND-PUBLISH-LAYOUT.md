# Per-plugin repositories, shared publish workflow

## Model

- **Each Chameleon plugin** lives in its **own Git repository** (version, issues, releases, and CI are scoped to that product).
- **Publishing to the online plugin library** is **centralised at the `wordpress_plugins` workspace root**: copy into `plugins-live/`, regenerate `index.json`, optional SFTP sync. Do not fork or duplicate that chain inside individual plugin repos.

## What lives where

| Location | Git | Purpose |
|----------|-----|---------|
| Plugin repo root (`plugin/`, `scripts/build-*.ps1`, thin `scripts/after-build-live-plugins.ps1`, `README.md`, …) | **Per-plugin** | Shippable plugin code and build scripts. |
| `wordpress_plugins/.tools/scripts/publish-live-plugins.ps1` and related generators | **Umbrella / tooling** (this workspace or a small shared tools repo) | Single implementation of publish + manifest + SFTP trigger. |
| `wordpress_plugins/scripts/Run-AfterBuildLivePlugins.ps1`, `scripts/after-build-live-plugins.ps1`, `scripts/sync-live-plugins-repo-ftp.ps1`, `scripts/load-live-plugins-ftp-env.ps1` | Same as above | Common post-build entry and mirror upload. |
| `wordpress_plugins/plugins-live/` | Umbrella (zips gitignored; `index.json` committed when policy allows) | Latest zip per slug for the update server. |

## Layout requirement for automatic publish after build

Build scripts call the thin **`scripts/after-build-live-plugins.ps1`** in the plugin repo, which walks **upward** until it finds **`wordpress_plugins/scripts/Run-AfterBuildLivePlugins.ps1`**, then resolves the **monorepo root** (folder that has **both** `.tools/scripts/publish-live-plugins.ps1` and `scripts/after-build-live-plugins.ps1`) and runs publish with **`-RepoRoot`** set to the **plugin project root**.

Therefore:

- **Recommended:** keep every development plugin/client checkout **under** `wordpress_plugins/plugins-dev/` (e.g. `plugins-dev/chameleon/other/email-send-and-log/`). That keeps one clear bucket for repos the umbrella Git does not track. If anything still lives under a top-level `chameleon/` folder, relocate it to `plugins-dev/chameleon/...` when you can so paths stay consistent. Use **Git submodules**, **subtrees**, or plain clones as you prefer.
- **If a plugin is cloned in isolation** (no `wordpress_plugins` ancestor), post-build publish **skips** with a clear message. You can still run publish from a machine that has the umbrella tree:

  ```powershell
  Set-Location <path-to-wordpress_plugins>
  . .\scripts\load-live-plugins-ftp-env.ps1   # optional, for SFTP
  .\.tools\scripts\publish-live-plugins.ps1 -RepoRoot <path-to-plugin-repo-root>
  ```

## Commits

- **Plugin repo:** commit everything that ships or defines that plugin’s build (including the thin `after-build-live-plugins.ps1` wrapper).
- **Umbrella / tooling:** commit changes to `.tools/scripts/`, `scripts/Run-AfterBuildLivePlugins.ps1`, root `scripts/after-build-live-plugins.ps1`, SFTP scripts, env examples, and `plugins-live/README.md` / manifest policy—**not** duplicated per plugin.

## Umbrella Git (this folder)

The **`wordpress_plugins`** directory may use its **own Git repository** for shared files only. **`.gitignore`** excludes **`plugins-dev/`** (all dev trees), legacy top-level **`chameleon/`**, and optional root **`client/`** / **`archive/`** if those folders exist at the repo root. See root **`README.md`**.

See also: `plugins-live/README.md` and `.cursor/rules/live-plugins-latest.mdc`.
