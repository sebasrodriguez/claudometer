# TokenTap

Multi-provider macOS menu bar app that monitors your AI session usage in real-time. Supports Claude Code and OpenAI Codex, with more providers coming.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

<p align="center">
  <img src="assets/screenshot.png" alt="TokenTap dropdown showing Claude and Codex usage" width="320">
</p>

## How it works

TokenTap polls your AI provider usage in the background and displays it in your macOS menu bar. Each provider uses its own strategy:

- **Claude Code** — calls the Anthropic OAuth usage API (`api.anthropic.com/api/oauth/usage`) using the token from macOS Keychain
- **OpenAI Codex** — makes a minimal API call to the Codex backend and reads rate limit data from response headers

Lightweight HTTP requests — no CLI processes spawned, no terminal parsing. The menu bar auto-rotates between providers, and clicking shows the full breakdown for all of them.

## Features

- **Multi-provider** — track Claude Code and OpenAI Codex usage simultaneously
- **Menu bar indicator** — fill bar + percentage for the active provider
- **Auto-rotation** — cycles between providers in the menu bar (configurable: 10/20/30s)
- **Detailed dropdown** — click to see all providers with their usage tiers, progress bars, and reset times
- **Auto-refresh** — polls each provider on a configurable interval (1–30 min, default 5 min)
- **Cached data** — last known usage loads instantly on launch
- **Notifications** — macOS alerts when usage crosses configurable thresholds
- **Configurable** — display mode, rotation speed, refresh interval, thresholds, CLI paths
- **Zero dependencies** — native SwiftUI app, no external libraries
- **Pluggable architecture** — adding a new provider is one file + one enum case

## Supported Providers

| Provider | Method | What it tracks |
|----------|--------|----------------|
| Claude Code | Anthropic OAuth usage API | Session %, Weekly %, Sonnet %, Opus %, reset times |
| OpenAI Codex | Codex backend API response headers | 5h session %, Weekly %, reset times |

## Requirements

- macOS 14.0+
- At least one supported tool installed and authenticated:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — must be logged in (token stored in macOS Keychain)
  - [OpenAI Codex](https://github.com/openai/codex) — must be logged in (`~/.codex/auth.json`)
- Xcode or Swift toolchain (to build from source)

## Install

### Homebrew (recommended)

```bash
brew tap sebasrodriguez/tap
brew install tokentap
```

Then launch:

```bash
open $(brew --prefix)/opt/tokentap/TokenTap.app
```

Optionally link to Applications:

```bash
ln -sf $(brew --prefix)/opt/tokentap/TokenTap.app /Applications/TokenTap.app
```

### Build from source

```bash
git clone https://github.com/sebasrodriguez/tokentap.git
cd tokentap/TokenTap
make install
open TokenTap.app
```

## Usage

Once launched, TokenTap appears in your menu bar with a fill bar and provider usage (e.g. `CL 34%`). With multiple providers, it auto-rotates between them.

**Click** the menu bar item to see all providers:
- **Claude** — Session, Weekly (all models), and Sonnet usage with progress bars and reset times
- **Codex** — 5h session limit and weekly limit with reset times

**Settings** (gear icon in dropdown):
- **General** — menu bar style, rotation speed, notification thresholds
- **Claude** — refresh interval, CLI binary path
- **Codex** — refresh interval

## Architecture

```
    ProviderManager (SwiftUI MenuBarExtra)
    │
    ├── ProviderState (Claude)
    │   └── ClaudeProvider
    │       ├── ClaudePoller  — GET api.anthropic.com/api/oauth/usage (Keychain token)
    │       └── ClaudeParser  — maps JSON { five_hour, seven_day, ... } → UsageTiers
    │
    └── ProviderState (Codex)
        └── CodexProvider
            ├── CodexPoller   — POST chatgpt.com/backend-api/codex/responses (~/.codex/auth.json)
            └── CodexParser   — reads x-codex-*-used-percent response headers
```

Adding a new provider requires:
1. A `*Provider.swift` implementing the `UsageProvider` protocol
2. A `*Poller.swift` to fetch usage data (API call, scraping, etc.)
3. A `*Parser.swift` to convert the response into `[UsageTier]`
4. One case added to `ProviderKind`

## Troubleshooting

**No Claude data** — Make sure Claude Code is installed and logged in. TokenTap reads the OAuth token from macOS Keychain (`Claude Code-credentials`). Try `claude /usage` to verify your login works.

**No Codex data** — Make sure Codex CLI is installed and logged in (`codex login`). TokenTap reads the auth token from `~/.codex/auth.json`.

**No data on first launch** — The first poll takes a few seconds. Subsequent launches show cached data immediately.

**Stale data** — Click "Refresh All" in the dropdown to force a fresh poll.

## License

MIT
