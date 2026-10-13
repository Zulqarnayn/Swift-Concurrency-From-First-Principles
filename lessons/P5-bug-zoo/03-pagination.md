# P5.03 — Bug: "duplicate posts while scrolling; old posts after pull-to-refresh" ⭐

<!-- nav:start -->
[← P5.02](./02-tools.md) · [Roadmap](../../ROADMAP.md) · [P5.04 →](./04-continuations.md)
<!-- nav:end -->

⏱ 30 min · Repro `p5.03` · iOS lab **P5.03 Pagination bugs** · Exercise `P5_03`

## 🐞 Bug report #1219

> **Title:** Feed shows duplicate posts / wrong posts after refresh
> **Steps A:** Scroll the feed fast to the bottom. → The same posts appear 2–3 times.
> **Steps B:** Start scrolling (next page loading), then pull to refresh. → After the refresh, posts from the *old* scroll position appear in the fresh feed.
> **Platform:** worse on slow networks.
> **Code:** `Sources/Exercises/P5_03_Feed.swift`

## 1. Reproduce (5 min)

```bash
swift run lab p5.03
swift test --filter P5_03
# iOS: app → "P5.03 · Pagination", fixed OFF → "Fast scroll", then "Refresh mid-load"
#   or: xcrun simctl launch --console-pty booted dev.learning.concurrency.lab -autorun feed
```

## 2. Timelines (8 min)

Draw **two** timelines:
- A: three `loadNextPage()` calls fired by the list within a few milliseconds.
- B: `loadNextPage()` for page 2 (slow, 80 ms), with `refresh()` called 20 ms later (page 1, fast).

For each, mark which value of `nextPage` each call reads and **which feed** each response gets appended to.

<details><summary>Hint 1 (A)</summary>
Where is `nextPage` read, and where is it updated, relative to the `await`?
</details>
<details><summary>Hint 2 (B)</summary>
After `refresh()` resets the list, nothing stops the old page-2 request from finishing and appending. How could the old response know it belongs to an outdated feed?
</details>

## 3. Fix + prove (12 min)

Two separate fixes are needed. Requirements (from the tests): concurrent load requests trigger **one** request per page; anything started before a refresh must never touch the refreshed feed.

```bash
swift test --filter P5_03
scripts/stress.sh P5_03 30
```

## 4. Root cause

<details><summary>Spoiler: after your fix passes</summary>

Original code:
```
3 'near the bottom' events at once → requested pages ["1", "1", "1"], posts [p1-0, p1-1, p1-2, p1-0, p1-1, p1-2, p1-0, p1-1, p1-2]
scroll (slow page 2) + pull-to-refresh → posts [p1-0, p1-1, p1-2, p2-0, p2-1, p2-2]
```
iOS lab (simulator): buggy → `24 duplicates` during the fast scroll, and after the refresh the feed **started with page 3**. Fixed → clean.

- **A, duplicates:** check-then-act across an `await`. Every call read `nextPage == 1` before any of them finished. Fix: single-flight. If a load is in flight, join it (P2.04, P4.07).
- **B, stale page:** a response outlived the state it was requested for. Fix: a **generation token**, bumped on refresh and captured at request time; apply results only if the generation still matches (and cancel the old load). This is the same idea as P3.07's "re-check before applying" and P4.06's stale search.

The general lesson: **every async result must be checked against the state of the world when it arrives, not when it was requested.**
</details>

## 5. Interview cards

- **Pagination shows duplicate pages. Why, and how do you fix it?** Several "load more" triggers read the same next-page number before the first request finishes (check-then-act across an await). Single-flight the load: one in-flight task, which later triggers join or ignore.
- **After pull-to-refresh, old content reappears. Why?** A request from before the refresh completed afterwards and appended to the new list. Use a generation or request id captured at request time and compared on arrival, plus cancellation of superseded loads.

---

<!-- nav:start -->
[← P5.02](./02-tools.md) · [Roadmap](../../ROADMAP.md) · [P5.04 →](./04-continuations.md)
<!-- nav:end -->
