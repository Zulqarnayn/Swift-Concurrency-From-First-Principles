---
title: Home
template: home.html
---

# Swift concurrency, from first principles

You will learn Swift concurrency the way it actually sticks: by being wrong first. Each of the 86 sessions takes about half an hour. You read a short idea, predict what a small program will print, run it, and then explain the difference between what you expected and what happened. A failing test closes the session, and you make it pass.

The course starts below `async`, with threads, cores and a counter that loses 23,649 updates out of 400,000. It works up through actors, `Sendable` and structured concurrency, into real bug reports with no hints, and ends with the questions senior iOS interviews ask. Every number on these pages came from running the code.

[Start with the first session →](lessons/P0-foundations/01-threads-cores.md){ .start }

You need Xcode 26 or later (Swift 6.2). The labs are a Swift package; clone the [repository](https://github.com/Zulqarnayn/Swift-Concurrency-From-First-Principles) and run `swift run lab list` inside `ConcurrencyLab/` to see every demo.
