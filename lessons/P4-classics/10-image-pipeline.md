# P4.10 — An image pipeline: dedupe + limit + LRU ⭐

<!-- nav:start -->
[← P4.09](./09-leetcode-set.md) · [Roadmap](../../README.md) · [P4.11 →](./11-retry-backoff.md)
<!-- nav:end -->

⏱ 30 min · Demo `p4.10` · iOS lab **P4.10 Image pipeline grid** · Exercise `P4_10`

This is the K1 kata and a staple of iOS system design rounds ("design an image loading library"). It combines three things you've already built.

## 1. Concept (5 min)

A grid or feed requests the same images many times (cells reuse ids; scrolling back re-requests them). A good pipeline:

| Requirement | Technique | From |
|---|---|---|
| **Dedupe** concurrent requests for the same image | In-flight `Task` dictionary in an actor | P2.04 |
| **Limit** concurrent downloads (sockets, bandwidth, server limits) | A small async semaphore *inside* the pipeline; **cache hits never wait for it** | P4.04 |
| **Bound memory** | A cache with LRU eviction (or `NSCache`, which evicts under memory pressure) | new today |
| Don't cache failures | Remove the in-flight entry on error | P2.04 |

LRU (least recently used): on every hit, move the id to the "most recent" end; on insert past capacity, evict from the "least recent" end. Production structure: a dictionary plus a doubly linked list for O(1) operations. An array is fine for the lab.

Design questions an interviewer will raise:
- **Cancellation:** a cell scrolls away and its `.task` is cancelled. Should the shared download stop? (No if other cells are waiting on it. Yes if nobody is. That needs per-download reference counting.)
- **Priority:** visible cells first; prefetch at low priority.
- **Decode off main:** `@concurrent` decoding and downsampling to the cell size.
- **Disk cache** as a second level, and HTTP caching.

## 2. Predict (5 min)

Naive actor cache: 120 concurrent requests for 40 distinct images. Downloads? Peak in flight? Memory over time? ______

## 3. Run (5 min)

```bash
swift run lab p4.10
# iOS: app → "P4.10 · Image pipeline grid", toggle the pipeline on and off.
#   or: xcrun simctl launch --console-pty booted dev.learning.concurrency.lab -autorun grid
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
120 requests for 40 distinct images: 120 downloads, 120 in flight at once, 40 images (2000KB) kept forever
```
iOS lab (simulator, 60 cells showing 20 distinct images):
```
■ NAIVE:    54 downloads, peak 54 in flight
■ PIPELINE: 20 downloads, peak 4 in flight
```
The naive cache *has* a cache. It just checks it before the `await`, so every concurrent duplicate misses (reentrancy). The cache only helps requests that arrive after a download has finished.
</details>

## 5. Exercise (10 min)

File: `Sources/Exercises/P4_10_ImagePipeline.swift`. Add all three: dedupe, a download limit, LRU eviction. The tests check each separately.

```bash
swift test --filter P4_10
```

## 6. Interview cards

- **Design an image loader for a scrolling grid.** An actor with an in-flight Task dictionary (dedupe), a download limiter (async semaphore; hits bypass it), and a memory cache with LRU or NSCache. Decode and downsample off main. Don't cache failures. Discuss a disk cache, prefetch priority, and cancellation when no one is waiting anymore.
- **Why does a naive actor cache still download duplicates?** Reentrancy: the cache check happens before the `await download`; while the first request is suspended, the others find the cache empty too.
- **LRU in O(1)?** A hash map from key to linked-list node plus a doubly linked list ordered by recency: move to the front on access, evict from the back.

---

<!-- nav:start -->
[← P4.09](./09-leetcode-set.md) · [Roadmap](../../README.md) · [P4.11 →](./11-retry-backoff.md)
<!-- nav:end -->
