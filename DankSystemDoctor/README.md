# Dank System Doctor

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) plugin that monitors your Linux system in real-time and uses local AI (via [Ollama](https://ollama.com)) to diagnose issues and suggest one-click fixes.

## Features

- **Live metrics** — CPU, RAM, disk usage and temperature, updated every 5 seconds
- **Health score** — 0–100 score shown on the bar pill; turns orange or red when thresholds are exceeded
- **Process monitor** — top CPU consumers with mini progress bars
- **Log viewer** — recent `journalctl` error entries, polled every 30 seconds
- **AI Doctor** — sends your full system context to a local Ollama model; response is displayed with one-click "Apply Fix" buttons for every suggested shell command
- **Root-safe fixes** — commands that need root run through `pkexec` (graphical auth prompt, no passwordless sudo required)

## Screenshots

> Overview tab — metric cards with live progress bars  
> Processes tab — top CPU consumers  
> Logs tab — recent journal errors  
> AI Doctor tab — Ollama analysis with fix buttons

## Requirements

| Dependency | Purpose |
|---|---|
| [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) ≥ 1.4.0 | Shell framework |
| [Ollama](https://ollama.com) | Local AI backend |
| `bash`, `ps`, `free`, `df`, `journalctl` | System metric collection (standard on any Linux system) |

## Installation

### Via DMS Plugin Manager (recommended)

1. Open DankMaterialShell Settings → Plugins → Install
2. Enter the repo URL: `YOUR_USERNAME/DankSystemDoctor`
3. Enable the plugin and add it to your bar

### Manual

Install via the DMS plugin manager, or clone the standalone repo:

```bash
cd ~/.config/DankMaterialShell/plugins
git clone https://github.com/NordicsSys/DankSystemDoctor dankSystemDoctor
```

Then add to `plugin_settings.json`:

```json
"dankSystemDoctor": {
    "enabled": true,
    "ollamaModel": "llama3.2",
    "cpuThreshold": 85,
    "ramThreshold": 85,
    "diskThreshold": 90,
    "logInterval": 30
}
```

And add to your bar config in `settings.json`:

```json
{ "id": "dankSystemDoctor", "enabled": true }
```

## Ollama Setup

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model (choose one)
ollama pull llama3.2        # recommended — best balance
ollama pull llama3.2:1b     # fastest, smaller
ollama pull mistral         # good for technical analysis
ollama pull deepseek-r1:7b  # strong reasoning
```

Ollama runs as a systemd service automatically after install. The plugin connects to `http://localhost:11434`.

## Settings

| Setting | Default | Description |
|---|---|---|
| Ollama Model | `llama3.2` | Model name for AI diagnostics |
| CPU Threshold | 85% | Health score penalty above this |
| RAM Threshold | 85% | Health score penalty above this |
| Disk Threshold | 90% | Health score penalty above this |
| Log Interval | 30s | How often to poll `journalctl` |

## How the Health Score Works

Starts at 100 and loses points when:

- CPU > threshold → −20
- RAM > threshold → −20
- Disk > threshold → −15
- Temperature > 80°C → −15 (> 90°C → −30)
- Journal errors found → −10 (many errors → −15)

**Green** (80–100) · **Orange** (50–79) · **Red** (0–49)

## License

MIT
