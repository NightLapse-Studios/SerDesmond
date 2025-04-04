---
sidebar_position: 4
---

# Development

Project structure is simple. Roblox Studio is used as a dev environment. Development files are in [src/ReplicatedFirst/Modules](https://github.com/NightLapse-Studios/SerDesmond/tree/main/src/ReplicatedFirst/), including test files.

A config file is at [src/ReplicatedFirst/Config.luau](https://github.com/NightLapse-Studios/SerDesmond/blob/main/src/ReplicatedFirst/Config.luau). It has a `Benchmarks` and `Testing` flag that are used to toggle the associated features when you run the project. The file inherits from LazyModule's config file as we use that to run our scripts/tests at runtime. Knowledge of LazyModules is not necessary, it is just our test runner.

Note: the benchmarks thing has been scrapped for now. Anyone willing to set up some benchmarks with other libraries such as squash & blink would be appreciated. We would like to benchmark serdes speed, as well as performance, as well as compilation times.

Compiler internals are generally simple as well. Serdes performance and size are prioritized over compilation speed, but since compilation happens at runtime, it sometimes takes the cake.