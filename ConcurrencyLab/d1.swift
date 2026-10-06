import Foundation
func racyGlobalQueue() {
    var count = 0
    for _ in 0..<4 {
        DispatchQueue.global().async { count += 1 }
    }
    print(count)
}
func racyConcurrentPerform() -> Int {
    var count = 0
    DispatchQueue.concurrentPerform(iterations: 4) { _ in count += 1 }
    return count
}
func asyncFromSync() { let _ = await fetch() }
func fetch() async -> Int { 1 }
func semInAsync() async {
    let s = DispatchSemaphore(value: 0)
    s.wait()
    let g = DispatchGroup(); g.wait()
    _ = Thread.current
    Thread.sleep(forTimeInterval: 1)
}
