import Foundation
import HousekeepCore

/// Replicates bash's exact `for arg in "$@"` classification loop (lines 26-34 of the original
/// script) rather than trusting ArgumentParser's positional-argument ordering to coincidentally
/// match undocumented bash flag-ordering flexibility.
struct ParsedArgs {
    enum Command: String {
        case space, security, git, fix, all
    }

    var command: Command = .all
    var root: String = "."
    var clean = false
    var json = false
    var showHelp = false
}

func parseArgs(_ args: [String]) -> ParsedArgs {
    var parsed = ParsedArgs()
    for arg in args {
        switch arg {
        case "space": parsed.command = .space
        case "security": parsed.command = .security
        case "git": parsed.command = .git
        case "fix": parsed.command = .fix
        case "--clean": parsed.clean = true
        case "--json": parsed.json = true
        case "-h", "--help": parsed.showHelp = true
        default: parsed.root = arg
        }
    }
    return parsed
}

let usage = """
usage: housekeep [space|security|git|fix] [path] [--clean] [--json]

  housekeep [path]                 run all three checks (default path: .)
  housekeep space [path] [--clean] reclaimable cache/build dirs (--clean moves to Trash)
  housekeep security [path]        gitleaks + osv-scanner across git projects
  housekeep git [path]             uncommitted/unpushed/no-remote status
  housekeep fix [path]             interactive: walk every finding, choose an action per item

  --json   emit structured JSON instead of a table (any subcommand)
"""

let args = parseArgs(Array(CommandLine.arguments.dropFirst()))

if args.showHelp {
    print(usage)
    exit(0)
}

guard FileManager.default.fileExists(atPath: args.root) else {
    FileHandle.standardError.write("housekeep: no such directory: \(args.root)\n".data(using: .utf8)!)
    exit(1)
}
let root = URL(fileURLWithPath: args.root).standardizedFileURL.path

await Runner.run(args: args, root: root)
