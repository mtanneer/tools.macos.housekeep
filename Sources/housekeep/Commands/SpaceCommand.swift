import Foundation
import HousekeepCore

enum SpaceCommand {
    static func run(root: String, clean: Bool, json: Bool) async {
        let report = await SpaceScanner.scan(root: root)

        if json {
            JSONRenderer.render(report)
        } else {
            TableRenderer.renderSpace(report, root: root)
        }

        guard clean else { return }
        print("")
        for finding in report.dirs {
            print("Move \(finding.path) (\(finding.sizeHuman)) to Trash? [y/N] ", terminator: "")
            guard let answer = readLine()?.lowercased(), answer == "y" || answer == "yes" else { continue }
            let outcomes = TrashDeleter.moveToTrash(paths: [finding.path])
            if let outcome = outcomes.first, outcome.succeeded {
                print("moved \(finding.path) to Trash")
            } else {
                print("failed to move \(finding.path): \(outcomes.first?.error ?? "unknown error")")
            }
        }
    }
}
