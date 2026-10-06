// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: call to actor-isolated instance method 'add' in a synchronous nonisolated context
// EXPECT: error: main actor-isolated property 'title' can not be referenced from a nonisolated context
// EXPECT: error: actor-isolated property 'secrets' can not be mutated from a nonisolated context
//
// Lesson P2.02. Crossing an isolation boundary. PREDICT which lines are errors, then:
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_02_crossing.swift

actor Vault {
    var secrets: [String] = []
    func add(_ s: String) { secrets.append(s) }
}

@MainActor final class Screen {
    var title = ""
}

func syncCaller(vault: Vault, screen: Screen) {
    vault.add("a")                 // 1. sync code calls an actor method
    print(screen.title)            // 2. sync nonisolated code reads main-actor state
}

func asyncCaller(vault: Vault, screen: Screen) async {
    vault.secrets.append("b")      // 3. mutate an actor's property from outside
    await vault.add("c")           // 4. call an actor method with await
    let n = await vault.secrets.count   // 5. read an actor's property with await
    let t = await screen.title     // 6. read main-actor state with await
    print(n, t)
}
