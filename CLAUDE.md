# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`housekeep` audits a dev folder tree (default: `.`) for reclaimable disk space, leaked secrets/vulnerable deps, and git hygiene (uncommitted/unpushed/no-remote repos). Originally a bash script (retired once parity was proven), now a Swift package with a shared core library, a CLI executable, and (in progress) a native macOS GUI — all consuming the same scanning logic so behavior never drifts between the two.

A native SwiftUI GUI is being layered on top, modeled on `/Users/mtanneer/dev/purge-app`'s UX patterns (sidebar+detail layout, destructive-action confirmation flow, honest empty/loading states) — see `.claude/plans/golden-soaring-willow.md` in this session's plan history for the full design rationale, decisions, and sequencing.

## Building & testing

```
swift build                  # debug build of HousekeepCore + housekeep CLI
swift build -c release       # release build (used for real-world parity checks)
swift test                   # runs all HousekeepCoreTests (unit + ProcessRunner regressions + bash parity)
swift test --filter <Suite>  # e.g. --filter ProcessRunnerTests, --filter BashParityTests
```

The GUI app target is built via `xcodegen generate && xcodebuild -scheme Housekeep` once `project.yml`/`HousekeepApp/` exist (see plan doc) — SPM alone cannot produce a signed `.app` bundle.

## Running the CLI

```
.build/debug/housekeep [space|security|git|fix] [path] [--clean] [--json]
```

Same command surface as the original bash script (verified via `BashParityTests`):
- `space` — finds cache/build dirs (node_modules, .venv, venv, __pycache__, .next, dist, build, target, .gradle, DerivedData, .turbo) up to 4 dirs deep, sorted by size. `--clean` prompts per-dir, then **moves to Trash** (not `rm -rf` — a deliberate behavior change from the bash original).
- `security` — runs `gitleaks` + `osv-scanner` against every git repo found (requires both installed via `brew install gitleaks osv-scanner`; degrades gracefully if only one is present). `security --json` now actually emits JSON — the bash script silently never did despite accepting the flag.
- `git` — reports dirty/branch/upstream/unpushed-commit status per repo.
- `fix` — interactive CLI-only walk through every finding (space/git/security in that order), prompting an action per item (Trash, commit, push, gitignore-and-untrack, open in `$EDITOR`, skip). The GUI's per-tab UIs (multi-select+Trash, commit/push sheet, security remediation view) are the GUI's answer to this flow, not a literal port.
- No subcommand runs all three read-only checks (`space`, `security`, `git`) in sequence.
- `--json` emits structured JSON instead of a table; works with every subcommand including the default `all` path.

## Architecture

- `Sources/HousekeepCore/` — the single source of truth, consumed by both the CLI and (eventually) the GUI. Key types: `ProcessRunner` (subprocess wrapper, ported from purge-app — fixes three real deadlock/hang classes, see its doc comment), `SpaceScanner`, `SecurityScanner`/`SecurityRemediation`, `SecurityToolDetector`, `GitStatusScanner`/`GitActions`, `TrashDeleter`, `GitRepoFinder` (shared `.git` discovery, dedupes what was three near-identical `find` loops in bash), and `Models/` (Codable report types that produce both CLI JSON and, later, GUI-bound state).
- `Sources/housekeep/` — CLI executable. `main.swift` has a small hand-rolled arg pre-parser (not full ArgumentParser subcommand dispatch) that replicates bash's exact `for arg in "$@"` classification loop, since the original script tolerated any argument order. `Commands/` dispatch to `HousekeepCore`; `Rendering/` matches the bash script's table column widths and JSON field names exactly.
- `Tests/HousekeepCoreTests/` — `FixtureTree.swift` builds a throwaway dev-tree (fake `node_modules`, a real git repo with one commit + one dirty file) at test-run time rather than shipping a committed fixture, since a `.git` directory doesn't round-trip cleanly through SPM resource copying. `ParityTests/BashParityTests.swift` is the parity gate — it shells out to the archived bash script and diffs its JSON against the Swift core's, semantically (decoded and compared as data, not byte-for-byte).
- JSON field names are pinned via `CodingKeys` to match the original bash output exactly (`total_kb`/`dirs`/`path`/`size`/`kb` for space; `repos`/`path`/`dirty`/`branch`/`upstream`/`unpushed` for git) — anyone scripting against `housekeep --json` today shouldn't see a break.
- Gitleaks report parsing decodes JSON natively via `Codable` (`GitleaksFinding`) instead of bash's `python3 -c` shellout — removes a system-Python dependency.
