# P0.04 — Locks and race conditions (check-then-act) ⭐

<!-- nav:start -->
[← P0.03](./03-atomicity.md) · [Roadmap](../../README.md) · [P0.05 →](./05-deadlock.md)
<!-- nav:end -->

⏱ 30 min · Demo `p0.04` · Exercise `P0_04`

## 1. Concept (5 min)

A **critical section** is code that must not run on two threads at once. **Mutual exclusion** primitives on Apple platforms:

| Primitive | Notes |
|---|---|
| `Mutex<Value>` (Synchronization, Swift 6) | Owns the value it protects: `m.withLock { $0 += 1 }`. You *can't* touch the value without the lock. **Default choice in new code.** |
| `OSAllocatedUnfairLock<State>` | Same idea, iOS 16+. Wraps `os_unfair_lock`. |
| `NSLock` | Classic. Easy to forget an `unlock()`. Always pair it with `defer`. |
| `os_unfair_lock` (raw) | Never store it in a Swift `var` and take `&lock`. Swift may move the memory. Use the wrappers above. |
| Serial `DispatchQueue` + `sync` | The GCD way. Slower than a lock. Can deadlock (P0.05). |
| Concurrent queue + `.barrier` | Readers–writer lock (P4). |
| `NSRecursiveLock` | The same thread can re-lock it. Usually a sign the design needs fixing. |

**Locks prevent data races. They don't make your *logic* atomic.** The classic bug is **check-then-act** (TOCTOU, "time of check to time of use"):

```swift
if account.balance >= 100 {      // check: lock, read, unlock
    account.balance -= 100       // act:   lock, read, unlock, lock, write, unlock
}
```

Each access is locked, so there's no data race, and Swift 6 compiles it without a word. But between the check and the act, other threads run the same check against the same old balance.

**Rule:** the critical section has to cover the whole **invariant-preserving operation**, not each individual access. Pick the lock boundaries around *meaning*, not around variables.

This is the bug we'll keep meeting: at the actor level (reentrancy across `await`), in UI (stale search results), and in caches (duplicate downloads).

## 2. Predict (5 min)

Demo: `SplitLockAccount` protects every read and write with a `Mutex`. It starts at **500**. **10 threads** at once each run `if balance >= 100 { (1ms work); balance = balance − 100 }`.

1. Does this file compile in Swift 6 without warnings? ______
2. How many withdrawals get approved? ______
3. Final balance? ______
4. Does `approved × 100 == 500 − final balance`? ______

## 3. Run (5 min)

```bash
swift run lab p0.04
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
start balance: 500, 10 people withdraw 100 each
withdrawals approved: 10
final balance:        -500
money handed out:     1000
```
1. **It compiles cleanly.** No data race exists. The compiler checks memory safety, not your business rules.
2. **All 10.** All 10 threads did the check before any of them did the write.
3. **−500 on this run, and it varies.** Each thread reads `current` again for the write, so some writes overwrite others. That's a lost update on top of the overdraft.
4. Not necessarily. Lost updates make the books stop balancing. Two bugs from one design mistake.

Fix: put the check and the write in one `withLock`. Then there's no gap for another thread to use.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P0_04_BankAccount.swift`. Make `withdraw` correct. Keep the `simulateLatency()` call; it makes the bug reproducible.

```bash
swift test --filter P0_04
```

## 6. Interview cards

- **Is code with no data races thread-safe?** No. It can still have race conditions. Check-then-act across separate critical sections gives you overdrafts and lost updates, and Swift 6 accepts it.
- **What's TOCTOU?** Time-of-check to time-of-use: the state changes between checking a condition and acting on it. Fix: make the check and the act one atomic step (one lock scope, or a CAS).
- **Which lock should you use in Swift today?** `Mutex` (iOS 18+) or `OSAllocatedUnfairLock` (iOS 16+). Both own their protected state, so you can't access it unlocked. Never keep a raw `os_unfair_lock` in a Swift `var`.
- **How do you choose lock scope?** Around the invariant, not the variable. Keep it as small as possible but no smaller. Never do slow work (I/O) or call unknown code (callbacks, delegates) while holding a lock.

## Going deeper
- [SE-0433 Synchronous Mutual Exclusion Lock (Mutex)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0433-mutex.md)
- Apple: [OSAllocatedUnfairLock](https://developer.apple.com/documentation/os/osallocatedunfairlock)

---

<!-- nav:start -->
[← P0.03](./03-atomicity.md) · [Roadmap](../../README.md) · [P0.05 →](./05-deadlock.md)
<!-- nav:end -->
