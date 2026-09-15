# Bnum v1.4.0

**Bnum** is a high-performance big-number library for Roblox Luau built around a compact two-number logarithmic representation.

```text
Version:          1.4.0
Representation:   {sign, logMagnitude}
Value:            sign × 10^logMagnitude
Core API:         122 lowercase functions
Convenience API:  123 PascalCase functions
Total Public API: 245 functions
Compiler:         --!native + --!optimize 2
```

Bnum is designed for simulator, incremental, clicker, economy, damage, upgrade, leaderboard, and other Roblox systems that need values far beyond normal finite Luau display ranges while keeping arithmetic lightweight.

v1.4.0 keeps the optimized lowercase API intact and adds a complete PascalCase convenience layer. The new convenience functions automatically convert supported `number`, `string`, and Bnum-like table inputs so call sites no longer need to wrap every argument in `Bnum.convert(...)`.

---

## Highlights

- Compact `{sign, logMagnitude}` canonical representation.
- Numbers far beyond normal finite Luau range.
- Positive values, negative values, zero, infinity, negative infinity, and NaN.
- 122 lowercase core APIs for direct/hot-path work.
- 123 PascalCase convenience APIs for automatic input conversion.
- `Bnum.SubZ(...)` for subtract-and-clamp-to-zero behavior.
- Direct Bnum + number arithmetic.
- Allocation-saving `*Into` APIs.
- PascalCase `*Into` wrappers that convert inputs while reusing the output table.
- Fused `mulAdd` / `addMul` and `MulAdd` / `AddMul`.
- Square, cube, arbitrary roots, powers, logarithms, exponentials, and factorial.
- Decimal, scientific, and suffix string parsing.
- Standard suffix ladder through tier `999`.
- High exponent formatting such as `E100UCe` instead of nested `E1e308`.
- Extended, hybrid, alphabetic, metric, exponent, scientific, engineering, Roman, plain, comma, logarithm, and raw formatting.
- `--!native` and `--!optimize 2`.

---

# Installation

Place the ModuleScript somewhere accessible to your game code. A common layout is:

```text
ReplicatedStorage
└── Bnum
```

Require it:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage:WaitForChild("Bnum"))

print(Bnum.Version)
-- 1.4.0
```

---

# Quick Start

## Convenience API

For normal game code, v1.4.0 can convert supported inputs for you:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage:WaitForChild("Bnum"))

local coins = Bnum.Add(1000, "1.25M")
coins = Bnum.Mul(coins, 1.15)

print(Bnum.Format(coins, 2))
```

Mixed inputs work directly:

```lua
local a = Bnum.Add(10, "25")
local b = Bnum.Sub("100", 25)
local c = Bnum.Mul("12", 5)
local d = Bnum.Div("100", 4)

print(Bnum.ToNumber(a)) -- 35
print(Bnum.ToNumber(b)) -- 75
print(Bnum.ToNumber(c)) -- 60
print(Bnum.ToNumber(d)) -- 25
```

`SubZ` clamps negative subtraction results to zero:

```lua
print(Bnum.ToNumber(Bnum.SubZ(100, 25))) -- 75
print(Bnum.ToNumber(Bnum.SubZ(5, 10)))   -- 0
```

## Core API

The lowercase API remains unchanged and is still the preferred form when your values are already canonical Bnums:

```lua
local coins = Bnum.fromNumber(1000)
local reward = Bnum.fromString("1.25M")

coins = Bnum.add(coins, reward)

print(Bnum.format(coins, 2))
```

---

# Two API Layers

v1.4.0 intentionally exposes two layers.

## Lowercase core API

Examples:

```lua
Bnum.add(a, b)
Bnum.mul(a, b)
Bnum.sqrt(value)
Bnum.format(value, 2)
Bnum.addInto(out, a, b)
```

Use the lowercase API when:

- inputs are already Bnums,
- code is inside a hot loop,
- you want the least conversion overhead,
- or you need maximum control over allocations.

## PascalCase convenience API

Examples:

```lua
Bnum.Add(10, "25")
Bnum.Mul("1e100", 2)
Bnum.Sqrt("144")
Bnum.Eq(1000, "1e3")
Bnum.Format("1.25M", 2)
Bnum.AddInto(out, 10, "25")
```

Use the PascalCase API when:

- values may arrive as numbers, strings, or Bnum-like tables,
- cleaner call sites matter more than conversion overhead,
- data comes from configs, UI, DataStores, or external systems,
- or you do not want to repeatedly write `Bnum.convert(...)`.

Most value-taking PascalCase functions use the internal convenience converter. Unsupported values become NaN instead of causing the wrapper to immediately index `nil`.

`Bnum.Convert(...)` itself intentionally mirrors the lowercase `Bnum.convert(...)` contract and can still return `nil` for unsupported input types.

---

# How Bnum Stores Numbers

Internally, a canonical Bnum is:

```lua
{sign, logMagnitude}
```

where:

```text
sign         = -1, 0, or 1
logMagnitude = log10(abs(value))
value        = sign × 10^logMagnitude
```

Examples:

| Number | Canonical Bnum |
| ---: | --- |
| `0` | `{0, 0}` |
| `1` | `{1, 0}` |
| `10` | `{1, 1}` |
| `1000` | `{1, 3}` |
| `-1000` | `{-1, 3}` |
| `1e1000` | `{1, 1000}` |

This keeps enormous magnitudes compact. `1e1000` does not require one thousand decimal digits internally; the magnitude is represented by the log value `1000`.

---

# Canonical Form vs `{mantissa, exponent}`

The internal canonical form is:

```lua
{sign, logMagnitude}
```

The public scientific table form is:

```lua
{mantissa, exponent}
```

Example:

```lua
local value = Bnum.fromTable({9.5, 3})
local pair = Bnum.toTable(value)

print(pair[1], pair[2])
-- approximately: 9.5  3
```

The PascalCase equivalents are also available:

```lua
local value = Bnum.FromTable({9.5, 3})
local pair = Bnum.ToTable(value)
```

---

# Creating and Converting Values

Core constructors:

```lua
Bnum.new(9.5, 3)
Bnum.raw(1, 1000)
Bnum.fromNumber(125000)
Bnum.fromTable({9.5, 3})
Bnum.fromScientific(1.25, 1000)
Bnum.fromLog10(1000)
Bnum.pow10(5000)
Bnum.fromString("1.25M")
```

Convenience names:

```lua
Bnum.New(9.5, 3)
Bnum.Raw(1, 1000)
Bnum.FromNumber(125000)
Bnum.FromTable({9.5, 3})
Bnum.FromScientific(1.25, 1000)
Bnum.FromLog10(1000)
Bnum.Pow10(5000)
Bnum.FromString("1.25M")
```

Supported string examples:

```lua
Bnum.FromString("1000")
Bnum.FromString("123.456")
Bnum.FromString("1e250")
Bnum.FromString("-5.25e100")
Bnum.FromString("1.25M")
Bnum.FromString("5Qa")
Bnum.FromString("inf")
Bnum.FromString("-inf")
Bnum.FromString("nan")
```

Do not create huge native values first:

```lua
-- Wrong: native overflow happens before Bnum receives the value.
Bnum.FromNumber(10 ^ 1000)

-- Correct:
Bnum.Pow10(1000)
Bnum.FromString("1e1000")
```

---

# Convenience Arithmetic

The major convenience arithmetic functions are:

```lua
Bnum.Add(a, b)
Bnum.Sub(a, b)
Bnum.SubZ(a, b)
Bnum.Mul(a, b)
Bnum.Div(a, b)

Bnum.AddNumber(value, number)
Bnum.SubNumber(value, number)
Bnum.MulNumber(value, number)
Bnum.DivNumber(value, number)

Bnum.Scale10(value, exponent)
Bnum.Square(value)
Bnum.Cube(value)

Bnum.MulAdd(a, b, c)
Bnum.AddMul(a, b, c)

Bnum.Reciprocal(value)
Bnum.Pow(value, power)
Bnum.Sqrt(value)
Bnum.Cbrt(value)
Bnum.Root(value, degree)
Bnum.Abs(value)
Bnum.Neg(value)
```

Examples:

```lua
local total = Bnum.Add("1e100", "2e100")
local damage = Bnum.MulAdd(25, 15, 100)
local root = Bnum.Sqrt("144")
local clamped = Bnum.SubZ(5, 10)

print(Bnum.Format(total, 2))
print(Bnum.ToNumber(damage))  -- 475
print(Bnum.ToNumber(root))    -- 12
print(Bnum.ToNumber(clamped)) -- 0
```

---

# Advanced Math

Both layers expose logarithmic and exponential helpers:

```lua
Bnum.Log10(value)
Bnum.Ln(value)
Bnum.Log2(value)
Bnum.Log(value, base)

Bnum.Exp(value)
Bnum.Exp10(value)
Bnum.Exp2(value)

Bnum.PowValue(value, power)
Bnum.Log1p(value)
Bnum.Expm1(value)
Bnum.Hypot(a, b)
Bnum.Factorial(value)
```

Example:

```lua
print(Bnum.ToNumber(Bnum.Log10(1000))) -- 3
print(Bnum.ToNumber(Bnum.Log2(1024)))  -- 10
print(Bnum.ToNumber(Bnum.Exp10(3)))    -- 1000
print(Bnum.ToNumber(Bnum.Hypot(3, 4))) -- 5
```

---

# Comparison and Selection

Convenience comparisons accept mixed supported values:

```lua
Bnum.Compare(a, b)

Bnum.Eq(a, b)
Bnum.Neq(a, b)
Bnum.Lt(a, b)
Bnum.Lte(a, b)
Bnum.Gt(a, b)
Bnum.Gte(a, b)

Bnum.Min(a, b, ...)
Bnum.Max(a, b, ...)
Bnum.Clamp(value, minimum, maximum)
```

Examples:

```lua
print(Bnum.Eq(1000, "1e3")) -- true
print(Bnum.Lt("5", 10))     -- true

local smallest = Bnum.Min(10, "2", 5)
local largest = Bnum.Max(10, "2", 5)
local clamped = Bnum.Clamp("15", 0, "10")
```

`Bnum.Compare(a, b)` returns:

```text
-1   a < b
 0   a == b
 1   a > b
nil  comparison contains NaN
```

---

# Rounding, Range, and Utility Math

Convenience helpers include:

```lua
Bnum.Floor(value)
Bnum.Ceil(value)
Bnum.Round(value, digits?)
Bnum.Mod(a, b)
Bnum.Trunc(value)
Bnum.Fract(value)

Bnum.IsInteger(value)
Bnum.Between(value, minimum, maximum)

Bnum.Distance(a, b)
Bnum.RelativeDifference(a, b)
Bnum.ApproxEq(a, b, relTolerance?, absTolerance?)

Bnum.Lerp(a, b, alpha)
Bnum.InverseLerp(a, b, value)
Bnum.Remap(value, inMin, inMax, outMin, outMax)

Bnum.Sum(values)
Bnum.Product(values)
Bnum.Mean(values)

Bnum.Percent(part, whole)
Bnum.PercentChange(oldValue, newValue)
```

Array helpers convert every element:

```lua
local total = Bnum.Sum({1, "2", 3, "4"})
local product = Bnum.Product({2, "3", 4})
local average = Bnum.Mean({2, "4", 6})

print(Bnum.ToNumber(total))   -- 10
print(Bnum.ToNumber(product)) -- 24
print(Bnum.ToNumber(average)) -- 4
```

---

# Value Checks

Convenience checks accept supported mixed inputs:

```lua
Bnum.IsZero(value)
Bnum.IsNaN(value)
Bnum.IsInfinite(value)
Bnum.IsFinite(value)
Bnum.IsPositive(value)
Bnum.IsNegative(value)
Bnum.Sign(value)
```

Examples:

```lua
print(Bnum.IsPositive("5")) -- true
print(Bnum.IsNegative(-5))  -- true
print(Bnum.Sign("-5"))      -- -1
```

---

# Formatting

v1.4.0 keeps the v1.3.3 formatting system and exposes both lowercase and PascalCase entry points.

Defaults:

```text
Default format:     standard
Default precision:  2 decimal places
Maximum precision:  8 decimal places
E-notation start:   3000
```

Primary format names:

```text
standard
extended
hybrid
alphabetic
metric
exponent
scientific
engineering
roman
romanextended
plain
comma
logarithm
raw
```

Examples:

```lua
local value = "1.2345e12"

print(Bnum.Format(value))
print(Bnum.Format(value, 2))
print(Bnum.Format(value, 2, "standard"))
print(Bnum.Format(value, 2, "scientific"))
print(Bnum.Format(value, 2, "engineering"))
print(Bnum.Format(value, 2, "comma"))
```

Dedicated convenience formatters include:

```lua
Bnum.FormatStandard(value, digits?)
Bnum.FormatExtended(value, digits?)
Bnum.FormatHybrid(value, digits?)
Bnum.FormatAlphabetic(value, digits?)
Bnum.FormatMetric(value, digits?)
Bnum.FormatExponent(value, digits?)
Bnum.FormatScientific(value, digits?)
Bnum.FormatEngineering(value, digits?)
Bnum.FormatRoman(value, digits?)
Bnum.FormatRomanExtended(value, digits?)
Bnum.FormatSuffix(value, digits?)
Bnum.FormatSuffixLong(value, digits?)
Bnum.FormatPlain(value, digits?)
Bnum.FormatComma(value, digits?)
Bnum.FormatLogarithm(value, digits?)
Bnum.FormatRaw(value)
Bnum.AutoFormat(value, digits?, options?)
```

## High exponent suffix formatting

The standard suffix ladder extends through tier `999`.

Important tiers include:

```text
tier 101 -> Ce
tier 102 -> UCe
tier 103 -> DCe
```

That keeps exponent displays compact:

```text
logMagnitude = 1e305 -> E100Ce
logMagnitude = 1e306 -> E1UCe
logMagnitude = 1e307 -> E10UCe
logMagnitude = 1e308 -> E100UCe
```

instead of falling back to nested scientific text such as `E1e308`.

---

# Reusable Output / `Into`

The lowercase `*Into` functions remain the fastest choice when inputs are already Bnums:

```lua
local out = {0, 0}

Bnum.addInto(out, a, b)
Bnum.mulInto(out, a, b)
Bnum.mulNumberInto(out, a, 1.15)
```

v1.4.0 also adds PascalCase convenience wrappers:

```lua
local out = {0, 0}

Bnum.AddInto(out, 10, "25")
Bnum.MulInto(out, "1e100", 2)
Bnum.MulAddInto(out, 2, "3", 4)
```

The output table is reused directly; only the value inputs are automatically converted.

For maximum throughput in a hot loop, prefer the lowercase form:

```lua
local current = Bnum.fromString("1e100")
local out = {0, 0}

for _ = 1, 100000 do
	Bnum.mulNumberInto(out, current, 1.01)
	current, out = out, current
end
```

---

# Performance Guidelines

For fastest practical Bnum code:

1. Keep values in canonical Bnum form during repeated calculations.
2. Use the lowercase core API when inputs are already Bnums.
3. Use PascalCase convenience APIs at boundaries where inputs may be numbers, strings, or public tables.
4. Do not repeatedly auto-convert the same value inside a tight loop if you can convert it once.
5. Prefer `addNumber`, `subNumber`, `mulNumber`, and `divNumber` when the second operand is already a normal number.
6. Prefer `scale10`, `square`, and `cube` over composing generic operations.
7. Use `mulAdd` and `addMul` when the formula matches.
8. Use `*Into` functions where allocation pressure is measurable.
9. Avoid formatting inside tight simulation loops; format when updating UI.
10. Use `fromString`, `pow10`, or scientific constructors for magnitudes that cannot first exist as finite native numbers.

The convenience layer prioritizes call-site ergonomics. It is not intended to replace the lowercase API in performance-critical loops.

---

# Example: Clicker Currency

Convenience-first version:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage:WaitForChild("Bnum"))

local coins = Bnum.zero
local clickPower = Bnum.FromNumber(1)

local function click()
	coins = Bnum.Add(coins, clickPower)
	print("Coins:", Bnum.Format(coins, 2))
end

for _ = 1, 10 do
	click()
end
```

For a hot click loop, keep the values canonical and use lowercase arithmetic:

```lua
local coins = Bnum.zero
local clickPower = Bnum.fromNumber(1)
local out = {0, 0}

for _ = 1, 100000 do
	Bnum.addInto(out, coins, clickPower)
	coins, out = out, coins
end
```

---

# Example: Upgrade Cost

```lua
local baseCost = Bnum.FromNumber(100)
local growth = Bnum.FromNumber(1.15)

local function getUpgradeCost(level: number)
	return Bnum.Mul(baseCost, Bnum.Pow(growth, level))
end

for level = 0, 10 do
	print(level, Bnum.Format(getUpgradeCost(level), 2))
end
```

A faster repeated-growth path can still use the lower-level number API:

```lua
local cost = Bnum.fromString("1e100")
local growth = 1.15

for _ = 1, 100 do
	cost = Bnum.mulNumber(cost, growth)
end
```

---

# Example: Progress Bar

```lua
local minimum = 0
local maximum = "1e100"
local current = "5e99"

local alpha = Bnum.InverseLerp(minimum, maximum, current)
local alphaNumber = Bnum.ToNumber(alpha)

progressBar.Size = UDim2.fromScale(
	math.clamp(alphaNumber, 0, 1),
	1
)
```

---

# Special Values

Bnum includes immutable predefined values:

```lua
Bnum.zero
Bnum.one
Bnum.two
Bnum.half
Bnum.ten
Bnum.e
Bnum.inf
Bnum.ninf
Bnum.nan
```

Check values with either API layer:

```lua
Bnum.isInfinite(value)
Bnum.isNaN(value)
Bnum.isFinite(value)

Bnum.IsInfinite(value)
Bnum.IsNaN(value)
Bnum.IsFinite(value)
```

---

# Accuracy Model

Bnum is a **magnitude-oriented floating-point big-number system**.

It is not an arbitrary-precision decimal integer library.

It is well suited for values such as:

```text
7.25e5000
1.93e850
4.12e100000
```

where useful magnitude and floating-point precision matter more than retaining every decimal digit.

Bnum is not intended for cryptographic arithmetic or exact arbitrary-length integer accounting.

---

# Recommended Data Flow

For convenience-oriented code:

```text
DataStore / config / UI input
        ↓
number / string / {mantissa, exponent}
        ↓
PascalCase convenience API
        ↓
canonical {sign, logMagnitude}
        ↓
game calculations
        ↓
Bnum.Format(...)
        ↓
player UI
```

For performance-oriented code:

```text
input
  ↓
convert once
  ↓
canonical Bnum
  ↓
lowercase core / Into hot paths
  ↓
format only when needed
```

---

# Core API Reference

The lowercase API is the direct, performance-oriented layer.


## Construction and Conversion

| Function | Purpose |
| --- | --- |
| `Bnum.new(man: number?, exp: number?): Value` | Creates a Bnum from a mantissa and a base-10 exponent. |
| `Bnum.raw(sign: number, logMagnitude: number): Value` | Creates a canonical Bnum directly from a sign and log10 magnitude. |
| `Bnum.clone(val: Value): Value` | Returns a new table containing the same Bnum value. |
| `Bnum.read(val: Value): (number, number)` | Returns the raw sign and log10 magnitude stored in a Bnum. |
| `Bnum.fromNumber(n: number): Value` | Converts a normal Luau number into a Bnum. |
| `Bnum.fromTable(val: {any}): Value` | Converts a public {mantissa, exponent} table into the internal canonical Bnum. |
| `Bnum.toTable(val: Value): Value` | Returns a normalized public {mantissa, exponent} table. |
| `Bnum.normalize(val: Value): Value` | Normalizes either a canonical Bnum or a public {mantissa, exponent} pair. |
| `Bnum.isValid(val: any): boolean` | Checks whether a two-number table can be converted into a Bnum. |
| `Bnum.convert(val: any): Value?` | Converts a number, string, canonical Bnum, or {mantissa, exponent} table into a Bnum. |
| `Bnum.fromScientific(man: number, exp: number): Value` | Creates a Bnum from scientific mantissa × 10^exponent form. |
| `Bnum.fromLog10(logMagnitude: number, sign: number?): Value` | Creates a Bnum directly from log10(abs(value)) and an optional sign. |
| `Bnum.pow10(exp: number): Value` | Creates 10 raised to a normal numeric exponent. |
| `Bnum.fromString(str: string): Value` | Parses decimal, scientific, infinity, NaN, and supported suffix strings. |
| `Bnum.toNumber(val: Value): number` | Converts a Bnum back to a normal Luau number when representable. |
| `Bnum.toScientific(val: Value): (number, number)` | Returns a normal scientific mantissa and exponent pair. |
| `Bnum.mantissa(val: Value): number` | Returns the signed scientific mantissa of a Bnum. |
| `Bnum.exponent(val: Value): number` | Returns the base-10 scientific exponent of a Bnum. |
| `Bnum.toString(val: Value): string` |  |


## Core Arithmetic

| Function | Purpose |
| --- | --- |
| `Bnum.add(val1: Value, val2: Value): Value` | Adds two Bnums using direct log-space arithmetic. |
| `Bnum.sub(val1: Value, val2: Value): Value` | Subtracts the second Bnum from the first using direct log-space arithmetic. |
| `Bnum.mul(val1: Value, val2: Value): Value` | Multiplies two Bnums by multiplying signs and adding log magnitudes. |
| `Bnum.div(val1: Value, val2: Value): Value` | Divides the first Bnum by the second using direct log-space arithmetic. |
| `Bnum.addNumber(val: Value, n: number): Value` | Adds a normal Luau number directly to a Bnum without creating a temporary Bnum. |
| `Bnum.subNumber(val: Value, n: number): Value` | Subtracts a normal Luau number directly from a Bnum. |
| `Bnum.mulNumber(val: Value, n: number): Value` | Multiplies a Bnum directly by a normal Luau number. |
| `Bnum.divNumber(val: Value, n: number): Value` | Divides a Bnum directly by a normal Luau number. |
| `Bnum.scale10(val: Value, exponent: number): Value` | Multiplies a Bnum by 10^exponent by shifting its log magnitude. |
| `Bnum.square(val: Value): Value` | Squares a Bnum using the direct log identity log10(x²) = 2 log10(x). |
| `Bnum.cube(val: Value): Value` | Cubes a Bnum using the direct log identity log10(x³) = 3 log10(x). |
| `Bnum.mulAdd(a: Value, b: Value, c: Value): Value` | Computes a × b + c in one fused Bnum operation. |
| `Bnum.addMul(a: Value, b: Value, c: Value): Value` | Computes a + b × c in one fused Bnum operation. |
| `Bnum.reciprocal(val: Value): Value` | Returns 1 / value by negating the stored log magnitude. |
| `Bnum.pow(val: Value, power: number): Value` | Raises a Bnum to a normal numeric power. |
| `Bnum.sqrt(val: Value): Value` | Returns the real square root of a non-negative Bnum. |
| `Bnum.cbrt(val: Value): Value` | Returns the real cube root of a Bnum, including negative values. |
| `Bnum.root(val: Value, degree: number): Value` | Returns the real nth root of a Bnum when the requested root is defined. |
| `Bnum.abs(val: Value): Value` | Returns the absolute value of a Bnum. |
| `Bnum.neg(val: Value): Value` | Negates the sign of a Bnum. |


## Logs, Exponentials, and Advanced Math

| Function | Purpose |
| --- | --- |
| `Bnum.log10(val: Value): Value` | Returns the base-10 logarithm of a positive Bnum as another Bnum. |
| `Bnum.ln(val: Value): Value` | Returns the natural logarithm of a positive Bnum. |
| `Bnum.log2(val: Value): Value` | Returns the base-2 logarithm of a positive Bnum. |
| `Bnum.log(val: Value, base: Value): Value` | Returns the logarithm of a value in an arbitrary positive base other than 1. |
| `Bnum.exp(val: Value): Value` | Returns e^value while preserving Bnum overflow and underflow behavior. |
| `Bnum.exp10(val: Value): Value` | Returns 10^value where value itself is a Bnum. |
| `Bnum.exp2(val: Value): Value` | Returns 2^value where value itself is a Bnum. |
| `Bnum.powValue(val: Value, power: Value): Value` | Raises a Bnum to a power that is also stored as a Bnum. |
| `Bnum.log1p(val: Value): Value` | Computes ln(1 + x) with extra care for tiny x values. |
| `Bnum.expm1(val: Value): Value` | Computes e^x - 1 with extra care for tiny x values. |
| `Bnum.hypot(a: Value, b: Value): Value` | Computes sqrt(a² + b²) in Bnum space. |
| `Bnum.factorial(val: Value): Value` | Computes n! for non-negative integer Bnum inputs. |


## Comparison and Selection

| Function | Purpose |
| --- | --- |
| `Bnum.compare(val1: Value, val2: Value): number?` | Compares two Bnums and returns -1, 0, or 1. |
| `Bnum.eq(val1: Value, val2: Value): boolean` | Returns true when two Bnums represent exactly the same canonical value. |
| `Bnum.neq(val1: Value, val2: Value): boolean` | Returns true when two Bnums represent different canonical values. |
| `Bnum.lt(val1: Value, val2: Value): boolean` | Returns true when the first Bnum is less than the second. |
| `Bnum.lte(val1: Value, val2: Value): boolean` | Returns true when the first Bnum is less than or equal to the second. |
| `Bnum.gt(val1: Value, val2: Value): boolean` | Returns true when the first Bnum is greater than the second. |
| `Bnum.gte(val1: Value, val2: Value): boolean` | Returns true when the first Bnum is greater than or equal to the second. |
| `Bnum.min(val1: Value, val2: Value?, ...: Value): Value` | Returns the smallest Bnum from the supplied values. |
| `Bnum.max(val1: Value, val2: Value?, ...: Value): Value` | Returns the largest Bnum from the supplied values. |
| `Bnum.clamp(val: Value, minimum: Value, maximum: Value): Value` | Clamps a Bnum between a minimum and maximum value. |


## Rounding, Range, and Utility Math

| Function | Purpose |
| --- | --- |
| `Bnum.floor(val: Value): Value` | Rounds a Bnum down toward negative infinity. |
| `Bnum.ceil(val: Value): Value` | Rounds a Bnum up toward positive infinity. |
| `Bnum.round(val: Value, digits: number?): Value` | Rounds a Bnum to the requested decimal digit count. |
| `Bnum.mod(val1: Value, val2: Value): Value` | Returns the remainder of integer-style division between two Bnums. |
| `Bnum.trunc(val: Value): Value` | Removes the fractional part of a Bnum by rounding toward zero. |
| `Bnum.fract(val: Value): Value` | Returns only the signed fractional part using direct inline math. |
| `Bnum.isInteger(val: Value): boolean` | Checks whether a finite Bnum represents an exact integer in the supported precision range. |
| `Bnum.between(val: Value, minimum: Value, maximum: Value): boolean` | Checks whether a Bnum lies inclusively between two bounds. |
| `Bnum.distance(a: Value, b: Value): Value` | Returns the absolute distance between two Bnums. |
| `Bnum.relativeDifference(a: Value, b: Value): Value` | Returns the absolute difference relative to the larger absolute input. |
| `Bnum.approxEq(a: Value, b: Value, relTolerance: number?, absTolerance: number?): boolean` | Checks approximate equality using relative and absolute tolerances. |
| `Bnum.lerp(a: Value, b: Value, alpha: number): Value` | Linearly interpolates between two Bnums using a normal numeric alpha. |
| `Bnum.inverseLerp(a: Value, b: Value, val: Value): Value` | Returns the interpolation alpha of a value between two Bnum endpoints. |
| `Bnum.remap(val: Value, inMin: Value, inMax: Value, outMin: Value, outMax: Value): Value` | Maps a Bnum from one numeric range into another range. |
| `Bnum.sum(values: {Value}): Value` | Adds every Bnum in an array using an inline accumulator. |
| `Bnum.product(values: {Value}): Value` | Multiplies every Bnum in an array using an inline accumulator. |
| `Bnum.mean(values: {Value}): Value` | Returns the arithmetic mean of all Bnums in an array. |
| `Bnum.percent(part: Value, whole: Value): Value` | Returns part / whole × 100 as a Bnum. |
| `Bnum.percentChange(oldValue: Value, newValue: Value): Value` | Returns the percentage change from an old Bnum to a new Bnum. |


## Checks

| Function | Purpose |
| --- | --- |
| `Bnum.isZero(val: Value): boolean` | Checks whether a Bnum is canonical zero. |
| `Bnum.isNaN(val: Value): boolean` | Checks whether a Bnum stores NaN. |
| `Bnum.isInfinite(val: Value): boolean` | Checks whether a Bnum represents positive or negative infinity. |
| `Bnum.isFinite(val: Value): boolean` | Checks whether a Bnum is finite and not NaN. |
| `Bnum.isPositive(val: Value): boolean` | Checks whether a Bnum is strictly greater than zero. |
| `Bnum.isNegative(val: Value): boolean` | Checks whether a Bnum is strictly less than zero. |
| `Bnum.sign(val: Value): number` | Returns -1, 0, or 1 for the Bnum sign. |


## Formatting

| Function | Purpose |
| --- | --- |
| `Bnum.getSuffix(tier: number): string?` | Returns the suffix used by the standard formatter through tier 999. |
| `Bnum.isFormatType(formatType: string): boolean` | Checks whether a formatter notation name is supported. |
| `Bnum.setDefaultFormat(formatType: string): boolean` | Sets the default notation used by Bnum.format(). |
| `Bnum.format(val: Value, decimalPlaces: number?, formatType: FormatType?): string` | NanoNum-style default formatter. |
| `Bnum.formatStandard(val: Value, decimalPlaces: number?): string` | Formats with the standard suffix ladder. |
| `Bnum.formatExtended(val: Value, decimalPlaces: number?): string` | Formats with standard suffixes through Ce, then alphabetic suffixes through tier 999. |
| `Bnum.formatHybrid(val: Value, decimalPlaces: number?): string` | Formats with standard suffixes first and alphabetic suffixes beyond the standard ladder. |
| `Bnum.formatAlphabetic(val: Value, decimalPlaces: number?): string` | Formats 10^3 tiers as aa, ab, ac, ... |
| `Bnum.formatMetric(val: Value, decimalPlaces: number?): string` | Formats using SI-style metric suffixes k, M, G, T, ... |
| `Bnum.formatExponent(val: Value, decimalPlaces: number?): string` | Formats as mantissa E exponent. |
| `Bnum.formatScientific(val: Value, decimalPlaces: number?): string` | Formats in scientific notation. |
| `Bnum.formatEngineering(val: Value, decimalPlaces: number?): string` | Formats in engineering notation. |
| `Bnum.formatRoman(val: Value, decimalPlaces: number?): string` | Formats exact integers as classical Roman numerals when possible. |
| `Bnum.formatRomanExtended(val: Value, decimalPlaces: number?): string` | Formats exact integers with parenthesized extended Roman numerals. |
| `Bnum.formatSuffix(val: Value, decimalPlaces: number?): string` | Legacy alias for the standard suffix formatter. |
| `Bnum.formatSuffixLong(val: Value, decimalPlaces: number?): string` | Legacy long-name suffix formatter. |
| `Bnum.formatPlain(val: Value, decimalPlaces: number?): string` | Formats as a fixed decimal when representable. |
| `Bnum.formatComma(val: Value, decimalPlaces: number?): string` | Formats normal-sized values with comma grouping. |
| `Bnum.formatLogarithm(val: Value, decimalPlaces: number?): string` | Formats as 10^logMagnitude. |
| `Bnum.formatRaw(val: Value): string` | Returns the raw {sign, logMagnitude} representation. |
| `Bnum.autoFormat(val: Value, digits: number?, options: AutoFormatOptions?): string` | Compatibility entry point. The NanoNum-style standard formatter is now the default. |


## Reusable Output / Into

| Function | Purpose |
| --- | --- |
| `Bnum.addInto(out: Value, val1: Value, val2: Value): Value` | Adds two Bnums and writes the result into an existing output table. |
| `Bnum.subInto(out: Value, val1: Value, val2: Value): Value` | Subtracts two Bnums and writes the result into an existing output table. |
| `Bnum.mulInto(out: Value, val1: Value, val2: Value): Value` | Multiplies two Bnums and writes the result into an existing output table. |
| `Bnum.divInto(out: Value, val1: Value, val2: Value): Value` | Divides two Bnums and writes the result into an existing output table. |
| `Bnum.powInto(out: Value, val: Value, power: number): Value` | Raises a Bnum to a numeric power and writes into an existing output table. |
| `Bnum.addNumberInto(out: Value, val: Value, n: number): Value` | Adds a normal number to a Bnum and writes into an existing output table. |
| `Bnum.subNumberInto(out: Value, val: Value, n: number): Value` | Subtracts a normal number from a Bnum and writes into an existing output table. |
| `Bnum.mulNumberInto(out: Value, val: Value, n: number): Value` | Multiplies a Bnum by a normal number and writes into an existing output table. |
| `Bnum.divNumberInto(out: Value, val: Value, n: number): Value` | Divides a Bnum by a normal number and writes into an existing output table. |
| `Bnum.scale10Into(out: Value, val: Value, exponent: number): Value` | Scales a Bnum by 10^exponent and writes into an existing output table. |
| `Bnum.squareInto(out: Value, val: Value): Value` | Squares a Bnum and writes into an existing output table. |
| `Bnum.cubeInto(out: Value, val: Value): Value` | Cubes a Bnum and writes into an existing output table. |
| `Bnum.mulAddInto(out: Value, a: Value, b: Value, c: Value): Value` | Computes a × b + c directly into an existing output table. |
| `Bnum.addMulInto(out: Value, a: Value, b: Value, c: Value): Value` | Computes a + b × c directly into an existing output table. |


---

# PascalCase Convenience API Reference

The PascalCase layer keeps the same feature set while converting supported Bnum-value inputs automatically.

`SubZ` is the one additional convenience-only operation; it subtracts and clamps negative results to `Bnum.zero`.


## Construction and Conversion

| Convenience API | Core counterpart | Purpose |
| --- | --- | --- |
| `Bnum.New(man: number?, exp: number?): Value` | `Bnum.new` | Creates a Bnum from a mantissa and base-10 exponent. |
| `Bnum.Raw(sign: number, logMagnitude: number): Value` | `Bnum.raw` | Creates a canonical Bnum directly from sign and log10 magnitude. |
| `Bnum.Clone(value: any): Value` | `Bnum.clone` | Clones any supported Bnum input after converting it automatically. |
| `Bnum.Read(value: any): (number, number)` | `Bnum.read` | Reads the canonical sign and log10 magnitude from any supported input. |
| `Bnum.FromNumber(value: number): Value` | `Bnum.fromNumber` | Creates a Bnum from a normal Luau number. |
| `Bnum.FromTable(value: {any}): Value` | `Bnum.fromTable` | Creates a Bnum from a public {mantissa, exponent} table. |
| `Bnum.ToTable(value: any): Value` | `Bnum.toTable` | Converts any supported input and returns a normalized public {mantissa, exponent} table. |
| `Bnum.Normalize(value: any): Value` | `Bnum.normalize` | Normalizes any supported Bnum input. |
| `Bnum.IsValid(value: any): boolean` | `Bnum.isValid` | Checks whether a value is a valid Bnum-compatible table. |
| `Bnum.Convert(value: any): Value?` | `Bnum.convert` | Converts a number, string, or table into a canonical Bnum. |
| `Bnum.FromScientific(man: number, exp: number): Value` | `Bnum.fromScientific` | Creates a Bnum from scientific mantissa × 10^exponent form. |
| `Bnum.FromLog10(logMagnitude: number, sign: number?): Value` | `Bnum.fromLog10` | Creates a Bnum directly from log10 magnitude and an optional sign. |
| `Bnum.Pow10(exponent: number): Value` | `Bnum.pow10` | Creates 10^exponent directly. |
| `Bnum.FromString(value: string): Value` | `Bnum.fromString` | Parses a string into a Bnum. |
| `Bnum.ToNumber(value: any): number` | `Bnum.toNumber` | Converts any supported input back to a normal Luau number when representable. |
| `Bnum.ToScientific(value: any): (number, number)` | `Bnum.toScientific` | Returns the scientific mantissa and exponent for any supported input. |
| `Bnum.Mantissa(value: any): number` | `Bnum.mantissa` | Returns the scientific mantissa for any supported input. |
| `Bnum.Exponent(value: any): number` | `Bnum.exponent` | Returns the scientific exponent for any supported input. |
| `Bnum.ToString(value: any): string` | `Bnum.toString` | Serializes any supported input to Bnum scientific text. |


## Core Arithmetic

| Convenience API | Core counterpart | Purpose |
| --- | --- | --- |
| `Bnum.Add(a: any, b: any): Value` | `Bnum.add` | Adds two supported values without requiring Bnum.convert at the call site. |
| `Bnum.Sub(a: any, b: any): Value` | `Bnum.sub` | Subtracts b from a after converting both inputs automatically. |
| `Bnum.SubZ(a: any, b: any): Value` | custom | Subtracts b from a and clamps negative results to zero. |
| `Bnum.Mul(a: any, b: any): Value` | `Bnum.mul` | Multiplies two supported values after converting both inputs automatically. |
| `Bnum.Div(a: any, b: any): Value` | `Bnum.div` | Divides a by b after converting both inputs automatically. |
| `Bnum.AddNumber(value: any, n: number): Value` | `Bnum.addNumber` | Adds a normal Luau number to any supported Bnum input. |
| `Bnum.SubNumber(value: any, n: number): Value` | `Bnum.subNumber` | Subtracts a normal Luau number from any supported Bnum input. |
| `Bnum.MulNumber(value: any, n: number): Value` | `Bnum.mulNumber` | Multiplies any supported Bnum input by a normal Luau number. |
| `Bnum.DivNumber(value: any, n: number): Value` | `Bnum.divNumber` | Divides any supported Bnum input by a normal Luau number. |
| `Bnum.Scale10(value: any, exponent: number): Value` | `Bnum.scale10` | Multiplies any supported input by 10^exponent. |
| `Bnum.Square(value: any): Value` | `Bnum.square` | Squares any supported input. |
| `Bnum.Cube(value: any): Value` | `Bnum.cube` | Cubes any supported input. |
| `Bnum.MulAdd(a: any, b: any, c: any): Value` | `Bnum.mulAdd` | Computes a × b + c after converting all three inputs automatically. |
| `Bnum.AddMul(a: any, b: any, c: any): Value` | `Bnum.addMul` | Computes a + b × c after converting all three inputs automatically. |
| `Bnum.Reciprocal(value: any): Value` | `Bnum.reciprocal` | Returns 1 / value after converting the input automatically. |
| `Bnum.Pow(value: any, power: number): Value` | `Bnum.pow` | Raises any supported input to a normal numeric power. |
| `Bnum.Sqrt(value: any): Value` | `Bnum.sqrt` | Returns the square root of any supported input. |
| `Bnum.Cbrt(value: any): Value` | `Bnum.cbrt` | Returns the real cube root of any supported input. |
| `Bnum.Root(value: any, degree: number): Value` | `Bnum.root` | Returns the real nth root of any supported input. |
| `Bnum.Abs(value: any): Value` | `Bnum.abs` | Returns the absolute value of any supported input. |
| `Bnum.Neg(value: any): Value` | `Bnum.neg` | Negates any supported input. |


## Logs, Exponentials, and Advanced Math

| Convenience API | Core counterpart | Purpose |
| --- | --- | --- |
| `Bnum.Log10(value: any): Value` | `Bnum.log10` | Returns log10(value) after converting the input automatically. |
| `Bnum.Ln(value: any): Value` | `Bnum.ln` | Returns the natural logarithm of any supported input. |
| `Bnum.Log2(value: any): Value` | `Bnum.log2` | Returns log2(value) after converting the input automatically. |
| `Bnum.Log(value: any, base: any): Value` | `Bnum.log` | Returns log_base(value) after converting both value and base automatically. |
| `Bnum.Exp(value: any): Value` | `Bnum.exp` | Returns e^value after converting the input automatically. |
| `Bnum.Exp10(value: any): Value` | `Bnum.exp10` | Returns 10^value where value can be any supported Bnum input. |
| `Bnum.Exp2(value: any): Value` | `Bnum.exp2` | Returns 2^value where value can be any supported Bnum input. |
| `Bnum.PowValue(value: any, power: any): Value` | `Bnum.powValue` | Raises value to a power that can also be a Bnum/string/number input. |
| `Bnum.Log1p(value: any): Value` | `Bnum.log1p` | Computes ln(1 + value) after converting the input automatically. |
| `Bnum.Expm1(value: any): Value` | `Bnum.expm1` | Computes e^value - 1 after converting the input automatically. |
| `Bnum.Hypot(a: any, b: any): Value` | `Bnum.hypot` | Computes sqrt(a^2 + b^2) after converting both inputs automatically. |
| `Bnum.Factorial(value: any): Value` | `Bnum.factorial` | Computes factorial(value) after converting the input automatically. |


## Comparison and Selection

| Convenience API | Core counterpart | Purpose |
| --- | --- | --- |
| `Bnum.Compare(a: any, b: any): number?` | `Bnum.compare` | Compares two supported values and returns -1, 0, or 1 when comparable. |
| `Bnum.Eq(a: any, b: any): boolean` | `Bnum.eq` | Checks exact Bnum equality after converting both inputs automatically. |
| `Bnum.Neq(a: any, b: any): boolean` | `Bnum.neq` | Checks whether two converted values are different. |
| `Bnum.Lt(a: any, b: any): boolean` | `Bnum.lt` | Checks whether a < b after converting both inputs automatically. |
| `Bnum.Lte(a: any, b: any): boolean` | `Bnum.lte` | Checks whether a <= b after converting both inputs automatically. |
| `Bnum.Gt(a: any, b: any): boolean` | `Bnum.gt` | Checks whether a > b after converting both inputs automatically. |
| `Bnum.Gte(a: any, b: any): boolean` | `Bnum.gte` | Checks whether a >= b after converting both inputs automatically. |
| `Bnum.Min(a: any, b: any?, ...: any): Value` | `Bnum.min` | Returns the smallest converted input. |
| `Bnum.Max(a: any, b: any?, ...: any): Value` | `Bnum.max` | Returns the largest converted input. |
| `Bnum.Clamp(value: any, minimum: any, maximum: any): Value` | `Bnum.clamp` | Clamps value between minimum and maximum after converting all inputs automatically. |


## Rounding, Range, and Utility Math

| Convenience API | Core counterpart | Purpose |
| --- | --- | --- |
| `Bnum.Floor(value: any): Value` | `Bnum.floor` | Rounds any supported input down toward negative infinity. |
| `Bnum.Ceil(value: any): Value` | `Bnum.ceil` | Rounds any supported input up toward positive infinity. |
| `Bnum.Round(value: any, digits: number?): Value` | `Bnum.round` | Rounds any supported input to the requested decimal precision. |
| `Bnum.Mod(a: any, b: any): Value` | `Bnum.mod` | Returns a modulo b after converting both inputs automatically. |
| `Bnum.Trunc(value: any): Value` | `Bnum.trunc` | Truncates the fractional part of any supported input. |
| `Bnum.Fract(value: any): Value` | `Bnum.fract` | Returns only the signed fractional part of any supported input. |
| `Bnum.IsInteger(value: any): boolean` | `Bnum.isInteger` | Checks whether any supported input represents an integer. |
| `Bnum.Between(value: any, minimum: any, maximum: any): boolean` | `Bnum.between` | Checks whether value lies inclusively between minimum and maximum. |
| `Bnum.Distance(a: any, b: any): Value` | `Bnum.distance` | Returns the absolute distance between two converted values. |
| `Bnum.RelativeDifference(a: any, b: any): Value` | `Bnum.relativeDifference` | Returns the relative difference between two converted values. |
| `Bnum.ApproxEq(a: any, b: any, relTolerance: number?, absTolerance: number?): boolean` | `Bnum.approxEq` | Checks approximate equality after converting both values automatically. |
| `Bnum.Lerp(a: any, b: any, alpha: number): Value` | `Bnum.lerp` | Linearly interpolates between two converted values. |
| `Bnum.InverseLerp(a: any, b: any, value: any): Value` | `Bnum.inverseLerp` | Returns the interpolation alpha of value between a and b. |
| `Bnum.Remap(value: any, inMin: any, inMax: any, outMin: any, outMax: any): Value` | `Bnum.remap` | Remaps value from one converted input range into another. |
| `Bnum.Sum(values: {any}): Value` | `Bnum.sum` | Adds every item in an array after converting each item automatically. |
| `Bnum.Product(values: {any}): Value` | `Bnum.product` | Multiplies every item in an array after converting each item automatically. |
| `Bnum.Mean(values: {any}): Value` | `Bnum.mean` | Returns the arithmetic mean after converting every array item automatically. |
| `Bnum.Percent(part: any, whole: any): Value` | `Bnum.percent` | Returns part / whole × 100 after converting both values automatically. |
| `Bnum.PercentChange(oldValue: any, newValue: any): Value` | `Bnum.percentChange` | Returns percentage change from oldValue to newValue after automatic conversion. |


## Checks

| Convenience API | Core counterpart | Purpose |
| --- | --- | --- |
| `Bnum.IsZero(value: any): boolean` | `Bnum.isZero` | Checks whether a converted value is zero. |
| `Bnum.IsNaN(value: any): boolean` | `Bnum.isNaN` | Checks whether a converted value is NaN. |
| `Bnum.IsInfinite(value: any): boolean` | `Bnum.isInfinite` | Checks whether a converted value is positive or negative infinity. |
| `Bnum.IsFinite(value: any): boolean` | `Bnum.isFinite` | Checks whether a converted value is finite. |
| `Bnum.IsPositive(value: any): boolean` | `Bnum.isPositive` | Checks whether a converted value is strictly positive. |
| `Bnum.IsNegative(value: any): boolean` | `Bnum.isNegative` | Checks whether a converted value is strictly negative. |
| `Bnum.Sign(value: any): number` | `Bnum.sign` | Returns -1, 0, or 1 for the sign of any supported input. |


## Formatting

| Convenience API | Core counterpart | Purpose |
| --- | --- | --- |
| `Bnum.GetSuffix(tier: number): string?` | `Bnum.getSuffix` | Returns the suffix for a numeric suffix tier. |
| `Bnum.IsFormatType(formatType: string): boolean` | `Bnum.isFormatType` | Checks whether a string names a supported format mode. |
| `Bnum.SetDefaultFormat(formatType: string): boolean` | `Bnum.setDefaultFormat` | Changes the module's default format mode. |
| `Bnum.Format(value: any, decimalPlaces: number?, formatType: FormatType?): string` | `Bnum.format` | Formats any supported input using the selected format mode. |
| `Bnum.FormatStandard(value: any, decimalPlaces: number?): string` | `Bnum.formatStandard` | Formats any supported input using standard notation. |
| `Bnum.FormatExtended(value: any, decimalPlaces: number?): string` | `Bnum.formatExtended` | Formats any supported input using extended notation. |
| `Bnum.FormatHybrid(value: any, decimalPlaces: number?): string` | `Bnum.formatHybrid` | Formats any supported input using hybrid notation. |
| `Bnum.FormatAlphabetic(value: any, decimalPlaces: number?): string` | `Bnum.formatAlphabetic` | Formats any supported input using alphabetic notation. |
| `Bnum.FormatMetric(value: any, decimalPlaces: number?): string` | `Bnum.formatMetric` | Formats any supported input using metric notation. |
| `Bnum.FormatExponent(value: any, decimalPlaces: number?): string` | `Bnum.formatExponent` | Formats any supported input using exponent notation. |
| `Bnum.FormatScientific(value: any, decimalPlaces: number?): string` | `Bnum.formatScientific` | Formats any supported input using scientific notation. |
| `Bnum.FormatEngineering(value: any, decimalPlaces: number?): string` | `Bnum.formatEngineering` | Formats any supported input using engineering notation. |
| `Bnum.FormatRoman(value: any, decimalPlaces: number?): string` | `Bnum.formatRoman` | Formats any supported input using Roman numeral notation. |
| `Bnum.FormatRomanExtended(value: any, decimalPlaces: number?): string` | `Bnum.formatRomanExtended` | Formats any supported input using extended Roman numeral notation. |
| `Bnum.FormatSuffix(value: any, decimalPlaces: number?): string` | `Bnum.formatSuffix` | Formats any supported input using the short suffix notation. |
| `Bnum.FormatSuffixLong(value: any, decimalPlaces: number?): string` | `Bnum.formatSuffixLong` | Formats any supported input using long suffix names. |
| `Bnum.FormatPlain(value: any, decimalPlaces: number?): string` | `Bnum.formatPlain` | Formats any supported input as a plain decimal string when practical. |
| `Bnum.FormatComma(value: any, decimalPlaces: number?): string` | `Bnum.formatComma` | Formats any supported input with comma grouping. |
| `Bnum.FormatLogarithm(value: any, decimalPlaces: number?): string` | `Bnum.formatLogarithm` | Formats any supported input using logarithmic notation. |
| `Bnum.FormatRaw(value: any): string` | `Bnum.formatRaw` | Formats any supported input as its raw Bnum representation. |
| `Bnum.AutoFormat(value: any, digits: number?, options: AutoFormatOptions?): string` | `Bnum.autoFormat` | Automatically selects a suitable notation for any supported input. |


## Reusable Output / Into

| Convenience API | Core counterpart | Purpose |
| --- | --- | --- |
| `Bnum.AddInto(out: Value, a: any, b: any): Value` | `Bnum.addInto` | Adds two converted inputs directly into an existing output Bnum table. |
| `Bnum.SubInto(out: Value, a: any, b: any): Value` | `Bnum.subInto` | Subtracts two converted inputs directly into an existing output Bnum table. |
| `Bnum.MulInto(out: Value, a: any, b: any): Value` | `Bnum.mulInto` | Multiplies two converted inputs directly into an existing output Bnum table. |
| `Bnum.DivInto(out: Value, a: any, b: any): Value` | `Bnum.divInto` | Divides two converted inputs directly into an existing output Bnum table. |
| `Bnum.PowInto(out: Value, value: any, power: number): Value` | `Bnum.powInto` | Raises a converted input to a normal numeric power directly into out. |
| `Bnum.AddNumberInto(out: Value, value: any, n: number): Value` | `Bnum.addNumberInto` | Adds a normal number to a converted Bnum input directly into out. |
| `Bnum.SubNumberInto(out: Value, value: any, n: number): Value` | `Bnum.subNumberInto` | Subtracts a normal number from a converted Bnum input directly into out. |
| `Bnum.MulNumberInto(out: Value, value: any, n: number): Value` | `Bnum.mulNumberInto` | Multiplies a converted Bnum input by a normal number directly into out. |
| `Bnum.DivNumberInto(out: Value, value: any, n: number): Value` | `Bnum.divNumberInto` | Divides a converted Bnum input by a normal number directly into out. |
| `Bnum.Scale10Into(out: Value, value: any, exponent: number): Value` | `Bnum.scale10Into` | Scales a converted input by 10^exponent directly into out. |
| `Bnum.SquareInto(out: Value, value: any): Value` | `Bnum.squareInto` | Squares a converted input directly into out. |
| `Bnum.CubeInto(out: Value, value: any): Value` | `Bnum.cubeInto` | Cubes a converted input directly into out. |
| `Bnum.MulAddInto(out: Value, a: any, b: any, c: any): Value` | `Bnum.mulAddInto` | Computes a × b + c from converted inputs directly into out. |
| `Bnum.AddMulInto(out: Value, a: any, b: any, c: any): Value` | `Bnum.addMulInto` | Computes a + b × c from converted inputs directly into out. |


---

# Format Constants

```lua
Bnum.DEFAULT_FORMAT
Bnum.DEFAULT_PRECISION
Bnum.MAX_PRECISION
Bnum.E_NOTATION_START
Bnum.FORMAT_PRECISION_MODE
Bnum.ROMAN_CLASSICAL_MAX
Bnum.ROMAN_EXTENDED_MAX
Bnum.FormatTypes
Bnum.SuffixTypes
Bnum.Suffixes
```

Current defaults:

```text
DEFAULT_FORMAT         = standard
DEFAULT_PRECISION      = 2
MAX_PRECISION          = 8
E_NOTATION_START       = 3000
FORMAT_PRECISION_MODE  = decimal-places
ROMAN_CLASSICAL_MAX    = 3999
ROMAN_EXTENDED_MAX     = 9007199254740991
```

---

# v1.4.0 Changes

v1.4.0 keeps the complete v1.3.3 math and formatting core and adds the full convenience layer.

Major changes:

- Version updated to `1.4.0`.
- Public API expanded from `122` to `245` functions.
- All `122` lowercase public functions now have PascalCase counterparts.
- Added `Bnum.SubZ(a, b)` as a convenience-only subtract-and-clamp helper.
- Value-taking PascalCase operations accept supported `number`, `string`, and table inputs automatically.
- `Sum`, `Product`, and `Mean` convert every array element.
- PascalCase `*Into` wrappers convert inputs while preserving the reusable output table.
- Unsupported auto-converted values become NaN rather than causing immediate nil indexing.
- `Bnum.Convert(...)` keeps the original `Bnum.convert(...)` return contract.
- The lowercase API remains unchanged for compatibility and hot-path performance.
- v1.3.3 high-exponent suffix formatting such as `E100UCe` remains available.
- Existing `--!native` and `--!optimize 2` directives remain intact.

---

# Summary

Bnum v1.4.0 now gives you two ways to use the same math system.

For clean general-purpose code:

```lua
local result = Bnum.Add("1.25M", 500)
print(Bnum.Format(result, 2))
```

For already-converted values and hot paths:

```lua
local result = Bnum.add(a, b)
```

For allocation-sensitive loops:

```lua
Bnum.addInto(out, a, b)
```

The core representation remains:

```text
value = sign × 10^logMagnitude
```

so the library stays compact and efficient while the v1.4 convenience layer makes ordinary call sites substantially easier to write.

---

## Version

```text
Bnum v1.4.0
```
