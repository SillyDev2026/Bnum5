# Bnum v1.3.3

**Bnum** is a high-performance big-number library for Roblox Luau built around a compact two-number logarithmic representation.

```text
Version:        1.3.3
Representation: {sign, logMagnitude}
Value:          sign × 10^logMagnitude
Public API:     122 functions
Compiler:       --!native + --!optimize 2
```

Bnum is designed for simulator, incremental, clicker, economy, damage, upgrade, leaderboard, and other Roblox systems that need numbers far beyond ordinary floating-point display ranges while keeping arithmetic lightweight.

The v1.3.3 core keeps the canonical logarithmic representation used by earlier Bnum releases, while also accepting and returning public `{mantissa, exponent}` pairs when that form is more convenient.

---

## Highlights

- Compact two-number canonical representation
- Numbers far beyond normal Luau floating-point range
- Positive values, negative values, zero, infinity, negative infinity, and NaN
- Fast multiplication and division in logarithmic space
- Direct Bnum + normal-number arithmetic
- Fused `mulAdd` and `addMul` operations
- Square, cube, arbitrary roots, and powers
- Bnum-valued powers with `powValue`
- `exp`, `exp10`, `exp2`, `log1p`, `expm1`, and `hypot`
- Factorial for supported non-negative integer values
- Public `{mantissa, exponent}` conversion
- Decimal, scientific, and suffix string parsing
- Standard suffix ladder through tier `999`
- Extended, hybrid, alphabetic, metric, exponent, scientific, engineering, Roman, plain, comma, logarithm, and raw formatting
- Extended exponent-suffix formatting such as `E100UCe`
- Interpolation, remapping, distance, percent, mean, sum, and product helpers
- Exact and approximate comparisons
- Allocation-saving `*Into` APIs
- Direct `*NumberInto` APIs
- `--!native`
- `--!optimize 2`

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
-- 1.3.3
```

---

# Quick Start

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage:WaitForChild("Bnum"))

local coins = Bnum.fromNumber(1000)
local reward = Bnum.fromString("1.25M")

coins = Bnum.add(coins, reward)

print(Bnum.format(coins, 2))
```

Bnum v1.3.3 can parse supported display suffixes directly:

```lua
local a = Bnum.fromString("1.25M")
local b = Bnum.fromString("5Qa")
local c = Bnum.fromString("1e1000")
```

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
```

The represented value is:

```text
value = sign × 10^logMagnitude
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

This makes gigantic magnitudes cheap to store. `1e1000` does not need a thousand decimal digits internally; it only needs:

```lua
{1, 1000}
```

---

# Canonical Form vs `{mantissa, exponent}` Form

v1.3.3 supports both concepts, but they are not the same representation.

The **canonical internal form** is:

```lua
{sign, logMagnitude}
```

The public scientific table form is:

```lua
{mantissa, exponent}
```

For example:

```lua
local public = {9.5, 3}
local value = Bnum.fromTable(public)
```

represents:

```text
9.5 × 10^3
= 9500
```

Convert a Bnum back to a normalized scientific pair:

```lua
local pair = Bnum.toTable(value)

print(pair[1]) -- 9.5
print(pair[2]) -- 3
```

This gives you the convenience of `{mantissa, exponent}` without changing the optimized canonical log-space arithmetic used by the module.

---

# Value Type

```lua
export type Value = {number}
```

A normal canonical value contains two numeric entries:

```lua
{
	sign,
	logMagnitude,
}
```

Do not manually mix canonical Bnums and scientific pairs in arithmetic calls.

Use:

```lua
Bnum.fromTable(...)
Bnum.toTable(...)
Bnum.normalize(...)
Bnum.convert(...)
```

when crossing between representations.

---

# Built-in Constants

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

Examples:

```lua
print(Bnum.format(Bnum.zero))
print(Bnum.format(Bnum.one))
print(Bnum.format(Bnum.e, 4))
```

These predefined values should be treated as immutable.

---

# Creating Numbers

## `Bnum.fromNumber`

```lua
local value = Bnum.fromNumber(125000)
```

Use this for ordinary finite Luau numbers.

Do not do:

```lua
Bnum.fromNumber(10 ^ 1000)
```

because the native number overflows before Bnum receives it.

Use:

```lua
Bnum.pow10(1000)
```

or:

```lua
Bnum.fromString("1e1000")
```

instead.

---

## `Bnum.new`

`new` accepts scientific components:

```lua
local value = Bnum.new(9.5, 3)
```

which represents:

```text
9.5e3
9500
```

The exponent defaults to zero.

```lua
local value = Bnum.new(25)
```

---

## `Bnum.raw`

`raw` constructs the canonical representation directly:

```lua
local value = Bnum.raw(1, 1000)
```

Equivalent canonical value:

```lua
{1, 1000}
```

Use `raw` only when you already understand Bnum's internal representation.

---

## `Bnum.fromTable`

Convert a public scientific table:

```lua
local value = Bnum.fromTable({9.5, 3})
```

Result:

```text
9500
```

---

## `Bnum.toTable`

Convert a Bnum to a normalized public scientific pair:

```lua
local value = Bnum.fromNumber(9500)
local pair = Bnum.toTable(value)

print(pair[1], pair[2])
-- approximately: 9.5  3
```

---

## `Bnum.normalize`

Accepts either a canonical Bnum or a scientific pair and returns canonical form:

```lua
local value = Bnum.normalize({9.5, 3})
```

---

## `Bnum.isValid`

Check whether a two-number table can be interpreted as a Bnum:

```lua
print(Bnum.isValid({9.5, 3}))
-- true
```

---

## `Bnum.convert`

Supported inputs include:

```text
number
string
table
```

Examples:

```lua
local a = Bnum.convert(1000)
local b = Bnum.convert("1e1000")
local c = Bnum.convert({9.5, 3})
```

Unsupported input types return `nil`.

---

## `Bnum.fromScientific`

```lua
local value = Bnum.fromScientific(1.25, 1000)
```

Represents:

```text
1.25e1000
```

---

## `Bnum.fromLog10`

```lua
local value = Bnum.fromLog10(1000)
```

represents:

```text
1e1000
```

Negative example:

```lua
local value = Bnum.fromLog10(1000, -1)
```

---

## `Bnum.pow10`

```lua
local value = Bnum.pow10(5000)
```

represents:

```text
10^5000
```

---

# String Parsing

`fromString` supports:

- Normal decimal numbers
- Scientific notation
- `inf`
- `infinity`
- `nan`
- Supported Bnum suffixes

Examples:

```lua
Bnum.fromString("1000")
Bnum.fromString("123.456")
Bnum.fromString("1e250")
Bnum.fromString("-5.25e100")
Bnum.fromString("1.25M")
Bnum.fromString("5Qa")
Bnum.fromString("inf")
Bnum.fromString("-inf")
Bnum.fromString("nan")
```

Whitespace around the value is supported:

```lua
local value = Bnum.fromString("   1e500   ")
```

---

# Reading and Conversion

## Raw read

```lua
local value = Bnum.fromString("1e500")
local sign, logMagnitude = Bnum.read(value)

print(sign)
print(logMagnitude)
```

Output:

```text
1
500
```

## Normal Luau number

```lua
local value = Bnum.fromNumber(500)
local numberValue = Bnum.toNumber(value)
```

`toNumber` is still limited by ordinary floating-point range.

A valid Bnum such as:

```lua
Bnum.fromString("1e1000")
```

cannot become a normal finite Luau `number`.

## Scientific components

```lua
local value = Bnum.fromString("9.5e100")

local mantissa, exponent = Bnum.toScientific(value)
print(mantissa, exponent)
```

You can also read them individually:

```lua
print(Bnum.mantissa(value))
print(Bnum.exponent(value))
```

## Compact string

```lua
local text = Bnum.toString(value)
```

---

# Arithmetic

## Addition

```lua
local a = Bnum.fromNumber(500)
local b = Bnum.fromNumber(250)

local result = Bnum.add(a, b)

print(Bnum.format(result))
-- 750
```

Addition is performed in logarithmic space. When two values are so far apart that the smaller operand cannot affect the represented floating-point result, Bnum intentionally keeps the dominant value.

---

## Subtraction

```lua
local result = Bnum.sub(
	Bnum.fromNumber(1000),
	Bnum.fromNumber(250)
)

print(Bnum.format(result))
-- 750
```

---

## Multiplication

```lua
local a = Bnum.fromString("1e500")
local b = Bnum.fromString("1e500")

local result = Bnum.mul(a, b)

print(Bnum.formatScientific(result, 2))
-- 1e1000
```

For canonical values:

```text
{signA, logA} × {signB, logB}

sign = signA × signB
log  = logA + logB
```

This is one of the major strengths of the representation.

---

## Division

```lua
local a = Bnum.fromString("1e1000")
local b = Bnum.fromString("1e250")

local result = Bnum.div(a, b)

print(Bnum.formatScientific(result, 2))
-- 1e750
```

Division primarily subtracts log magnitudes.

---

# Direct Bnum + Number Operations

v1.3.3 avoids unnecessary temporary Bnums when one operand is already a normal Luau number.

```lua
local value = Bnum.fromNumber(100)

value = Bnum.addNumber(value, 25)
value = Bnum.subNumber(value, 5)
value = Bnum.mulNumber(value, 1.5)
value = Bnum.divNumber(value, 2)
```

Use these in hot paths instead of repeatedly doing:

```lua
Bnum.add(value, Bnum.fromNumber(25))
```

---

# Fast Scale, Square, Cube, and Fused Math

## `scale10`

Multiply by a power of ten:

```lua
local value = Bnum.fromNumber(9.5)
local scaled = Bnum.scale10(value, 10)
```

Result:

```text
9.5e10
```

## `square`

```lua
local result = Bnum.square(Bnum.fromNumber(12))
-- 144
```

## `cube`

```lua
local result = Bnum.cube(Bnum.fromNumber(5))
-- 125
```

## `mulAdd`

Computes:

```text
a × b + c
```

```lua
local result = Bnum.mulAdd(
	Bnum.fromNumber(2),
	Bnum.fromNumber(3),
	Bnum.fromNumber(4)
)

-- 10
```

## `addMul`

Computes:

```text
a + b × c
```

```lua
local result = Bnum.addMul(
	Bnum.fromNumber(2),
	Bnum.fromNumber(3),
	Bnum.fromNumber(4)
)

-- 14
```

---

# Powers and Roots

## Numeric power

```lua
local value = Bnum.fromNumber(10)
local result = Bnum.pow(value, 1000)

print(Bnum.formatScientific(result))
-- 1e1000
```

## Bnum-valued power

```lua
local base = Bnum.fromNumber(2)
local power = Bnum.fromNumber(10)

local result = Bnum.powValue(base, power)

print(Bnum.format(result))
-- 1024
```

## Square root

```lua
local result = Bnum.sqrt(Bnum.fromNumber(144))
-- 12
```

## Cube root

```lua
local result = Bnum.cbrt(Bnum.fromNumber(-125))
-- -5
```

## Arbitrary root

```lua
local result = Bnum.root(Bnum.fromNumber(32), 5)
-- 2
```

---

# Exponential and Logarithmic Math

Bnum includes:

```lua
Bnum.log10(value)
Bnum.ln(value)
Bnum.log2(value)
Bnum.log(value, base)

Bnum.exp(value)
Bnum.exp10(value)
Bnum.exp2(value)

Bnum.log1p(value)
Bnum.expm1(value)
```

Examples:

```lua
local a = Bnum.log10(Bnum.fromNumber(1000))
local b = Bnum.log2(Bnum.fromNumber(1024))
local c = Bnum.exp10(Bnum.fromNumber(3))

print(Bnum.format(a)) -- 3
print(Bnum.format(b)) -- 10
print(Bnum.format(c)) -- 1000
```

`log1p` and `expm1` are useful when inputs are very close to zero because they avoid unnecessary precision loss compared with naively composing larger operations.

---

# Other Advanced Math

## Hypotenuse

```lua
local result = Bnum.hypot(
	Bnum.fromNumber(3),
	Bnum.fromNumber(4)
)

print(Bnum.format(result))
-- 5
```

## Factorial

```lua
local result = Bnum.factorial(Bnum.fromNumber(5))

print(Bnum.format(result))
-- 120
```

Factorial expects a supported non-negative integer Bnum.

---

# Comparisons

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

`compare` returns:

```text
-1   a < b
 0   a == b
 1   a > b
nil  comparison contains NaN
```

---

# Min, Max, and Clamp

```lua
local smallest = Bnum.min(a, b, c)
local largest = Bnum.max(a, b, c)

local clamped = Bnum.clamp(
	value,
	Bnum.fromNumber(0),
	Bnum.fromNumber(100)
)
```

---

# Rounding

```lua
Bnum.floor(value)
Bnum.ceil(value)
Bnum.round(value, digits)
Bnum.trunc(value)
Bnum.fract(value)
```

Examples:

```lua
local x = Bnum.fromNumber(12.75)

print(Bnum.format(Bnum.floor(x))) -- 12
print(Bnum.format(Bnum.ceil(x)))  -- 13
print(Bnum.format(Bnum.trunc(x))) -- 12
print(Bnum.format(Bnum.fract(x))) -- 0.75
```

---

# Modulo

```lua
local result = Bnum.mod(
	Bnum.fromNumber(17),
	Bnum.fromNumber(5)
)

print(Bnum.format(result))
-- 2
```

Modulo follows Bnum's supported numeric precision model. It is not an arbitrary-precision integer remainder engine.

---

# Range, Distance, and Approximate Math

v1.3.3 includes higher-level helpers:

```lua
Bnum.isInteger(value)
Bnum.between(value, minimum, maximum)

Bnum.distance(a, b)
Bnum.relativeDifference(a, b)
Bnum.approxEq(a, b, relTolerance?, absTolerance?)

Bnum.lerp(a, b, alpha)
Bnum.inverseLerp(a, b, value)
Bnum.remap(value, inMin, inMax, outMin, outMax)
```

Example:

```lua
local a = Bnum.fromNumber(0)
local b = Bnum.fromNumber(100)

local midpoint = Bnum.lerp(a, b, 0.5)

print(Bnum.format(midpoint))
-- 50
```

---

# Array Math

```lua
local values = {
	Bnum.fromNumber(2),
	Bnum.fromNumber(4),
	Bnum.fromNumber(6),
}

local total = Bnum.sum(values)
local multiplied = Bnum.product(values)
local average = Bnum.mean(values)
```

---

# Percent Helpers

```lua
local percent = Bnum.percent(
	Bnum.fromNumber(25),
	Bnum.fromNumber(100)
)

local change = Bnum.percentChange(
	Bnum.fromNumber(100),
	Bnum.fromNumber(125)
)
```

Results are Bnums.

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

`Bnum.sign` returns:

```text
-1
0
1
```

---

# Formatting

Bnum v1.3.3 has a much larger formatting system than the older README documented.

Defaults:

```text
Default format:    standard
Default precision: 2 decimal places
Maximum precision: 8 decimal places
E-notation start:  3000
```

The precision argument is interpreted as **decimal places**.

---

# Format Types

Primary v1.3.3 styles include:

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

Legacy-compatible names are also accepted:

```text
Auto
Suffix
SuffixLong
Scientific
Engineering
Standard
Comma
Logarithm
Raw
```

---

## Standard

```lua
print(Bnum.formatStandard(Bnum.fromNumber(1_250_000), 2))
```

Typical result:

```text
1.25M
```

`Bnum.formatSuffix` remains a legacy alias for this formatter.

---

## Extended

```lua
Bnum.formatExtended(value, 2)
```

Uses standard suffixes through the built-in standard ladder and then extends into generated alphabetic suffixes.

---

## Hybrid

```lua
Bnum.formatHybrid(value, 2)
```

Uses familiar standard suffixes first and generated alphabetic suffixes beyond that range.

---

## Alphabetic

```lua
Bnum.formatAlphabetic(value, 2)
```

Uses generated suffix tiers such as:

```text
aa
ab
ac
...
```

---

## Metric

```lua
Bnum.formatMetric(value, 2)
```

Uses SI-style suffixes such as:

```text
k
M
G
T
P
E
Z
Y
R
Q
```

---

## Exponent

```lua
Bnum.formatExponent(value, 2)
```

Formats as:

```text
mantissa E exponent
```

The exponent itself can use the expanded suffix ladder.

v1.3.3 extends the standard suffix ladder through tier `999`.

Important high-tier examples:

```text
tier 101 -> Ce
tier 102 -> UCe
tier 103 -> DCe
```

That allows exponent displays such as:

```text
logMagnitude = 1e305 -> E100Ce
logMagnitude = 1e306 -> E1UCe
logMagnitude = 1e307 -> E10UCe
logMagnitude = 1e308 -> E100UCe
```

instead of falling back to an awkward nested scientific exponent.

---

## Scientific

```lua
Bnum.formatScientific(value, 2)
```

Example:

```text
1.23e1000
```

---

## Engineering

```lua
Bnum.formatEngineering(value, 2)
```

Engineering notation keeps the displayed exponent aligned to multiples of three.

---

## Roman

```lua
Bnum.formatRoman(Bnum.fromNumber(2026))
```

Classical Roman formatting is supported for exact integers through:

```text
3999
```

Unsupported values fall back to standard formatting.

---

## Extended Roman

```lua
Bnum.formatRomanExtended(value)
```

Extended Roman formatting supports exact integers through the safe-integer range used by the module:

```text
9007199254740991
```

Unsupported inputs fall back to standard formatting.

---

## Plain

```lua
Bnum.formatPlain(value, 2)
```

Uses fixed decimal formatting when practical and falls back to the standard display ladder for large magnitudes.

---

## Comma

```lua
Bnum.formatComma(Bnum.fromNumber(123456789), 2)
```

Example:

```text
123,456,789
```

---

## Logarithm

```lua
Bnum.formatLogarithm(Bnum.fromString("1e1000"), 2)
```

Example:

```text
10^1000
```

Negative values are displayed with a leading `-`.

---

## Raw

```lua
Bnum.formatRaw(Bnum.fromString("1e1000"))
```

Result:

```text
{1, 1000}
```

---

# `Bnum.format`

The main formatter is:

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

Change the default notation:

```lua
Bnum.setDefaultFormat("scientific")
```

Check a name before applying it:

```lua
if Bnum.isFormatType("hybrid") then
	Bnum.setDefaultFormat("hybrid")
end
```

---

# Suffix Lookup

Use:

```lua
local suffix = Bnum.getSuffix(tier)
```

Examples:

```text
tier 1   -> k
tier 101 -> Ce
tier 102 -> UCe
```

The standard generated ladder extends through tier `999`.

---

# Auto Formatting

`autoFormat` remains available for compatibility:

```lua
local text = Bnum.autoFormat(value, 2)
```

It now maps to the newer standard formatter behavior unless the provided options request the compatible long-suffix mode.

---

# Hot-Path Operations

Normal operations allocate a new two-number result table:

```lua
value = Bnum.add(value, reward)
```

For high-frequency loops, reuse an output table:

```lua
local out = {0, 0}

Bnum.addInto(out, value, reward)
```

Available reusable-output APIs include:

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

---

# Reusing Two Buffers/Tables

Instead of allocating every iteration:

```lua
for _ = 1, 100000 do
	value = Bnum.mulNumber(value, 1.01)
end
```

reuse two output tables:

```lua
local current = Bnum.fromNumber(1)
local out = {0, 0}

for _ = 1, 100000 do
	Bnum.mulNumberInto(out, current, 1.01)
	current, out = out, current
end
```

This reduces temporary table allocation pressure in genuine hot paths.

---

# Performance Guidelines

For fastest practical Bnum code:

1. Keep values in canonical Bnum form during calculations.
2. Use `addNumber`, `subNumber`, `mulNumber`, and `divNumber` when the other operand is a normal number.
3. Use `scale10`, `square`, and `cube` instead of composing slower generic operations when they express the calculation directly.
4. Use `mulAdd` and `addMul` when the formula matches.
5. Use `*Into` versions in loops where result allocation is measurable.
6. Avoid repeatedly converting gigantic values to normal Luau numbers.
7. Avoid formatting inside tight simulation loops; format when updating UI.
8. Use `fromString`, `pow10`, or scientific constructors for magnitudes that cannot first exist as normal finite numbers.

---

# Example: Clicker Currency

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage:WaitForChild("Bnum"))

local coins = Bnum.zero
local clickPower = Bnum.fromNumber(1)

local function click()
	coins = Bnum.add(coins, clickPower)
	print("Coins:", Bnum.format(coins, 2))
end

for _ = 1, 10 do
	click()
end
```

---

# Example: Upgrade Cost

```lua
local baseCost = Bnum.fromNumber(100)
local growth = Bnum.fromNumber(1.15)

local function getUpgradeCost(level: number)
	return Bnum.mul(
		baseCost,
		Bnum.pow(growth, level)
	)
end

for level = 0, 10 do
	print(level, Bnum.format(getUpgradeCost(level), 2))
end
```

---

# Example: Faster Upgrade Cost

When one factor is a normal number, use the direct number API:

```lua
local cost = Bnum.fromString("1e100")
local growth = 1.15

for _ = 1, 100 do
	cost = Bnum.mulNumber(cost, growth)
end
```

For a very hot loop:

```lua
local current = Bnum.fromString("1e100")
local out = {0, 0}
local growth = 1.15

for _ = 1, 100000 do
	Bnum.mulNumberInto(out, current, growth)
	current, out = out, current
end
```

---

# Example: Damage Formula

```lua
local baseDamage = Bnum.fromNumber(25)
local strength = Bnum.fromNumber(15)
local bonus = Bnum.fromNumber(100)

local damage = Bnum.mulAdd(baseDamage, strength, bonus)

print(Bnum.format(damage, 2))
```

This computes:

```text
baseDamage × strength + bonus
```

without requiring the caller to manually compose two public Bnum operations.

---

# Example: Progress Bar

```lua
local minimum = Bnum.fromNumber(0)
local maximum = Bnum.fromString("1e100")
local current = Bnum.fromString("5e99")

local alpha = Bnum.inverseLerp(minimum, maximum, current)
local alphaNumber = Bnum.toNumber(alpha)

progressBar.Size = UDim2.fromScale(
	math.clamp(alphaNumber, 0, 1),
	1
)
```

---

# Example: Parsing User-Friendly Values

```lua
local values = {
	"1K",
	"2.5M",
	"7Qa",
	"1e1000",
}

for _, text in values do
	local value = Bnum.fromString(text)
	print(text, "->", Bnum.formatScientific(value, 3))
end
```

---

# Special Values

Bnum supports:

```lua
Bnum.inf
Bnum.ninf
Bnum.nan
```

Check them with:

```lua
Bnum.isInfinite(value)
Bnum.isNaN(value)
Bnum.isFinite(value)
```

Special values propagate according to the operation being performed.

---

# Accuracy Model

Bnum is a **magnitude-oriented floating-point big-number system**.

It is not an arbitrary-precision decimal integer library.

That means it is well suited for values such as:

```text
7.25e5000
1.93e850
4.12e100000
```

where useful magnitude and floating-point precision matter more than retaining every decimal digit.

Bnum is not intended for cryptographic arithmetic or exact arbitrary-length integer accounting.

---

# Why Multiplication and Division Are Fast

Consider:

```text
1e500 × 1e700
```

Canonical storage:

```text
1e500 -> {1, 500}
1e700 -> {1, 700}
```

The magnitude calculation is mainly:

```text
500 + 700 = 1200
```

giving:

```text
{1, 1200}
```

which represents:

```text
1e1200
```

Division works similarly by subtracting logarithmic magnitudes.

---

# Why Addition Is More Expensive

Addition cannot simply add logarithms.

```text
1e100 + 1e100 = 2e100
```

not:

```text
1e200
```

Bnum therefore performs logarithmic addition/subtraction logic that accounts for relative magnitude.

When operands differ by enough orders of magnitude that the smaller one cannot affect the represented floating-point precision, the smaller contribution is intentionally discarded.

Example:

```text
1e1000 + 1
≈ 1e1000
```

for this representation.

---

# Recommended Data Flow

```text
DataStore / config / input
        ↓
number / string / {mantissa, exponent}
        ↓
Bnum.convert / constructor
        ↓
canonical {sign, logMagnitude}
        ↓
game calculations
        ↓
Bnum.format
        ↓
player UI
```

Keep values in Bnum form for the calculation pipeline and only format them when needed for display.

---

# Complete Basic Example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage:WaitForChild("Bnum"))

local coins = Bnum.fromNumber(100)
local clickPower = Bnum.fromNumber(25)
local upgradeCost = Bnum.fromNumber(500)
local upgradeMultiplier = 2.5

local function printStats()
	print("Coins:", Bnum.format(coins, 2))
	print("Click Power:", Bnum.format(clickPower, 2))
	print("Upgrade Cost:", Bnum.format(upgradeCost, 2))
end

local function click()
	coins = Bnum.add(coins, clickPower)
end

local function buyUpgrade()
	if not Bnum.gte(coins, upgradeCost) then
		return false
	end

	coins = Bnum.sub(coins, upgradeCost)
	clickPower = Bnum.mulNumber(clickPower, 2)
	upgradeCost = Bnum.mulNumber(upgradeCost, upgradeMultiplier)

	return true
end

printStats()

for _ = 1, 20 do
	click()
end

printStats()

if buyUpgrade() then
	print("Upgrade purchased")
end

printStats()
```

The same structure keeps working as the economy grows from ordinary values into magnitudes far beyond normal finite Luau numbers.

---

# API Reference

The following API list is generated from the v1.3.3 module's actual public function definitions.


## Construction and Conversion

| Function | Returns | Purpose |
| --- | --- | --- |
| `Bnum.new(man: number?, exp: number?)` | `Value` | Creates a Bnum from a mantissa and a base-10 exponent. |
| `Bnum.raw(sign: number, logMagnitude: number)` | `Value` | Creates a canonical Bnum directly from a sign and log10 magnitude. |
| `Bnum.clone(val: Value)` | `Value` | Returns a new table containing the same Bnum value. |
| `Bnum.read(val: Value)` | `(number, number)` | Returns the raw sign and log10 magnitude stored in a Bnum. |
| `Bnum.fromNumber(n: number)` | `Value` | Converts a normal Luau number into a Bnum. |
| `Bnum.fromTable(val: {any})` | `Value` | Converts a public {mantissa, exponent} table into the internal canonical Bnum. |
| `Bnum.toTable(val: Value)` | `Value` | Returns a normalized public {mantissa, exponent} table. |
| `Bnum.normalize(val: Value)` | `Value` | Normalizes either a canonical Bnum or a public {mantissa, exponent} pair. Canonical values use mantissas -1, 0, or 1, so scientific interpretation preserves their numeric value while also accepting values such as {9.5, 3}. |
| `Bnum.isValid(val: any)` | `boolean` | Checks whether a two-number table can be converted into a Bnum. Both internal canonical values and public {mantissa, exponent} pairs are valid. |
| `Bnum.convert(val: any)` | `Value?` | Converts a number, string, canonical Bnum, or {mantissa, exponent} table into a Bnum. |
| `Bnum.fromScientific(man: number, exp: number)` | `Value` | Creates a Bnum from scientific mantissa × 10^exponent form. |
| `Bnum.fromLog10(logMagnitude: number, sign: number?)` | `Value` | Creates a Bnum directly from log10(abs(value)) and an optional sign. |
| `Bnum.pow10(exp: number)` | `Value` | Creates 10 raised to a normal numeric exponent. |
| `Bnum.fromString(str: string)` | `Value` | Parses decimal, scientific, infinity, NaN, and supported suffix strings. |
| `Bnum.toNumber(val: Value)` | `number` | Converts a Bnum back to a normal Luau number when representable. |
| `Bnum.toScientific(val: Value)` | `(number, number)` | Returns a normal scientific mantissa and exponent pair. |
| `Bnum.mantissa(val: Value)` | `number` | Returns the signed scientific mantissa of a Bnum. |
| `Bnum.exponent(val: Value)` | `number` | Returns the base-10 scientific exponent of a Bnum. |
| `Bnum.toString(val: Value)` | `string` | Serializes a Bnum into a compact scientific string. |

## Core Arithmetic

| Function | Returns | Purpose |
| --- | --- | --- |
| `Bnum.add(val1: Value, val2: Value)` | `Value` | Adds two Bnums using direct log-space arithmetic. |
| `Bnum.sub(val1: Value, val2: Value)` | `Value` | Subtracts the second Bnum from the first using direct log-space arithmetic. |
| `Bnum.mul(val1: Value, val2: Value)` | `Value` | Multiplies two Bnums by multiplying signs and adding log magnitudes. |
| `Bnum.div(val1: Value, val2: Value)` | `Value` | Divides the first Bnum by the second using direct log-space arithmetic. |
| `Bnum.addNumber(val: Value, n: number)` | `Value` | Adds a normal Luau number directly to a Bnum without creating a temporary Bnum. |
| `Bnum.subNumber(val: Value, n: number)` | `Value` | Subtracts a normal Luau number directly from a Bnum. |
| `Bnum.mulNumber(val: Value, n: number)` | `Value` | Multiplies a Bnum directly by a normal Luau number. |
| `Bnum.divNumber(val: Value, n: number)` | `Value` | Divides a Bnum directly by a normal Luau number. |
| `Bnum.scale10(val: Value, exponent: number)` | `Value` | Multiplies a Bnum by 10^exponent by shifting its log magnitude. |
| `Bnum.square(val: Value)` | `Value` | Squares a Bnum using the direct log identity log10(x²) = 2 log10(x). |
| `Bnum.cube(val: Value)` | `Value` | Cubes a Bnum using the direct log identity log10(x³) = 3 log10(x). |
| `Bnum.mulAdd(a: Value, b: Value, c: Value)` | `Value` | Computes a × b + c in one fused Bnum operation. |
| `Bnum.addMul(a: Value, b: Value, c: Value)` | `Value` | Computes a + b × c in one fused Bnum operation. |
| `Bnum.reciprocal(val: Value)` | `Value` | Returns 1 / value by negating the stored log magnitude. |

## Powers, Roots, Logs, and Advanced Math

| Function | Returns | Purpose |
| --- | --- | --- |
| `Bnum.pow(val: Value, power: number)` | `Value` | Raises a Bnum to a normal numeric power. |
| `Bnum.sqrt(val: Value)` | `Value` | Returns the real square root of a non-negative Bnum. |
| `Bnum.cbrt(val: Value)` | `Value` | Returns the real cube root of a Bnum, including negative values. |
| `Bnum.root(val: Value, degree: number)` | `Value` | Returns the real nth root of a Bnum when the requested root is defined. |
| `Bnum.abs(val: Value)` | `Value` | Returns the absolute value of a Bnum. |
| `Bnum.neg(val: Value)` | `Value` | Negates the sign of a Bnum. |
| `Bnum.log10(val: Value)` | `Value` | Returns the base-10 logarithm of a positive Bnum as another Bnum. |
| `Bnum.ln(val: Value)` | `Value` | Returns the natural logarithm of a positive Bnum. |
| `Bnum.log2(val: Value)` | `Value` | Returns the base-2 logarithm of a positive Bnum. |
| `Bnum.log(val: Value, base: Value)` | `Value` | Returns the logarithm of a value in an arbitrary positive base other than 1. |
| `Bnum.exp(val: Value)` | `Value` | Returns e^value while preserving Bnum overflow and underflow behavior. |
| `Bnum.exp10(val: Value)` | `Value` | Returns 10^value where value itself is a Bnum. |
| `Bnum.exp2(val: Value)` | `Value` | Returns 2^value where value itself is a Bnum. |
| `Bnum.powValue(val: Value, power: Value)` | `Value` | Raises a Bnum to a power that is also stored as a Bnum. |
| `Bnum.log1p(val: Value)` | `Value` | Computes ln(1 + x) with extra care for tiny x values. |
| `Bnum.expm1(val: Value)` | `Value` | Computes e^x - 1 with extra care for tiny x values. |
| `Bnum.hypot(a: Value, b: Value)` | `Value` | Computes sqrt(a² + b²) in Bnum space. |
| `Bnum.factorial(val: Value)` | `Value` | Computes n! for non-negative integer Bnum inputs. |

## Comparison and Selection

| Function | Returns | Purpose |
| --- | --- | --- |
| `Bnum.compare(val1: Value, val2: Value)` | `number?` | Compares two Bnums and returns -1, 0, or 1. |
| `Bnum.eq(val1: Value, val2: Value)` | `boolean` | Returns true when two Bnums represent exactly the same canonical value. |
| `Bnum.neq(val1: Value, val2: Value)` | `boolean` | Returns true when two Bnums represent different canonical values. |
| `Bnum.lt(val1: Value, val2: Value)` | `boolean` | Returns true when the first Bnum is less than the second. |
| `Bnum.lte(val1: Value, val2: Value)` | `boolean` | Returns true when the first Bnum is less than or equal to the second. |
| `Bnum.gt(val1: Value, val2: Value)` | `boolean` | Returns true when the first Bnum is greater than the second. |
| `Bnum.gte(val1: Value, val2: Value)` | `boolean` | Returns true when the first Bnum is greater than or equal to the second. |
| `Bnum.min(val1: Value, val2: Value?, ...: Value)` | `Value` | Returns the smallest Bnum from the supplied values. |
| `Bnum.max(val1: Value, val2: Value?, ...: Value)` | `Value` | Returns the largest Bnum from the supplied values. |
| `Bnum.clamp(val: Value, minimum: Value, maximum: Value)` | `Value` | Clamps a Bnum between a minimum and maximum value. |

## Rounding, Ranges, and Utility Math

| Function | Returns | Purpose |
| --- | --- | --- |
| `Bnum.floor(val: Value)` | `Value` | Rounds a Bnum down toward negative infinity. |
| `Bnum.ceil(val: Value)` | `Value` | Rounds a Bnum up toward positive infinity. |
| `Bnum.round(val: Value, digits: number?)` | `Value` | Rounds a Bnum to the requested decimal digit count. |
| `Bnum.mod(val1: Value, val2: Value)` | `Value` | Returns the remainder of integer-style division between two Bnums. |
| `Bnum.trunc(val: Value)` | `Value` | Removes the fractional part of a Bnum by rounding toward zero. |
| `Bnum.fract(val: Value)` | `Value` | Returns only the signed fractional part using direct inline math. |
| `Bnum.isInteger(val: Value)` | `boolean` | Checks whether a finite Bnum represents an exact integer in the supported precision range. |
| `Bnum.between(val: Value, minimum: Value, maximum: Value)` | `boolean` | Checks whether a Bnum lies inclusively between two bounds. |
| `Bnum.distance(a: Value, b: Value)` | `Value` | Returns the absolute distance between two Bnums. |
| `Bnum.relativeDifference(a: Value, b: Value)` | `Value` | Returns the absolute difference relative to the larger absolute input. |
| `Bnum.approxEq(a: Value, b: Value, relTolerance: number?, absTolerance: number?)` | `boolean` | Checks approximate equality using relative and absolute tolerances. |
| `Bnum.lerp(a: Value, b: Value, alpha: number)` | `Value` | Linearly interpolates between two Bnums using a normal numeric alpha. |
| `Bnum.inverseLerp(a: Value, b: Value, val: Value)` | `Value` | Returns the interpolation alpha of a value between two Bnum endpoints. |
| `Bnum.remap(val: Value, inMin: Value, inMax: Value, outMin: Value, outMax: Value)` | `Value` | Maps a Bnum from one numeric range into another range. |
| `Bnum.sum(values: {Value})` | `Value` | Adds every Bnum in an array using an inline accumulator. |
| `Bnum.product(values: {Value})` | `Value` | Multiplies every Bnum in an array using an inline accumulator. |
| `Bnum.mean(values: {Value})` | `Value` | Returns the arithmetic mean of all Bnums in an array. |
| `Bnum.percent(part: Value, whole: Value)` | `Value` | Returns part / whole × 100 as a Bnum. |
| `Bnum.percentChange(oldValue: Value, newValue: Value)` | `Value` | Returns the percentage change from an old Bnum to a new Bnum. |

## Checks

| Function | Returns | Purpose |
| --- | --- | --- |
| `Bnum.isZero(val: Value)` | `boolean` | Checks whether a Bnum is canonical zero. |
| `Bnum.isNaN(val: Value)` | `boolean` | Checks whether a Bnum stores NaN. |
| `Bnum.isInfinite(val: Value)` | `boolean` | Checks whether a Bnum represents positive or negative infinity. |
| `Bnum.isFinite(val: Value)` | `boolean` | Checks whether a Bnum is finite and not NaN. |
| `Bnum.isPositive(val: Value)` | `boolean` | Checks whether a Bnum is strictly greater than zero. |
| `Bnum.isNegative(val: Value)` | `boolean` | Checks whether a Bnum is strictly less than zero. |
| `Bnum.sign(val: Value)` | `number` | Returns -1, 0, or 1 for the Bnum sign. |

## Formatting

| Function | Returns | Purpose |
| --- | --- | --- |
| `Bnum.getSuffix(tier: number)` | `string?` | Returns the suffix used by the standard formatter through tier 999. Examples: tier 1 -> "k", tier 101 -> "Ce", tier 102 -> "UCe" |
| `Bnum.isFormatType(formatType: string)` | `boolean` | Checks whether a formatter notation name is supported. |
| `Bnum.setDefaultFormat(formatType: string)` | `boolean` | Sets the default notation used by Bnum.format(). |
| `Bnum.format(val: Value, decimalPlaces: number?, formatType: FormatType?)` | `string` | NanoNum-style default formatter. Examples: 1250000 -> "1.25M", 10^3000 -> "E3k" |
| `Bnum.formatStandard(val: Value, decimalPlaces: number?)` | `string` | Formats with the standard suffix ladder. |
| `Bnum.formatExtended(val: Value, decimalPlaces: number?)` | `string` | Formats with standard suffixes through Ce, then alphabetic suffixes through tier 999. |
| `Bnum.formatHybrid(val: Value, decimalPlaces: number?)` | `string` | Formats with standard suffixes first and alphabetic suffixes beyond the standard ladder. |
| `Bnum.formatAlphabetic(val: Value, decimalPlaces: number?)` | `string` | Formats 10^3 tiers as aa, ab, ac, ... |
| `Bnum.formatMetric(val: Value, decimalPlaces: number?)` | `string` | Formats using SI-style metric suffixes k, M, G, T, ... |
| `Bnum.formatExponent(val: Value, decimalPlaces: number?)` | `string` | Formats as mantissa E exponent. |
| `Bnum.formatScientific(val: Value, decimalPlaces: number?)` | `string` | Formats in scientific notation. |
| `Bnum.formatEngineering(val: Value, decimalPlaces: number?)` | `string` | Formats in engineering notation. |
| `Bnum.formatRoman(val: Value, decimalPlaces: number?)` | `string` | Formats exact integers as classical Roman numerals when possible. Falls back to standard notation when the value is not a supported integer. |
| `Bnum.formatRomanExtended(val: Value, decimalPlaces: number?)` | `string` | Formats exact integers with parenthesized extended Roman numerals. Falls back to standard notation when the value is not a supported integer. |
| `Bnum.formatSuffix(val: Value, decimalPlaces: number?)` | `string` | Legacy alias for the standard suffix formatter. |
| `Bnum.formatSuffixLong(val: Value, decimalPlaces: number?)` | `string` | Legacy long-name suffix formatter. |
| `Bnum.formatPlain(val: Value, decimalPlaces: number?)` | `string` | Formats as a fixed decimal when representable. Large values fall back to the standard display ladder. |
| `Bnum.formatComma(val: Value, decimalPlaces: number?)` | `string` | Formats normal-sized values with comma grouping. Large values fall back to the standard display ladder. |
| `Bnum.formatLogarithm(val: Value, decimalPlaces: number?)` | `string` | Formats as 10^logMagnitude. |
| `Bnum.formatRaw(val: Value)` | `string` | Returns the raw {sign, logMagnitude} representation. |
| `Bnum.autoFormat(val: Value, digits: number?, options: AutoFormatOptions?)` | `string` | Compatibility entry point. The NanoNum-style standard formatter is now the default. Existing option fields are retained where they map cleanly to the new formatter. |

## Reusable Output / Hot-Path API

| Function | Returns | Purpose |
| --- | --- | --- |
| `Bnum.addInto(out: Value, val1: Value, val2: Value)` | `Value` | Adds two Bnums and writes the result into an existing output table. |
| `Bnum.subInto(out: Value, val1: Value, val2: Value)` | `Value` | Subtracts two Bnums and writes the result into an existing output table. |
| `Bnum.mulInto(out: Value, val1: Value, val2: Value)` | `Value` | Multiplies two Bnums and writes the result into an existing output table. |
| `Bnum.divInto(out: Value, val1: Value, val2: Value)` | `Value` | Divides two Bnums and writes the result into an existing output table. |
| `Bnum.powInto(out: Value, val: Value, power: number)` | `Value` | Raises a Bnum to a numeric power and writes into an existing output table. |
| `Bnum.addNumberInto(out: Value, val: Value, n: number)` | `Value` | Adds a normal number to a Bnum and writes into an existing output table. |
| `Bnum.subNumberInto(out: Value, val: Value, n: number)` | `Value` | Subtracts a normal number from a Bnum and writes into an existing output table. |
| `Bnum.mulNumberInto(out: Value, val: Value, n: number)` | `Value` | Multiplies a Bnum by a normal number and writes into an existing output table. |
| `Bnum.divNumberInto(out: Value, val: Value, n: number)` | `Value` | Divides a Bnum by a normal number and writes into an existing output table. |
| `Bnum.scale10Into(out: Value, val: Value, exponent: number)` | `Value` | Scales a Bnum by 10^exponent and writes into an existing output table. |
| `Bnum.squareInto(out: Value, val: Value)` | `Value` | Squares a Bnum and writes into an existing output table. |
| `Bnum.cubeInto(out: Value, val: Value)` | `Value` | Cubes a Bnum and writes into an existing output table. |
| `Bnum.mulAddInto(out: Value, a: Value, b: Value, c: Value)` | `Value` | Computes a × b + c directly into an existing output table. |
| `Bnum.addMulInto(out: Value, a: Value, b: Value, c: Value)` | `Value` | Computes a + b × c directly into an existing output table. |


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

Current v1.3.3 defaults:

```text
DEFAULT_FORMAT        = standard
DEFAULT_PRECISION     = 2
MAX_PRECISION         = 8
E_NOTATION_START      = 3000
FORMAT_PRECISION_MODE = decimal-places

ROMAN_CLASSICAL_MAX   = 3999
ROMAN_EXTENDED_MAX    = 9007199254740991
```

---

# v1.3.3 Changes

Compared with the much older v0.5.5 README, the current module now documents and exposes a substantially larger API.

Major current capabilities include:

- 122 public functions
- Public `{mantissa, exponent}` table conversion
- Suffix parsing in `fromString`
- Direct Bnum/number arithmetic
- Fast `scale10`, `square`, and `cube`
- Fused `mulAdd` and `addMul`
- Bnum-valued powers
- `exp10` and `exp2`
- `log1p` and `expm1`
- `hypot`
- `factorial`
- `trunc` and `fract`
- Integer/range checks
- Distance and approximate equality
- Interpolation and remapping
- Array sum/product/mean
- Percent and percent-change helpers
- Expanded formatter family
- Roman and extended Roman formatting
- Standard suffix generation through tier `999`
- Exponent suffixes including `UCe` and `DCe`
- Expanded reusable-output APIs
- Direct reusable Bnum/number operations
- Fused reusable-output math

---

# Summary

Bnum v1.3.3 keeps its core design simple:

> Store a sign and the base-10 logarithm of the magnitude, then perform as much arithmetic as possible directly in that space.

The result is a compact big-number system suited to Roblox economy and simulation workloads where:

- values can become enormous,
- approximate floating-point precision is acceptable,
- formatting matters,
- multiplication/division/powers are common,
- and hot paths benefit from low allocation overhead.

For normal code, use the straightforward API:

```lua
value = Bnum.add(value, reward)
```

For mixed Bnum/number math, prefer:

```lua
value = Bnum.mulNumber(value, 1.15)
```

For extremely hot loops, move to reusable output:

```lua
Bnum.mulNumberInto(out, value, 1.15)
```

And when you want `{mantissa, exponent}` for interoperability or inspection:

```lua
local pair = Bnum.toTable(value)
local restored = Bnum.fromTable(pair)
```

---

## Version

```text
Bnum v1.3.3
```
