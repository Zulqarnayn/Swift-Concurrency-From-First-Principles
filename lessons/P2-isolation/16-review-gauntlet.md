# P2.16 — Review: isolation puzzles + the diagnostics gauntlet ⭐

<!-- nav:start -->
[← P2.15](./15-nonsendable-first.md) · [Roadmap](../../ROADMAP.md) · [P3.01 →](../P3-structured/01-structured-concurrency.md)
<!-- nav:end -->

⏱ 30 min · Puzzles `Sources/Puzzles/IsolationPuzzles.swift` · Exercise `P2_16` (graded predictions)

## 1. Puzzles (12 min)

Read `Sources/Puzzles/IsolationPuzzles.swift`. **Don't run.** Write all six sequences in `Sources/Exercises/P2_16_Predictions.swift`.

```bash
swift test --filter P2_16
swift run lab p2.16
```

<details><summary>Spoiler: after grading</summary>

| # | Answer | Why |
|---|---|---|
| 1 | `1 start, 2 start, 2 end, 1 end` | An actor is **not** "one call at a time, start to finish". Call 1 suspends at its `await`, so the actor runs call 2. Mutual exclusion holds only between suspension points. |
| 2 | `approved: 2, balance: -60` | Reentrancy (P2.04): both checks ran before either debit. |
| 3 | `m1, m2, task` | A `Task {}` capturing `self` is isolated to the actor, so it can't start until the method suspends (`await task.value`). Same as P1.10 #1, with an actor instead of main. |
| 4 | `a, helper, b, other` | `await self.helper()` on the **same** actor doesn't hop and doesn't suspend, so "other" waits until the method really suspends. P1.10 #4 again. |
| 5 | `1, plain, 2, task` | A plain async func is nonsending (P2.08): it runs on main without a hop, so main is never released before `2`. |
| 6 | `1, task, 2` | `@concurrent` **leaves** main. The hop releases the main actor, and the queued Task runs. |

5 vs 6 is the cleanest demonstration of SE-0461 you'll find. Learn to explain it.
</details>

## 2. Diagnostics gauntlet (10 min)

Run each P2 diagnostics file. **Before each one**, cover the spoiler in its lesson and predict every error out loud:

```bash
for f in ConcurrencyLab/Diagnostics/P2_*.swift; do scripts/typecheck.sh "$f"; echo; done
```

Then, for each error message, say:
1. which **domain** the code is in,
2. which **boundary** it's crossing (or which rule it breaks),
3. the **right fix**, and one *wrong* fix (an escape hatch) and why it's wrong.

That three-part answer is what interviewers want when they paste a Swift 6 error and ask "how would you fix this?"

## 3. Flashcards (8 min)

`interview/flashcards.md` → **P2**, out loud. Mark the ones you missed.

## Phase 2 checkpoint ✅

You can now explain: isolation domains; actors vs queues; reentrancy and its fixes; global actors and inference; Sendable vs `sending` vs regions; nonsending vs `@concurrent`; MainActor-by-default; isolation inheritance and isolated params; global state; isolated conformances; legacy bridges and dynamic checks; the Massicotte designs; non-Sendable-first.

| P2 idea | Shows up again in |
|---|---|
| Reentrancy + in-flight tasks | P4.07 single-flight token refresh, P4.10 image cache, P5.03 |
| Sendable / sending | Every TaskGroup in P3 (child results must be Sendable) |
| Task inheritance | P3.07 cancellation of unstructured tasks |
| Dynamic isolation checks | P5.10 (crashes and silent violations in the field) |

Next: **Phase 3: structured concurrency.** Tell Claude "next phase", along with which P2 predictions you got wrong.

---

<!-- nav:start -->
[← P2.15](./15-nonsendable-first.md) · [Roadmap](../../ROADMAP.md) · [P3.01 →](../P3-structured/01-structured-concurrency.md)
<!-- nav:end -->
