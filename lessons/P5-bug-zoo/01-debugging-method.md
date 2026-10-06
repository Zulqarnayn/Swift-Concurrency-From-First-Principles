# P5.01 — The debugging method (bug: "the cart total is wrong, sometimes") ⭐

<!-- nav:start -->
[← P4.12](../P4-classics/12-review.md) · [Roadmap](../../README.md) · [P5.02 →](./02-tools.md)
<!-- nav:end -->

⏱ 30 min · Repro `p5.01` · Exercise `P5_01`

Phase 5 is different. Each session starts with a **bug report**, written the way QA or a user would write it. The code doesn't say where the bug is. You find it the way you would at work.

## The method (memorize it; it's also the answer to "how do you debug concurrency bugs?")

| Step | What you do | Tools |
|---|---|---|
| **1. Reproduce** | Make it happen at all. Concurrency bugs need **pressure**: repetition, parallelism, slow paths. | Loops, `scripts/stress.sh`, strict pool, TSan, slower fakes |
| **2. Make it deterministic** | Take timing out of it: force the bad interleaving **on purpose**, every run. | Fakes that answer when the *test* says (`ScriptedResponder`), manual clocks (`ManualSleeper`), gates |
| **3. Draw the timeline** | Two columns, one per task. Mark every `await`. Find the instant where an assumption breaks. | Paper, `trace()` output, Instruments |
| **4. Fix the cause, not the symptom** | Change the design so the bad interleaving *can't* happen. A sleep, a retry or a timeout that makes the symptom rarer is not a fix. | Everything in P0–P4 |
| **5. Prove it** | The deterministic test passes, then stress it 100× (and under TSan). | `stress.sh P5_01 100 --tsan` |

Step 2 is what most engineers skip and seniors don't. A bug you can reproduce on demand is a bug you've mostly fixed.

---

## 🐞 Bug report #1184

> **Title:** Cart total wrong
> **Steps:** On the product list, tap "Add" on 3 products quickly.
> **Expected:** Total = sum of the prices.
> **Actual:** Sometimes the total is too low. Can't reproduce when tapping slowly. QA says "about 1 in 5", the dev says "works on my machine".
> **Code:** `Sources/Exercises/P5_01_Cart.swift`

## 1. Reproduce (5 min)

```bash
swift run lab p5.01          # 20 trials of 3 quick taps, running YOUR CartModel
swift test --filter P5_01
```

## 2. Make it deterministic (5 min)

Read `overlappingAddsKeepBothPrices` in `Tests/ExercisesTests/P5Tests.swift`. It uses `ScriptedResponder` (in `LabKit/Deterministic.swift`): the fake price service doesn't answer until the test calls `resolve`. The test **chooses** the order: B's price arrives before A's. That interleaving used to be "1 in 5 on QA's phone"; now it happens on every run.

## 3. Timeline (5 min)

Draw it before opening the hints. Two columns, `add("A")` and `add("BB")`, both on the main actor. Write each line of `add`, mark the `await`, and note the value of `total` at each step.

<details><summary>Hint 1</summary>
Both calls are on the main actor, so there's no data race. Where can one `add` pause and let the other run?
</details>
<details><summary>Hint 2</summary>
What is `runningTotal` holding by the time the `await` returns?
</details>

## 4. Fix + prove (10 min)

```bash
swift test --filter P5_01
scripts/stress.sh P5_01 50
```

## 5. Root cause

<details><summary>Spoiler: after your fix passes</summary>

`swift run lab p5.01` on the original code:
```
3 quick taps, 20 trials: wrong total in 20/20 runs — e.g. items ["a", "bb", "ccc"] → total 300 (expected 600)
```
```
add("A")                          add("BB")
items += A
runningTotal = 0
await price(A)  ──────suspends──→ items += BB
                                  runningTotal = 0          ← reads the same stale total
                                  await price(BB)
                                  total = 0 + 200 = 200
total = 0 + 100 = 100   ← overwrites 200: lost update
```
P0.04's check-then-act and P2.04's reentrancy, on the main actor. The state was read **before** the suspension point and written **after** it. Fix: read and write in one synchronous step after the `await`: `let price = await …; total += price`.
</details>

## 6. Interview cards

- **How do you debug a concurrency bug?** Reproduce under pressure. Make it deterministic by controlling the interleaving (scripted fakes, manual clocks). Draw the timeline with every suspension point. Fix the design, not the timing. Prove it with the deterministic test plus stress and TSan runs.
- **Why can single-threaded (main actor) code still have race conditions?** Reentrancy. At every `await`, other main-actor work runs. State read before the `await` may be stale after it.
- **What's wrong with "add a small delay" or "retry" as a fix?** It changes the probability, not the possibility. The bug returns on a slower device or a faster network.

---

<!-- nav:start -->
[← P4.12](../P4-classics/12-review.md) · [Roadmap](../../README.md) · [P5.02 →](./02-tools.md)
<!-- nav:end -->
