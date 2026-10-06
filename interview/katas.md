# Timed katas (P7, but try any time)

Interview-style live-coding problems. **25 minutes each**, with no docs for the first 15. Graded versions:

| Kata | Graded as |
|---|---|
| K1 image loader | P4.10 `ImagePipeline` |
| K2 token refresh | P4.07 `AuthClient` |
| K3 debounced search | P4.06 `DebouncedSearch` |
| K4 parallel fetch + deadline | **P7.03** `fetchAll` |
| K5 async semaphore | P4.04 `AsyncSemaphore` |
| K6 rate limiter | P4.05 `TokenBucket` |
| K7 retry with backoff | P4.11 `retry` |
| K8 AsyncStream from delegate | P5.04 + P5.09 |
| K9 ordered pipeline | **P7.04** `mapOrdered` |
| K10 observable async value | **P7.05** `AsyncValue` |

To redo a kata later: move your implementation into a scratch file, reduce the function body to a placeholder, and start the timer again. The tests are your interviewer.

Grading rubric (what interviewers look for):
1. **Correct under concurrency.** No data races (Swift 6 compiles it), no race conditions (state re-checked after `await`).
2. **Cancellation.** Stops promptly; doesn't swallow `CancellationError`.
3. **Structured** where possible; unstructured tasks justified and their lifetime owned.
4. **Bounded** resources: no unbounded fan-out or buffers.
5. **Explains trade-offs** out loud.

---

### K1 · Image loader with cache + request dedupe
`actor ImageLoader { func image(for url: URL) async throws -> Image }`
- Cache results in memory.
- 10 simultaneous calls for the same URL → **one** network request, 10 results.
- A failure isn't cached; the next call retries.
- *Trap:* actor reentrancy. Check the cache, `await` the download, and another caller has already started the same download.

### K2 · Token refresh single-flight
`actor AuthClient { func validToken() async throws -> String }`
- If the token is expired, refresh it. While a refresh is in flight, every caller awaits **that same** refresh.
- If the refresh fails, every waiter gets the error; the next call tries again.

### K3 · Debounced search
`@MainActor final class SearchModel { var query: String; var results: [Item] }`
- Search 300 ms after the user stops typing.
- A newer query cancels the older in-flight request; stale results must **never** overwrite newer ones.

### K4 · Parallel fetch with timeout and partial results
`func fetchAll(_ ids: [Int], timeout: Duration) async -> [Int: Result<Item, Error>]`
- Run all requests concurrently (at most 6 in flight).
- At the timeout, cancel the remaining ones and return what you have.

### K5 · Async semaphore
`actor AsyncSemaphore { init(value: Int); func wait() async; func signal() }`
- `wait()` suspends (never blocks a thread) when no permits are left. FIFO wake-up.
- Bonus: cancellation-aware `wait()`, so a cancelled waiter leaves the queue.

### K6 · Rate limiter
At most N calls per rolling second; extra callers suspend until allowed. Must work with 1000 concurrent callers.

### K7 · Retry with exponential backoff
`func retry<T>(max: Int, initialDelay: Duration, _ op: () async throws -> T) async throws -> T`
- Jitter. Doesn't retry `CancellationError`. Cancelling the caller during the backoff sleep stops immediately.

### K8 · AsyncStream from a delegate
Wrap a `CLLocationManager`-style delegate in `AsyncStream<Location>`.
- Start on first iteration, stop on termination.
- Only one consumer allowed. What do you do about a second one?

### K9 · Ordered event pipeline
Sync callbacks arrive in order. Process them with async work, **in order**, and report the number processed. Then make it concurrent with in-order *completion* (sequence numbers).
