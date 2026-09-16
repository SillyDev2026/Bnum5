# Bnum v1.6.0

**Bnum** is a high-performance big-number library for Roblox Luau built around a compact two-number logarithmic representation.

```text
Version:          1.6.0
Representation:   {sign, logMagnitude}
Value:            sign × 10^logMagnitude
Core API:         127 lowercase functions
Convenience API:  128 PascalCase functions
Total Public API: 255 functions
Compiler:         --!native + --!optimize 2
```

Bnum is designed for simulator, incremental, clicker, economy, damage, upgrade, leaderboard, progression, and other Roblox systems that need magnitudes far beyond ordinary finite Luau numbers.

v1.6.0 keeps the canonical log-space representation, the v1.5 string model, and the current leaderboard codec, then rebuilds the math internals around a **fast-path / hard-path kernel**. Common finite arithmetic stays directly inside the public hot functions, while rare NaN, infinity, zero, cancellation, and extreme-value cases share private raw kernels instead of duplicating hundreds of lines of logic.

---

## Highlights

- Compact `{sign, logMagnitude}` canonical representation.
- Values far beyond ordinary finite Luau magnitude.
- Positive values, negative values, zero, infinity, negative infinity, and NaN.
- 127 lowercase core APIs for direct/hot-path work.
- 128 PascalCase convenience APIs for automatic input conversion.
- Dedicated fast-path and hard-path arithmetic architecture.
- Private raw kernels for addition, multiplication, division, and comparison.
- Reduced temporary allocations in higher-level math.
- Allocation-saving `*Into` APIs.
- Direct Bnum + normal-number arithmetic.
- Fused `mulAdd` and `addMul` operations.
- Specialized `powInteger`, `midpoint`, `geometricMean`, `quadraticMean`, and `saturate`.
- Conventional scientific `toString()` plus canonical-log `toBnumString()`.
- `fromString()` parses decimal, scientific, suffix, Bnum-style exponent, infinity, and NaN forms.
- Safe-integer leaderboard codec with `lbencode` / `lbdecode`.
- Standard suffix ladder through tier `999`.
- High-exponent formatting such as `E100UCe`.
- Extended, hybrid, alphabetic, metric, exponent, scientific, engineering, Roman, plain, comma, logarithm, and raw formatting.
- `--!native`.
- `--!optimize 2`.

---

# Installation

Place the module somewhere accessible to your game code.

A common layout is:

```text
ReplicatedStorage
└── Bnum
```

Require it:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage:WaitForChild("Bnum"))

print(Bnum.Version)
-- 1.6.0
```

---

# Quick Start

## Convenience API

For ordinary game code, the PascalCase layer converts supported inputs automatically:

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

`SubZ` subtracts and clamps negative results to zero:

```lua
print(Bnum.ToNumber(Bnum.SubZ(100, 25))) -- 75
print(Bnum.ToNumber(Bnum.SubZ(5, 10)))   -- 0
```

## Core API

When values are already canonical Bnums, use the lowercase layer:

```lua
local coins = Bnum.fromNumber(1000)
local reward = Bnum.fromString("1.25M")

coins = Bnum.add(coins, reward)

print(Bnum.format(coins, 2))
```

---

# Two API Layers

v1.6 intentionally exposes two public layers.

## Lowercase core API

Examples:

```lua
Bnum.add(a, b)
Bnum.mul(a, b)
Bnum.sqrt(value)
Bnum.midpoint(a, b)
Bnum.format(value, 2)
Bnum.addInto(out, a, b)
```

Use the lowercase layer when values are already Bnums, when code is in a hot loop, or when conversion/allocation overhead matters.

## PascalCase convenience API

Examples:

```lua
Bnum.Add(10, "25")
Bnum.Mul("1e100", 2)
Bnum.Sqrt("144")
Bnum.Midpoint(10, "20")
Bnum.Eq(1000, "1e3")
Bnum.Format("1.25M", 2)
Bnum.AddInto(out, 10, "25")
```

Use the convenience layer at input boundaries such as configs, UI text, DataStores, or general game logic where mixed `number`, `string`, and Bnum-like inputs are useful.

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

This representation makes huge multiplication, division, roots, powers, comparisons, and scaling inexpensive because the stored magnitude is already logarithmic.

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

That value is `9500`, whose canonical storage is approximately:

```lua
{1, 3.9777236052888477}
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

Convenience equivalents:

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

Do not create a huge native value before handing it to Bnum:

```lua
-- Wrong: native overflow happens first.
Bnum.FromNumber(10 ^ 1000)

-- Correct:
Bnum.Pow10(1000)
Bnum.FromString("1e1000")
```

---

# String Parsing and Serialization

v1.6 keeps the v1.5 split between **normal scientific strings** and **Bnum-storage strings**.

## `toString`

`toString()` returns conventional normalized scientific notation with an integer exponent:

```lua
local value = Bnum.new(9.5, 3)

print(Bnum.toString(value))
-- 9.5e3
```

The PascalCase version is:

```lua
Bnum.ToString(value)
```

## `toBnumString`

`toBnumString()` preserves the stored logarithmic exponent:

```lua
local value = Bnum.new(9.5, 3)

print(Bnum.toBnumString(value))
-- 1e3.9777236052888477
```

Negative example:

```lua
print(Bnum.toBnumString(Bnum.new(-9.5, 3)))
-- -1e3.9777236052888477
```

The PascalCase version is:

```lua
Bnum.ToBnumString(value)
```

## `fromString`

`fromString()` understands both formats:

```lua
Bnum.fromString("9.5e3")
Bnum.fromString("1e3.9777236052888477")
```

Both represent `9500`.

It also supports:

```lua
Bnum.fromString("1000")
Bnum.fromString("123.456")
Bnum.fromString("1e250")
Bnum.fromString("1e3.5")
Bnum.fromString("1e1e6")
Bnum.fromString("-5.25e100")
Bnum.fromString("1.25M")
Bnum.fromString("2 Million")
Bnum.fromString("inf")
Bnum.fromString("-inf")
Bnum.fromString("nan")
```

For very large stored log exponents, Bnum-style text may itself contain scientific exponent text:

```text
1e1e+308
```

The parser accepts that form.

---

# Fast Path and Hard Path

v1.6 restructures the arithmetic internals around two execution paths.

## Fast path

The common finite/canonical cases stay directly inside the public functions.

Examples include:

```text
finite nonzero multiplication
finite nonzero division
same-sign addition
far-magnitude addition
normal scalar multiplication/division
```

This keeps hot operations short and avoids an extra public helper call.

## Hard path

Rare cases use private raw kernels:

```text
rawAddHard
rawAdd
rawMul
rawDiv
rawCompare
```

These handle:

```text
NaN
positive/negative infinity
zero
mixed signs
close cancellation
division by zero
underflow
unordered comparison
```

Higher-level math also reuses the raw kernels, so functions such as `lerp`, `remap`, `mean`, and `percentChange` no longer carry large duplicated copies of add/subtract logic.

---

# Core Arithmetic

```lua
local a = Bnum.fromNumber(500)
local b = Bnum.fromNumber(250)

print(Bnum.format(Bnum.add(a, b))) -- 750
print(Bnum.format(Bnum.sub(a, b))) -- 250
print(Bnum.format(Bnum.mul(a, b)))
print(Bnum.format(Bnum.div(a, b)))
```

## Direct Bnum + Number Operations

When one operand is already a normal Luau number:

```lua
local value = Bnum.fromNumber(100)

value = Bnum.addNumber(value, 25)
value = Bnum.subNumber(value, 5)
value = Bnum.mulNumber(value, 1.5)
value = Bnum.divNumber(value, 2)
```

This avoids allocating a temporary Bnum for the scalar operand.

## Scale, Square, Cube, and Fused Math

```lua
local scaled = Bnum.scale10(Bnum.fromNumber(9.5), 10)
local squared = Bnum.square(Bnum.fromNumber(12))
local cubed = Bnum.cube(Bnum.fromNumber(5))

local damage = Bnum.mulAdd(
	Bnum.fromNumber(25),
	Bnum.fromNumber(15),
	Bnum.fromNumber(100)
)
```

`mulAdd(a, b, c)` computes:

```text
a × b + c
```

`addMul(a, b, c)` computes:

```text
a + b × c
```

---

# Powers, Roots, Logs, and Exponentials

Core functions include:

```lua
Bnum.pow(value, power)
Bnum.powInteger(value, integerPower)
Bnum.powValue(value, powerValue)

Bnum.sqrt(value)
Bnum.cbrt(value)
Bnum.root(value, degree)

Bnum.log10(value)
Bnum.ln(value)
Bnum.log2(value)
Bnum.log(value, base)

Bnum.exp(value)
Bnum.exp10(value)
Bnum.exp2(value)

Bnum.log1p(value)
Bnum.expm1(value)
Bnum.hypot(a, b)
Bnum.factorial(value)
```

## `powInteger`

`powInteger` is the specialized integer exponent path:

```lua
print(Bnum.ToNumber(Bnum.PowInteger("-2", 3))) -- -8
print(Bnum.ToNumber(Bnum.PowInteger("-2", 4))) -- 16
```

Fractional powers are rejected by this API:

```lua
Bnum.powInteger(Bnum.fromNumber(2), 2.5)
-- NaN
```

Use `pow()` for general numeric exponents.

---

# New v1.6 Math Helpers

## `midpoint`

Returns `(a + b) / 2` using one raw addition and a fixed `log10(2)` shift:

```lua
print(Bnum.ToNumber(Bnum.Midpoint(10, "20")))
-- 15
```

## `geometricMean`

Returns the real geometric mean:

```lua
print(Bnum.ToNumber(Bnum.GeometricMean(4, 16)))
-- 8
```

Negative real inputs return NaN.

## `quadraticMean`

Returns the quadratic mean / RMS:

```lua
local rms = Bnum.QuadraticMean(3, 4)
print(Bnum.ToNumber(rms))
-- sqrt((3^2 + 4^2) / 2)
```

## `saturate`

Clamps a value to `[0, 1]`:

```lua
print(Bnum.ToNumber(Bnum.Saturate(-5)))   -- 0
print(Bnum.ToNumber(Bnum.Saturate(0.25))) -- 0.25
print(Bnum.ToNumber(Bnum.Saturate(5)))    -- 1
```

This is useful for normalized progress, UI fill values, interpolation parameters, and similar game math.

---

# Comparison and Selection

```lua
local a = Bnum.fromNumber(100)
local b = Bnum.fromNumber(250)

print(Bnum.compare(a, b)) -- -1
print(Bnum.eq(a, b))
print(Bnum.neq(a, b))
print(Bnum.lt(a, b))
print(Bnum.lte(a, b))
print(Bnum.gt(a, b))
print(Bnum.gte(a, b))
```

`compare()` returns:

```text
-1   a < b
 0   a == b
 1   a > b
nil  comparison contains NaN
```

Selection helpers:

```lua
Bnum.min(a, b, c)
Bnum.max(a, b, c)
Bnum.clamp(value, minimum, maximum)
```

---

# Rounding, Range, and Utility Math

```lua
Bnum.floor(value)
Bnum.ceil(value)
Bnum.round(value, digits?)
Bnum.mod(a, b)
Bnum.trunc(value)
Bnum.fract(value)

Bnum.isInteger(value)
Bnum.between(value, minimum, maximum)

Bnum.distance(a, b)
Bnum.relativeDifference(a, b)
Bnum.approxEq(a, b, relTolerance?, absTolerance?)

Bnum.lerp(a, b, alpha)
Bnum.inverseLerp(a, b, value)
Bnum.remap(value, inMin, inMax, outMin, outMax)

Bnum.sum(values)
Bnum.product(values)
Bnum.mean(values)

Bnum.percent(part, whole)
Bnum.percentChange(oldValue, newValue)
```

## Allocation-aware array math

`sum()` and `mean()` keep their running accumulator as two numeric locals:

```text
accSign
accLogMagnitude
```

They use the raw add kernel during the loop and allocate only the final result Bnum.

Example:

```lua
local values = {
	Bnum.fromNumber(1),
	Bnum.fromNumber(2),
	Bnum.fromNumber(3),
	Bnum.fromNumber(4),
}

print(Bnum.ToNumber(Bnum.sum(values)))  -- 10
print(Bnum.ToNumber(Bnum.mean(values))) -- 2.5
```

---

# Value Checks

```lua
Bnum.isZero(value)
Bnum.isNaN(value)
Bnum.isInfinite(value)
Bnum.isFinite(value)
Bnum.isPositive(value)
Bnum.isNegative(value)
Bnum.sign(value)
```

Convenience equivalents accept supported mixed inputs:

```lua
Bnum.IsZero(value)
Bnum.IsNaN(value)
Bnum.IsInfinite(value)
Bnum.IsFinite(value)
Bnum.IsPositive(value)
Bnum.IsNegative(value)
Bnum.Sign(value)
```

---

# Formatting

v1.6 uses canonical lowercase format names only:

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

Defaults:

```text
Default format:     standard
Default precision:  2 decimal places
Maximum precision:  8 decimal places
E-notation start:   3000
Precision mode:     decimal-places
```

Main formatter:

```lua
Bnum.format(value, decimalPlaces?, formatType?)
```

Examples:

```lua
local value = Bnum.fromString("1.2345e12")

print(Bnum.format(value))
print(Bnum.format(value, 2))
print(Bnum.format(value, 2, "standard"))
print(Bnum.format(value, 2, "scientific"))
print(Bnum.format(value, 2, "engineering"))
print(Bnum.format(value, 2, "comma"))
```

Dedicated formatters:

```lua
Bnum.formatStandard(value, digits?)
Bnum.formatExtended(value, digits?)
Bnum.formatHybrid(value, digits?)
Bnum.formatAlphabetic(value, digits?)
Bnum.formatMetric(value, digits?)
Bnum.formatExponent(value, digits?)
Bnum.formatScientific(value, digits?)
Bnum.formatEngineering(value, digits?)
Bnum.formatRoman(value, digits?)
Bnum.formatRomanExtended(value, digits?)
Bnum.formatPlain(value, digits?)
Bnum.formatComma(value, digits?)
Bnum.formatLogarithm(value, digits?)
Bnum.formatRaw(value)
```

## High exponent suffix formatting

The standard suffix ladder extends through tier `999`.

Important tiers include:

```text
tier 101 -> Ce
tier 102 -> UCe
tier 103 -> DCe
```

That allows compact exponent displays:

```text
logMagnitude = 1e305 -> E100Ce
logMagnitude = 1e306 -> E1UCe
logMagnitude = 1e307 -> E10UCe
logMagnitude = 1e308 -> E100UCe
```

instead of nested output such as `E1e308`.

---

# Removed Legacy Formatting APIs

The following old compatibility functions are no longer part of the v1.6 public API:

```text
formatSuffix
formatSuffixLong
autoFormat

FormatSuffix
FormatSuffixLong
AutoFormat
```

Use the canonical formatter functions instead:

```text
formatStandard / FormatStandard
formatExtended / FormatExtended
formatHybrid / FormatHybrid
format / Format
```

Old capitalized format-name aliases such as `"Standard"`, `"Suffix"`, and `"Auto"` are also removed. Use the canonical lowercase format names.

---

# Reusable Output / `Into`

Normal operations allocate a new two-number result table:

```lua
value = Bnum.add(value, reward)
```

For high-frequency loops, reuse an output table:

```lua
local out = {0, 0}

Bnum.addInto(out, value, reward)
```

Available core reusable-output APIs:

```lua
Bnum.addInto(out, a, b)
Bnum.subInto(out, a, b)
Bnum.mulInto(out, a, b)
Bnum.divInto(out, a, b)

Bnum.powInto(out, value, power)

Bnum.addNumberInto(out, value, number)
Bnum.subNumberInto(out, value, number)
Bnum.mulNumberInto(out, value, number)
Bnum.divNumberInto(out, value, number)

Bnum.scale10Into(out, value, exponent)
Bnum.squareInto(out, value)
Bnum.cubeInto(out, value)

Bnum.mulAddInto(out, a, b, c)
Bnum.addMulInto(out, a, b, c)
```

PascalCase wrappers convert the inputs but preserve the provided output table:

```lua
local out = {0, 0}

Bnum.AddInto(out, 10, "25")
Bnum.MulInto(out, "1e100", 2)
Bnum.MulAddInto(out, 2, "3", 4)
```

---

# Leaderboard Encoding

v1.6 keeps the current safe-integer leaderboard codec.

Core API:

```lua
local encoded = Bnum.lbencode(value)
local decoded = Bnum.lbdecode(encoded)
```

Convenience API:

```lua
local encoded = Bnum.Lbencode("1e1000000")
local decoded = Bnum.Lbdecode(encoded)
```

The codec transforms the stored `logMagnitude`:

```text
u = sign(logMagnitude) × log10(1 + abs(logMagnitude))
```

then quantizes that coordinate into an exact safe integer range below `2^52`.

Public constants:

```lua
Bnum.LB_CODEC_VERSION
Bnum.LB_SCALE
Bnum.LB_CENTER_CODE
Bnum.LB_MIN_FINITE_CODE
Bnum.LB_MAX_FINITE_CODE
Bnum.LB_INFINITY_CODE
Bnum.LB_NAN_CODE
```

Current codec version:

```text
LB_CODEC_VERSION = 2
LB_SCALE         = 4398046511104
```

Properties:

```text
sortable signed integer encoding
zero -> 0
positive infinity -> +LB_INFINITY_CODE
negative infinity -> -LB_INFINITY_CODE
NaN -> LB_NAN_CODE
values below 1 remain distinct
codes remain below 2^52
```

Legacy leaderboard decoding was removed in the v1.5 cleanup; `lbdecode()` accepts the current codec only.

---

# Performance Guidelines

For fastest practical Bnum code:

1. Keep values canonical during repeated calculations.
2. Use lowercase core functions when values are already Bnums.
3. Convert once at input boundaries instead of repeatedly auto-converting inside hot loops.
4. Prefer `addNumber`, `subNumber`, `mulNumber`, and `divNumber` when the other operand is a normal number.
5. Prefer `scale10`, `square`, `cube`, `powInteger`, `midpoint`, and other specialized operations when they match the formula.
6. Use `mulAdd` and `addMul` for matching fused formulas.
7. Use `*Into` APIs when allocation pressure is measurable.
8. Avoid formatting in simulation loops; format when UI actually updates.
9. Use `fromString`, `pow10`, or scientific constructors for values that cannot exist as finite native numbers first.
10. Benchmark in Roblox Studio before treating a source-level optimization as a measured speed win.

The PascalCase convenience layer prioritizes call-site ergonomics. It is not intended to replace the lowercase core API in the hottest loops.

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

Hot-loop version:

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

When the exponent is guaranteed to be an integer:

```lua
local function getIntegerUpgradeCost(level: number)
	return Bnum.Mul(baseCost, Bnum.PowInteger(growth, level))
end
```

---

# Example: Progress Bar

```lua
local minimum = 0
local maximum = "1e100"
local current = "5e99"

local alpha = Bnum.InverseLerp(minimum, maximum, current)
local normalized = Bnum.Saturate(alpha)
local alphaNumber = Bnum.ToNumber(normalized)

progressBar.Size = UDim2.fromScale(alphaNumber, 1)
```

---

# Example: DataStore / Leaderboard Flow

```lua
local score = Bnum.FromString("1e1000000")

local storedScore = Bnum.Lbencode(score)

-- Save storedScore to your ordered leaderboard storage.

local restoredScore = Bnum.Lbdecode(storedScore)

print(Bnum.Format(restoredScore, 2))
```

For normal DataStore persistence where ordering is not required, store an appropriate Bnum serialization for your own schema rather than assuming `lbencode()` is a lossless serializer.

---

# Special Values

Bnum includes:

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

Special arithmetic intentionally handles cases such as:

```text
0 × infinity -> NaN
infinity / infinity -> NaN
+infinity + -infinity -> NaN
1 / 0 -> +infinity
1 / infinity -> 0
0^-1 -> +infinity
NaN^0 -> 1
sqrt(-1) -> NaN
root(-32, 5) -> -2
root(-32, 4) -> NaN
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

For exact arbitrary-length integers, cryptographic arithmetic, or exact financial decimal accounting, use a representation designed for exact arithmetic.

---

# Recommended Data Flow

Convenience-oriented code:

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

Performance-oriented code:

```text
input
  ↓
convert once
  ↓
canonical Bnum
  ↓
lowercase core / raw-kernel-backed hot paths
  ↓
Into API when allocation matters
  ↓
format only when needed
```

---

# Core API Reference

The lowercase layer is the direct, performance-oriented API.

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
| `Bnum.fromString(str: string): Value` | Parses decimal, scientific, Bnum-style exponent, infinity, NaN, and suffix strings. |
| `Bnum.toNumber(val: Value): number` | Converts a Bnum back to a normal Luau number when representable. |
| `Bnum.toScientific(val: Value): (number, number)` | Returns a normal scientific mantissa and exponent pair. |
| `Bnum.mantissa(val: Value): number` | Returns the signed scientific mantissa of a Bnum. |
| `Bnum.exponent(val: Value): number` | Returns the base-10 scientific exponent of a Bnum. |
| `Bnum.toString(val: Value): string` | Serializes a Bnum using conventional normalized scientific notation. |
| `Bnum.toBnumString(val: Value): string` | Serializes the Bnum using its stored logarithmic exponent. |

## Core Arithmetic

| Function | Purpose |
| --- | --- |
| `Bnum.add(val1: Value, val2: Value): Value` | Adds two canonical Bnums. |
| `Bnum.sub(val1: Value, val2: Value): Value` | Subtracts the second Bnum from the first. |
| `Bnum.mul(val1: Value, val2: Value): Value` | Multiplies two Bnums. |
| `Bnum.div(val1: Value, val2: Value): Value` | Divides the first Bnum by the second. |
| `Bnum.addNumber(val: Value, n: number): Value` | Adds a normal Luau number directly to a Bnum. |
| `Bnum.subNumber(val: Value, n: number): Value` | Subtracts a normal Luau number directly from a Bnum. |
| `Bnum.mulNumber(val: Value, n: number): Value` | Multiplies a Bnum by a normal number without allocating a temporary Bnum. |
| `Bnum.divNumber(val: Value, n: number): Value` | Divides a Bnum by a normal number without allocating a temporary Bnum. |
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

## Logs, Exponentials, and Specialized Math

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
| `Bnum.powInteger(val: Value, power: number): Value` | Raises a Bnum to an integer power. |
| `Bnum.midpoint(a: Value, b: Value): Value` | Returns the arithmetic midpoint `(a + b) / 2`. |
| `Bnum.geometricMean(a: Value, b: Value): Value` | Returns the real geometric mean `sqrt(a * b)`. |
| `Bnum.quadraticMean(a: Value, b: Value): Value` | Returns the quadratic mean / RMS of two Bnums: |
| `Bnum.saturate(val: Value): Value` | Clamps a Bnum to the inclusive range [0, 1]. |

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
| `Bnum.clamp(val: Value, minimum: Value, maximum: Value): Value` | Clamps a Bnum between minimum and maximum. |

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
| `Bnum.relativeDifference(a: Value, b: Value): Value` | Returns \|a - b\| / max(\|a\|, \|b\|). |
| `Bnum.approxEq(a: Value, b: Value, relTolerance: number?, absTolerance: number?): boolean` | Checks approximate equality with relative and absolute tolerances. |
| `Bnum.lerp(a: Value, b: Value, alpha: number): Value` | Linearly interpolates between two Bnums: |
| `Bnum.inverseLerp(a: Value, b: Value, val: Value): Value` | Returns the interpolation alpha of val between a and b: |
| `Bnum.remap(val: Value, inMin: Value, inMax: Value, outMin: Value, outMax: Value): Value` | Remaps val from [inMin, inMax] into [outMin, outMax]. |
| `Bnum.sum(values: {Value}): Value` | Adds every Bnum in an array. |
| `Bnum.product(values: {Value}): Value` | Multiplies every Bnum in an array using an inline accumulator. |
| `Bnum.mean(values: {Value}): Value` | Returns the arithmetic mean of an array. |
| `Bnum.percent(part: Value, whole: Value): Value` | Returns part / whole × 100 as a Bnum. |
| `Bnum.percentChange(oldValue: Value, newValue: Value): Value` | Returns ((newValue - oldValue) / abs(oldValue)) * 100. |

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
| `Bnum.formatPlain(val: Value, decimalPlaces: number?): string` | Formats as a fixed decimal when representable. |
| `Bnum.formatComma(val: Value, decimalPlaces: number?): string` | Formats normal-sized values with comma grouping. |
| `Bnum.formatLogarithm(val: Value, decimalPlaces: number?): string` | Formats as 10^logMagnitude. |
| `Bnum.formatRaw(val: Value): string` | Returns the raw {sign, logMagnitude} representation. |

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

## Leaderboard Codec

| Function | Purpose |
| --- | --- |
| `Bnum.lbencode(val: Value): number` | Encodes a canonical Bnum into one sortable safe integer for leaderboard storage. |
| `Bnum.lbdecode(encoded: number): Value` | Decodes a leaderboard number into canonical Bnum form. |

---

# PascalCase Convenience API Reference

The PascalCase layer converts supported Bnum-value inputs automatically.

`SubZ` is the one convenience-only arithmetic operation; it subtracts and clamps negative results to zero.

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
| `Bnum.ToBnumString(value: any): string` | `Bnum.toBnumString` | Serializes any supported input using the stored Bnum logarithmic exponent. |

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

## Logs, Exponentials, and Specialized Math

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
| `Bnum.PowInteger(value: any, power: number): Value` | `Bnum.powInteger` | Raises a supported value to an integer power using the specialized integer path. |
| `Bnum.Midpoint(a: any, b: any): Value` | `Bnum.midpoint` | Returns the arithmetic midpoint of two supported values. |
| `Bnum.GeometricMean(a: any, b: any): Value` | `Bnum.geometricMean` | Returns the real geometric mean of two supported non-negative values. |
| `Bnum.QuadraticMean(a: any, b: any): Value` | `Bnum.quadraticMean` | Returns the quadratic mean / RMS of two supported values. |
| `Bnum.Saturate(value: any): Value` | `Bnum.saturate` | Clamps a supported value to [0, 1]. |

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
| `Bnum.FormatPlain(value: any, decimalPlaces: number?): string` | `Bnum.formatPlain` | Formats any supported input as a plain decimal string when practical. |
| `Bnum.FormatComma(value: any, decimalPlaces: number?): string` | `Bnum.formatComma` | Formats any supported input with comma grouping. |
| `Bnum.FormatLogarithm(value: any, decimalPlaces: number?): string` | `Bnum.formatLogarithm` | Formats any supported input using logarithmic notation. |
| `Bnum.FormatRaw(value: any): string` | `Bnum.formatRaw` | Formats any supported input as its raw Bnum representation. |

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

## Leaderboard Codec

| Convenience API | Core counterpart | Purpose |
| --- | --- | --- |
| `Bnum.Lbencode(value: any): number` | `Bnum.lbencode` | Encodes a number, string, or Bnum-like value with the v2 leaderboard codec. |
| `Bnum.Lbdecode(encoded: number): Value` | `Bnum.lbdecode` | Decodes a current v1.5 leaderboard code into a Bnum. |

---

# Format and Codec Constants

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

Bnum.LB_CODEC_VERSION
Bnum.LB_SCALE
Bnum.LB_CENTER_CODE
Bnum.LB_MIN_FINITE_CODE
Bnum.LB_MAX_FINITE_CODE
Bnum.LB_INFINITY_CODE
Bnum.LB_NAN_CODE
```

Current formatting defaults:

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

# v1.6.0 Changes

v1.6.0 is the math-kernel rebuild.

Major changes:

- Added private `rawAddHard`, `rawAdd`, `rawMul`, `rawDiv`, and `rawCompare` kernels.
- Kept common finite arithmetic inline in `add`, `sub`, `mul`, `div`, and number-specialized hot paths.
- Rebuilt higher-level math to reuse raw sign/log operations instead of duplicating full arithmetic implementations.
- Reworked `compare`, `clamp`, `relativeDifference`, `approxEq`, `lerp`, `inverseLerp`, `remap`, `sum`, `mean`, and `percentChange`.
- `sum` and `mean` now keep their accumulators as raw numeric fields and allocate only the final result.
- Added `powInteger` / `PowInteger`.
- Added `midpoint` / `Midpoint`.
- Added `geometricMean` / `GeometricMean`.
- Added `quadraticMean` / `QuadraticMean`.
- Added `saturate` / `Saturate`.
- Preserved v1.5 `toString`, `toBnumString`, and rebuilt `fromString` behavior.
- Preserved the current safe-integer leaderboard codec.
- Kept legacy formatter aliases and legacy leaderboard decode paths removed.
- Public API now contains `255` functions.
- Existing `--!native` and `--!optimize 2` directives remain.

---

# Migration from v1.4 README Examples

The old README documented compatibility APIs that no longer exist.

Replace:

```lua
Bnum.FormatSuffix(value, 2)
Bnum.FormatSuffixLong(value, 2)
Bnum.AutoFormat(value, 2)
```

with canonical v1.6 formatters such as:

```lua
Bnum.FormatStandard(value, 2)
Bnum.FormatExtended(value, 2)
Bnum.FormatHybrid(value, 2)
Bnum.Format(value, 2, "standard")
```

Replace old capitalized format names:

```text
"Standard"
"Scientific"
"Engineering"
"Auto"
"Suffix"
```

with canonical lowercase names:

```text
"standard"
"scientific"
"engineering"
```

For Bnum-storage serialization, use:

```lua
Bnum.ToBnumString(value)
```

For normalized scientific serialization, keep using:

```lua
Bnum.ToString(value)
```

---

# Summary

Bnum v1.6.0 keeps the compact logarithmic representation:

```text
value = sign × 10^logMagnitude
```

while making the math internals cleaner and more reusable.

For clean general-purpose code:

```lua
local result = Bnum.Add("1.25M", 500)
print(Bnum.Format(result, 2))
```

For already-converted hot-path values:

```lua
local result = Bnum.add(a, b)
```

For specialized math:

```lua
local midpoint = Bnum.midpoint(a, b)
local power = Bnum.powInteger(value, level)
```

For allocation-sensitive loops:

```lua
Bnum.addInto(out, a, b)
```

For sortable leaderboard storage:

```lua
local code = Bnum.lbencode(value)
local restored = Bnum.lbdecode(code)
```

For string serialization:

```lua
local scientific = Bnum.toString(value)
local canonicalLog = Bnum.toBnumString(value)
```

---

## Version

```text
Bnum v1.6.0
```
