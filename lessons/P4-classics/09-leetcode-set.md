# P4.09 — The LeetCode concurrency set, in async Swift

<!-- nav:start -->
[← P4.08](./08-latch-barrier.md) · [Roadmap](../../README.md) · [P4.10 →](./10-image-pipeline.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.09` · Exercise `P4_09`

## 1. Concept (5 min)

LeetCode's "Concurrency" category is used by many interviewers, even for iOS roles. The official solutions use threads with semaphores, locks or condition variables:

| Problem | Thread solution |
|---|---|
| **1114 Print in Order** | 2 semaphores: `first` signals A, `second` waits A then signals B, `third` waits B |
| **1115 FooBar Alternately** | 2 semaphores: foo waits `fooSem` (starts at 1), signals `barSem`; bar does the reverse |
| 1116 Zero Even Odd | 3 semaphores passing a "turn" around |
| **1117 Building H2O** | `hSem(2)`, `oSem(1)` plus a barrier of 3 |
| 1195 Fizz Buzz Multithreaded | 4 threads, a shared counter, one condition variable |

The async-Swift answer uses the same idea with different primitives: **state in an actor + parked continuations**.
- "Whose turn is it?" is a property of the actor.
- "Wait for my turn" means: if it isn't my turn, park my continuation.
- "Pass the turn" means: update the state and resume the parked continuation.

This works only because actors are **reentrant**: when `foo` parks, the actor is free for `bar` to run and hand the turn back. A non-reentrant actor would deadlock here.

For H2O, release a whole molecule **synchronously inside the actor** (three release calls back to back, then resume all three), so no other atom can slip into the middle of a group.

## 2. Predict (5 min)

`p4.09`: two threads, `fooSem = 1`, `barSem = 0`. Output for n = 5? What if both started at 1? ______

## 3. Run (5 min)

```bash
swift run lab p4.09
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
two threads + two semaphores: foobarfoobarfoobarfoobarfoobar
```
If both start at 1, the first round can print `barfoo` or `foobar`, and later rounds can interleave. The initial permit counts encode "who goes first". In the actor version that's the initial value of `fooTurn`.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_09_LeetCode.swift`. Implement `InOrder` (1114), `FooBar` (1115) and `H2O` (1117) with actors and continuations: no sleeping, no polling, no blocking.

```bash
swift test --filter P4_09
```

Then try 1116 and 1195 on your own; they use the same technique.

## 6. Interview cards

- **Solve "Print FooBar Alternately" with threads.** Two semaphores, foo = 1 and bar = 0. foo: wait fooSem, print, signal barSem. bar: wait barSem, print, signal fooSem.
- **The same in Swift concurrency?** An actor with a turn flag and a parked continuation. Each method loops: while it's not my turn, park; print; flip the turn; resume the other side. Reentrancy lets the other method run while one is parked.
- **Building H2O: how do you guarantee whole molecules?** Queue waiting atoms. When 2 H and 1 O are available, release all three synchronously in one actor step, then resume them, so no other atom can interleave inside a molecule.

---

<!-- nav:start -->
[← P4.08](./08-latch-barrier.md) · [Roadmap](../../README.md) · [P4.10 →](./10-image-pipeline.md)
<!-- nav:end -->
