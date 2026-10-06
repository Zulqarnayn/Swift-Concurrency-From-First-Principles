import Dispatch
import Foundation

/// Label of the dispatch queue running the current code ("" if none / unlabeled).
/// Handy for checking "was my callback delivered on the queue I promised?"
public func currentQueueLabel() -> String {
    String(cString: __dispatch_queue_get_label(nil))
}

extension DispatchGroup {
    /// Await the group without blocking a thread.
    /// (`group.wait()` is unavailable in async code — it would block a cooperative-pool thread.)
    public func waitAsync() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            notify(queue: .global()) { cont.resume() }
        }
    }
}
