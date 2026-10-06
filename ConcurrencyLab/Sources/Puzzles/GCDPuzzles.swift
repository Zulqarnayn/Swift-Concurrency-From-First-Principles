import Dispatch
import LabKit

// P0.08 — "What does this print?" Classic GCD interview questions.
// Read each puzzle, write your prediction in Exercises/P0_08_Predictions.swift, then:
//     swift test --filter P0_08      (checks your predictions)
//     swift run lab p0.08            (shows the real answers)
//
// A private serial queue named "ui" stands in for the main queue, so the tests can run anywhere.
// Every puzzle is deterministic: same answer every run.

public enum GCDPuzzles {
    public static let all: [(String, @Sendable () -> [String])] = [
        ("puzzle1", puzzle1), ("puzzle2", puzzle2), ("puzzle3", puzzle3),
        ("puzzle4", puzzle4), ("puzzle5", puzzle5),
    ]

    /// Puzzle 1 — async onto the queue you're already on.
    public static func puzzle1() -> [String] {
        let log = EventLog()
        let ui = DispatchQueue(label: "ui")
        ui.sync {
            log.add("1")
            ui.async { log.add("2") }
            log.add("3")
        }
        ui.sync {} // wait for the queue to drain
        return log.all
    }

    /// Puzzle 2 — async then sync onto the same serial queue, from outside it.
    public static func puzzle2() -> [String] {
        let log = EventLog()
        let q = DispatchQueue(label: "serial")
        log.add("A")
        q.async {
            blockThread(ms: 20)
            log.add("B")
        }
        q.sync { log.add("C") }
        log.add("D")
        return log.all
    }

    /// Puzzle 3 — barrier on a concurrent queue.
    public static func puzzle3() -> [String] {
        let log = EventLog()
        let q = DispatchQueue(label: "concurrent", attributes: .concurrent)
        q.async {
            blockThread(ms: 30)
            log.add("slow read")
        }
        q.async(flags: .barrier) { log.add("write") }
        q.async { log.add("read after write") }
        q.sync(flags: .barrier) {} // wait for everything above
        return log.all
    }

    /// Puzzle 4 — DispatchGroup.notify does not block.
    public static func puzzle4() -> [String] {
        let log = EventLog()
        let ui = DispatchQueue(label: "ui")
        let group = DispatchGroup()
        let done = DispatchSemaphore(value: 0)

        group.enter()
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(60)) {
            log.add("A")
            group.leave()
        }
        group.enter()
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(10)) {
            log.add("B")
            group.leave()
        }
        group.notify(queue: ui) {
            log.add("notify")
            done.signal()
        }
        log.add("after notify()")
        done.wait()
        return log.all
    }

    /// Puzzle 5 — does QoS reorder a serial queue?
    public static func puzzle5() -> [String] {
        let log = EventLog()
        let q = DispatchQueue(label: "serial")
        q.async(qos: .background) { log.add("background") }
        q.async(qos: .userInteractive) { log.add("userInteractive") }
        q.sync {}
        return log.all
    }
}
