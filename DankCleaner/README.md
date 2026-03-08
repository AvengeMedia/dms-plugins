# Dank Cleaner

Safe one-click cleaner plugin for DankMaterialShell.

## Features

- One-click cleanup for safe user-space junk categories
- Reclaimable space estimation before cleanup
- Large file discovery view with configurable threshold
- Disk analyzer tab with top-directory bars and category split
- Optional per-file delete action in large-file results

## Safe Mode Scope

Default cleanup targets:

- `~/.cache` (excluding browser cache directories by default)
- `~/.local/share/Trash/files` and `~/.local/share/Trash/info`
- Browser cache folders (if present): `~/.cache/mozilla`, `~/.cache/google-chrome`, `~/.cache/chromium`
- Optional old `/tmp` files owned by current user only

The plugin does not clean system package caches or privileged paths.

## Development

- Main branch contains stable plugin code.
- Use short-lived feature branches and open PRs into `main`.
