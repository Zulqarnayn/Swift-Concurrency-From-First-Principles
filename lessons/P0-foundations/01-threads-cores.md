# P0.01 — Threads, cores, concurrency vs parallelism

<!-- nav:start -->
[← Roadmap](../../ROADMAP.md) · [P0.02 →](./02-data-race.md)
<!-- nav:end -->

<!-- dek: A Mac with 8 cores was running 3,812 threads while this lesson was written. Both numbers are true, and the gap between them explains most of this course. -->

⏱ 30 min · Demo `p0.01` · Exercise `P0_01`

## 1. Concept (5 min)

Run `ps -M -A | wc -l` in Terminal. On the 8-core Mac this course was written on, it counted 3,812 threads, and nothing was wrong. That works because a thread and a core are different things, and everything later in this course is built on the difference.

A **core** is hardware that runs one stream of instructions at a time. Your Mac has 8 of them: 4 fast "P" cores and 4 efficient "E" cores.

A **thread** is one of those streams: a program counter, registers, and a stack (about 512 KB on secondary threads). A thread makes progress only while it sits on a core.

The **scheduler**, inside the kernel, decides which threads run on which cores. When there are more threads than cores, it **time-slices**: it runs a thread for a few milliseconds, saves its registers, and switches to another. That switch is a *context switch*.

A **queue** or a **task** is your *description* of work, not a thread. GCD queues and Swift tasks go to a system library (libdispatch or the Swift runtime), and the library picks a thread to run your work on.

Two words get mixed up here. *Concurrency* is about structure: several jobs are in progress during the same period, which one core can manage by interleaving them. *Parallelism* is about execution: several jobs run at the same instant on different cores, which needs more than one core.

> Rob Pike: "Concurrency is about *dealing with* lots of things at once. Parallelism is about *doing* lots of things at once."

A GCD serial queue gives you concurrency with your caller, because your code keeps going while the block waits its turn, but no parallelism *inside* the queue. `DispatchQueue.concurrentPerform` gives you parallelism.

Speedup has a ceiling. If 5% of a program can't run in parallel, no number of cores makes it more than 20× faster, because that 5% still runs one step at a time. This is **Amdahl's law**: `speedup = 1 / ((1 − p) + p / n)`, where `p` is the fraction that can run in parallel and `n` is the number of cores. It is why adding threads stops helping.

## 2. Predict (5 min)

The demo uses `burnCPU(ms:)`, which keeps a core busy for that long, and `crunch(units:)`, a fixed amount of work: a thread that gets half a core takes twice as long to finish it. Write your guesses down before running anything.

1. 8 × `burnCPU(100)` on **one** thread. Total wall time? ______
2. 8 × `burnCPU(100)` via `concurrentPerform` on 8 cores? ______
3. 32 × `burnCPU(100)` via `concurrentPerform`? ______
4. `crunch(200)` alone takes X ms. Now 16 threads each run `crunch(200)` at the same time on 8 cores.
   - Do all 16 *start* right away, or do 8 wait? ______
   - Do 8 finish at ≈X and the other 8 at ≈2X, or something else? ______

## 3. Run (5 min)

```bash
cd ConcurrencyLab
swift run lab p0.01
```

## 4. Explain (5 min)

<details><summary>Spoiler: open after running</summary>

A real run on this machine:

```
8 × 100ms CPU work, one thread:                800ms
8 × 100ms CPU work, concurrentPerform:         100ms
32 × 100ms CPU work, concurrentPerform:        400ms
crunch(units: 200) alone on one thread:         210ms
16 threads × crunch(200): start times (ms) 0,0,0,0,0,0,0,0,12,13,13,14,22,24,25,29
16 threads × crunch(200): end times   (ms) 757,900,909,916,923,927,932,955,958,961,962,975,975,978,979,984
```

1. 800 ms. One thread can use only one core.
2. About 100 ms: 8 jobs on 8 cores, all at once. That is parallelism.
3. About 400 ms. `concurrentPerform` uses roughly one thread per core, so the 32 jobs run in 4 rounds of 8. The exercise asks you for the same arithmetic.
4. All 16 start immediately, and they all finish together, at about 4–5×X rather than 2×.

   The OS doesn't make threads wait in line. It time-slices, so all 16 are *concurrent* (in progress) while only 8 are *parallel* at any moment. Each thread gets a fair share of the cores, and they finish as a pack instead of in two waves.

   It comes out worse than 2× because half the cores are E-cores, roughly 2–3× slower, while the run "alone" measured a P-core. Context switches and cache misses account for the rest. Real hardware never matches the clean model.

So more threads than cores makes nothing faster. You pay for the time-slicing and for the memory of every extra stack. Swift's concurrency runtime is built on exactly this observation, as you will see in P1.03.
</details>

## 5. Exercise (10 min)

File: `ConcurrencyLab/Sources/Exercises/P0_01_Cores.swift`

Implement `wallTimeMs(tasks:taskMs:cores:)` and `amdahlSpeedup(parallelFraction:cores:)`.

```bash
swift test --filter P0_01
```

Stuck? `solutions/Exercises/P0_01_Cores.swift`

## 6. Interview cards

- **Concurrency vs parallelism?** Concurrency means multiple tasks in progress over the same period (structure; works on one core by interleaving). Parallelism means multiple tasks executing at the same instant (needs multiple cores). Concurrency is a way to structure a program; parallelism is one way to run it.
- **Why not one thread per task?** Threads cost memory (stack), creation time, and context switches. More runnable threads than cores adds overhead without adding throughput. Thread pools exist for this reason, and Swift concurrency caps its pool at the core count.
- **What is Amdahl's law?** The best speedup with `n` cores is `1/((1−p) + p/n)`. The serial part caps it: 95% parallel tops out at 20×.

## Going deeper
- Apple: [Energy Efficiency Guide — Prioritize Work with QoS](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/PrioritizeWorkWithQoS.html) (P vs E cores and QoS)
- Rob Pike, [Concurrency is not Parallelism](https://go.dev/blog/waza-talk) (talk)

---

<!-- nav:start -->
[← Roadmap](../../ROADMAP.md) · [P0.02 →](./02-data-race.md)
<!-- nav:end -->
