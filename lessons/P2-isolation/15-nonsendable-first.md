# P2.15 — Non-Sendable first design

<!-- nav:start -->
[← P2.14](./14-massicotte-storage-stateful.md) · [Roadmap](../../README.md) · [P2.16 →](./16-review-gauntlet.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.15` · Diagnostics `P2_15_nonsendable_legacy.swift` · Exercise **Fixme** `P2_15_nonsendable_first.swift`

## 1. Concept (5 min)

A common Swift 6 migration habit: every error looks like "make it Sendable" or "make it an actor". The result is actors everywhere, `Sendable` on every type, `await` on every line, and reentrancy bugs.

Massicotte's [Non-Sendable First Design](https://massicotte.org/blog/non-sendable-first-design/) argues the opposite default:

> Start with plain, **non-Sendable, non-isolated** classes. Add isolation only where you have a real reason.

Why it works now: with `nonisolated(nonsending)` (P2.08), a non-Sendable class's **async methods run in the caller's domain**. A `@MainActor` view model that owns a `DraftStore` calls `await store.save()`, and it runs on main. An actor that owns its *own* `DraftStore` calls the same method, and it runs on that actor. The object never crosses a boundary, so it never needs to be Sendable.

Benefits:
- **No isolation in the type**, so it works with any owner, any protocol, subclassing, and sync APIs.
- **No `await` for sync methods**, and no actor hops.
- **No reentrancy surprises** beyond the owner's.

Limits:
- Each instance belongs to one owner. If two domains really need to *share* mutable state, you need an actor or a lock.
- Starting unstructured `Task`s from inside such a type is deliberately hard. Expose async methods and let callers decide.
- Before Swift 6.2 (no nonsending), the same code failed: `sending 'self.store' risks causing data races`. That's why older advice pushed actors.

## 2. Predict (5 min)

1. `p2.15`: one non-Sendable `ThumbnailRenderer` class, one instance owned by a `@MainActor` model and another by an actor. What does `render` report as its isolation in each case? ______
2. `Diagnostics/P2_15_nonsendable_legacy.swift` compiles the same pattern with 6.0/6.1 rules. Error? ______

## 3. Run (5 min)

```bash
swift run lab p2.15
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_15_nonsendable_legacy.swift
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
MAIN | rendered gallery.png as MainActor
T1   | rendered export.png as ExportService
same class, two owners, zero locks, zero Sendable, zero actors inside it
```
The class takes on its **owner's** isolation. Under 6.0/6.1 rules:
```
error: sending 'self.store' risks causing data races
```
The plain async method would hop off main, dragging the non-Sendable `self` across a boundary.
</details>

## 5. Exercise (10 min) — Fixme

File: `ConcurrencyLab/Fixme/P2_15_nonsendable_first.swift`. An "actors first" design that can't compile. Redesign it with **no custom actors** (the grader forbids `actor `), no `Sendable`, and no escape hatches. Keep `EditorModel` `@MainActor` and its method signatures.

```bash
scripts/fixme.sh ConcurrencyLab/Fixme/P2_15_nonsendable_first.swift
```

## 6. Interview cards

- **What's non-Sendable-first design?** Default to plain classes with no isolation and no Sendable, owned by a single isolated owner (`@MainActor` model or an actor). With Swift 6.2's nonsending default, their async methods run in the owner's domain, so nothing crosses a boundary. Add actors only for state that truly must be shared across domains.
- **Why not make everything an actor?** Every call becomes async and a boundary crossing, everything passed needs Sendable, and every `await` is a reentrancy point. Stateless actors add cost without protecting anything.
- **What changed in Swift 6.2 to make this practical?** `nonisolated(nonsending)` by default. Async methods on non-Sendable types no longer hop to the global executor, so calling them from an actor doesn't send `self`.

## Going deeper
- Massicotte, [Non-Sendable First Design](https://massicotte.org/blog/non-sendable-first-design/) · [Stateless Actors](https://massicotte.org/stateless-actors/)

---

<!-- nav:start -->
[← P2.14](./14-massicotte-storage-stateful.md) · [Roadmap](../../README.md) · [P2.16 →](./16-review-gauntlet.md)
<!-- nav:end -->
