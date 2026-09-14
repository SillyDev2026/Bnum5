# Bnum v0.5.5

An update to the supplied v0.5.4 module. Existing function names, aliases, constants, and the `{sign, log10(abs(value))}` representation remain available. Standard arithmetic returns a fresh table; inputs are not modified.

## Changes

- Addition and subtraction use `math.exp(delta * LN10)` to calculate the magnitude ratio. Equal magnitudes with the same effective sign use the `log10(2)` identity.
- Near-cancellation subtraction uses a fifth-order Horner polynomial over a wider interval. Extremely small logarithm differences are evaluated in log space to avoid subnormal intermediate precision loss.
- Multiplication and division propagate NaN through the required exponent arithmetic, reducing repeated checks.
- Parsing retains the decimal scanner, including scientific exponents beyond normal floating-point range. Digit accumulation and the final log expression avoid unnecessary intermediate rounding.
- `ln` and `log2` operate directly on the stored logarithm. General `log` falls back to subtracting logarithms when its quotient overflows or underflows.
- Formatter precision is floored and clamped to 0–15; omitted or NaN precision uses 2. Scientific formatting uses the existing rounding-factor table.
- The last suffix now carries correctly into scientific notation. Logarithm formatting preserves huge finite exponents while rounding. `exp` canonicalizes zero at the negative overflow boundary.
- Five optional `Into` methods reuse caller-owned output tables without creating a result table or calling another Bnum arithmetic function.

## Replace the module

Paste `Bnum.lua` into your existing Bnum ModuleScript. Existing calls continue to work:

```lua
local Bnum = require(game.ReplicatedStorage.Bnum)
local coins = Bnum.fromString("1e1000")
local reward = Bnum.fromString("2.5e999")
local total = Bnum.add(coins, reward)
print(Bnum.formatScientific(total, 2)) -- 1.25e1000
```

## Reuse output tables in repeated calculations

```lua
local total = Bnum.fromString("1e1000")
local reward = Bnum.fromString("2.5e999")

Bnum.addInto(total, total, reward)
print(Bnum.formatScientific(total, 2)) -- 1.25e1000
```

| Function | Operation |
|---|---|
| `addInto(out, a, b)` | `out = a + b` |
| `subInto(out, a, b)` | `out = a - b` |
| `mulInto(out, a, b)` | `out = a * b` |
| `divInto(out, a, b)` | `out = a / b` |
| `powInto(out, a, power)` | `out = a ^ power`; power is a Lua number |

Each function returns `out`. It may be the same table as either input, including both inputs. Use a mutable Bnum value or `{0, 0}` for the output. Frozen constants such as `Bnum.zero` cannot be used as output tables. Shared references to an output table observe its changes.

## Run the checks in Roblox Studio

Create a folder in `ServerScriptService` containing:

- ModuleScript `Bnum`: paste `Bnum.lua`.
- ModuleScript `BnumOld`: paste `BnumOld.lua` (the supplied v0.5.4 baseline).
- Script `Regression`: paste `Regression.server.lua`.
- Script `Benchmark`: paste `Benchmark.server.lua`, initially disabled.

Run Regression first. Then disable Regression, enable Benchmark, and start a fresh server session. Avoid running other benchmarks simultaneously. Keep native code generation settings consistent between versions.

The benchmark alternates old/new order, warms up both functions, calibrates sample sizes, reports seven-round medians and spread, and yields between samples in Studio. A speedup above 1 means the new path is faster. The final five rows compare v0.5.5 ordinary calls against its reusable-output calls. Large spreads indicate noisy timings.

For standalone Luau, run the two `.server.lua` scripts from this directory with `luau -O2 --codegen`. Omit `--codegen` to test interpreted execution.

## Validation and limits

The module passed Luau static analysis and 137,613 regression checks in both interpreted and native standalone Luau. Checks cover the special-value matrix, randomized finite arithmetic, parsers, formatting, fresh-result identity, output/input aliasing, and 75 cancellation pairs computed independently with Python Decimal at 400-digit precision.

`BENCHMARK-RESULTS.txt` contains local standalone Luau measurements. Roblox Studio performance has not been measured here; use the included benchmark for your environment. Improvements vary by operation, and some compatibility fixes add a small cost.

Bnum remains a logarithmic floating-point library. It does not retain exact ordinary integers or arbitrary decimal precision, and cancellation cannot recover information already lost when constructing the operands. Inputs should be canonical values returned by the constructors, rather than manually malformed records.
