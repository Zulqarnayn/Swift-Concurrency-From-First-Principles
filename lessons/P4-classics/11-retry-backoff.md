# P4.11 — Retry with exponential backoff

<!-- nav:start -->
[← P4.10](./10-image-pipeline.md) · [Roadmap](../../README.md) · [P4.12 →](./12-review.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.11` · Exercise `P4_11`

## 1. Concept (5 min)

Networks fail transiently: 503s, timeouts, a flaky cell connection. Retrying usually helps. Retrying *badly* makes outages worse.

Good retry policy:
1. **Bounded attempts.** Always give up eventually, and surface the **last** error.
2. **Exponential backoff:** wait `d, 2d, 4d, …` so a struggling server gets breathing room.
3. **Jitter:** randomize the waits (e.g. "full jitter": `random(0...delay)`). Otherwise 100,000 clients that failed together all retry at the same instant, the *thundering herd*.
4. **Only retry retryable errors:** timeouts and 5xx, yes; 4xx (bad request, unauthorized, not found), no; and **never `CancellationError`**, because the caller is gone.
5. **Cancellable backoff:** if the user leaves, stop *during* the wait. That's exactly what `try await Task.sleep` gives you, and exactly what `try?` throws away (P1.07).
6. Respect `Retry-After` headers; idempotency matters (retrying a POST can double-charge, P2.14).

## 2. Predict (5 min)

`p4.11`: a retry loop uses `try? await Task.sleep(for: 40ms)` between attempts. The caller is cancelled after attempt 2. How many attempts run? ______

## 3. Run (5 min)

```bash
swift run lab p4.11
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
  attempt 1 failed; backing off 40ms
  attempt 2 failed; backing off 40ms
user left the screen: cancel()
  attempt 3 failed; backing off 40ms
  attempt 4 failed; backing off 40ms
  attempt 5 failed; backing off 40ms
the loop ran all 5 attempts anyway; each sleep returned instantly once cancelled
```
Worse than ignoring cancellation: after `cancel()` the sleeps return **immediately**, so the remaining attempts fire with **no backoff at all**, hammering the server right when the user left.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_11_Retry.swift`. Implement `retry`: exponential delays, the `shouldRetry` predicate, never retry cancellation, stop immediately when cancelled during backoff, and throw the last error when attempts run out.

```bash
swift test --filter P4_11
```

Then add jitter yourself. The tests require each wait to be **at least** the nominal delay, so use additive jitter (`delay + random(0...delay × 0.2)`), not full jitter (`random(0...delay)`), which can wait less. Which one spreads a herd out better, and why might production code accept shorter waits?

## 6. Interview cards

- **Design a retry policy.** Bounded attempts, exponential backoff with jitter, retry only transient errors (timeouts, 5xx, connectivity), never cancellation, honor Retry-After, retry only idempotent operations (or use idempotency keys), and surface the last error.
- **Why jitter?** Clients that failed at the same moment would retry in lockstep and overload the recovering server (thundering herd). Randomized delays spread them out.
- **How do you make backoff cancellable?** Use `try await Task.sleep`, which throws `CancellationError` immediately. `try?` swallows it and turns the remaining backoffs into zero-delay retries.

## Going deeper
- AWS Architecture Blog, [Exponential Backoff And Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)

---

<!-- nav:start -->
[← P4.10](./10-image-pipeline.md) · [Roadmap](../../README.md) · [P4.12 →](./12-review.md)
<!-- nav:end -->
