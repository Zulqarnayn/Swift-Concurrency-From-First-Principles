# P7.06 — iOS system design: the networking layer

<!-- nav:start -->
[← P7.05](./05-kata-async-value.md) · [Roadmap](../../ROADMAP.md) · [P7.07 →](./07-design-offline-sync.md)
<!-- nav:end -->

⏱ 30 min: 20 min designing out loud / on paper + 10 min comparing with the model answer

## The prompt (classic senior iOS design round)

> "Design the networking layer for a large app: REST + auth (access/refresh tokens), retries, request deduplication, cancellation tied to screens, offline handling, and a way to test it all. Use modern Swift concurrency."

## How to run the session

1. Set a 20-minute timer. Talk through it out loud: an interviewer grades your *reasoning* and trade-offs.
2. Use the structure below. Spend at most 2 minutes on each heading, then go deeper where you're strong.
3. Then open the model answer and score yourself with the rubric.

**Structure:** requirements → API surface → components and their isolation → the key flows (normal request, 401, offline, cancel) → concurrency hazards → testing → trade-offs.

## Rubric (score each 0–2)

| Area | 2 points looks like |
|---|---|
| Isolation choices | Says *what* each component is (actor / `@MainActor` / nonisolated `Sendable` struct) and *why* |
| Auth | Single-flight refresh, the stale-401 check, failure fan-out (P4.07) |
| Cancellation | Tied to `.task` / view lifetime; `withTaskCancellationHandler` for legacy; never retry `CancellationError` |
| Retries | Backoff + jitter, idempotency, Retry-After (P4.11) |
| Dedupe / caching | In-flight GET dedupe (P2.04); HTTP caching versus app-level caches |
| Limits | Per-host concurrency limit (async semaphore, P4.04) and/or rate limiting (P4.05) |
| Main thread | Decoding off main (`@concurrent`); only results cross to the UI (P5.08) |
| Testability | Protocol- or closure-based transport, scripted fakes and manual clocks (P5.11) |
| Failure modes | Names at least 3 concurrency bugs it prevents |

**14+** strong senior · **9–13** solid · **< 9** revisit the referenced lessons.

<details><summary>Model answer (after your 20 minutes)</summary>

**API surface**
```swift
protocol HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }
struct Endpoint<Response: Decodable & Sendable>: Sendable { … }          // value type, Sendable
final class APIClient: Sendable { func send<R>(_ e: Endpoint<R>) async throws -> R }
```
Callers are `@MainActor` view models running inside `.task {}`. Nothing on main except assigning results.

**Components and isolation**
- `APIClient`: a nonisolated `Sendable` façade (stateless). Composes the parts below.
- `AuthManager`: an **actor**. Owns the tokens. `validToken()` and `refresh(after staleToken:)` are single-flight via a stored `Task` (P4.07); the token is stored in the Keychain.
- `RequestDeduplicator`: an **actor** holding `[RequestKey: Task<(Data, HTTPURLResponse), Error>]` for idempotent GETs (P2.04). Failures aren't cached.
- `Limiter`: an async semaphore per host (P4.04), or a token bucket if the API has quotas (P4.05).
- `RetryPolicy`: a pure `Sendable` struct; `retry(...)` with exponential backoff, jitter, Retry-After, idempotent methods only, never `CancellationError` (P4.11).
- Decoding: `@concurrent` static functions (P5.08). Models are `Sendable` structs (marked `nonisolated` if the module is MainActor-by-default: P2.09).
- `Reachability`: an `AsyncValue<NetworkState>` (P7.05) that services observe.

**Flows**
1. Request → the limiter acquires a permit → attach the token → transport → validate the status → decode off main → return.
2. 401 → `AuthManager.refresh(after: usedToken)` (single-flight; a late 401 just reuses the new token) → retry once → on refresh failure, log out everyone **once** (single-flight logout).
3. Offline → fail fast with a typed error; mutations go to a persisted outbox (P7.07).
4. Cancel → the view's `.task` is cancelled → URLSession cancels the request; retries and backoff stop; no error UI for `CancellationError` (P5.07).

**Hazards named:** a refresh storm (P4.07), a stale response overwriting a newer one (P3.07/P5.03), decode hangs on main (P5.08), retry hammering after cancellation (P4.11), leaked tasks capturing view models (P5.06), pool starvation from sync bridges (P5.05).

**Testing:** inject `HTTPTransport` (a scripted fake: P5.01's `ScriptedResponder`) and a clock (P5.11); test the 10-concurrent-401 case deterministically; stress-test with TSan.

**Trade-offs to volunteer:** an actor for auth vs a lock (callers are async anyway, so an actor is natural); dedupe only for GETs; URLCache vs an app-level cache; how much to centralize retries vs leave them to callers.
</details>

---

<!-- nav:start -->
[← P7.05](./05-kata-async-value.md) · [Roadmap](../../ROADMAP.md) · [P7.07 →](./07-design-offline-sync.md)
<!-- nav:end -->
