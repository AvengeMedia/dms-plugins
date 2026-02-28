# Dank Audio Visualizer

A circular audio visualizer desktop widget for [Dank Material Shell](https://github.com/AvengeMedia/dms-docs).

Ported from **[Fancy Audiovisualizer](https://github.com/noctalia-dev/noctalia-plugins/tree/main/fancy-audiovisualizer)** by **Lemmy / Noctalia Team** — originally built for the Noctalia shell.

## Credits

- **Original author:** Lemmy / [Noctalia Team](https://github.com/noctalia-dev)
- **Original repository:** [noctalia-dev/noctalia-plugins](https://github.com/noctalia-dev/noctalia-plugins)
- **Original license:** MIT
- **DMS port by:** [odtgit](https://github.com/odtgit)

## What changed in the port

- Adapted from Noctalia's `DraggableDesktopWidget` to DMS `DesktopPluginComponent`
- Bundled a self-contained 32-bar, 60 FPS cava process (DMS built-in CavaService only provides 6 bars)
- Added idle detection with automatic fade support
- Settings mapped to DMS `PluginSettings` components
- Theme integration switched from Noctalia `Color.*` / `Style.*` to DMS `Theme.*`
- GLSL 450 shader copied unchanged — all rendering logic is identical to the original

## Features

- 6 visualization modes: Bars, Wave, Rings, Bars+Rings, Wave+Rings, All
- Bloom/glow effects with configurable intensity
- Smooth content scaling to prevent border clipping
- Custom color overrides or automatic theme integration
- Fade when idle option
- 12 configurable settings via the DMS settings panel

## Requirements

- [cava](https://github.com/karlstav/cava) must be installed (`pacman -S cava` on Arch)
- Dank Material Shell >= 1.2.0

## License

MIT — see the [original repository](https://github.com/noctalia-dev/noctalia-plugins) for full license text.
