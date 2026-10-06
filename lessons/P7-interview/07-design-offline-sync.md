# P7.07 — iOS system design: an offline-first sync engine

<!-- nav:start -->
[← P7.06](./06-design-networking.md) · [Roadmap](../../README.md) · [P7.08 →](./08-mock-interview.md)
<!-- nav:end -->

⏱ 30 min: 20 min designing out loud + 10 min comparing with the model answer

## The prompt

> "Users edit notes offline. When connectivity returns, changes sync to the server. Edits can also arrive from other devices. Design the sync engine: local storage, the outgoing queue, conflict handling, background execution, and the concurrency model. What can go wrong?"

Run it like P7.06: a timer, talking out loud, the structure below, then the rubric and the model answer.

**Structure:** data model → local persistence → outbox (outgoing operations) → sync loop → incoming changes → conflicts → lifecycle (background, termination) → concurrency hazards → testing.

## Rubric (score each 0–2)

| Area | 2 points looks like |
|---|---|
| Single writer | One component (an actor, or a `@ModelActor` for SwiftData) owns writes to the store; UI reads snapshots |
| Outbox ordering | Operations persisted and replayed **in order**, one consumer (P1.08, P4.01) |
| Idempotency | Client-generated operation IDs so retries can't double-apply (P4.11, P2.14) |
| Sync triggering | Coalesced (debounce or single-flight: P4.06, P4.07) on connectivity, foreground and edits |
| Conflicts | A stated policy: last-writer-wins / per-field merge / CRDT, plus versions or vector clocks |
| Stale results | Server responses checked against the local version on arrival (P5.03) |
| Cancellation and lifecycle | Background task budget, cooperative cancellation, resume after relaunch |
| Testability | Deterministic: fake server, manual clock, scripted interleavings (P5.11) |

**12+** strong · **8–11** solid · **< 8** revisit.

<details><summary>Model answer (after your 20 minutes)</summary>

**Model:** `Note { id: UUID, title, body, version: Int, updatedAt, isDeleted }`. Every local mutation creates an `Operation { opID: UUID, noteID, kind, payload, baseVersion }`.

**Persistence:** SwiftData or SQLite behind a **single actor** (`NoteStore`, or a `@ModelActor`): the only writer. The UI gets `Sendable` snapshots (structs) or observes on the main actor. A model context or `NSManagedObject` never crosses actors; pass IDs (P5.10).

**Outbox:** a persisted, append-only list of operations. **One** sync task drains it in order (an async serial queue: P1.08). An operation is removed only after the server acknowledges its `opID`, and the server de-duplicates by `opID`, which makes retries idempotent.

**Sync loop:** `SyncEngine` is an actor with `requestSync()` that is single-flight (if a sync is running, mark "dirty" and run once more afterwards). It's triggered by edits (debounced about 1 s), connectivity going online (an `AsyncValue<NetworkState>` from P7.05) and app foreground. It pushes the outbox (retry with backoff: P4.11), then pulls changes since `lastSyncToken`.

**Incoming changes and conflicts:** apply server changes in the store actor in one transaction. If the local note has pending operations whose `baseVersion` is older than the server's version, there's a conflict. Policy: per-field last-writer-wins by timestamp for simple apps; a three-way merge for text; CRDTs if real-time collaboration matters. Always keep the losing version recoverable.

**Lifecycle:** run inside `BGTaskScheduler`/`BGProcessingTask` with an expiration handler that **cancels** the sync task (cooperative cancellation: P3.06). The outbox makes it resumable after termination.

**Hazards named:** two sync loops running concurrently (single-flight), out-of-order replay (one consumer), duplicate application on retry (opIDs), a stale pull overwriting a fresh local edit (version checks: P5.03), main-thread stalls during large merges (`@concurrent` diffing: P5.08), non-Sendable model objects crossing actors (pass IDs).

**Testing:** a fake server with scripted responses (P5.01), a manual clock for the debounce and backoff (P5.11), deterministic tests for the "edit during sync" and "two devices, same note" interleavings, and a stress test of the sync loop under TSan.
</details>

---

<!-- nav:start -->
[← P7.06](./06-design-networking.md) · [Roadmap](../../README.md) · [P7.08 →](./08-mock-interview.md)
<!-- nav:end -->
