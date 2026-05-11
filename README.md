# WordPress plugins (umbrella workspace)

This folder is an **umbrella workspace**: shared **publish pipeline**, **Cursor rules**, **scripts**, and **`live-plugins`** metadata live here in **one Git repository**.

## What this repo tracks

- `.cursor/rules/` — Chameleon / WordPress agent and team standards  
- `.tools/` — shared build helpers, manifest generation, prompts (`publish-live-plugins`, `build-plugin-install-zip`, etc.)  
- `scripts/` — monorepo entry points (`Run-AfterBuildLivePlugins.ps1`, SFTP sync, env examples)  
- `live-plugins/` — `README.md`, `index.json` (zips are ignored; see `live-plugins/.gitignore`)  
- `.docs/` — workspace-level documentation (e.g. repo + publish layout)

## What this repo does **not** track

All **per-product development** checkouts live under **`plugins/`** (for example `plugins/client/knowles`, `plugins/archive/…`, and Chameleon plugins under `plugins/chameleon/...` once moved). Each product directory is its **own Git repository**. These paths are **`.gitignore`d** so the umbrella repo only tracks shared tooling. A legacy top-level **`chameleon/`** tree may still exist until everything is under `plugins/chameleon/`; it stays ignored too.

Builds and `publish-live-plugins.ps1 -RepoRoot` use the **plugin project root** path (where that product’s `README.md` lives), regardless of whether that is under `plugins/...` or a transitional `chameleon/...` path.

## Working on a single plugin

Open the **plugin project root** (the folder that contains its `README.md` and `plugin/`) in Cursor/VS Code so Git, commits, and remotes apply to **that** repo only.

## New plugin wiring

See **`.docs/REPO-AND-PUBLISH-LAYOUT.md`** and **`@.tools/prompts/prompt-chameleon-new-plugin-wiring.md`**.

## Adding a new top-level tree

- If it is **more per-repo source** (another vendor or product line), add a **`/new-folder/`** line to **`.gitignore`** so it is not absorbed into the umbrella by mistake.  
- If it is **shared infrastructure** (like `scripts/`), remove ignore (if any) and commit it here.
