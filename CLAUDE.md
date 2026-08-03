# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`housekeep` audits a dev folder tree (default: `.`) for reclaimable disk space, leaked secrets/vulnerable deps, and git hygiene (uncommitted/unpushed/no-remote repos). Originally a bash script, now a Swift package: a shared core library (`HousekeepCore`), a CLI executable (`housekeep`), and a native macOS SwiftUI GUI (`Housekeep.app`) — all three consuming the same scanning/deletion logic so behavior never drifts between CLI and GUI.

The GUI's UX was modeled on `/Users/mtanneer/dev/purge-app` (sidebar+detail layout, destructive-action confirmation flow, honest empty/loading states, Trash-not-delete philosophy) — see `.claude/plans/golden-soaring-willow.md` for the full original design rationale and the decisions locked in with the user (bundle ID, signing approach, scope boundaries vs. purge, etc).

## History (for context on why things look the way they do)

1. **Bash → Swift rewrite.** The original `housekeep` was a single 319-line bash script. It was fully ported to Swift, verified byte-for-byte identical against the real `~/dev` tree (43 repos, 33 cache dirs, ~3GB) via a temporary `BashParityTests` suite, then the bash script was deleted and the parity tests removed (their job — gating the deletion — was done; they'd have failed forever afterward since there's nothing left to diff against).
2. **GUI scaffold added.** `project.yml` (xcodegen) + `HousekeepApp/` SwiftUI sources, consuming `HousekeepCore` as a local SPM package dependency.
3. **Crash fix.** `GitActions.commit`/`.push` and `SecurityToolDetector`'s tool lookup were calling the blocking `ProcessRunner.run` directly from the main actor (GUI button taps, `@MainActor` store) — tripped `ProcessRunner`'s own `notOnQueue(.main)` debug guardrail and crashed with `EXC_BREAKPOINT`. Fixed by making `GitActions` fully async (backed by `ProcessRunner.runAsync`) and adding `SecurityToolDetector.checkAsync()`.
4. **Security tool detection fix.** The GUI showed "gitleaks not found" even after `brew install gitleaks osv-scanner` succeeded, because GUI apps launch via Finder/launchd with a minimal `PATH` that excludes Homebrew's install dirs (unlike a login shell's `PATH`) — the original `which`-subprocess lookup silently failed. Replaced with direct `FileManager.isExecutableFile` checks against `$PATH` plus `/opt/homebrew/bin` and `/usr/local/bin` explicitly. No subprocess involved anymore.

At this point: CLI and GUI both build and run correctly, all 18 `swift test` cases pass, and the app has been manually smoke-tested (onboarding → scan → tabs load, security tab correctly detects installed tools).

## Known gap: GUI needs a UX pass

The GUI scaffold is functionally correct but was built to "get it working," not polished. Before this is something to actually use day-to-day, revisit:

- **Onboarding is bare-bones.** Welcome/pick-root/first-scan/results/celebration steps exist but have placeholder copy and no real visual design pass — feels like a wireframe, not a finished flow.
- **No visual identity.** No app icon (empty `AppIcon.appiconset`), default SF Symbols everywhere, no real color/typography decisions beyond `AppColors.swift`'s stub semantic tokens.
- **Sidebar/detail layout is functional but plain.** Compare against purge-app's actual polish level (card shadows, spacing rhythm, hover states) — this was deliberately simplified for v1 scope but is rougher than intended as a final look.
- **Empty/loading states are minimal.** `SkeletonList`/`EmptyStateView` exist but are generic placeholders, not tuned per-tab.
- **No error surfacing for scan failures.** If a scan silently returns empty (e.g. permissions issue, git not installed), the UI can't currently distinguish that from "genuinely nothing found."
- **Security tab detail view is a flat list.** No per-finding remediation actions wired up yet in the GUI (the CLI's `fix` command has this via `SecurityRemediation`; the GUI's "security remediation view" from the original plan was never actually built — only the missing-tools banner was).
- **Git commit/push sheet has no loading state.** Buttons don't disable/spin during the async git call, so a slow push looks unresponsive.
- **Settings is a stub.** Appearance picker exists but isn't wired to actually restyle the running app; Excluded Paths section has no add/remove UI, just a static empty-state label.
- **No keyboard shortcut discoverability** beyond ⌘1-3 tab switching and ⇧⌘R — no menu items showing them, no help.

Worth deciding next session: whether to do a focused design pass (spend a session just on visual polish + the missing security remediation view) or keep shipping functional gaps and defer polish further. Either way, the functional core (`HousekeepCore`) is solid — this is purely presentation-layer work.

## Building & testing

```
swift build                  # debug build of HousekeepCore + housekeep CLI
swift build -c release       # release build (used for real-world parity checks)
swift test                   # runs all HousekeepCoreTests (unit + ProcessRunner regressions)
swift test --filter <Suite>  # e.g. --filter ProcessRunnerTests, --filter SpaceScannerTests
```

GUI: `xcodegen generate && xcodebuild -project Housekeep.xcodeproj -scheme Housekeep -configuration Debug build`, or just open `Housekeep.xcodeproj` in Xcode and hit ⌘R. `Housekeep.xcodeproj` is gitignored (regenerated from `project.yml`) — always run `xcodegen generate` after pulling if `project.yml` changed.

Debug builds use automatic ad-hoc signing (no team ID needed to run locally). Release builds need a real Developer ID team ID in `Config/Signing.xcconfig` (gitignored; copy from `Config/Signing.xcconfig.example`).

## Running the CLI

```
.build/debug/housekeep [space|security|git|fix] [path] [--clean] [--json]
```

- `space` — finds cache/build dirs (node_modules, .venv, venv, __pycache__, .next, dist, build, target, .gradle, DerivedData, .turbo) up to 4 dirs deep, sorted by size. `--clean` prompts per-dir, then **moves to Trash** (not `rm -rf` — a deliberate behavior change from the original bash script).
- `security` — runs `gitleaks` + `osv-scanner` against every git repo found (requires both installed via `brew install gitleaks osv-scanner`; degrades gracefully if only one is present). `security --json` emits real structured JSON (the bash original silently never did despite accepting the flag).
- `git` — reports dirty/branch/upstream/unpushed-commit status per repo.
- `fix` — interactive CLI-only walk through every finding (space/git/security in that order), prompting an action per item (Trash, commit, push, gitignore-and-untrack, open in `$EDITOR`, skip). The GUI's per-tab UIs are the GUI's answer to this flow, not a literal port (though see the security-remediation gap above — that answer is currently incomplete).
- No subcommand runs all three read-only checks (`space`, `security`, `git`) in sequence.
- `--json` emits structured JSON instead of a table; works with every subcommand including the default `all` path.

## Architecture

- `Sources/HousekeepCore/` — the single source of truth, consumed by both CLI and GUI. Key types: `ProcessRunner` (subprocess wrapper, ported from purge-app — fixes three real deadlock/hang classes, see its doc comment; always call `runAsync`, never blocking `run`, from anything that might run on the main actor), `SpaceScanner`, `SecurityScanner`/`SecurityRemediation`, `SecurityToolDetector` (filesystem-based tool detection, not subprocess-based — see history above for why), `GitStatusScanner`/`GitActions` (fully async), `TrashDeleter`, `GitRepoFinder` (shared `.git` discovery), and `Models/` (Codable report types that produce both CLI JSON and GUI-bound state).
- `Sources/housekeep/` — CLI executable. `main.swift` has a small hand-rolled arg pre-parser (not full ArgumentParser subcommand dispatch) that replicates the original bash's exact `for arg in "$@"` classification loop, since it tolerated any argument order. `Commands/` dispatch to `HousekeepCore`; `Rendering/` matches the original bash table column widths and JSON field names exactly.
- `HousekeepApp/` — GUI sources (not under `Sources/` — xcodegen's `project.yml` references this directly, SPM doesn't see it). `HousekeepStore` is the central `@MainActor` `ObservableObject` (mirrors purge-app's `PurgeStore`). `Views/` has the 3 tabs (Space/Security/Git), `DeletionConfirmSheet` (Trash confirmation with git-dirty-nearby warning), `GitCommitPushSheet`, `SecurityToolsMissingBanner`, `SettingsView`, and `Views/Onboarding/`.
- `Tests/HousekeepCoreTests/` — `FixtureTree.swift` builds a throwaway dev-tree (fake `node_modules`, a real git repo with one commit + one dirty file) at test-run time rather than shipping a committed fixture, since a `.git` directory doesn't round-trip cleanly through SPM resource copying.
- JSON field names are pinned via `CodingKeys` to match the original bash output exactly (`total_kb`/`dirs`/`path`/`size`/`kb` for space; `repos`/`path`/`dirty`/`branch`/`upstream`/`unpushed` for git) — anyone scripting against `housekeep --json` shouldn't see a break.
- Gitleaks report parsing decodes JSON natively via `Codable` (`GitleaksFinding`) instead of shelling to `python3 -c` — removes a system-Python dependency.

## Known pending work

- **GitHub issue #1**: Homebrew formula + cask + CI setup — blocked on cutting a real tagged release first.
- **GUI UX pass** — see section above.
