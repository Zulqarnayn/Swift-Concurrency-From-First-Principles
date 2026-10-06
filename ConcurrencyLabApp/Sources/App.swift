import LabKit
import SwiftUI

@main
struct ConcurrencyLabApp: App {
    var body: some Scene {
        WindowGroup {
            // `-autorun <step>` (e.g. `-autorun concurrent`) opens a step and runs it once. Handy from the CLI:
            //   xcrun simctl launch --console-pty booted dev.learning.concurrency.lab -autorun concurrent
            if Self.autorunArgument == "lifecycle" {
                NavigationStack { LifecycleLab(autorun: true) }
            } else if Self.autorunArgument == "search" {
                NavigationStack { SearchLab(autorun: true) }
            } else if Self.autorunArgument == "grid" {
                NavigationStack { ImageGridLab(autorun: true) }
            } else if Self.autorunArgument == "feed" {
                NavigationStack { FeedLab(autorun: true) }
            } else if Self.autorunArgument == "export" {
                NavigationStack { ExportLab(autorun: true) }
            } else if let step = Self.autorunStep {
                NavigationStack { RobotLab(step: step, autorun: true) }
            } else {
                LabListView()
            }
        }
    }
}

extension ConcurrencyLabApp {
    static var autorunArgument: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-autorun"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var autorunStep: RobotStep? {
        autorunArgument.flatMap(RobotStep.init(rawValue:))
    }
}

struct LabListView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(RobotStep.allCases) { step in
                        NavigationLink(step.title) { RobotLab(step: step) }
                    }
                } header: {
                    Text("P2.01 — A network request, step by step")
                } footer: {
                    Text("Lesson: lessons/P2-isolation/01-network-request-lab.md")
                }

                Section("P3.07 — Task lifecycle") {
                    NavigationLink(".task vs onAppear { Task {} } vs .task(id:)") { LifecycleLab() }
                }

                Section("P4 — Classic problems in an app") {
                    NavigationLink("P4.06 · Debounced search") { SearchLab() }
                    NavigationLink("P4.10 · Image pipeline grid") { ImageGridLab() }
                }

                Section("P5 — Bug Zoo in an app") {
                    NavigationLink("P5.03 · Pagination: duplicates + stale pages") { FeedLab() }
                    NavigationLink("P5.08 · Main-thread hang (+ Instruments)") { ExportLab() }
                }
            }
            .navigationTitle("Concurrency Lab")
        }
    }
}
