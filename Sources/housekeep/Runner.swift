import Foundation
import HousekeepCore

enum Runner {
    static func run(args: ParsedArgs, root: String) async {
        switch args.command {
        case .space:
            await SpaceCommand.run(root: root, clean: args.clean, json: args.json)
        case .security:
            await SecurityCommand.run(root: root, json: args.json)
        case .git:
            await GitCommand.run(root: root, json: args.json)
        case .fix:
            await FixCommand.run(root: root)
        case .all:
            await runAll(root: root, json: args.json)
        }
    }

    private static func runAll(root: String, json: Bool) async {
        let availability = SecurityToolDetector.check()
        async let space = SpaceScanner.scan(root: root)
        async let security = SecurityScanner.scan(root: root, availability: availability)
        async let git = GitStatusScanner.scan(root: root)

        let report = await HousekeepReport(space: space, security: security, git: git)

        if json {
            JSONRenderer.render(report)
        } else {
            TableRenderer.renderSpace(report.space, root: root)
            print("")
            TableRenderer.renderSecurity(report.security)
            print("")
            TableRenderer.renderGit(report.git)
        }
    }
}
