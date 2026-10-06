# P7.03 — Timed kata: parallel fetch with a limit and a deadline

<!-- nav:start -->
[← P7.02](./02-output-marathon.md) · [Roadmap](../../README.md) · [P7.04 →](./04-kata-ordered-pipeline.md)
<!-- nav:end -->

⏱ **25 min coding** + 5 min debrief · Exercise `P7_03`

A live-coding round. The interviewer gives you the signature and the spec, and you talk while you code.

## The prompt (as an interviewer would say it)

> "We load a dashboard made of many widgets, each from its own endpoint. Write `fetchAll(ids, maxConcurrent, deadline, fetch)`. Fetch everything in parallel, but never more than `maxConcurrent` at once. When the deadline hits, return what you have: anything unfinished is reported as timed out, and its request must be cancelled. Every id gets exactly one result."

Spec and signature: `Sources/Exercises/P7_03_KataFetchAll.swift`.

## Rules

- Timer: 25 minutes. No looking at P3/P4 code. Docs are allowed after minute 15.
- Narrate: say your design before typing (an interviewer grades the narration as much as the code).
- When the timer stops: `swift test --filter P7_03`, then read the debrief.

## Things a strong answer mentions (check yourself afterwards)

- [ ] Sliding-window TaskGroup for the limit (P3.04)
- [ ] The deadline as a **child task that races** the work (P3.08), *not* a separate unstructured timer
- [ ] On deadline: `cancelAll()`, and requests that never started also count as timed out
- [ ] Children return `(id, Result)`; the parent owns the dictionary (no shared mutable state)
- [ ] Knows the structural caveat: the group still awaits cancelled children, so this relies on `fetch` honoring cancellation (P3.08)
- [ ] Mentions what they'd do in production: per-request timeouts, retries (P4.11), priority for visible widgets

<details><summary>Debrief: reference solution notes</summary>

`solutions/Exercises/P7_03_KataFetchAll.swift`. The shape:
```
withTaskGroup(of: Event.self):
  add deadline child (sleep → .deadline)
  fill window with fetch children (→ .finished(id, result))
  loop next():
    .finished → store; if all done → cancelAll (kills the timer), return; else startNext()
    .deadline → cancelAll, return
fill missing ids with DeadlineExceeded
```
Common mistakes: forgetting to cancel the timer when everything finishes early (the function then waits for the deadline anyway, because the group awaits all children); mutating a shared dictionary from the children; reporting unstarted ids as missing instead of timed out.
</details>

## Interview cards

- **Fetch N things with max K concurrency and an overall deadline: design?** A TaskGroup with an extra deadline child. A sliding window of fetch children returns `(id, Result)`. When the deadline child wins, `cancelAll()` and mark the unfinished ones as timed out. When all finish first, cancel the deadline child. Requires cooperative fetches.

---

<!-- nav:start -->
[← P7.02](./02-output-marathon.md) · [Roadmap](../../README.md) · [P7.04 →](./04-kata-ordered-pipeline.md)
<!-- nav:end -->
