---
sidebar_position: 4
---

# Development

Project structure is simple. Roblox Studio is used as a dev environment. Development files are in [src/ReplicatedFirst/Modules](https://github.com/NightLapse-Studios/SerDesmond/tree/main/src/ReplicatedFirst/), including test files, the benchmark script, project dependencies (Squash for benchmarking), and the library itself.

A config file is at [src/ReplicatedFirst/Config.luau](https://github.com/NightLapse-Studios/SerDesmond/blob/main/src/ReplicatedFirst/Config.luau). It has a `Benchmarks` and `Testing` flag that are used to toggle the associated features when you run the project. The file inherits from LazyModule's config file as we use that to run our scripts/tests at runtime. Knowledge of LazyModules is not necessary, it simply works.
