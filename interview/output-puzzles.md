# "What does this print?" — puzzle index

The most common concurrency interview format. Every puzzle in this course is **runnable and graded**: you write your prediction in `Sources/Exercises/…_Predictions.swift`, and the tests check it.

| Set | Puzzles | Predict in | Grade | Topics |
|---|---|---|---|---|
| P0.08 GCD | `Sources/Puzzles/GCDPuzzles.swift` (5) | `P0_08_Predictions.swift` | `swift test --filter P0_08` | async onto own queue, sync behind async, barriers, group notify, QoS vs FIFO |
| P1.10 async/await | `Sources/Puzzles/AsyncPuzzles.swift` (8) | `P1_10_Predictions.swift` | `swift test --filter P1_10` | Task start order, `Task.immediate`, interleaving at awaits, `await` without suspension, stream buffering, termination, lost errors |
| P2.02 isolation map | `Sources/Puzzles/IsolationMap.swift` (9) | `P2_02_Predictions.swift` | `swift test --filter P2_02` | which domain: main, nonisolated, actor; Task inheritance |
| P2.16 isolation | `Sources/Puzzles/IsolationPuzzles.swift` (6) | `P2_16_Predictions.swift` | `swift test --filter P2_16` | actor interleaving, reentrancy, same-actor await, nonsending vs `@concurrent` |
| P3.12 structured | `Sources/Puzzles/StructuredPuzzles.swift` (6) | `P3_12_Predictions.swift` | `swift test --filter P3_12` | `async let` implicit cancel, completion order, `waitForAll` trap, propagation, handlers, task-locals |
| P4.12 toolbox | `Sources/Exercises/P4_12_Toolbox.swift` (12 scenarios) | same file | `swift test --filter P4_12` | not output order but tool choice: which primitive fits each scenario |
| P7.02 marathon | `Sources/Puzzles/MarathonPuzzles.swift` (10) | `P7_02_Marathon.swift` | `swift test --filter P7_02` | mixed, timed: 20 minutes for 10 |

## Interview technique for output puzzles

1. **Say the model out loud first**: "This is a serial queue, so FIFO…" / "We're on the main actor, so the Task is enqueued and can't run until we suspend…"
2. **Mark every `await`** and ask: *could this suspend? who could run meanwhile?*
3. **Separate "start order" from "finish order".**
4. If the answer is nondeterministic, **say so** and explain which interleavings are possible. That's often the point of the question.
5. Mention the tool you'd use to check: TSan, strict pool, a trace.
