import Foundation
import HousekeepCore

enum GitCommand {
    static func run(root: String, json: Bool) async {
        let report = await GitStatusScanner.scan(root: root)
        if json {
            JSONRenderer.render(report)
        } else {
            TableRenderer.renderGit(report)
        }
    }
}
