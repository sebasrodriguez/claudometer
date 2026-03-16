# Changelog

All notable changes to Claudometer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-16

### Added

- Menu bar indicator with session usage fill bar and percentage
- Dropdown with session, weekly (all models), and Sonnet usage progress bars
- Reset time display for session and weekly limits
- Auto-refresh polling on configurable interval (1–30 min, default 5 min)
- macOS notifications at configurable warning (80%) and critical (90%) thresholds
- Cached usage data in UserDefaults for instant display on launch
- Settings window with display mode, polling interval, notification thresholds, and Claude CLI path override
- PTY-based Claude CLI polling via `forkpty()` — no external dependencies
- ANSI-tolerant parser for Claude's TUI `/usage` output
- Three display modes: Bar + %, Bar only, Text only
- Auto-detection of Claude binary from common install locations

[0.1.0]: https://github.com/sebasrodriguez/claudometer/releases/tag/v0.1.0
