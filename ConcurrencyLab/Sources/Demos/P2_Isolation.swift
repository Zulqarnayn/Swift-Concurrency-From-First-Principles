import Foundation
import LabKit
import LegacySemantics
import MainActorDefault
import Puzzles
// UnsafeZone is a Swift 5 module with no concurrency annotations. The compiler itself suggests this:
// treat Sendable problems from it as warnings, because it was written before Sendable existed. (P2.13)
@preconcurrency import UnsafeZone

let phase2: [Demo] = [
    Demo("p2.02", "Isolation domains: who am I running as?", p2_02),
    Demo("p2.03", "Actor vs serial queue: same safety, different shape", p2_03),
    Demo("p2.04", "Actor reentrancy: the overdraft and the duplicate download", p2_04),
    Demo("p2.05", "Global actors and isolation inference", p2_05),
    Demo("p2.05c", "MainActor.assumeIsolated off the main thread (crashes)", optIn: true, p2_05c),
    Demo("p2.06", "@unchecked Sendable: a promise the compiler can't check", p2_06),
    Demo("p2.07", "Region-based isolation: sending a non-Sendable value safely", p2_07),
    Demo("p2.08", "nonisolated(nonsending) vs @concurrent vs pre-6.2 rules", p2_08),
    Demo("p2.09", "MainActor by default: a module where everything is @MainActor", p2_09),
    Demo("p2.10", "Isolation inheritance: Task{}, detached, closures, isolated params", p2_10),
    Demo("p2.11", "Globals: `static let` initializes once; `lazy var` races", p2_11),
    Demo("p2.12", "Protocols: isolated conformances", p2_12),
    Demo("p2.12c", "@preconcurrency conformance used off the main actor (crashes)", optIn: true, p2_12c),
    Demo("p2.13", "Legacy callbacks into Swift 6 code: the safe bridge", p2_13),
    Demo("p2.13b", "Legacy code stores a @MainActor closure, calls it off-main: SILENT violation", p2_13b),
    Demo("p2.13c", "Legacy code takes a @MainActor closure argument, calls it off-main (crashes)", optIn: true, p2_13c),
    Demo("p2.14", "Massicotte: reading from storage + stateful systems", p2_14),
    Demo("p2.15", "Non-Sendable first: one class, many owners", p2_15),
    Demo("p2.16", "Isolation output puzzles", p2_16),
]

// MARK: - P2.02

actor Vault {
    var secrets: [String] = []
    func label() -> String { isolationLabel() }
}


@MainActor
func p2_02() async {
    let sites = [
        "a  inside a @MainActor function",
        "b  plain SYNC func, called from main",
        "c  plain ASYNC func, called from main",
        "d  @concurrent func, called from main",
        "e  actor method",
        "f  Task {} created on main",
        "g  Task.detached {}",
        "h  Task {} inside an actor, not using self",
        "i  Task {} inside an actor, using self",
    ]
    for ((_, run), site) in zip(IsolationMap.all, sites) {
        let label = await run()
        trace("\(site.padding(toLength: 44, withPad: " ", startingAt: 0)) → \(label)")
    }
    let vault = Vault()
    // vault.secrets.append("x")             // ✗ error: actor-isolated property can't be mutated from the main actor
    let count = await vault.secrets.count     // ✓ reading crosses the boundary: needs `await`
    trace("reading an actor's property from outside needs await → \(count)")
}

// MARK: - P2.03

/// The GCD way: a class + a private serial queue. You promise (@unchecked) to route every access through it.
final class QueueBox: @unchecked Sendable {
    private let queue = DispatchQueue(label: "QueueBox")
    private var value = 0
    func increment() { queue.sync { value += 1 } }
    var current: Int { queue.sync { value } }
}

/// The actor way: the compiler routes every access through the actor's serial executor.
actor ActorBox {
    private var value = 0
    let threads = ThreadSet()
    let meter = ConcurrencyMeter()
    func increment() {
        meter.enter()
        threads.record()
        value += 1
        meter.leave()
    }
    func incrementTwice() {
        increment() // inside the actor: plain sync call, no await, no deadlock (cf. queue.sync inside queue.sync)
        increment()
    }
    var current: Int { value }
}

@concurrent
func p2_03() async {
    let box = QueueBox()
    let boxMs = await measureMs {
        await withTaskGroup(of: Void.self) { g in
            for _ in 0..<10_000 { g.addTask { box.increment() } }
        }
    }
    trace("class + serial queue: \(box.current) in \(boxMs)ms (each caller BLOCKS in queue.sync)")

    let actor = ActorBox()
    let actorMs = await measureMs {
        await withTaskGroup(of: Void.self) { g in
            for _ in 0..<10_000 { g.addTask { await actor.increment() } }
        }
    }
    let total = await actor.current
    trace("actor:                \(total) in \(actorMs)ms (each caller SUSPENDS on await)")
    trace("the actor ran on \(actor.threads.count) different threads, max \(actor.meter.peak) at a time")
    await actor.incrementTwice()
    let v1 = await actor.current
    trace("incrementTwice() called increment() inside the actor without await → \(v1)")
}

// MARK: - P2.04

actor ReentrantBank {
    var balance = 100

    func withdraw(_ amount: Int, who: String) async -> Bool {
        guard balance >= amount else {
            trace("\(who): declined (balance \(balance))")
            return false
        }
        trace("\(who): check passed (balance \(balance)) → awaiting fraud check...")
        await suspend(ms: 20) // ← suspension point: the actor is FREE to run other calls now
        balance -= amount
        trace("\(who): debited \(amount) → balance \(balance)")
        return true
    }
}

actor NaiveImageCache {
    var cache: [String: String] = [:]
    let downloads = CallCounter()

    func image(_ url: String) async -> String {
        if let hit = cache[url] { return hit }
        downloads.increment()
        await suspend(ms: 30) // download
        let image = "pixels(\(url))"
        cache[url] = image
        return image
    }
}

@concurrent
func p2_04() async {
    trace("— the bank: balance 100, two withdrawals of 80 at the same time —")
    let bank = ReentrantBank()
    async let a = bank.withdraw(80, who: "A")
    async let b = bank.withdraw(80, who: "B")
    let results = await [a, b]
    let v2 = await bank.balance
    trace("approved: \(results)  final balance: \(v2)")

    trace("— the cache: 10 simultaneous requests for the same URL —")
    let cache = NaiveImageCache()
    await withTaskGroup(of: String.self) { g in
        for _ in 0..<10 { g.addTask { await cache.image("cat.png") } }
    }
    trace("downloads performed: \(cache.downloads.count)")
}

// MARK: - P2.05

@globalActor
actor LabDatabaseActor {
    static let shared = LabDatabaseActor()
}

@LabDatabaseActor
final class LabDatabase {
    var rows: [String] = []
    func insert(_ row: String) {
        rows.append(row)
        let isolation = isolationLabel() // evaluate HERE, not inside trace's autoclosure (see P2.10)
        trace("  LabDatabase.insert(\(row)) → isolation: \(isolation)")
    }
}

@MainActor
class ScreenModel {
    var title = ""
    func render() { let i = isolationLabel(); trace("  ScreenModel.render → \(i)") }
}

final class DetailModel: ScreenModel { // inherits @MainActor from its superclass
    override func render() { let i = isolationLabel(); trace("  DetailModel.render (subclass) → \(i)") }
}

enum LegacyNotifier {
    /// Old API, documented as "always calls back on the main queue". Its closure type is @Sendable,
    /// so the compiler treats the closure as nonisolated — it can't know about that documentation.
    static func onMainQueue(_ callback: @escaping @Sendable () -> Void) {
        DispatchQueue.main.async(execute: callback)
    }
}

@MainActor
func p2_05() async {
    let db = LabDatabase()
    await db.insert("row 1")
    ScreenModel().render()
    DetailModel().render()

    let model = ScreenModel()
    await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
        LegacyNotifier.onMainQueue {
            // model.title = "x"                 // ✗ error: main actor-isolated property from a nonisolated closure
            MainActor.assumeIsolated {            // ✓ "I KNOW I'm on main" — checked at runtime, traps if wrong
                model.title = "updated from a legacy main-queue callback"
            }
            done.resume()
        }
    }
    trace("model.title = \(model.title)")
}

@concurrent
func p2_05c() async {
    trace("calling MainActor.assumeIsolated from a background thread...")
    // MainActor.assumeIsolated { }   // ✗ won't even compile here: "unavailable from asynchronous contexts"
    assumeMainFromSyncCode()          // ...but a sync helper can call it — and the runtime check traps
}

func assumeMainFromSyncCode() {
    MainActor.assumeIsolated { _ = trace("never printed") }
}

// MARK: - P2.06

/// Compiles in Swift 6 without a single warning. It is still a data race.
final class LyingCounter: @unchecked Sendable {
    var value = 0
    func increment() { value += 1 }
}

@concurrent
func p2_06() async {
    let counter = LyingCounter()
    await withTaskGroup(of: Void.self) { g in
        for _ in 0..<8 {
            g.addTask { for _ in 0..<100_000 { counter.increment() } }
        }
    }
    trace("@unchecked Sendable counter: expected 800000, got \(counter.value)")
    trace("Swift 6 accepted this: @unchecked turns the checking OFF. Try: swift run --sanitize=thread lab p2.06")
}

// MARK: - P2.07

final class Draft { // not Sendable
    var text = ""
}

func makeDraft() -> sending Draft { // `sending` result: the caller gets a value nobody else can reach
    let d = Draft()
    d.text = "hello"
    return d
}

@MainActor
func p2_07() async {
    let draft = makeDraft()
    draft.text += ", world"
    // `draft` is not Sendable, but the compiler can prove nothing else references it:
    // its whole "region" is handed to the detached task. Using `draft` after this line would be an error.
    let result = await Task.detached {
        draft.text += "!"
        return draft.text
    }.value
    trace("non-Sendable Draft moved into another task safely: \(result)")
}

// MARK: - P2.08

func modernPlainAsync() async -> String {
    trace("  modern module: plain async func")
    return isMainThread() ? "MAIN" : "background"
}

@concurrent func modernConcurrent() async -> String {
    trace("  modern module: @concurrent func")
    return isMainThread() ? "MAIN" : "background"
}

@MainActor
func p2_08() async {
    trace("all called from the main actor:")
    let v3 = await modernPlainAsync()
    trace("plain async, Swift 6.2 rules (nonsending)     → \(v3)")
    let v4 = await legacyPlainAsync()
    trace("plain async, Swift 6.0/6.1 rules              → \(v4)")
    let v5 = await legacyExplicitNonsending()
    trace("explicit nonisolated(nonsending), old module  → \(v5)")
    let v6 = await modernConcurrent()
    trace("@concurrent                                   → \(v6)")
    trace("plain SYNC func (any module, any rules)       → \(legacyPlainSync())")
}

// MARK: - P2.09

@MainActor
func p2_09() async {
    let settings = Settings()        // MainActorDefault.Settings: no annotation in its source, yet @MainActor
    settings.theme = "dark"
    let launches = recordLaunch()   // mutates a global `var` inside that module — legal because it's @MainActor
    trace("free function in MainActor-default module → \(freeFunctionIsolation())")
    trace("`nonisolated` opt-out function            → \(optedOutIsolation())")
    let v7 = await concurrentHelper()
    trace("@concurrent helper ran on                 → \(v7)")
    trace("launches = \(launches), theme = \(settings.theme)")
}

// MARK: - P2.10

actor Recorder {
    var log: [String] = []

    func demo() async {
        let withSelf = Task { // captures `self` → isolated to this actor
            self.log.append("task")
            return isolationLabel()
        }
        let withoutSelf = Task { isolationLabel() } // doesn't capture self → ?
        let detached = Task.detached { isolationLabel() }
        let v8 = await withSelf.value
        trace("Task {} that uses self, inside actor → \(v8)")
        let v9 = await withoutSelf.value
        trace("Task {} that ignores self            → \(v9)")
        let v10 = await detached.value
        trace("Task.detached inside actor           → \(v10)")

        [1, 2].forEach { log.append("closure \($0)") } // non-escaping closure: runs on the actor, sync access OK
        let childLabel = await withTaskGroup(of: String.self) { g in
            g.addTask { isolationLabel() }
            return await g.next()!
        }
        trace("TaskGroup child task                 → \(childLabel)")
        trace("log = \(log)")
    }
}

/// A free function that runs ON the actor passed in. Sync access to its state, no awaits needed inside.
func appendBatch(_ items: [String], to recorder: isolated Recorder) {
    for item in items { recorder.log.append(item) } // no hop per item: one atomic batch
    let isolation = isolationLabel()
    trace("appendBatch runs as → \(isolation)")
}

@concurrent
func p2_10() async {
    let recorder = Recorder()
    await recorder.demo()
    await appendBatch(["x", "y"], to: recorder) // one hop for the whole batch
}

// MARK: - P2.11

let globalInitCount = CallCounter()
let expensiveGlobal: Int = { // global `let`: lazily initialized, exactly once, thread-safe (swift_once)
    globalInitCount.increment()
    blockThread(ms: 2)
    return 42
}()

@concurrent
func p2_11() async {
    let sum = await onDedicatedThread {
        let total = Locked(0)
        onThreads(8) { _ in total.withLock { $0 += expensiveGlobal } }
        return total.value
    }!
    trace("8 threads read a global let: sum \(sum), initializer ran \(globalInitCount.count) time(s)")

    let holder = LazyHolder()
    await onDedicatedThread { onThreads(8) { _ in blackHole(holder.expensive) } }
    trace("8 threads read a lazy var:   initializer ran \(holder.initCount.count) time(s)")
}

// MARK: - P2.12

protocol Describable {
    func describe() -> String
}

@MainActor
final class ProfileModel: Describable { // isolated conformance, inferred (InferIsolatedConformances)
    var name = "Ada"
    func describe() -> String { "\(name) (described as \(isolationLabel()))" }
}

func describeAll(_ items: [any Describable]) -> [String] { items.map { $0.describe() } }

@MainActor
func p2_12() async {
    let model = ProfileModel()
    trace("used on the main actor: \(describeAll([model]))")
    trace("(passing `model` as `any Describable` to @concurrent code is a COMPILE error — see Diagnostics/P2_12b)")
}

@MainActor
final class LegacyProfile {
    var name = "Grace"
}

extension LegacyProfile: @preconcurrency Describable { // "trust me" conformance, checked at RUNTIME
    func describe() -> String { name }
}

@MainActor
func p2_12c() async {
    let profile = LegacyProfile()
    trace("on main: \(describeAll([profile]))")
    let erased: any Describable = profile
    trace("now calling describe() from a background task...")
    let fromBackground = await Task.detached { describeAll([erased]) }.value
    trace("never printed: \(fromBackground)")
}

// MARK: - P2.13

@MainActor
func p2_13() async {
    let client = LegacyThermometerClient()
    let (readings, continuation) = AsyncStream.makeStream(of: Int.self)
    // Explicitly @Sendable: this closure may run on ANY thread, so it must not be inferred @MainActor.
    // All it does is hand the value to a thread-safe continuation.
    client.onReading = { @Sendable value in
        trace("  legacy callback: \(value)")
        continuation.yield(value)
        if value == 22 { continuation.finish() }
    }
    client.start(count: 3)
    for await value in readings {
        trace("main actor consumed \(value)")
    }
}

@MainActor
final class ReadingsModel {
    var values: [Int] = []
}

@MainActor
func p2_13b() async {
    let model = ReadingsModel()
    let client = LegacyThermometerClient()
    // Looks innocent. This closure is formed on the main actor and isn't @Sendable, so Swift 6 infers it
    // @MainActor — that's why touching `model.values` compiles. But the Swift 5 client stores it in a
    // property and calls it on a background queue. No runtime check happens on this path.
    client.onReading = { value in
        model.values.append(value)
        let onMain = isMainThread()
        trace("closure isolated to @MainActor just mutated main-actor state. On main? \(onMain)")
    }
    client.start(count: 1)
    await suspend(ms: 100)
}

@MainActor
func p2_13c() async {
    let model = ReadingsModel()
    trace("passing a @MainActor-inferred closure as an ARGUMENT to Swift 5 code that runs it in the background...")
    LegacyScheduler.runInBackground {
        model.values.append(1)
        trace("never printed")
    }
    await suspend(ms: 200)
}

// MARK: - P2.14

struct NoteFile: Codable, Sendable {
    let title: String
    let words: Int
}

/// Massicotte "Reading from Storage", option C: a @MainActor store + value types + background helpers.
@MainActor
final class NoteStore {
    private(set) var loaded: [NoteFile] = []

    func load(from url: URL) async throws {
        trace("NoteStore.load: start")
        let data = try await Self.readFile(url)
        let notes = try await Self.decode(data)
        loaded = notes // back on the main actor: the only place state changes
        trace("NoteStore.load: assigned \(notes.count) notes")
    }

    @concurrent private static func readFile(_ url: URL) async throws -> Data {
        trace("  readFile (I/O)")
        return try Data(contentsOf: url)
    }

    @concurrent private static func decode(_ data: Data) async throws -> [NoteFile] {
        trace("  decode (CPU)")
        return try JSONDecoder().decode([NoteFile].self, from: data)
    }
}

actor ToggleRemote {
    var state = false
    var toggles = 0
    func toggle() async {
        await suspend(ms: 20)
        state.toggle()
        toggles += 1
    }
}

@MainActor
func p2_14() async {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("p2_14_notes.json")
    try? JSONEncoder().encode([NoteFile(title: "Actors", words: 900), NoteFile(title: "Sendable", words: 1200)]).write(to: url)
    let store = NoteStore()
    try? await store.load(from: url)

    trace("— stateful systems: 4 rapid taps on a toggle, no guard —")
    let ui = UnguardedToggle()
    await withTaskGroup(of: Void.self) { g in
        for _ in 0..<4 {
            g.addTask { await ui.tap() }
        }
    }
    let toggles = await ui.remote.toggles
    let remoteState = await ui.remote.state
    trace("remote toggled \(toggles) times; final remote \(remoteState), UI \(ui.isOn)")
}

@MainActor
final class UnguardedToggle {
    let remote = ToggleRemote()
    var isOn = false
    func tap() async {
        await remote.toggle()
        isOn = await remote.state
    }
}

// MARK: - P2.15

/// Non-Sendable, non-isolated. Just a class. Its async method runs wherever its OWNER runs.
final class ThumbnailRenderer {
    var rendered = 0
    func render(_ name: String) async {
        await suspend(ms: 5)
        rendered += 1 // safe: only the owner's isolation domain can reach this instance
        let isolation = isolationLabel()
        trace("  rendered \(name) as \(isolation)")
    }
}

@MainActor
final class GalleryModel {
    let renderer = ThumbnailRenderer()
    func refresh() async { await renderer.render("gallery.png") }
}

actor ExportService {
    let renderer = ThumbnailRenderer() // a different owner, a different instance
    func export() async { await renderer.render("export.png") }
}

@MainActor
func p2_15() async {
    await GalleryModel().refresh()
    await ExportService().export()
    trace("same class, two owners, zero locks, zero Sendable, zero actors inside it")
}

// MARK: - P2.16

func p2_16() async {
    for (name, run) in IsolationPuzzles.all {
        let answer = await run()
        trace("\(name): \(answer)")
    }
}
