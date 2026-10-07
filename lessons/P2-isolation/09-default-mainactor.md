# P2.09 — MainActor by default (SE-0466)

<!-- nav:start -->
[← P2.08](./08-nonsending-vs-concurrent.md) · [Roadmap](../../README.md) · [P2.10 →](./10-isolation-inheritance.md)
<!-- nav:end -->

⏱ 30 min · Demo `p2.09` · Diagnostics `P2_09_decodable.swift` · Exercise **Fixme** `P2_09_default_isolation.swift`

## 1. Concept (5 min)

New Xcode 26 app targets set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (SwiftPM: `.defaultIsolation(MainActor.self)`). **Every declaration in the module that doesn't say otherwise is `@MainActor`**: types, methods, free functions, global variables.

Why? Most app code is UI code and *should* run on main. With this default, a beginner's app is single-threaded and data-race-free with zero annotations. Concurrency becomes opt-in: `nonisolated` (stay off the main actor's rules), `@concurrent` (run off main).

What changes in practice:
- ✅ Mutable globals and statics compile, because they're main-actor-isolated (P2.11 errors disappear).
- ✅ Your view models, services and models "just work" together on main.
- ⚠️ **Free helper functions are `@MainActor` too.** Calling one from `@concurrent` code means a hop to main, or an error if the call is synchronous (P2.01).
- ⚠️ **Model types are `@MainActor`, and so are their protocol conformances** (with InferIsolatedConformances, also on in new projects). So `JSONDecoder().decode(User.self, …)` in a `@concurrent` function fails: the `Decodable` conformance is `@MainActor`.
- The fix is **`nonisolated`** on the type or function: "this has no UI state; it belongs to no actor".

Which modules should use it? App/UI targets: yes. Library and networking modules: usually no, because they're used from many isolation domains and should stay nonisolated. Massicotte: [Default isolation with Swift 6.2](https://massicotte.org/default-isolation-swift-6_2/), [MainActor by Default](https://massicotte.org/blog/mainactor-by-default/).

## 2. Predict (5 min)

`Sources/MainActorDefault/AppLikeModule.swift` has **no** isolation annotations except `nonisolated`/`@concurrent`. Called from main:
1. What does `freeFunctionIsolation()` report? `optedOutIsolation()`? ______
2. Can that module have `var launchCount = 0` at global scope in Swift 6? ______
3. `Diagnostics/P2_09_decodable.swift`: a plain `struct User: Decodable` decoded in a `@concurrent` function. Error? Which one? ______

## 3. Run (5 min)

```bash
swift run lab p2.09
scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_09_decodable.swift
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

```
free function in MainActor-default module → MainActor
`nonisolated` opt-out function            → nonisolated
@concurrent helper ran on                 → background
launches = 1, theme = dark
```
2. **Yes:** the global is `@MainActor`, so it's safe.
3. Compiler error:
   ```
   error: main actor-isolated conformance of 'User' to 'Decodable' cannot be used in nonisolated context
   ```
   You'll meet this in real Xcode 26 projects. Fix: `nonisolated struct User: Decodable`.
</details>

## 5. Exercise (10 min) — Fixme

File: `ConcurrencyLab/Fixme/P2_09_default_isolation.swift`. It's compiled as a MainActor-by-default target. Keep decoding inside the `@concurrent` function, and fix it by **opting the right declarations out**. Errors come in waves: fixing one can reveal the next.

```bash
scripts/fixme.sh ConcurrencyLab/Fixme/P2_09_default_isolation.swift
```

## 6. Interview cards

- **What does default MainActor isolation do?** Every declaration in the module is implicitly `@MainActor` unless marked `nonisolated` or `@concurrent` (SE-0466; the default in new Xcode 26 app targets). It makes app code single-threaded and race-free by default.
- **What typically breaks?** Background work that uses module types: free helper functions and model conformances (Codable, Hashable) are main-actor-isolated, so `@concurrent` code can't use them. Fix with `nonisolated` on pure helpers and plain data types.
- **Should a networking framework use MainActor-by-default?** Usually not. Libraries serve many isolation domains and should stay nonisolated, with explicit isolation where needed. App/UI targets benefit from it.

## Going deeper
- [SE-0466 Control default actor isolation inference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)
- Massicotte, [MainActor by Default](https://massicotte.org/blog/mainactor-by-default/)

---

<!-- nav:start -->
[← P2.08](./08-nonsending-vs-concurrent.md) · [Roadmap](../../README.md) · [P2.10 →](./10-isolation-inheritance.md)
<!-- nav:end -->
