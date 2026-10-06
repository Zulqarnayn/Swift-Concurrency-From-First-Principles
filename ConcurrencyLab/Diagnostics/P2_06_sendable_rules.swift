// FLAGS: -swift-version 6 -enable-upcoming-feature NonisolatedNonsendingByDefault
// EXPECT: error: stored property 'counter' of 'Sendable'-conforming struct 'Box' has non-Sendable type 'Counter'
// EXPECT: error: stored property 'name' of 'Sendable'-conforming class 'MutableConfig' is mutable
// EXPECT: error: non-final class 'OpenConfig' cannot conform to the 'Sendable' protocol
//
// Lesson P2.06. Which of these types may conform to Sendable?
//   scripts/typecheck.sh ConcurrencyLab/Diagnostics/P2_06_sendable_rules.swift

final class Counter { var value = 0 }

struct Point: Sendable { var x = 0; var y = 0 }                 // 1. struct of Sendable members
struct Box: Sendable { let counter: Counter }                   // 2. struct holding a non-Sendable class
final class Config: Sendable { let name = "prod" }              // 3. final class, only lets
final class MutableConfig: Sendable { var name = "prod" }       // 4. final class with a var
class OpenConfig: Sendable { let name = "prod" }                // 5. non-final class
enum Mode: Sendable { case light, dark(level: Int) }           // 6. enum with Sendable payloads
actor Store {}                                                  // 7. actor (implicitly Sendable)
@MainActor final class Model { var count = 0 }                  // 8. global-actor class (implicitly Sendable)
