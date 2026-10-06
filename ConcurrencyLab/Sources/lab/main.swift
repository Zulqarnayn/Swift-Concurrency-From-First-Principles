import Demos
import Foundation
import LabKit

// Usage:
//   swift run lab list          show all demos
//   swift run lab p1.01         run demo p1.01 and its sub-demos (p1.01b, ...) except opt-in ones
//   swift run lab p0.05c        run exactly one demo (needed for opt-in crash/deadlock demos)

let args = Array(CommandLine.arguments.dropFirst())

guard let query = args.first, query != "list" else {
    print("Demos (★ = opt-in: crashes or hangs on purpose, run by exact id)\n")
    for demo in DemoRegistry.all {
        print("  \(demo.id.padding(toLength: 8, withPad: " ", startingAt: 0)) \(demo.optIn ? "★" : " ") \(demo.title)")
    }
    exit(0)
}

let exact = DemoRegistry.all.filter { $0.id == query }
let selected = exact.isEmpty == false && exact.first!.optIn
    ? exact
    : DemoRegistry.all.filter { $0.id.hasPrefix(query) && !$0.optIn }

if selected.isEmpty {
    print("No demo matches '\(query)'. Try: swift run lab list")
    exit(1)
}

for demo in selected {
    print("\n━━━ \(demo.id) — \(demo.title) ━━━")
    Trace.reset()
    do {
        try await demo.body()
    } catch {
        print("demo threw: \(error)")
    }
}
exit(0)
