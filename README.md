# GitHub Sessions

A lightweight macOS menu-bar app that scans your local git repos and surfaces **pending push work** — staged changes, modified files, untracked files, and unpushed commits.

Built for solo developers with many repos under `~/Github` who want a fast triage list without GitHub auth, PRs, or worktree management.

## Features

- **Pending-only filter** — lists repos with local work waiting to push; ignores repos that are only behind remote
- **Depth-1 scan** — immediate children of your scan root (default `~/Github`)
- **Sorted by activity** — most recently touched repos first, with relative timestamps (`2h ago`)
- **Incremental cache** — fingerprints each repo on disk and skips `git status` when nothing changed
- **Menu bar** — pending count + quick-access dropdown (top 12 repos)
- **Expandable rows** — click a repo for full `git status`; open in iTerm, Finder, or copy path from the context menu
- **Background refresh** — auto-rescans every 60 seconds

## Requirements

- macOS 14.0+
- Xcode 15+ (Swift 6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) for project generation

## Build & run

```bash
# Generate Xcode project (when project.yml changes)
xcodegen generate

# Debug build
xcodebuild -scheme GitHubSessions -configuration Debug -destination 'platform=macOS' build

# Or open in Xcode
open GitHubSessions.xcodeproj
```

## Release DMG

```bash
make          # Release build + dist/GitHubSessions-<version>.dmg
make build    # Release .app only
make clean    # remove build/ and dist/
```

Optional code signing:

```bash
make dmg CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

## Settings

Open **Settings** from the app menu (⌘,):

| Setting | Description |
|---------|-------------|
| Scan path | Root folder to scan (default `~/Github`) |
| Menu bar icon | Show pending count in the menu bar |
| Hide dock icon | Run as menu-bar-only (accessory app) |

Manual refresh (↻ button or menu bar **Refresh**) forces a full rescan of every repo. Auto-refresh uses the cache.

On launch, cached pending repos appear immediately while a background incremental scan runs (max 12 concurrent `git` processes).

## Scan cache

Cache lives at:

```
~/Library/Application Support/GitHubSessions/scan-cache/
```

Each repo is fingerprinted using mtimes on `.git/HEAD`, `.git/index`, `.git/logs/HEAD`, `.git/FETCH_HEAD`, and the repo root. If the fingerprint matches the last scan, cached status is reused — no `git` subprocess.

## Project layout

```
Sources/
  Models/          GitRepoStatus, fingerprints, cache types
  Services/        Scanner, store, cache persistence
  MenuBar/         Status item + dropdown
  Views/           Main list, settings, row/detail views
  Utilities/       Git subprocess runner, iTerm launcher
Resources/         App icon + menu bar icon assets
Tests/             Scanner and cache unit tests
project.yml        XcodeGen spec
Makefile           Release DMG packaging
```

