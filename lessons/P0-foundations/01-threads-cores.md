# P0.01 — Threads, cores, concurrency vs parallelism

<!-- nav:start -->
[← Roadmap](../../README.md) · [P0.02 →](./02-data-race.md)
<!-- nav:end -->

⏱ 30 min · Demo `p0.01` · Exercise `P0_01`

## 1. Concept (5 min)

Start at the bottom. Everything later in this course is built on these four things.

| Thing | What it is | Who controls it |
|---|---|---|
| **Core** | Hardware that runs one stream of instructions at a time. Your Mac has 8 (4 fast "P" cores, 4 efficient "E" cores). | Silicon |
| **Thread** | One stream of instructions: a program counter, registers, and a stack (~512 KB on secondary threads). Must be on a core to make progress. | The OS scheduler |
| **Scheduler** | Picks which threads run on which cores. When there are more threads than cores, it **time-slices**: runs a thread for a few ms, saves its registers, switches to another (a *context switch*). | The kernel |
| **Queue / Task** | Your *description* of work. GCD queues and Swift tasks are not threads. A system library picks a thread to run your work on. | libdispatch / Swift runtime |

Two words people mix up:

- **Concurrency** is about *structure*: several jobs are **in progress** in the same period. Possible on a single core, by interleaving.
- **Parallelism** is about *execution*: several jobs **running at the same instant** on different cores. Needs more than one core.

> Rob Pike: "Concurrency is about *dealing with* lots of things at once. Parallelism is about *doing* lots of things at once."

A GCD serial queue gives you concurrency with your caller (your code keeps going while the block waits its turn) but zero parallelism *inside* the queue. `DispatchQueue.concurrentPerform` gives parallelism.

**Speedup has a ceiling.** If 5% of a program can't be parallelized, no number of cores makes it more than 20× faster. That's **Amdahl's law**: `speedup = 1 / ((1 − p) + p / n)`, with `p` the parallel fraction and `n` the cores. It's why "just add threads" stops helping.

## 2. Predict (5 min)

The demo uses `burnCPU(ms:)` (spins a core for that long) and `crunch(units:)` (a fixed amount of work: a thread that gets half a core takes twice as long). Write your guesses down **before** running.

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

1. **800 ms.** One thread can only use one core.
2. **~100 ms.** 8 jobs, 8 cores, all at once. That's parallelism.
3. **~400 ms.** `concurrentPerform` uses about one thread per core, so the jobs run in 4 rounds of 8. Same arithmetic as the exercise.
4. **All 16 start immediately, and they all finish together, at ~4–5×X (not 2×).**
   - The OS doesn't make threads wait in line. It time-slices: all 16 are *concurrent* (in progress), but only 8 are *parallel* at any moment. Every thread gets a fair share, so they finish as a pack instead of in two waves.
   - Why worse than 2×? Half the cores are **E-cores**, roughly 2–3× slower. The run measured "alone" on a P-core. On top of that there are context switches and cache misses. Real hardware is never the clean model.

**Takeaway:** more threads than cores doesn't make anything faster. It gives you time-slicing overhead and more memory used by stacks. Keep this in mind: Swift's concurrency runtime is built on exactly this observation (P1.03).
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
[← Roadmap](../../README.md) · [P0.02 →](./02-data-race.md)
<!-- nav:end -->
