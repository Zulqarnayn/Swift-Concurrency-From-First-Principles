// P4.12 — SOLUTION (reasons in the lesson spoiler). Review: pick the right tool
// Lesson: lessons/P4-classics/12-review.md
// Test:   swift test --filter P4_12
//
// For each scenario, choose the ONE tool that fits best. Then read the spoiler in the lesson.

public enum Tool: Equatable, Sendable {
    case mutex             // a Mutex / lock around in-memory state, synchronous API
    case actor             // an actor owning the state, async API
    case mainActor         // @MainActor isolation
    case slidingWindow     // TaskGroup with at most N children in flight
    case asyncSemaphore    // a suspending semaphore shared by unrelated call sites
    case boundedChannel    // producer–consumer queue with backpressure
    case serialStream      // one consumer task reading an AsyncStream (ordered processing)
    case singleFlight      // share one in-flight Task between concurrent callers
    case debounce          // act after a quiet period; latest wins
    case throttle          // at most once per interval
    case tokenBucket       // rate limit with bursts
    case latch             // wait until N things have happened (one-shot)
    case retryBackoff      // try again later, increasingly patiently
    case unset
}

public enum P4_12 {
    /// 1. A view model's `items` array, read and written only by the UI.
    public static let s1: Tool = .mainActor
    /// 2. 300 thumbnails to download for one screen, at most 6 at a time.
    public static let s2: Tool = .slidingWindow
    /// 3. Uploads started from many unrelated screens must share a global limit of 3 at a time.
    public static let s3: Tool = .asyncSemaphore
    /// 4. A synchronous `func increment()` called from C callbacks on random threads, millions of times.
    public static let s4: Tool = .mutex
    /// 5. 20 requests get HTTP 401 at once; refresh the access token only once.
    public static let s5: Tool = .singleFlight
    /// 6. A search field: query the server only after the user stops typing for 300ms.
    public static let s6: Tool = .debounce
    /// 7. A "pull to refresh" that should hit the server at most once every 10 seconds.
    public static let s7: Tool = .throttle
    /// 8. A camera produces frames faster than the ML model can process them; memory must stay bounded
    ///    and the camera must slow down rather than drop frames.
    public static let s8: Tool = .boundedChannel
    /// 9. A chat socket delivers messages via a sync delegate; they must be saved in arrival order.
    public static let s9: Tool = .serialStream
    /// 10. The API allows bursts of 10 requests, then 2 per second.
    public static let s10: Tool = .tokenBucket
    /// 11. App launch must wait until config, auth and feature flags (3 independent loaders) have all reported in.
    public static let s11: Tool = .latch
    /// 12. A flaky endpoint returns 503 now and then.
    public static let s12: Tool = .retryBackoff
}
