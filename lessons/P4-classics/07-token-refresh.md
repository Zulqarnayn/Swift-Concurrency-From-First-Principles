# P4.07 — Single-flight: the token-refresh race ⭐⭐

<!-- nav:start -->
[← P4.06](./06-debounce-throttle.md) · [Roadmap](../../README.md) · [P4.08 →](./08-latch-barrier.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.07` · Exercise `P4_07`

Probably the most-asked real-world iOS concurrency question. It combines reentrancy, single-flight, error fan-out and stale-state checks.

## 1. Concept (5 min)

Your app wakes after a long break, and its access token is expired. The home screen fires 10 requests at once, and **all 10 get HTTP 401**. The naive client refreshes the token in each 401 handler:
1. **10 refresh calls.** The server may rate-limit you, or flag the account.
2. With **refresh-token rotation** (common for security), each refresh *invalidates* the previous token. Request 3's retry carries token #2, but the server has already issued #5, so it gets **401 again**. Users see random failures.

**Single-flight:** concurrent callers who need the same result share one execution of the work.
```swift
actor AuthClient {
    private var token: String
    private var refreshTask: Task<String, Error>?

    func send(path) async throws -> Response {
        let used = token                                   // which token did THIS request carry?
        do { return try await fetch(path, used) }
        catch is Unauthorized {
            let fresh = try await validToken(replacing: used)
            return try await fetch(path, fresh)            // retry once
        }
    }

    private func validToken(replacing stale: String) async throws -> String {
        if token != stale { return token }                 // ① a late 401: already refreshed
        if let t = refreshTask { return try await t.value } // ② join the refresh in flight
        let t = Task { try await server.refresh() }        // ③ start one, publish it BEFORE awaiting
        refreshTask = t
        defer { refreshTask = nil }                        // ④ success or failure, allow the next one
        token = try await t.value
        return token
    }
}
```
Each line has a reason:
- **①** Some 401s arrive *after* the refresh finished (slow requests). Comparing against the token *that request used* stops a second refresh.
- **②–③** This is P2.04's in-flight pattern: publish the Task before the first suspension point, so reentrant callers find it.
- **④** If the refresh fails, every joined caller gets the same error, and the *next* 401 may try again. Don't cache failures.

## 2. Predict (5 min)

Naive client: 10 concurrent requests with an expired token, and the server rotates tokens on refresh. How many refreshes? How many requests succeed? ______

## 3. Run (5 min)

```bash
swift run lab p4.07
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
10 concurrent requests with an expired token: 10 refreshes, 2/10 succeeded
```
Eight of ten requests failed **after** a "successful" refresh, because each refresh invalidated the token another request had just obtained. In production this looks like intermittent logouts after app resume. It's very hard to reproduce on a fast Wi-Fi network.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_07_TokenRefresh.swift`. Make `send` refresh exactly once for concurrent 401s, skip refreshing for late 401s, fan a refresh failure out to every waiter, and let the next call retry.

```bash
swift test --filter P4_07
```

## 6. Interview cards

- **Many requests get 401 at once. How do you refresh the token safely?** Put auth in an actor. Remember which token each request used. On 401: if the token has changed since, retry with the current one; if a refresh Task is in flight, await it; otherwise create one, store it before awaiting, clear it in `defer`. Retry the request once. Failures propagate to every waiter and aren't cached.
- **Why does refresh-token rotation make the naive approach fail?** Each refresh invalidates the previous token, so parallel refreshes keep invalidating each other's results and retries get 401 again.
- **What is single-flight?** Deduplicating concurrent requests for the same work into one execution whose result (or error) all callers share. In Swift: a dictionary or optional of in-flight `Task`s inside an actor.

---

<!-- nav:start -->
[← P4.06](./06-debounce-throttle.md) · [Roadmap](../../README.md) · [P4.08 →](./08-latch-barrier.md)
<!-- nav:end -->
