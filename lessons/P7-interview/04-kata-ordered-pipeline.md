# P7.04 — Timed kata: concurrent processing, in-order delivery

<!-- nav:start -->
[← P7.03](./03-kata-fetch-all.md) · [Roadmap](../../README.md) · [P7.05 →](./05-kata-async-value.md)
<!-- nav:end -->

⏱ **25 min coding** + 5 min debrief · Exercise `P7_04`

## The prompt

> "We decode video frames (or render pages, or translate messages) concurrently for speed, but they must be **shown in their original order**, as soon as possible, without waiting for the whole batch. Write `mapOrdered(inputs, maxConcurrent, transform, emit)`."

Spec and signature: `Sources/Exercises/P7_04_KataOrdered.swift`.

Run it like P7.03: a 25-minute timer, narrate first, then `swift test --filter P7_04`.

## A strong answer mentions

- [ ] Sliding window for the concurrency limit, with children returning `(index, value)`
- [ ] A **reorder buffer**: park out-of-order results; after each arrival, flush the contiguous prefix starting at `nextToEmit`
- [ ] "As soon as possible": emit inside the loop, not after the group finishes (the tests check that the first emit happens early)
- [ ] **Head-of-line blocking:** one slow item holds back everything after it, so the buffer can hold up to `maxConcurrent − 1` finished results. Bounded by the window, so memory is bounded.
- [ ] Contrast with P1.08 (serial, in order, no parallelism) and P3.03 (parallel, completion order)
- [ ] Possible extensions: cancellation propagation, error policy (fail fast vs skip), streaming input via `AsyncSequence`

<details><summary>Debrief: reference solution notes</summary>

`solutions/Exercises/P7_04_KataOrdered.swift`:
```
window of K children → (index, output)
while let (i, out) = await group.next():
    buffer[i] = out
    while let ready = buffer.removeValue(forKey: nextToEmit) { emit(ready); nextToEmit += 1 }
    startNext()
```
The classic mistake is collecting everything and sorting at the end: correct order, but nothing is emitted until the slowest item is done. The other is emitting in completion order.
</details>

## Interview cards

- **Process items concurrently but deliver them in input order?** A sliding-window TaskGroup whose children return `(index, result)`, plus a reorder buffer that emits the contiguous prefix as soon as it's complete. Memory is bounded by the window. Mention head-of-line blocking.

---

<!-- nav:start -->
[← P7.03](./03-kata-fetch-all.md) · [Roadmap](../../README.md) · [P7.05 →](./05-kata-async-value.md)
<!-- nav:end -->
