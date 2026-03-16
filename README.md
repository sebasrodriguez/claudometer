# Claudometer

Native macOS menu bar app that monitors your Claude Pro/Max session and weekly usage in real-time.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## How it works

Claudometer spawns an ephemeral Claude CLI process via a pseudo-terminal (PTY), sends the `/usage` command, parses the TUI output, and displays the results in your menu bar. No persistent background processes — each poll is a fresh spawn that's killed immediately after capturing data.

## Features

- **Menu bar indicator** — session usage fill bar + percentage, always visible
- **Detailed dropdown** — click to see session, weekly, and Sonnet usage with progress bars and reset times
- **Auto-refresh** — polls on a configurable interval (1–30 min, default 5 min)
- **Cached data** — last known usage loads instantly on launch while a fresh poll runs in the background
- **Notifications** — macOS alerts when usage crosses configurable warning/critical thresholds
- **Configurable** — display mode, refresh interval, thresholds, and Claude CLI path via Settings
- **Zero dependencies** — native SwiftUI app, only requires the `claude` CLI installed

## Requirements

- macOS 14.0+
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Xcode or Swift toolchain (to build from source)

## Install

```bash
git clone https://github.com/sebasrodriguez/claudometer.git
cd claudometer/ClaudeUsageBar
make install
```

This builds a release binary and creates `ClaudeUsageBar.app`. Then either:

```bash
# Run directly
open ClaudeUsageBar.app

# Or copy to Applications
cp -r ClaudeUsageBar.app /Applications/
```

## Build from source

```bash
cd ClaudeUsageBar
swift build -c release
```

The binary will be at `.build/release/ClaudeUsageBar`.

## Usage

Once launched, Claudometer appears in your menu bar with a fill bar and session percentage (e.g. `CC 7%`).

**Click** the menu bar item to see:
- **Session usage** — current session progress bar, percentage, and reset time
- **Weekly usage** — all-models weekly progress bar, percentage, and reset time
- **Sonnet usage** — Sonnet-only weekly usage (if applicable)

**Settings** (gear icon in dropdown):
- **Menu bar style** — Bar + %, Bar only, or Text only
- **Refresh interval** — how often to poll Claude (1–30 minutes)
- **Notifications** — enable/disable and set warning (default 80%) and critical (default 90%) thresholds
- **Claude CLI path** — override auto-detection if needed

## Architecture

```
┌─────────────────────┐    forkpty() + /usage     ┌──────────────┐
│  SwiftUI Menu Bar   │ ───────────────────────→  │ claude CLI   │
│  App                │    parse TUI output        │ (ephemeral   │
│                     │ ←───────────────────────  │  PTY process) │
└─────────────────────┘                            └──────────────┘
```

- **UsagePoller** — spawns `claude` via `forkpty()`, types `/usage`, captures output, kills process
- **UsageParser** — strips ANSI escape codes and parses percentages/reset times from TUI output
- **UsageModel** — observable data model with polling timer, caching, and notification logic
- **BarRenderer** — renders the menu bar fill indicator as an `NSImage`

## Troubleshooting

**"Claude CLI not found"** — Make sure `claude` is installed and on your PATH. You can also set the path manually in Settings. Common locations: `~/.local/bin/claude`, `/usr/local/bin/claude`, `/opt/homebrew/bin/claude`.

**No data on first launch** — The first poll takes ~10 seconds (Claude CLI startup + /usage fetch). Subsequent launches show cached data immediately.

**Stale data** — Click "Refresh Now" in the dropdown to force a fresh poll.

## License

MIT
