# P7.08 — Mock interview ⭐

<!-- nav:start -->
[← P7.07](./07-design-offline-sync.md) · [Roadmap →](../../README.md)
<!-- nav:end -->

⏱ 45–60 min (plan a longer session, or split it over two days)

The final session: a full mock interview with **Claude as the interviewer**. You answer in your own words, out loud or typed. No notes.

## How to start it

Open a fresh Claude Code session in this folder and paste:

> **"Run my P7.08 mock interview. Senior iOS, concurrency-focused. Use lessons/P7-interview/08-mock-interview.md for the format. Ask one question at a time, wait for my answer, push back with follow-ups like a real interviewer, don't give me the answer until I've tried, and score me at the end with the rubric."**

## Format (the interviewer follows this)

| Round | Time | Content |
|---|---|---|
| 1. Fundamentals | 10 min | 4–5 conceptual questions across P0–P3 (data race vs race condition, `await` semantics, cooperative pool, structured vs unstructured, cancellation) |
| 2. Swift 6 isolation | 10 min | Isolation domains, Sendable / `sending`, actor reentrancy, `nonisolated(nonsending)` vs `@concurrent`, MainActor-by-default, one compiler error to diagnose (P2.16 format) |
| 3. Output puzzle | 5 min | One new "what does this print?" (P7.02 format), solved out loud |
| 4. Live coding | 15 min | One kata variant (P4.04 / P4.07 / P7.03–P7.05 family), talking while you design |
| 5. Debugging | 10 min | A bug report from production (P5 format): your hypothesis, how you'd reproduce and prove it |
| 6. Design (optional) | 10 min | One part of P7.06 or P7.07 |

The interviewer should ask at least one **follow-up** per answer ("What if the task is cancelled there?", "Is that guaranteed or just likely?", "What does the compiler say?", "How would you test it?").

## Scoring rubric (the interviewer applies it at the end)

| Signal | Strong | Weak |
|---|---|---|
| Precision | Correct terms: isolation domain, suspension point, happens-before, region | Hand-waving: "it's on a background thread so it's fine" |
| Mechanism | Explains *why* (frames, executors, the cooperative pool's contract) | Recites rules without reasons |
| Guarantee vs observation | "The model guarantees…" / "that's not guaranteed" | "It worked when I tried it" |
| Failure modes | Brings up cancellation, reentrancy, ordering and leaks unprompted | Only the happy path |
| Code | Structured first, correct isolation, cancellation-aware, bounded | Detached tasks, `try?` sleeps, unbounded fan-out |
| Debugging | Reproduce → make deterministic → timeline → fix the cause → prove it | Adds sleeps or retries |
| Communication | Thinks out loud, states trade-offs, asks clarifying questions | Silent coding, or guessing |

Each signal is 0–2. **12+**: ready for senior concurrency interviews. **8–11**: almost there; redo the weak phase's review session. **< 8**: return to the ⭐ track.

## After the mock

1. Write down every question you hesitated on.
2. Find its lesson (the flashcards are grouped by lesson), redo that lesson's Predict and Explain sections, and say the card out loud three times.
3. Run another mock a week later with *"focus on my weak areas: …"*.

## Course complete 🎓

If you've done P0–P7, you have:
- first-principles knowledge of threads, races, locks, deadlocks and memory ordering;
- a working model of Swift concurrency from `await` down to executors, and from `Sendable` up to Swift 6.2's defaults;
- implementations of every classic concurrency primitive in async Swift;
- a debugging method and the tools for the hardest async bugs;
- interview practice under realistic conditions.

Keep `interview/flashcards.md` in rotation, re-run the marathons before interviews, and re-read Massicotte's [Problematic Swift Concurrency Patterns](https://massicotte.org/problematic-patterns/) every few months: the language keeps evolving, and so should your instincts.

---

<!-- nav:start -->
[← P7.07](./07-design-offline-sync.md) · [Roadmap →](../../README.md)
<!-- nav:end -->
