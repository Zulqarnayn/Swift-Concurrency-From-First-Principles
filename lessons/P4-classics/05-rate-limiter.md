# P4.05 — Rate limiting: the token bucket

<!-- nav:start -->
[← P4.04](./04-async-semaphore.md) · [Roadmap](../../README.md) · [P4.06 →](./06-debounce-throttle.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.05` · Exercise `P4_05`

## 1. Concept (5 min)

A semaphore limits **how many at once**. A rate limiter limits **how many per unit of time** ("max 10 requests/second", an API quota, analytics batching).

| Algorithm | Idea | Behavior |
|---|---|---|
| **Fixed window** | Count per calendar second | Simple, but allows 2× bursts at the window edge |
| **Sliding window** | At most N in any interval | Precise; must remember timestamps |
| **Token bucket** | A bucket holds up to B tokens and refills at rate r; each call takes one | **Allows bursts up to B**, steady rate r afterwards. The most common in practice. |
| Leaky bucket | Requests drain at a constant rate | Smooths everything; no bursts |

Token bucket, implemented lazily with no timer task:
```
tokens += (now − lastRefill) / interval     (capped at capacity)
if tokens ≥ 1 → take one, go
else          → sleep until the next token is due, then CHECK AGAIN
```

**"Check again" is the trap.** After the sleep, other callers may have woken first and taken the token. Inside an actor, every `await` is a reentrancy point (P2.04), so the check must be a **`while` loop, not an `if`**. Condition variables have the same rule: always re-test the predicate after waking.

`Task.sleep` throws on cancellation, so a cancelled waiter leaves immediately. That's free cancellation support, as long as you don't write `try?`.

## 2. Predict (5 min)

GCD-style limiter (p4.05): capacity 3, each token refilled 40 ms after use, 9 callers at once. At what times do they get tokens? ______

## 3. Run (5 min)

```bash
swift run lab p4.05
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
capacity 3, refill 40ms → 9 callers got tokens at [0, 0, 0, 44, 44, 44, 86, 86, 86] ms
```
Bursts of 3, every 40 ms. That's a sliding window, built from a blocking semaphore plus one `asyncAfter` per token. It blocks threads, which is fine on GCD threads and forbidden in async code. A token bucket would hand out the next tokens spaced *evenly*: one every 40 ms after the initial burst.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_05_TokenBucket.swift`. Implement `acquire()`: lazy refill, suspend until a token is due, cancellable.

```bash
swift test --filter P4_05
```

## 6. Interview cards

- **Token bucket vs leaky bucket vs sliding window?** Token bucket: bursts up to capacity, then a steady refill rate (the most common). Leaky bucket: a constant output rate, no bursts. Sliding window: at most N in any window of length T, precise but stores timestamps. Fixed window: simple, with double bursts at the boundaries.
- **Implement an async rate limiter.** An actor with a token count and a last-refill time. Refill lazily from elapsed time; if empty, sleep until the next token and loop to re-check (reentrancy). Throwing `Task.sleep` gives you cancellation.
- **Why `while` and not `if` after waking?** Between deciding to wait and resuming, other callers ran (actor reentrancy, or spurious wakeups for condition variables). Always re-validate the condition after any wait.

---

<!-- nav:start -->
[← P4.04](./04-async-semaphore.md) · [Roadmap](../../README.md) · [P4.06 →](./06-debounce-throttle.md)
<!-- nav:end -->
