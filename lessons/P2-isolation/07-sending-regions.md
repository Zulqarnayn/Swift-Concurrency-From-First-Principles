# P2.07 — `sending` and region-based isolation

<!-- nav:start -->
[← P2.06](./06-sendable.md) · [Roadmap](../../ROADMAP.md) · [P2.08 →](./08-nonsending-vs-concurrent.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.07` · Diagnostics `P2_07_regions.swift` · Exercise **Fixme** `P2_07_sending.swift`

## 1. Concept (5 min)

Sendable answers "is it *always* safe to share this type?" But often you just want to **hand over** a non-Sendable object: build a `Report` here, give it to an actor, and never touch it again. Handing something over isn't sharing it.

**Region-based isolation** (SE-0414, Swift 6) lets the compiler prove that. It tracks **regions**: groups of non-Sendable values that might reference each other. When you pass a value across a boundary, its whole region is **transferred**. That's legal only if:
1. the region isn't reachable from your current domain's state (not stored in `self`, a global, or an actor property), **and**
2. you never use anything in that region again after the transfer.

```swift
let r = Report()            // fresh region, owned by nobody
r.lines.append("draft")
await archive.store(r)      // ✅ region transferred to the actor
print(r.lines)              // ❌ "sending 'r' risks causing data races": used after transfer
```

**`sending`** (SE-0430) puts that contract into a signature:
- `func submit(_ r: sending Report)`: the **caller** must give up `r`. Inside, you may transfer it again.
- `func make() -> sending Report`: the result belongs to nobody else, so the caller may transfer it anywhere.

The standard library uses this everywhere: `Task.init` takes a `sending` closure, and `withCheckedContinuation` returns `sending T`. That's why some non-Sendable captures in `Task {}` compile and some don't.

**What can never be sent:** state owned by a domain. `self.current` on a `@MainActor` class stays reachable from the main actor, so sending it would create two owners. The fix is to send a **fresh copy**.

## 2. Predict (5 min)

`Diagnostics/P2_07_regions.swift`, functions `a`–`d` and `makeReport`: which compile? ______
`p2.07`: a non-Sendable `Draft` is modified on main, then moved into `Task.detached`. Compiles? ______

## 3. Run (5 min)

```bash
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_07_regions.swift
swift run lab p2.07
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
error: sending 'r' risks causing data races         ← b: used after sending
error: sending 'report' risks causing data races    ← c: a plain parameter: the CALLER might still hold it
```
- **a** compiles: a fresh value that's never used again.
- **d** compiles: `sending` moves the obligation to the caller.
- **makeReport** compiles: a fresh object with no other references.
- `p2.07` prints `non-Sendable Draft moved into another task safely: hello, world!`. Add a `print(draft.text)` after the `Task.detached` and it becomes an error.

**Why `c` fails, in one sentence:** inside `c`, the compiler can't see who else holds `report`, so it has to assume the caller still does.
</details>

## 5. Exercise (10 min) — Fixme

File: `ConcurrencyLab/Fixme/P2_07_sending.swift`. Three errors, three different fixes. `Report` must stay a non-Sendable class.

```bash
scripts/fixme.sh ConcurrencyLab/Fixme/P2_07_sending.swift
```

## 6. Interview cards

- **What is region-based isolation?** The compiler groups non-Sendable values into regions and lets you pass one across an isolation boundary if its whole region is unreachable from your domain and never used again. Ownership transfer, proven at compile time.
- **What does `sending` mean on a parameter? On a result?** Parameter: the caller gives up the value, and the callee may transfer it onward. Result: the returned value is in a fresh, disconnected region, so the caller may send it anywhere.
- **Why can't a `@MainActor` class send one of its properties to an actor?** The property stays reachable from the main actor, so you'd have two domains touching one object. Send a copy instead.
- **Sendable vs sending?** Sendable is a property of a *type*: always safe to share. `sending` is a property of a *particular value at a particular point*: safe to hand over once.

## Going deeper
- [SE-0414 Region-based isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md) (read the examples)
- [SE-0430 `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)
- Massicotte, [Reading from Storage](https://massicotte.org/step-by-step-reading-from-storage/): option E uses `-> sending DataModel`

---

<!-- nav:start -->
[← P2.06](./06-sendable.md) · [Roadmap](../../ROADMAP.md) · [P2.08 →](./08-nonsending-vs-concurrent.md)
<!-- nav:end -->
