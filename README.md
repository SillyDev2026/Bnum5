# Bnum

**Bnum v0.5.5** is a fast big-number library for Roblox Luau built around a compact **base-10 logarithmic representation**.

Instead of storing the full number directly, Bnum stores each value as:

```lua
{sign, logMagnitude}
```

where:

```text
sign         = -1, 0, or 1
logMagnitude = log10(abs(value))
```

For example:

```text
1,000       -> { 1, 3 }
1,000,000   -> { 1, 6 }
-1,000      -> {-1, 3 }
1e1000      -> { 1, 1000 }
```

This lets Bnum represent numbers far beyond the normal range of a Luau `number` while keeping the internal representation extremely small and making common operations such as multiplication, division, powers, comparisons, and formatting inexpensive.

Bnum is designed for systems such as:

* Clicker and incremental games
* Simulators
* Currency systems
* Damage systems
* Upgrade prices
* Leaderboards
* Economy calculations
* Extremely large statistics
* High-frequency server calculations

---

# Features

Bnum v0.5.5 includes:

* Compact two-number representation
* Positive and negative huge numbers
* Zero, infinity, negative infinity, and NaN
* Fast number construction
* Scientific-notation string parsing
* Addition and subtraction
* Multiplication and division
* Powers and roots
* Logarithms
* Exponential calculations
* Comparisons
* Min, max, and clamp
* Floor, ceil, round, and modulo
* Number classification helpers
* Scientific formatting
* Engineering formatting
* Standard formatting
* Comma formatting
* Short suffix formatting
* Long suffix formatting
* Logarithmic formatting
* Raw/debug formatting
* Automatic formatting
* Allocation-saving `*Into` operations for hot paths

The module is compiled with:

```lua
--!native
--!optimize 2
```

---

# Installation

Place the Bnum ModuleScript somewhere accessible to your code.

For example:

```text
ReplicatedStorage
└── Bnum
```

Then require it:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage.Bnum)
```

You can check the current version with:

```lua
print(Bnum.Version)
```

Current version:

```text
0.5.5
```

---

# Quick Start

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage.Bnum)

local coins = Bnum.fromNumber(1000)
local reward = Bnum.fromString("1e6")

coins = Bnum.add(coins, reward)

print(Bnum.format(coins, 2, "Auto"))
```

Result:

```text
1M
```

The exact displayed value can vary depending on the calculation and requested precision.

---

# How Bnum Works

A normal Luau `number` stores the actual numeric value.

Bnum instead stores its sign and logarithmic magnitude.

For a positive number:

```text
value = 10 ^ logMagnitude
```

For a negative number:

```text
value = -(10 ^ logMagnitude)
```

Conceptually:

```lua
local value = {1, 1000}
```

means:

```text
10^1000
```

That number cannot be represented as an ordinary finite Luau number, but Bnum only needs to store:

```text
sign = 1
logMagnitude = 1000
```

## Examples

| Number   | Bnum representation |
| -------- | ------------------- |
| `0`      | `{0, 0}`            |
| `1`      | `{1, 0}`            |
| `10`     | `{1, 1}`            |
| `100`    | `{1, 2}`            |
| `1000`   | `{1, 3}`            |
| `1e100`  | `{1, 100}`          |
| `1e1000` | `{1, 1000}`         |
| `-1000`  | `{-1, 3}`           |

This is particularly useful for incremental games because the magnitude of a value can grow enormously without requiring the full decimal number to be stored.

---

# Value Type

Bnum defines its core value as:

```lua
export type Value = {number}
```

In practice a normal Bnum contains two entries:

```lua
{
	sign,
	logMagnitude,
}
```

You normally should not modify these entries manually.

Use the constructors provided by Bnum instead.

---

# Built-in Constants

Bnum includes several predefined constants:

```lua
Bnum.zero
Bnum.one
Bnum.ten

Bnum.inf
Bnum.ninf
Bnum.nan
```

Examples:

```lua
print(Bnum.format(Bnum.zero))
print(Bnum.format(Bnum.one))
print(Bnum.format(Bnum.ten))
```

The predefined constants are frozen tables, so treat them as immutable.

---

# Creating Numbers

## `Bnum.fromNumber`

Convert a normal Luau number into Bnum.

```lua
local value = Bnum.fromNumber(125000)
```

Example:

```lua
local coins = Bnum.fromNumber(500)
local damage = Bnum.fromNumber(2500)
```

---

## `Bnum.fromString`

Parse a number from a string.

```lua
local value = Bnum.fromString("1e1000")
```

Examples:

```lua
local a = Bnum.fromString("1000")
local b = Bnum.fromString("123.456")
local c = Bnum.fromString("1e250")
local d = Bnum.fromString("-5.25e100")
```

Whitespace is allowed:

```lua
local value = Bnum.fromString("   1e500   ")
```

Special values are also recognized:

```lua
Bnum.fromString("inf")
Bnum.fromString("+inf")
Bnum.fromString("-inf")

Bnum.fromString("infinity")
Bnum.fromString("-infinity")

Bnum.fromString("nan")
```

`fromString` parses numeric and scientific notation. It does **not** parse Bnum display suffixes such as `"1M"` or `"5Qa"`.

---

## `Bnum.new`

Construct a number from a mantissa and base-10 exponent.

```lua
local value = Bnum.new(2.5, 6)
```

This represents approximately:

```text
2.5 × 10^6
```

or:

```text
2,500,000
```

The exponent defaults to `0`.

```lua
local value = Bnum.new(25)
```

---

## `Bnum.fromScientific`

Explicitly create a value from scientific notation components.

```lua
local value = Bnum.fromScientific(1.25, 1000)
```

Represents:

```text
1.25e1000
```

---

## `Bnum.fromLog10`

Create a Bnum directly from its logarithmic magnitude.

```lua
local value = Bnum.fromLog10(1000)
```

Represents:

```text
10^1000
```

Negative values can specify the sign:

```lua
local value = Bnum.fromLog10(1000, -1)
```

Represents:

```text
-10^1000
```

---

## `Bnum.pow10`

Create:

```text
10^x
```

directly.

```lua
local value = Bnum.pow10(5000)
```

Represents:

```text
10^5000
```

This is preferable to:

```lua
Bnum.fromNumber(10 ^ 5000)
```

because the normal Luau calculation would overflow before Bnum receives it.

---

## `Bnum.raw`

Directly construct the internal representation.

```lua
local value = Bnum.raw(1, 1000)
```

Equivalent conceptually to:

```lua
{1, 1000}
```

This is mainly useful for advanced code that already understands Bnum's representation.

---

## `Bnum.convert`

Automatically converts supported input types.

```lua
local a = Bnum.convert(1000)
local b = Bnum.convert("1e1000")
```

Currently supported inputs are:

```text
number
string
```

Unsupported input types return `nil`.

---

# Reading Bnum Values

## `Bnum.read`

Get the internal sign and logarithmic magnitude.

```lua
local value = Bnum.fromString("1e500")

local sign, logMagnitude = Bnum.read(value)

print(sign)
print(logMagnitude)
```

Result:

```text
1
500
```

---

## `Bnum.clone`

Create another Bnum table with the same value.

```lua
local original = Bnum.fromString("1e100")
local copy = Bnum.clone(original)
```

---

## `Bnum.toNumber`

Convert a Bnum back into a normal Luau number.

```lua
local value = Bnum.fromNumber(500)
local numberValue = Bnum.toNumber(value)

print(numberValue)
```

Result:

```text
500
```

### Important

`toNumber` is limited by the normal floating-point range.

For example:

```lua
local value = Bnum.fromString("1e1000")
local n = Bnum.toNumber(value)
```

The Bnum itself is valid, but converting it into a normal `number` may produce infinity because a normal floating-point value cannot hold `1e1000`.

Keep calculations as Bnum values whenever possible.

---

## `Bnum.toScientific`

Return a normal mantissa and exponent.

```lua
local value = Bnum.fromString("1.5e100")

local mantissa, exponent = Bnum.toScientific(value)

print(mantissa, exponent)
```

Conceptually:

```text
1.5    100
```

---

## `Bnum.mantissa`

Get the scientific mantissa.

```lua
local value = Bnum.fromString("2.5e20")

print(Bnum.mantissa(value))
```

---

## `Bnum.exponent`

Get the base-10 scientific exponent.

```lua
local value = Bnum.fromString("2.5e20")

print(Bnum.exponent(value))
```

Result:

```text
20
```

---

# Arithmetic

Bnum arithmetic returns new Bnum values.

---

## Addition

```lua
local a = Bnum.fromNumber(500)
local b = Bnum.fromNumber(250)

local result = Bnum.add(a, b)

print(Bnum.format(result))
```

Result:

```text
750
```

Huge values work the same way:

```lua
local a = Bnum.fromString("1e500")
local b = Bnum.fromString("1e500")

local result = Bnum.add(a, b)

print(Bnum.formatScientific(result))
```

Conceptually:

```text
2e500
```

For values separated by a very large number of orders of magnitude, Bnum may intentionally discard the insignificant smaller operand because it cannot meaningfully affect the represented result.

---

## Subtraction

```lua
local a = Bnum.fromNumber(1000)
local b = Bnum.fromNumber(250)

local result = Bnum.sub(a, b)

print(Bnum.format(result))
```

Result:

```text
750
```

Negative results are supported:

```lua
local result = Bnum.sub(
	Bnum.fromNumber(100),
	Bnum.fromNumber(500)
)

print(Bnum.format(result))
```

Result:

```text
-400
```

---

## Multiplication

```lua
local a = Bnum.fromString("1e500")
local b = Bnum.fromString("1e500")

local result = Bnum.mul(a, b)

print(Bnum.formatScientific(result))
```

Result conceptually:

```text
1e1000
```

Because Bnum stores logarithms, multiplication is primarily equivalent to adding logarithmic magnitudes:

```text
10^500 × 10^500
=
10^(500 + 500)
=
10^1000
```

This is one of the main advantages of the representation.

---

## Division

```lua
local a = Bnum.fromString("1e1000")
local b = Bnum.fromString("1e250")

local result = Bnum.div(a, b)

print(Bnum.formatScientific(result))
```

Result:

```text
1e750
```

Internally, division primarily subtracts logarithmic magnitudes.

---

## Reciprocal

Calculate:

```text
1 / x
```

with:

```lua
local value = Bnum.fromNumber(4)
local result = Bnum.reciprocal(value)

print(Bnum.format(result))
```

Result:

```text
0.25
```

---

# Powers

## `Bnum.pow`

Raise a Bnum to a normal Luau-number power.

```lua
local value = Bnum.fromNumber(10)
local result = Bnum.pow(value, 1000)

print(Bnum.formatScientific(result))
```

Result:

```text
1e1000
```

Another example:

```lua
local value = Bnum.fromNumber(2)
local squared = Bnum.pow(value, 2)
```

### Negative bases

Negative bases require integer powers.

Valid:

```lua
Bnum.pow(Bnum.fromNumber(-2), 3)
Bnum.pow(Bnum.fromNumber(-2), 4)
```

A fractional power of a negative value returns NaN:

```lua
Bnum.pow(Bnum.fromNumber(-2), 0.5)
```

---

# Roots

## Square root

```lua
local value = Bnum.fromNumber(144)
local result = Bnum.sqrt(value)

print(Bnum.format(result))
```

Approximately:

```text
12
```

Negative inputs return NaN.

---

## Cube root

```lua
local value = Bnum.fromNumber(1000)
local result = Bnum.cbrt(value)

print(Bnum.format(result))
```

Approximately:

```text
10
```

---

## Arbitrary root

```lua
local value = Bnum.fromString("1e1000")
local result = Bnum.root(value, 10)

print(Bnum.formatScientific(result))
```

Result:

```text
1e100
```

Negative values only support appropriate odd integer roots.

---

# Sign Operations

## Absolute value

```lua
local value = Bnum.fromNumber(-100)
local result = Bnum.abs(value)
```

Result:

```text
100
```

## Negate

```lua
local value = Bnum.fromNumber(100)
local result = Bnum.neg(value)
```

Result:

```text
-100
```

---

# Logarithms

Bnum provides several logarithmic functions.

## Base 10

```lua
local value = Bnum.fromString("1e1000")
local result = Bnum.log10(value)

print(Bnum.format(result))
```

Conceptually:

```text
1000
```

---

## Natural logarithm

```lua
local result = Bnum.ln(
	Bnum.fromNumber(100)
)
```

---

## Base 2 logarithm

```lua
local result = Bnum.log2(
	Bnum.fromNumber(1024)
)

print(Bnum.format(result))
```

Approximately:

```text
10
```

---

## Custom logarithm base

```lua
local value = Bnum.fromNumber(1000)
local base = Bnum.fromNumber(10)

local result = Bnum.log(value, base)

print(Bnum.format(result))
```

Approximately:

```text
3
```

Both the value and base are Bnums.

---

# Exponential Function

Calculate:

```text
e^x
```

with:

```lua
local value = Bnum.fromNumber(10)
local result = Bnum.exp(value)
```

The returned result is another Bnum.

---

# Comparisons

Bnum provides direct comparison functions.

```lua
local a = Bnum.fromString("1e100")
local b = Bnum.fromString("1e200")
```

## Equality

```lua
Bnum.eq(a, b)
Bnum.neq(a, b)
```

Aliases:

```lua
Bnum.equal(a, b)
Bnum.notEqual(a, b)
```

`eq` compares the internal Bnum representation exactly. It is not an approximate floating-point comparison.

---

## Less / Greater

```lua
Bnum.lt(a, b)
Bnum.lte(a, b)

Bnum.gt(a, b)
Bnum.gte(a, b)
```

Aliases:

```lua
Bnum.lessThan(a, b)
Bnum.lessThanOrEqual(a, b)

Bnum.greaterThan(a, b)
Bnum.greaterThanOrEqual(a, b)
```

Example:

```lua
if Bnum.gte(coins, price) then
	print("Player can afford the upgrade")
end
```

---

## `Bnum.compare`

Returns:

```text
-1    val1 < val2
 0    val1 == val2
 1    val1 > val2
nil   comparison contains NaN
```

Example:

```lua
local result = Bnum.compare(a, b)

if result == -1 then
	print("a is smaller")
elseif result == 0 then
	print("equal")
elseif result == 1 then
	print("a is larger")
end
```

---

# Min and Max

```lua
local smallest = Bnum.min(a, b)
local largest = Bnum.max(a, b)
```

Multiple values are supported:

```lua
local largest = Bnum.max(a, b, c, d, e)
```

---

# Clamp

Clamp a Bnum between two values:

```lua
local value = Bnum.fromNumber(150)
local minimum = Bnum.fromNumber(0)
local maximum = Bnum.fromNumber(100)

local result = Bnum.clamp(value, minimum, maximum)

print(Bnum.format(result))
```

Result:

```text
100
```

---

# Rounding

## Floor

```lua
local result = Bnum.floor(
	Bnum.fromNumber(12.9)
)
```

Conceptually:

```text
12
```

---

## Ceil

```lua
local result = Bnum.ceil(
	Bnum.fromNumber(12.1)
)
```

Conceptually:

```text
13
```

---

## Round

```lua
local value = Bnum.fromNumber(12.34567)
local result = Bnum.round(value, 2)

print(Bnum.format(result, 2, "Standard"))
```

Conceptually:

```text
12.35
```

For sufficiently large values where decimal rounding can no longer meaningfully alter the represented magnitude, Bnum can return the value unchanged.

---

# Modulo

```lua
local a = Bnum.fromNumber(17)
local b = Bnum.fromNumber(5)

local result = Bnum.mod(a, b)

print(Bnum.format(result))
```

Result:

```text
2
```

## Modulo limitation

Modulo converts its operands through normal floating-point arithmetic internally.

It is therefore intended for ordinary-sized values.

Values outside its supported magnitude range return NaN rather than pretending to produce a reliable huge-number remainder.

---

# Value Checks

## Zero

```lua
Bnum.isZero(value)
```

## NaN

```lua
Bnum.isNaN(value)
```

## Infinity

```lua
Bnum.isInfinite(value)
```

## Finite

```lua
Bnum.isFinite(value)
```

## Positive

```lua
Bnum.isPositive(value)
```

## Negative

```lua
Bnum.isNegative(value)
```

## Sign

```lua
local sign = Bnum.sign(value)
```

Returns:

```text
-1
0
1
```

depending on the value.

---

# Formatting

Bnum contains a full formatting system for turning huge numbers into readable strings.

The main function is:

```lua
Bnum.format(value, digits?, formatType?)
```

Example:

```lua
local value = Bnum.fromString("123456789")

print(Bnum.format(value, 2, "Auto"))
```

The precision defaults to `2` when applicable and is clamped to the supported formatter range.

---

# Format Types

Available format modes:

```lua
Bnum.FormatTypes.Auto
Bnum.FormatTypes.Suffix
Bnum.FormatTypes.SuffixLong
Bnum.FormatTypes.Scientific
Bnum.FormatTypes.Engineering
Bnum.FormatTypes.Standard
Bnum.FormatTypes.Comma
Bnum.FormatTypes.Logarithm
Bnum.FormatTypes.Raw
```

You can also provide the string directly:

```lua
Bnum.format(value, 2, "Suffix")
```

---

## Auto

```lua
Bnum.format(value, 2, "Auto")
```

Auto formatting selects a readable representation based on magnitude.

Smaller values use standard formatting.

Large values use suffix notation when possible.

Extremely large values fall back to scientific notation.

Example:

```lua
local value = Bnum.fromNumber(1500000)

print(Bnum.format(value, 2, "Auto"))
```

Result:

```text
1.5M
```

Because Auto is the default, this is also valid:

```lua
print(Bnum.format(value))
```

---

# Short Suffix Formatting

```lua
Bnum.formatSuffix(value, digits?)
```

or:

```lua
Bnum.format(value, 2, "Suffix")
```

Common suffixes begin with:

```text
K   Thousand
M   Million
B   Billion
T   Trillion
Qa  Quadrillion
Qi  Quintillion
Sx
Sp
Oc
No
Dc
...
```

Example:

```lua
local coins = Bnum.fromString("1250000000")

print(Bnum.format(coins, 2, "Suffix"))
```

Result:

```text
1.25B
```

Bnum generates suffix tiers up to tier `999`.

Values beyond the available suffix range automatically fall back to scientific notation.

---

# Long Suffix Formatting

```lua
Bnum.formatSuffixLong(value, digits?)
```

or:

```lua
Bnum.format(value, 2, "SuffixLong")
```

Example:

```lua
local value = Bnum.fromNumber(2500000)

print(Bnum.format(value, 2, "SuffixLong"))
```

Result:

```text
2.5 Million
```

Named long suffixes include:

```text
Thousand
Million
Billion
Trillion
Quadrillion
Quintillion
Sextillion
Septillion
Octillion
Nonillion
Decillion
...
Vigintillion
```

After the built-in long-name range, Bnum uses its generated abbreviated suffix system.

---

# Scientific Formatting

```lua
Bnum.formatScientific(value, digits?)
```

Example:

```lua
local value = Bnum.fromString("1.23456e1000")

print(Bnum.formatScientific(value, 2))
```

Approximately:

```text
1.23e1000
```

You can also use:

```lua
Bnum.format(value, 2, "Scientific")
```

---

# Engineering Formatting

Engineering notation keeps the exponent divisible by `3`.

```lua
local value = Bnum.fromString("12345678")

print(Bnum.formatEngineering(value, 2))
```

Output follows the form:

```text
12.35e6
```

depending on the input and precision.

Use:

```lua
Bnum.format(value, 2, "Engineering")
```

---

# Standard Formatting

```lua
Bnum.formatStandard(value, digits?)
```

For ordinary-sized numbers it displays a standard decimal representation.

Example:

```lua
local value = Bnum.fromNumber(123.456)

print(Bnum.formatStandard(value, 2))
```

Result:

```text
123.46
```

Very large or very small values automatically switch to scientific notation.

---

# Comma Formatting

Use:

```lua
Bnum.Comma(value, digits?)
```

or:

```lua
Bnum.format(value, 2, "Comma")
```

Example:

```lua
local value = Bnum.fromNumber(123456789)

print(Bnum.Comma(value))
```

Result:

```text
123,456,789
```

For values outside the normal decimal formatting range, Bnum falls back to scientific formatting.

---

# Logarithmic Formatting

Display the value directly as a power of ten.

```lua
local value = Bnum.fromString("1e1000")

print(Bnum.formatLogarithm(value, 2))
```

Result:

```text
10^1000
```

Negative numbers use:

```text
-10^x
```

Example:

```lua
local value = Bnum.fromString("-1e500")

print(Bnum.format(value, 2, "Logarithm"))
```

Result:

```text
-10^500
```

This format is especially useful for extremely large values where a suffix is no longer useful.

---

# Raw Formatting

Display the internal Bnum representation:

```lua
local value = Bnum.fromString("1e1000")

print(Bnum.formatRaw(value))
```

Result:

```text
{1, 1000}
```

You can also use:

```lua
Bnum.format(value, 2, "Raw")
```

This is useful for debugging.

---

# `toString`

`Bnum.toString` provides a basic scientific representation.

```lua
local value = Bnum.fromString("1e1000")

print(Bnum.toString(value))
```

For user interfaces, `Bnum.format` is generally preferable because it provides precision controls and multiple display modes.

---

# Hot-Path Operations

Regular operations create a new Bnum table:

```lua
local result = Bnum.add(a, b)
```

For calculations executed extremely frequently, Bnum also provides `*Into` variants.

These write their result into an existing table instead of allocating another result table.

Available operations:

```lua
Bnum.addInto(out, a, b)
Bnum.subInto(out, a, b)
Bnum.mulInto(out, a, b)
Bnum.divInto(out, a, b)
Bnum.powInto(out, value, power)
```

Example:

```lua
local a = Bnum.fromString("1e100")
local b = Bnum.fromString("2e100")

local result = {0, 0}

Bnum.addInto(result, a, b)

print(Bnum.format(result))
```

The `result` table is modified directly.

This can be useful in:

* Tight loops
* Simulation updates
* High-frequency economy calculations
* Server-side batching
* Large benchmark workloads
* Systems where temporary allocation pressure matters

---

# Reusing a Hot-Path Buffer

Instead of:

```lua
for i = 1, 100000 do
	value = Bnum.mul(value, multiplier)
end
```

you can reuse buffers:

```lua
local current = Bnum.fromNumber(1)
local multiplier = Bnum.fromNumber(1.01)

local out = {0, 0}

for i = 1, 100000 do
	Bnum.mulInto(out, current, multiplier)

	current[1] = out[1]
	current[2] = out[2]
end
```

If your architecture allows it, you can use two buffers and swap them rather than copying fields:

```lua
local current = Bnum.fromNumber(1)
local out = {0, 0}

local multiplier = Bnum.fromNumber(1.01)

for i = 1, 100000 do
	Bnum.mulInto(out, current, multiplier)
	current, out = out, current
end
```

This minimizes temporary Bnum allocations.

---

# Example: Clicker Currency

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage.Bnum)

local coins = Bnum.fromNumber(0)
local clickPower = Bnum.fromNumber(1)

local function Click()
	coins = Bnum.add(coins, clickPower)

	print(
		"Coins:",
		Bnum.format(coins, 2, "Auto")
	)
end

for _ = 1, 10 do
	Click()
end
```

---

# Example: Upgrade System

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage.Bnum)

local coins = Bnum.fromString("1e12")
local upgradeCost = Bnum.fromString("2.5e9")

if Bnum.gte(coins, upgradeCost) then
	coins = Bnum.sub(coins, upgradeCost)

	print("Upgrade purchased")
	print("Coins:", Bnum.format(coins, 2, "Suffix"))
else
	print("Not enough coins")
end
```

---

# Example: Exponential Upgrade Cost

A common incremental-game formula is:

```text
cost = baseCost × growth^level
```

With Bnum:

```lua
local baseCost = Bnum.fromNumber(100)
local growth = Bnum.fromNumber(1.15)

local function GetUpgradeCost(level: number)
	local growthAtLevel = Bnum.pow(growth, level)
	return Bnum.mul(baseCost, growthAtLevel)
end

for level = 0, 10 do
	local cost = GetUpgradeCost(level)

	print(
		level,
		Bnum.format(cost, 2, "Auto")
	)
end
```

---

# Example: Huge Upgrade Cost

The exact same system continues working after ordinary numbers would become inconvenient:

```lua
local baseCost = Bnum.fromString("1e500")
local growth = Bnum.fromNumber(10)

local level = 1000

local multiplier = Bnum.pow(growth, level)
local cost = Bnum.mul(baseCost, multiplier)

print(Bnum.formatScientific(cost, 2))
```

Conceptually:

```text
1e1500
```

---

# Example: Damage Calculation

```lua
local baseDamage = Bnum.fromNumber(25)
local strengthMultiplier = Bnum.fromNumber(15)
local criticalMultiplier = Bnum.fromNumber(2.5)

local damage = Bnum.mul(baseDamage, strengthMultiplier)
damage = Bnum.mul(damage, criticalMultiplier)

print(
	"Damage:",
	Bnum.format(damage, 2, "Auto")
)
```

---

# Example: Extremely Large Leaderboard Stat

```lua
local power = Bnum.fromString("7.521e2500")

print(
	"Power:",
	Bnum.format(power, 2, "Suffix")
)

print(
	"Scientific:",
	Bnum.format(power, 3, "Scientific")
)

print(
	"Log:",
	Bnum.format(power, 2, "Logarithm")
)
```

The same Bnum can be displayed differently without changing the stored value.

---

# Example: UI Counter

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage.Bnum)

local coinsLabel = script.Parent.Coins

local coins = Bnum.fromString("1.25e15")

local function UpdateUI()
	coinsLabel.Text = "$" .. Bnum.format(
		coins,
		2,
		"Auto"
	)
end

UpdateUI()
```

---

# Example: Affordability Helper

```lua
local function CanAfford(balance, cost)
	return Bnum.gte(balance, cost)
end

local balance = Bnum.fromString("1e100")
local cost = Bnum.fromString("2.5e99")

if CanAfford(balance, cost) then
	print("Can afford")
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

Formatting:

```lua
print(Bnum.format(Bnum.inf))
print(Bnum.format(Bnum.ninf))
print(Bnum.format(Bnum.nan))
```

Produces:

```text
inf
-inf
nan
```

Special values propagate through calculations according to the operation being performed.

---

# NaN

NaN is used when an operation has no valid real-number result or cannot safely produce the requested result.

Examples can include:

```text
negative square root
fractional power of a negative number
invalid string
undefined infinity arithmetic
unsupported huge modulo
```

Check with:

```lua
if Bnum.isNaN(value) then
	warn("Calculation returned NaN")
end
```

---

# Infinity

Check for infinity with:

```lua
if Bnum.isInfinite(value) then
	print("Infinite value")
end
```

Positive and negative infinity are represented separately through the sign.

---

# Why Multiplication Is Fast

Consider:

```text
1e500 × 1e700
```

A decimal big-number implementation may need to manipulate enormous digit arrays.

Bnum stores:

```text
1e500 -> {1, 500}
1e700 -> {1, 700}
```

Multiplication then becomes approximately:

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

Division works similarly:

```text
1e1200 / 1e200
```

becomes:

```text
1200 - 200
```

resulting in:

```text
1e1000
```

This is why logarithmic representations work particularly well for incremental-game economies.

---

# Addition Is Different

Addition cannot simply add logarithms.

For example:

```text
1e100 + 1e100
```

is:

```text
2e100
```

not:

```text
1e200
```

Bnum performs logarithmic addition to preserve the correct magnitude.

When one operand is many orders of magnitude smaller than the other, its contribution becomes insignificant at floating-point precision.

For example:

```text
1e1000 + 1
```

is effectively:

```text
1e1000
```

at the precision represented by this system.

This behavior is intentional and is ideal for most incremental-game workloads.

---

# Accuracy Model

Bnum is a **magnitude-oriented logarithmic number system**.

It is not an arbitrary-precision decimal integer library.

That distinction is important.

Bnum is excellent when you need:

```text
1e100
1e10000
1e1000000
```

and care about calculations and display at a useful floating-point level of precision.

It is not intended for applications requiring every decimal digit of a gigantic integer to remain exact.

For example, Bnum is appropriate for:

```text
Coins: 7.25e5000
Damage: 1.93e850
Power: 4.12e100000
```

It is not intended to replace arbitrary-precision cryptographic or exact-integer libraries.

---

# Normal Numbers vs Bnum

Normal Luau:

```lua
local value = 1e300
```

works.

Eventually:

```lua
local value = 1e1000
```

cannot remain a normal finite floating-point number.

Bnum:

```lua
local value = Bnum.fromString("1e1000")
```

continues to work because it stores the exponent rather than attempting to store the full value directly.

---

# Important Usage Rule

Do not do this:

```lua
local value = Bnum.fromNumber(10 ^ 1000)
```

The overflow happens **before** Bnum receives the number.

Instead use:

```lua
local value = Bnum.pow10(1000)
```

or:

```lua
local value = Bnum.fromString("1e1000")
```

or:

```lua
local value = Bnum.fromScientific(1, 1000)
```

---

# Recommended Game Pattern

Keep the player's value as Bnum for the entire calculation pipeline.

Good:

```lua
local coins = Bnum.fromString("1e1000")

coins = Bnum.add(
	coins,
	Bnum.fromString("1e995")
)

local display = Bnum.format(coins, 2, "Auto")
```

Avoid repeatedly converting gigantic values to normal numbers:

```lua
local normal = Bnum.toNumber(coins)
```

Once the number exceeds normal floating-point limits, converting it back defeats the purpose of using Bnum.

---

# API Reference

## Construction

```lua
Bnum.new(man?, exp?)
Bnum.raw(sign, logMagnitude)

Bnum.clone(value)
Bnum.read(value)

Bnum.fromNumber(number)
Bnum.fromScientific(mantissa, exponent)
Bnum.fromLog10(logMagnitude, sign?)
Bnum.pow10(exponent)
Bnum.fromString(string)
Bnum.convert(value)
```

## Conversion

```lua
Bnum.toNumber(value)
Bnum.toScientific(value)

Bnum.mantissa(value)
Bnum.exponent(value)

Bnum.toString(value)
```

## Arithmetic

```lua
Bnum.add(a, b)
Bnum.sub(a, b)

Bnum.mul(a, b)
Bnum.div(a, b)

Bnum.reciprocal(value)

Bnum.pow(value, power)

Bnum.sqrt(value)
Bnum.cbrt(value)
Bnum.root(value, degree)

Bnum.abs(value)
Bnum.neg(value)

Bnum.mod(a, b)
```

## Logarithms / Exponential

```lua
Bnum.log10(value)
Bnum.log2(value)
Bnum.ln(value)

Bnum.log(value, base)

Bnum.exp(value)
```

## Comparisons

```lua
Bnum.compare(a, b)

Bnum.eq(a, b)
Bnum.neq(a, b)

Bnum.lt(a, b)
Bnum.lte(a, b)

Bnum.gt(a, b)
Bnum.gte(a, b)
```

Aliases:

```lua
Bnum.equal
Bnum.notEqual

Bnum.lessThan
Bnum.lessThanOrEqual

Bnum.greaterThan
Bnum.greaterThanOrEqual
```

## Selection

```lua
Bnum.min(a, b, ...)
Bnum.max(a, b, ...)

Bnum.clamp(value, minimum, maximum)
```

## Rounding

```lua
Bnum.floor(value)
Bnum.ceil(value)
Bnum.round(value, digits?)

Bnum.mod(a, b)
```

## Checks

```lua
Bnum.isZero(value)
Bnum.isNaN(value)
Bnum.isInfinite(value)
Bnum.isFinite(value)

Bnum.isPositive(value)
Bnum.isNegative(value)

Bnum.sign(value)
```

## Formatting

```lua
Bnum.format(value, digits?, formatType?)

Bnum.formatScientific(value, digits?)
Bnum.formatEngineering(value, digits?)
Bnum.formatStandard(value, digits?)

Bnum.Comma(value, digits?)

Bnum.formatSuffix(value, digits?)
Bnum.formatSuffixLong(value, digits?)

Bnum.formatLogarithm(value, digits?)
Bnum.formatRaw(value)
```

## Hot-Path / Reusable Output

```lua
Bnum.addInto(out, a, b)
Bnum.subInto(out, a, b)

Bnum.mulInto(out, a, b)
Bnum.divInto(out, a, b)

Bnum.powInto(out, value, power)
```

---

# Format Type Reference

```lua
export type FormatType =
	"Auto"
	| "Suffix"
	| "SuffixLong"
	| "Scientific"
	| "Engineering"
	| "Standard"
	| "Comma"
	| "Logarithm"
	| "Raw"
```

Example:

```lua
local styles = {
	"Auto",
	"Suffix",
	"SuffixLong",
	"Scientific",
	"Engineering",
	"Standard",
	"Comma",
	"Logarithm",
	"Raw",
}

local value = Bnum.fromString("1.2345e12")

for _, style in styles do
	print(
		style,
		Bnum.format(value, 2, style)
	)
end
```

---

# Performance-Oriented Usage

For normal game code:

```lua
value = Bnum.add(value, reward)
```

is simple and convenient.

For extremely hot paths:

```lua
Bnum.addInto(out, value, reward)
```

can reduce temporary table creation.

Use regular functions unless profiling shows allocation pressure matters.

Then move critical loops to the `*Into` API.

A good architecture is:

```text
Normal gameplay
    ↓
Bnum.add / sub / mul / div
    ↓
Profile
    ↓
Identify true hot paths
    ↓
Replace selected operations with *Into
```

This keeps ordinary code clean while still allowing aggressive optimization where it actually matters.

---

# Limitations

Bnum intentionally makes several tradeoffs.

### It is logarithmic

Bnum prioritizes enormous range and fast arithmetic rather than exact arbitrary-precision decimal digits.

### `toNumber` is still limited

Converting back to a Luau number reintroduces normal floating-point limits.

### `pow` uses a normal-number exponent

```lua
Bnum.pow(value, power)
```

takes:

```lua
power: number
```

not another Bnum.

### `root` uses a normal-number degree

```lua
Bnum.root(value, degree)
```

also takes a normal Luau number.

### Modulo has a restricted magnitude range

Modulo relies on regular floating-point remainder calculations and intentionally returns NaN when the values are too large or small for that operation to be reliable.

### Suffix parsing is not implemented

This works:

```lua
Bnum.fromString("1e6")
```

This is not a supported parser input:

```lua
Bnum.fromString("1M")
```

Use suffixes for output formatting rather than storage/input.

---

# Suggested Data Flow

A typical incremental game can use:

```text
DataStore
   ↓
string / internal representation
   ↓
Bnum
   ↓
game calculations
   ↓
Bnum.format
   ↓
player UI
```

Keep the calculations in Bnum form and only convert to strings when displaying the value.

---

# Complete Basic Example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bnum = require(ReplicatedStorage.Bnum)

local coins = Bnum.fromNumber(100)
local clickPower = Bnum.fromNumber(25)

local upgradeCost = Bnum.fromNumber(500)
local upgradeMultiplier = Bnum.fromNumber(2)

local function PrintStats()
	print("Coins:", Bnum.format(coins, 2, "Auto"))
	print("Click Power:", Bnum.format(clickPower, 2, "Auto"))
	print("Upgrade Cost:", Bnum.format(upgradeCost, 2, "Auto"))
end

local function Click()
	coins = Bnum.add(coins, clickPower)
end

local function BuyUpgrade()
	if not Bnum.gte(coins, upgradeCost) then
		return false
	end

	coins = Bnum.sub(coins, upgradeCost)
	clickPower = Bnum.mul(clickPower, upgradeMultiplier)
	upgradeCost = Bnum.mul(upgradeCost, Bnum.fromNumber(2.5))

	return true
end

PrintStats()

for _ = 1, 20 do
	Click()
end

PrintStats()

if BuyUpgrade() then
	print("Upgrade purchased")
end

PrintStats()
```

The same structure continues working as the economy grows from:

```text
100
```

to:

```text
1M
```

to:

```text
1Qa
```

to:

```text
1e1000
```

and far beyond ordinary floating-point magnitudes.

---

# Summary

Bnum is designed around a simple idea:

> Store the logarithm of an enormous number instead of the enormous number itself.

That provides a compact representation and makes many common huge-number operations inexpensive.

For Roblox incremental games, Bnum provides the core pieces needed for a large-number economy:

```text
Construction
Parsing
Arithmetic
Powers
Roots
Logs
Comparisons
Rounding
Formatting
Special values
Hot-path operations
```

If your game needs numbers far larger than normal Luau floating-point values while still remaining lightweight and easy to use, Bnum is intended to provide that foundation.

---

## Version

```text
Bnum v0.5.5
```
