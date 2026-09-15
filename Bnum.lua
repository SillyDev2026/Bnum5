--!native
--!optimize 2

local Bnum = {}

Bnum.Version = "1.4.0"

export type Value = {number}
export type FormatType = "standard" | "extended" | "hybrid" | "alphabetic" | "metric" | "exponent" | "scientific" | "engineering" | "roman" | "romanextended" | "plain" | "comma" | "logarithm" | "raw" | "Auto" | "Suffix" | "SuffixLong" | "Scientific" | "Engineering" | "Standard" | "Comma" | "Logarithm" | "Raw"
export type AutoFormatOptions = {
	Digits: number?,
	SmallScientificAt: number?,
	SuffixAt: number?,
	SuffixMaxTier: number?,
	LongSuffix: boolean?,
	LogarithmAt: number?,
}

local LN10 = 2.302585092994046
local LOG10_2 = 0.3010299956639812
local LOG10_LN10 = 0.36221568869946325
local LOG10_INV_LOG10_2 = 0.5213902276543247
local LOG10_LOG10_E = -0.36221568869946325
local LOG10_E = 0.4342944819032518
local LOG10_170 = 2.230448921378274
local MAX_LOG10_DOUBLE = 308.25471555991675
local MAX_EXACT_INTEGER_LOG10 = 15.954589770191003
local ADD_CUTOFF = -16
local CLOSE_CANCEL = -1e-4
local INTEGER_SNAP_REL = 8.881784197001252e-16
local MAX_EXACT_INTEGER = 9007199254740992
local MANTISSA_CLEAN_FACTOR = 100000000000000

local factorialLogs = table.create(171)
factorialLogs[1] = 0
factorialLogs[2] = 0
do
	local acc = 0
	for i = 2, 170 do
		acc += math.log10(i)
		factorialLogs[i + 1] = acc
	end
end

Bnum.zero = table.freeze({0, 0})
Bnum.one = table.freeze({1, 0})
Bnum.ten = table.freeze({1, 1})
Bnum.inf = table.freeze({1, math.huge})
Bnum.ninf = table.freeze({-1, math.huge})
Bnum.nan = table.freeze({0, 0 / 0})
Bnum.two = table.freeze({1, LOG10_2})
Bnum.half = table.freeze({1, -LOG10_2})
Bnum.e = table.freeze({1, 0.4342944819032518})

local suffixes = table.create(1000)
suffixes[1] = ""
suffixes[2] = "K"
suffixes[3] = "M"
suffixes[4] = "B"
suffixes[5] = "T"
suffixes[6] = "Qa"
suffixes[7] = "Qi"
suffixes[8] = "Sx"
suffixes[9] = "Sp"
suffixes[10] = "Oc"
suffixes[11] = "No"
suffixes[12] = "Dc"
suffixes[13] = "Ud"
suffixes[14] = "Dd"
suffixes[15] = "Td"
suffixes[16] = "Qad"
suffixes[17] = "Qid"
suffixes[18] = "Sxd"
suffixes[19] = "Spd"
suffixes[20] = "Ocd"
suffixes[21] = "Nod"

local suffixOnes = {"", "U", "D", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"}
local suffixTensStandalone = {"", "Dc", "Vg", "Tg", "Qag", "Qig", "Sxg", "Spg", "Ocg", "Nog"}
local suffixTensCompound = {"", "d", "vg", "tg", "qag", "qig", "sxg", "spg", "ocg", "nog"}
local suffixHundreds = {"", "Ce", "DuCe", "TrCe", "QrCe", "QnCe", "SeCe", "StCe", "OtCe", "NgCe"}

for tier = 21, 999 do
	local illion = tier - 1
	local ones = illion % 10
	local tens = math.floor(illion / 10) % 10
	local hundreds = math.floor(illion / 100) % 10
	local low = ""

	if tens == 0 then
		low = suffixOnes[ones + 1]
	elseif ones == 0 then
		low = suffixTensStandalone[tens + 1]
	else
		low = suffixOnes[ones + 1] .. suffixTensCompound[tens + 1]
	end

	if hundreds == 0 then
		suffixes[tier + 1] = low
	else
		suffixes[tier + 1] = low .. suffixHundreds[hundreds + 1]
	end
end

local longSuffixes = {
	"", "Thousand", "Million", "Billion", "Trillion", "Quadrillion", "Quintillion",
	"Sextillion", "Septillion", "Octillion", "Nonillion", "Decillion", "Undecillion",
	"Duodecillion", "Tredecillion", "Quattuordecillion", "Quindecillion", "Sexdecillion",
	"Septendecillion", "Octodecillion", "Novemdecillion", "Vigintillion",
}

local suffixLookup: {[string]: number} = {}
for tier = 1, #suffixes - 1 do
	local suffix = suffixes[tier + 1]
	if suffix ~= "" then
		suffixLookup[string.lower(suffix)] = tier
	end
end
for tier = 1, #longSuffixes - 1 do
	suffixLookup[string.lower(longSuffixes[tier + 1])] = tier
end

Bnum.Suffixes = table.freeze(suffixes)

--[[
Creates a Bnum from a mantissa and a base-10 exponent.
Example: 9.5 × 10^10 -> 9.5e10
]]
function Bnum.new(man: number?, exp: number?): Value
	if man == nil or man == 0 then
		return {0, 0}
	end

	local e = exp or 0

	if man ~= man or e ~= e then
		return {0, 0 / 0}
	end

	local sign = math.sign(man)
	local logMagnitude = e + math.log10(if man < 0 then -man else man)

	if logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end

	if logMagnitude == -math.huge then
		return {0, 0}
	end

	return {sign, logMagnitude}
end

--[[
Creates a canonical Bnum directly from a sign and log10 magnitude.
Example: {1, 3} -> 1e3
]]
function Bnum.raw(sign: number, logMagnitude: number): Value
	if sign ~= sign or logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end
	if sign == 0 or logMagnitude == -math.huge then
		return {0, 0}
	end
	return {math.sign(sign), logMagnitude}
end

--[[
Returns a new table containing the same Bnum value.
Example: {1, 3} -> new {1, 3}
]]
function Bnum.clone(val: Value): Value
	return {val[1], val[2]}
end

--[[
Returns the raw sign and log10 magnitude stored in a Bnum.
Example: {-1, 3} -> -1, 3
]]
function Bnum.read(val: Value): (number, number)
	return val[1], val[2]
end

--[[
Converts a normal Luau number into a Bnum.
Example: 1000 -> {1, 3}
]]
function Bnum.fromNumber(n: number): Value
	if n > 0 then return {1, math.log10(n)} end
	if n < 0 then return {-1, math.log10(-n)} end
	if n == 0 then return {0, 0} end
	return {0, n}
end

--[[
Converts a public {mantissa, exponent} table into the internal canonical Bnum.
Example: {9.5, 3} -> 9500
]]
function Bnum.fromTable(val: {any}): Value
	local man = val[1]
	local exp = val[2]
	if type(man) ~= "number" or type(exp) ~= "number" or exp ~= exp then return {0, 0 / 0} end
	if man > 0 then
		local logMagnitude = exp + math.log10(man)
		if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
		if logMagnitude == -math.huge then return {0, 0} end
		return {1, logMagnitude}
	end
	if man < 0 then
		local logMagnitude = exp + math.log10(-man)
		if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
		if logMagnitude == -math.huge then return {0, 0} end
		return {-1, logMagnitude}
	end
	if man == 0 then return {0, 0} end
	return {0, 0 / 0}
end

--[[
Returns a normalized public {mantissa, exponent} table.
Example: 9500 -> {9.5, 3}
]]
function Bnum.toTable(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then return {0, logMagnitude} end
	if sign == 0 then return {0, 0} end
	if logMagnitude == math.huge then return {sign * math.huge, 0} end
	local exp = math.floor(logMagnitude)
	local man = sign * (10 ^ (logMagnitude - exp))
	man = math.round(man * MANTISSA_CLEAN_FACTOR) / MANTISSA_CLEAN_FACTOR
	if man >= 10 or man <= -10 then
		man *= 0.1
		exp += 1
	end
	return {man, exp}
end

--[[
Normalizes either a canonical Bnum or a public {mantissa, exponent} pair.
Canonical values use mantissas -1, 0, or 1, so scientific interpretation
preserves their numeric value while also accepting values such as {9.5, 3}.
]]
function Bnum.normalize(val: Value): Value
	local man = val[1]
	local exp = val[2]
	if type(man) ~= "number" or type(exp) ~= "number" or exp ~= exp then return {0, 0 / 0} end
	if man > 0 then
		local logMagnitude = exp + math.log10(man)
		if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
		if logMagnitude == -math.huge then return {0, 0} end
		return {1, logMagnitude}
	end
	if man < 0 then
		local logMagnitude = exp + math.log10(-man)
		if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
		if logMagnitude == -math.huge then return {0, 0} end
		return {-1, logMagnitude}
	end
	if man == 0 then return {0, 0} end
	return {0, 0 / 0}
end

--[[
Checks whether a two-number table can be converted into a Bnum.
Both internal canonical values and public {mantissa, exponent} pairs are valid.
]]
function Bnum.isValid(val: any): boolean
	if typeof(val) ~= "table" then return false end
	local man = val[1]
	local exp = val[2]
	if typeof(man) ~= "number" or typeof(exp) ~= "number" then return false end
	if man ~= man then return false end
	if exp ~= exp then return man == 0 end
	if man == 0 then return true end
	if (man == math.huge or man == -math.huge) and exp == -math.huge then return false end
	return true
end

--[[
Converts a number, string, canonical Bnum, or {mantissa, exponent} table into a Bnum.
Example: {9.5, 3} -> 9500
]]
function Bnum.convert(val: any): Value?
	local valueType = type(val)
	if valueType == 'string' then
		return Bnum.fromString(val)
	elseif valueType == 'number' then
		return Bnum.fromNumber(val)
	elseif valueType == 'table' then
		return Bnum.fromTable(val)
	end
	return nil
end

--[[
Creates a Bnum from scientific mantissa × 10^exponent form.
Example: 9.5, 10 -> 9.5e10
]]
function Bnum.fromScientific(man: number, exp: number): Value
	if man == 0 then
		return {0, 0}
	end

	if man ~= man or exp ~= exp then
		return {0, 0 / 0}
	end

	local sign = math.sign(man)
	local logMagnitude = exp + math.log10(if man < 0 then -man else man)

	if logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end

	if logMagnitude == -math.huge then
		return {0, 0}
	end

	return {sign, logMagnitude}
end

--[[
Creates a Bnum directly from log10(abs(value)) and an optional sign.
Example: 3, 1 -> 1e3
]]
function Bnum.fromLog10(logMagnitude: number, sign: number?): Value
	local s = sign or 1
	if logMagnitude ~= logMagnitude or s ~= s then
		return {0, 0 / 0}
	end
	if logMagnitude == -math.huge or s == 0 then
		return {0, 0}
	end
	return {math.sign(s), logMagnitude}
end

--[[
Creates 10 raised to a normal numeric exponent.
Example: 3 -> 1e3
]]
function Bnum.pow10(exp: number): Value
	if exp ~= exp then
		return {0, exp}
	end

	if exp == -math.huge then
		return {0, 0}
	end

	return {1, exp}
end

--[[
Parses decimal, scientific, infinity, NaN, and supported suffix strings.
Example: "1.25M" -> 1.25e6
]]
function Bnum.fromString(str: string): Value
	local length = #str
	if length == 0 then return {0, 0 / 0} end

	local direct = tonumber(str)
	if direct ~= nil then
		local magnitude = math.abs(direct)
		if magnitude < math.huge then
			if magnitude == 0 then return {0, 0} end
			return {math.sign(direct), math.log10(magnitude)}
		end
		if direct ~= direct then return {0, 0 / 0} end
	end

	local first = 1
	local last = length
	local c = string.byte(str, first)
	while c == 32 or c == 9 or c == 10 or c == 13 do
		first += 1
		if first > last then return {0, 0 / 0} end
		c = string.byte(str, first)
	end
	local tail = string.byte(str, last)
	while tail == 32 or tail == 9 or tail == 10 or tail == 13 do
		last -= 1
		tail = string.byte(str, last)
	end

	local sign = 1
	if c == 45 then
		sign = -1
		first += 1
		c = string.byte(str, first)
	elseif c == 43 then
		first += 1
		c = string.byte(str, first)
	end
	if first > last then return {0, 0 / 0} end

	if c == 73 or c == 105 or c == 78 or c == 110 then
		local special = string.lower(string.sub(str, first, last))
		if special == "inf" or special == "infinity" then return {sign, math.huge} end
		if special == "nan" then return {0, 0 / 0} end
	end

	local suffixTier = 0
	if (tail >= 65 and tail <= 90) or (tail >= 97 and tail <= 122) then
		local suffixEnd = last
		repeat
			last -= 1
			if last < first then return {0, 0 / 0} end
			tail = string.byte(str, last)
		until not ((tail >= 65 and tail <= 90) or (tail >= 97 and tail <= 122))
		local suffix = string.lower(string.sub(str, last + 1, suffixEnd))
		local found = suffixLookup[suffix]
		if found == nil then return {0, 0 / 0} end
		suffixTier = found
		while tail == 32 or tail == 9 or tail == 10 or tail == 13 do
			last -= 1
			if last < first then return {0, 0 / 0} end
			tail = string.byte(str, last)
		end
	end

	local i = first
	local dot = 0
	local firstSignificant = 0
	local significant = 0
	local significantDigits = 0
	while i <= last do
		c = string.byte(str, i)
		if c >= 48 and c <= 57 then
			if significantDigits == 17 then
				local stop = string.find(str, "[^0-9]", i + 1)
				i = if stop ~= nil and stop <= last then stop else last + 1
			elseif c == 48 and significantDigits == 0 then
				local stop = string.find(str, "[^0]", i + 1)
				i = if stop ~= nil and stop <= last then stop else last + 1
			else
				if significantDigits == 0 then firstSignificant = i end
				significant = significant * 10 + (c - 48)
				significantDigits += 1
				i += 1
			end
		elseif c == 46 and dot == 0 then
			dot = i
			i += 1
		else
			break
		end
	end
	if i == first or (i == first + 1 and dot == first) then return {0, 0 / 0} end

	local normalizedExponent = i - firstSignificant - 1
	if dot ~= 0 then
		normalizedExponent = dot - firstSignificant
		if firstSignificant < dot then normalizedExponent -= 1 end
	end

	local explicitExponent = 0
	if i <= last then
		if c ~= 69 and c ~= 101 then return {0, 0 / 0} end
		i += 1
		if i > last then return {0, 0 / 0} end
		local exponentSign = 1
		c = string.byte(str, i)
		if c == 45 then
			exponentSign = -1
			i += 1
		elseif c == 43 then
			i += 1
		end
		if i > last then return {0, 0 / 0} end
		if last - i < 15 then
			while i <= last do
				c = string.byte(str, i)
				if c < 48 or c > 57 then return {0, 0 / 0} end
				explicitExponent = explicitExponent * 10 + (c - 48)
				i += 1
			end
		else
			local stop = string.find(str, "[^0]", i)
			i = if stop ~= nil and stop <= last then stop else last + 1
			while i <= last do
				c = string.byte(str, i)
				if c < 48 or c > 57 then return {0, 0 / 0} end
				if explicitExponent < 1e307 then
					explicitExponent = explicitExponent * 10 + (c - 48)
				else
					local invalid = string.find(str, "[^0-9]", i + 1)
					if invalid ~= nil and invalid <= last then return {0, 0 / 0} end
					explicitExponent = math.huge
					break
				end
				i += 1
			end
		end
		if exponentSign < 0 then explicitExponent = -explicitExponent end
	end

	if firstSignificant == 0 then return {0, 0} end
	local logMagnitude = explicitExponent + suffixTier * 3 + normalizedExponent + math.log10(significant) - (significantDigits - 1)
	if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
	if logMagnitude == -math.huge then return {0, 0} end
	return {sign, logMagnitude}
end

--[[
Converts a Bnum back to a normal Luau number when representable.
Example: {1, 3} -> 1000
]]
function Bnum.toNumber(val: Value): number
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then return logMagnitude end
	if sign == 0 then return 0 end
	if logMagnitude == math.huge then return sign * math.huge end

	local result = sign * (10 ^ logMagnitude)
	local absResult = math.abs(result)
	if absResult >= 1 and absResult <= MAX_EXACT_INTEGER then
		local nearest = math.round(result)
		if math.abs(result - nearest) <= absResult * INTEGER_SNAP_REL then result = nearest end
	end
	return result
end

--[[
Returns a normal scientific mantissa and exponent pair.
Example: 95000 -> 9.5, 4
]]
function Bnum.toScientific(val: Value): (number, number)
	local sign = val[1]
	local logMagnitude = val[2]
	if sign == 0 then
		if logMagnitude ~= logMagnitude then return logMagnitude, 0 end
		return 0, 0
	end
	if logMagnitude == math.huge then return sign * math.huge, 0 end

	local exp = math.floor(logMagnitude)
	local man = sign * (10 ^ (logMagnitude - exp))
	man = math.round(man * MANTISSA_CLEAN_FACTOR) / MANTISSA_CLEAN_FACTOR
	if man >= 10 or man <= -10 then
		man *= 0.1
		exp += 1
	end
	return man, exp
end

--[[
Returns the signed scientific mantissa of a Bnum.
Example: 95000 -> 9.5
]]
function Bnum.mantissa(val: Value): number
	local sign = val[1]
	local logMagnitude = val[2]
	if sign == 0 then
		if logMagnitude ~= logMagnitude then return logMagnitude end
		return 0
	end
	if logMagnitude == math.huge then return sign * math.huge end

	local exp = math.floor(logMagnitude)
	local man = sign * (10 ^ (logMagnitude - exp))
	man = math.round(man * MANTISSA_CLEAN_FACTOR) / MANTISSA_CLEAN_FACTOR
	if man >= 10 or man <= -10 then man *= 0.1 end
	return man
end

--[[
Returns the base-10 scientific exponent of a Bnum.
Example: 95000 -> 4
]]
function Bnum.exponent(val: Value): number
	local sign = val[1]
	local logMagnitude = val[2]
	if sign == 0 then
		if logMagnitude ~= logMagnitude then return logMagnitude end
		return 0
	end
	if logMagnitude == math.huge then return 0 end

	local exp = math.floor(logMagnitude)
	local man = sign * (10 ^ (logMagnitude - exp))
	man = math.round(man * MANTISSA_CLEAN_FACTOR) / MANTISSA_CLEAN_FACTOR
	if man >= 10 or man <= -10 then exp += 1 end
	return exp
end

function Bnum.toString(val: Value): string
	local sign = val[1]
	local logMagnitude = val[2]
	if sign == 0 then
		if logMagnitude ~= logMagnitude then return "nan" end
		return "0"
	end
	if logMagnitude == math.huge then return if sign < 0 then "-inf" else "inf" end

	local exp = math.floor(logMagnitude)
	local man = sign * (10 ^ (logMagnitude - exp))
	man = math.round(man * MANTISSA_CLEAN_FACTOR) / MANTISSA_CLEAN_FACTOR
	if man >= 10 or man <= -10 then
		man *= 0.1
		exp += 1
	end
	return man .. "e" .. exp
end

--[[
Adds two Bnums using direct log-space arithmetic.
Example: 1 + 1 -> 2, stored as about {1, 0.3010299956639812}
]]
function Bnum.add(val1: Value, val2: Value): Value
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 then
		return {0, 0 / 0}
	end

	if s1 == 0 then
		return {s2, l2}
	end

	if s2 == 0 then
		return {s1, l1}
	end

	if s1 == s2 then
		if l1 == l2 then
			return {s1, l1 + LOG10_2}
		end

		if l1 >= l2 then
			if l1 == math.huge then
				return {s1, l1}
			end

			local delta = l2 - l1

			if delta < ADD_CUTOFF then
				return {s1, l1}
			end

			return {s1, l1 + math.log10(1 + math.exp(delta * LN10))}
		end

		if l2 == math.huge then
			return {s1, l2}
		end

		local delta = l1 - l2

		if delta < ADD_CUTOFF then
			return {s1, l2}
		end

		return {s1, l2 + math.log10(1 + math.exp(delta * LN10))}
	end

	if l1 == l2 then
		if l1 == math.huge then
			return {0, 0 / 0}
		end

		return {0, 0}
	end

	if l1 > l2 then
		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			return {s1, l1}
		end

		local difference

		if delta > CLOSE_CANCEL then
			if delta > -1e-300 then
				return {s1, l1 + (math.log10(-delta) + LOG10_LN10)}
			end

			local x = -delta * LN10
			difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
		else
			difference = 1 - math.exp(delta * LN10)
		end

		if difference <= 0 then
			return {0, 0}
		end

		return {s1, l1 + math.log10(difference)}
	end

	local delta = l1 - l2

	if delta < ADD_CUTOFF then
		return {s2, l2}
	end

	local difference

	if delta > CLOSE_CANCEL then
		if delta > -1e-300 then
			return {s2, l2 + (math.log10(-delta) + LOG10_LN10)}
		end

		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end

	if difference <= 0 then
		return {0, 0}
	end

	return {s2, l2 + math.log10(difference)}
end

--[[
Subtracts the second Bnum from the first using direct log-space arithmetic.
Example: 5 - 2 -> 3
]]
function Bnum.sub(val1: Value, val2: Value): Value
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = -val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 then
		return {0, 0 / 0}
	end

	if s1 == 0 then
		return {s2, l2}
	end

	if s2 == 0 then
		return {s1, l1}
	end

	if s1 == s2 then
		if l1 == l2 then
			return {s1, l1 + LOG10_2}
		end

		if l2 > l1 then
			l1, l2 = l2, l1
		end

		if l1 == math.huge then
			return {s1, l1}
		end

		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			return {s1, l1}
		end

		return {s1, l1 + math.log10(1 + math.exp(delta * LN10))}
	end

	if l1 == l2 then
		if l1 == math.huge then
			return {0, 0 / 0}
		end

		return {0, 0}
	end

	if l1 > l2 then
		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			return {s1, l1}
		end

		local difference

		if delta > CLOSE_CANCEL then
			if delta > -1e-300 then
				return {s1, l1 + (math.log10(-delta) + LOG10_LN10)}
			end

			local x = -delta * LN10
			difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
		else
			difference = 1 - math.exp(delta * LN10)
		end

		if difference <= 0 then
			return {0, 0}
		end

		return {s1, l1 + math.log10(difference)}
	end

	local delta = l1 - l2

	if delta < ADD_CUTOFF then
		return {s2, l2}
	end

	local difference

	if delta > CLOSE_CANCEL then
		if delta > -1e-300 then
			return {s2, l2 + (math.log10(-delta) + LOG10_LN10)}
		end

		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end

	if difference <= 0 then
		return {0, 0}
	end

	return {s2, l2 + math.log10(difference)}
end

--[[
Multiplies two Bnums by multiplying signs and adding log magnitudes.
Example: 10 × 100 -> 1000
]]
function Bnum.mul(val1: Value, val2: Value): Value
	local s1 = val1[1]
	local s2 = val2[1]
	local logMagnitude = val1[2] + val2[2]

	if logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end

	if s1 == 0 or s2 == 0 then
		if logMagnitude == math.huge then
			return {0, 0 / 0}
		end

		return {0, 0}
	end

	if logMagnitude == -math.huge then
		return {0, 0}
	end

	return {s1 * s2, logMagnitude}
end

--[[
Divides the first Bnum by the second using direct log-space arithmetic.
Example: 1000 / 10 -> 100
]]
function Bnum.div(val1: Value, val2: Value): Value
	local s1 = val1[1]
	local s2 = val2[1]
	local logMagnitude = val1[2] - val2[2]

	if logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end

	if s2 == 0 then
		if s1 == 0 then
			return {0, 0 / 0}
		end

		return {s1, math.huge}
	end

	if s1 == 0 or logMagnitude == -math.huge then
		return {0, 0}
	end

	return {s1 * s2, logMagnitude}
end

--[[
Adds a normal Luau number directly to a Bnum without creating a temporary Bnum.
Example: 100 + 25 -> 125
]]
function Bnum.addNumber(val: Value, n: number): Value
	local s1 = val[1]
	local l1 = val[2]

	if n ~= n then
		return {0, 0 / 0}
	end

	if n == 0 then
		return {s1, l1}
	end

	local s2 = math.sign(n)
	local l2 = math.log10(if n < 0 then -n else n)

	if l1 ~= l1 or l2 ~= l2 then
		return {0, 0 / 0}
	end

	if s1 == 0 then
		return {s2, l2}
	end

	if s2 == 0 then
		return {s1, l1}
	end

	if s1 == s2 then
		if l1 == l2 then
			return {s1, l1 + LOG10_2}
		end

		if l1 >= l2 then
			if l1 == math.huge then
				return {s1, l1}
			end

			local delta = l2 - l1

			if delta < ADD_CUTOFF then
				return {s1, l1}
			end

			return {s1, l1 + math.log10(1 + math.exp(delta * LN10))}
		end

		if l2 == math.huge then
			return {s1, l2}
		end

		local delta = l1 - l2

		if delta < ADD_CUTOFF then
			return {s1, l2}
		end

		return {s1, l2 + math.log10(1 + math.exp(delta * LN10))}
	end

	if l1 == l2 then
		if l1 == math.huge then
			return {0, 0 / 0}
		end

		return {0, 0}
	end

	if l1 > l2 then
		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			return {s1, l1}
		end

		local difference

		if delta > CLOSE_CANCEL then
			if delta > -1e-300 then
				return {s1, l1 + (math.log10(-delta) + LOG10_LN10)}
			end

			local x = -delta * LN10
			difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
		else
			difference = 1 - math.exp(delta * LN10)
		end

		if difference <= 0 then
			return {0, 0}
		end

		return {s1, l1 + math.log10(difference)}
	end

	local delta = l1 - l2

	if delta < ADD_CUTOFF then
		return {s2, l2}
	end

	local difference

	if delta > CLOSE_CANCEL then
		if delta > -1e-300 then
			return {s2, l2 + (math.log10(-delta) + LOG10_LN10)}
		end

		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end

	if difference <= 0 then
		return {0, 0}
	end

	return {s2, l2 + math.log10(difference)}
end

--[[
Subtracts a normal Luau number directly from a Bnum.
Example: 100 - 25 -> 75
]]
function Bnum.subNumber(val: Value, n: number): Value
	local s1 = val[1]
	local l1 = val[2]

	if n ~= n then
		return {0, 0 / 0}
	end

	if n == 0 then
		return {s1, l1}
	end

	local s2 = -math.sign(n)
	local l2 = math.log10(if n < 0 then -n else n)

	if l1 ~= l1 or l2 ~= l2 then
		return {0, 0 / 0}
	end

	if s1 == 0 then
		return {s2, l2}
	end

	if s2 == 0 then
		return {s1, l1}
	end

	if s1 == s2 then
		if l1 == l2 then
			return {s1, l1 + LOG10_2}
		end

		if l2 > l1 then
			l1, l2 = l2, l1
		end

		if l1 == math.huge then
			return {s1, l1}
		end

		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			return {s1, l1}
		end

		return {s1, l1 + math.log10(1 + math.exp(delta * LN10))}
	end

	if l1 == l2 then
		if l1 == math.huge then
			return {0, 0 / 0}
		end

		return {0, 0}
	end

	if l1 > l2 then
		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			return {s1, l1}
		end

		local difference

		if delta > CLOSE_CANCEL then
			if delta > -1e-300 then
				return {s1, l1 + (math.log10(-delta) + LOG10_LN10)}
			end

			local x = -delta * LN10
			difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
		else
			difference = 1 - math.exp(delta * LN10)
		end

		if difference <= 0 then
			return {0, 0}
		end

		return {s1, l1 + math.log10(difference)}
	end

	local delta = l1 - l2

	if delta < ADD_CUTOFF then
		return {s2, l2}
	end

	local difference

	if delta > CLOSE_CANCEL then
		if delta > -1e-300 then
			return {s2, l2 + (math.log10(-delta) + LOG10_LN10)}
		end

		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end

	if difference <= 0 then
		return {0, 0}
	end

	return {s2, l2 + math.log10(difference)}
end

--[[
Multiplies a Bnum directly by a normal Luau number.
Example: 100 × 1.5 -> 150
]]
function Bnum.mulNumber(val: Value, n: number): Value
	local s1 = val[1]
	local l1 = val[2]

	if l1 ~= l1 or n ~= n then
		return {0, 0 / 0}
	end

	if n == 0 then
		if s1 ~= 0 and l1 == math.huge then
			return {0, 0 / 0}
		end
		return {0, 0}
	end

	if s1 == 0 then
		if n == math.huge or n == -math.huge then
			return {0, 0 / 0}
		end
		return {0, 0}
	end

	local sign = if n < 0 then -s1 else s1
	local logMagnitude = l1 + math.log10(if n < 0 then -n else n)

	if logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end

	if logMagnitude == -math.huge then
		return {0, 0}
	end

	return {sign, logMagnitude}
end

--[[
Divides a Bnum directly by a normal Luau number.
Example: 100 / 4 -> 25
]]
function Bnum.divNumber(val: Value, n: number): Value
	local s1 = val[1]
	local l1 = val[2]

	if l1 ~= l1 or n ~= n then
		return {0, 0 / 0}
	end

	if n == 0 then
		if s1 == 0 then
			return {0, 0 / 0}
		end
		return {s1, math.huge}
	end

	if s1 == 0 then
		return {0, 0}
	end

	local sign = if n < 0 then -s1 else s1
	local logMagnitude = l1 - math.log10(if n < 0 then -n else n)

	if logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end

	if logMagnitude == -math.huge then
		return {0, 0}
	end

	return {sign, logMagnitude}
end

--[[
Multiplies a Bnum by 10^exponent by shifting its log magnitude.
Example: 9.5 × 10^10 -> 9.5e10
]]
function Bnum.scale10(val: Value, exponent: number): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude or exponent ~= exponent then
		return {0, 0 / 0}
	end

	if sign == 0 then
		return {0, 0}
	end

	local resultLog = logMagnitude + exponent
	if resultLog ~= resultLog then
		return {0, 0 / 0}
	end
	if resultLog == -math.huge then
		return {0, 0}
	end

	return {sign, resultLog}
end

--[[
Squares a Bnum using the direct log identity log10(x²) = 2 log10(x).
Example: 12² -> 144
]]
function Bnum.square(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return {0, logMagnitude}
	end
	if sign == 0 then
		return {0, 0}
	end

	local resultLog = logMagnitude * 2
	if resultLog == -math.huge then
		return {0, 0}
	end
	return {1, resultLog}
end

--[[
Cubes a Bnum using the direct log identity log10(x³) = 3 log10(x).
Example: 5³ -> 125
]]
function Bnum.cube(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return {0, logMagnitude}
	end
	if sign == 0 then
		return {0, 0}
	end

	local resultLog = logMagnitude * 3
	if resultLog == -math.huge then
		return {0, 0}
	end
	return {sign, resultLog}
end

--[[
Computes a × b + c in one fused Bnum operation.
Example: 2 × 3 + 4 -> 10
]]
function Bnum.mulAdd(a: Value, b: Value, c: Value): Value
	local s1 = a[1] * b[1]
	local l1 = a[2] + b[2]
	local s2 = c[1]
	local l2 = c[2]
	if l1 ~= l1 or l2 ~= l2 then
		return {0, 0 / 0}
	end
	if a[1] == 0 or b[1] == 0 then
		if l1 == math.huge then
			return {0, 0 / 0}
		end
		s1 = 0
		l1 = 0
	end
	if s1 == 0 then
		return {s2, l2}
	end
	if s2 == 0 then
		return {s1, l1}
	end
	if s1 == s2 then
		if l1 == l2 then
			return {s1, l1 + LOG10_2}
		end
		if l2 > l1 then l1, l2 = l2, l1 end
		if l1 == math.huge then return {s1, l1} end
		local delta = l2 - l1
		if delta < ADD_CUTOFF then return {s1, l1} end
		return {s1, l1 + math.log10(1 + math.exp(delta * LN10))}
	end
	if l1 == l2 then
		return if l1 == math.huge then {0, 0 / 0} else {0, 0}
	end
	local hiS, hiL, loL
	if l1 > l2 then hiS, hiL, loL = s1, l1, l2 else hiS, hiL, loL = s2, l2, l1 end
	local delta = loL - hiL
	if delta < ADD_CUTOFF then return {hiS, hiL} end
	if delta > -1e-300 then return {hiS, hiL + math.log10(-delta) + LOG10_LN10} end
	local difference
	if delta > CLOSE_CANCEL then
		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end
	if difference <= 0 then return {0, 0} end
	return {hiS, hiL + math.log10(difference)}
end

--[[
Computes a + b × c in one fused Bnum operation.
Example: 2 + 3 × 4 -> 14
]]
function Bnum.addMul(a: Value, b: Value, c: Value): Value
	local s1 = b[1] * c[1]
	local l1 = b[2] + c[2]
	local s2 = a[1]
	local l2 = a[2]
	if l1 ~= l1 or l2 ~= l2 then
		return {0, 0 / 0}
	end
	if b[1] == 0 or c[1] == 0 then
		if l1 == math.huge then
			return {0, 0 / 0}
		end
		s1 = 0
		l1 = 0
	end
	if s1 == 0 then
		return {s2, l2}
	end
	if s2 == 0 then
		return {s1, l1}
	end
	if s1 == s2 then
		if l1 == l2 then
			return {s1, l1 + LOG10_2}
		end
		if l2 > l1 then l1, l2 = l2, l1 end
		if l1 == math.huge then return {s1, l1} end
		local delta = l2 - l1
		if delta < ADD_CUTOFF then return {s1, l1} end
		return {s1, l1 + math.log10(1 + math.exp(delta * LN10))}
	end
	if l1 == l2 then
		return if l1 == math.huge then {0, 0 / 0} else {0, 0}
	end
	local hiS, hiL, loL
	if l1 > l2 then hiS, hiL, loL = s1, l1, l2 else hiS, hiL, loL = s2, l2, l1 end
	local delta = loL - hiL
	if delta < ADD_CUTOFF then return {hiS, hiL} end
	if delta > -1e-300 then return {hiS, hiL + math.log10(-delta) + LOG10_LN10} end
	local difference
	if delta > CLOSE_CANCEL then
		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end
	if difference <= 0 then return {0, 0} end
	return {hiS, hiL + math.log10(difference)}
end

--[[
Returns 1 / value by negating the stored log magnitude.
Example: 4 -> 0.25
]]
function Bnum.reciprocal(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if sign ~= 0 and logMagnitude < math.huge then return {sign, -logMagnitude} end
	if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
	if sign == 0 then return {1, math.huge} end
	return {0, 0}
end

--[[
Raises a Bnum to a normal numeric power.
Example: 10^3 -> 1000
]]
function Bnum.pow(val: Value, power: number): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if sign > 0 and logMagnitude == logMagnitude and power == power then
		if power == 0 then return {1, 0} end
		local resultLog = logMagnitude * power
		if resultLog == resultLog then
			if resultLog == -math.huge then return {0, 0} end
			return {1, resultLog}
		end
		if logMagnitude == 0 and (power == math.huge or power == -math.huge) then return {1, 0} end
		return {0, 0 / 0}
	end

	if power ~= power or logMagnitude ~= logMagnitude then return {0, 0 / 0} end
	if power == 0 then return {1, 0} end
	if sign == 0 then return if power > 0 then {0, 0} else {1, math.huge} end
	if power == math.huge or power == -math.huge then
		if sign < 0 then return {0, 0 / 0} end
		if logMagnitude == 0 then return {1, 0} end
		local grows = (power > 0 and logMagnitude > 0) or (power < 0 and logMagnitude < 0)
		return if grows then {1, math.huge} else {0, 0}
	end
	if sign < 0 and power % 1 ~= 0 then return {0, 0 / 0} end

	local resultLog = logMagnitude * power
	if resultLog ~= resultLog then return {0, 0 / 0} end
	if resultLog == -math.huge then return {0, 0} end
	return {if power % 2 == 0 then 1 else -1, resultLog}
end

--[[
Returns the real square root of a non-negative Bnum.
Example: 144 -> 12
]]
function Bnum.sqrt(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude or sign < 0 then
		return {0, 0 / 0}
	end
	if sign == 0 then
		return {0, 0}
	end
	return {1, logMagnitude * 0.5}
end

--[[
Returns the real cube root of a Bnum, including negative values.
Example: -125 -> -5
]]
function Bnum.cbrt(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end
	if sign == 0 then
		return {0, 0}
	end
	return {sign, logMagnitude / 3}
end

--[[
Returns the real nth root of a Bnum when the requested root is defined.
Example: 32 root 5 -> 2
]]
function Bnum.root(val: Value, degree: number): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if degree ~= degree or degree == 0 or logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end
	if sign == 0 then
		return if degree > 0 then {0, 0} else {1, math.huge}
	end
	if degree == math.huge or degree == -math.huge then
		if sign < 0 or logMagnitude == math.huge then
			return {0, 0 / 0}
		end
		return {1, 0}
	end
	if sign < 0 and (degree % 1 ~= 0 or math.abs(degree) % 2 == 0) then
		return {0, 0 / 0}
	end
	local resultLog = logMagnitude / degree
	if resultLog ~= resultLog then
		return {0, 0 / 0}
	end
	if resultLog == -math.huge then
		return {0, 0}
	end
	return {math.sign(sign), resultLog}
end

--[[
Returns the absolute value of a Bnum.
Example: -25 -> 25
]]
function Bnum.abs(val: Value): Value
	local sign = val[1]
	return {if sign < 0 then 1 else sign, val[2]}
end

--[[
Negates the sign of a Bnum.
Example: 25 -> -25
]]
function Bnum.neg(val: Value): Value
	return {-val[1], val[2]}
end

--==============================================================
-- Logarithms / exponential
--==============================================================

--[[
Returns the base-10 logarithm of a positive Bnum as another Bnum.
Example: 1000 -> 3
]]
function Bnum.log10(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return {0, logMagnitude}
	end

	if sign == 0 then
		return {-1, math.huge}
	end

	if sign < 0 then
		return {0, 0 / 0}
	end

	if logMagnitude == math.huge then
		return {1, math.huge}
	end

	if logMagnitude == 0 then
		return {0, 0}
	end

	if logMagnitude < 0 then
		return {-1, math.log10(-logMagnitude)}
	end

	return {1, math.log10(logMagnitude)}
end

--[[
Returns the natural logarithm of a positive Bnum.
Example: e -> 1
]]
function Bnum.ln(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return {0, logMagnitude}
	end

	if sign == 0 then
		return {-1, math.huge}
	end

	if sign < 0 then
		return {0, 0 / 0}
	end

	if logMagnitude == math.huge then
		return {1, math.huge}
	end

	if logMagnitude == 0 then
		return {0, 0}
	end

	if logMagnitude < 0 then
		return {-1, math.log10(-logMagnitude) + LOG10_LN10}
	end

	return {1, math.log10(logMagnitude) + LOG10_LN10}
end

--[[
Returns the base-2 logarithm of a positive Bnum.
Example: 8 -> 3
]]
function Bnum.log2(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return {0, logMagnitude}
	end

	if sign == 0 then
		return {-1, math.huge}
	end

	if sign < 0 then
		return {0, 0 / 0}
	end

	if logMagnitude == math.huge then
		return {1, math.huge}
	end

	if logMagnitude == 0 then
		return {0, 0}
	end

	if logMagnitude < 0 then
		return {-1, math.log10(-logMagnitude) + LOG10_INV_LOG10_2}
	end

	return {1, math.log10(logMagnitude) + LOG10_INV_LOG10_2}
end

--[[
Returns the logarithm of a value in an arbitrary positive base other than 1.
Example: log base 10 of 1000 -> 3
]]
function Bnum.log(val: Value, base: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	local baseSign = base[1]
	local baseLogMagnitude = base[2]
	if logMagnitude ~= logMagnitude or baseLogMagnitude ~= baseLogMagnitude then
		return {0, 0 / 0}
	end
	if sign < 0 or baseSign <= 0 or baseLogMagnitude == 0 or baseLogMagnitude == math.huge then
		return {0, 0 / 0}
	end
	if sign == 0 then
		return {-math.sign(baseLogMagnitude), math.huge}
	end
	if logMagnitude == math.huge then
		return {math.sign(baseLogMagnitude), math.huge}
	end
	local result = logMagnitude / baseLogMagnitude
	if result == 0 then
		if logMagnitude == 0 then return {0, 0} end
		local resultSign = math.sign(logMagnitude) * math.sign(baseLogMagnitude)
		return {resultSign, math.log10(math.abs(logMagnitude)) - math.log10(math.abs(baseLogMagnitude))}
	end
	if result == math.huge or result == -math.huge then
		local resultSign = math.sign(logMagnitude) * math.sign(baseLogMagnitude)
		return {resultSign, math.log10(math.abs(logMagnitude)) - math.log10(math.abs(baseLogMagnitude))}
	end
	return {math.sign(result), math.log10(math.abs(result))}
end

--[[
Returns e^value while preserving Bnum overflow and underflow behavior.
Example: 1 -> e
]]
function Bnum.exp(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude < math.huge then
		if sign > 0 then return {1, LOG10_E * (10 ^ logMagnitude)} end
		if sign < 0 then
			local resultLog = -LOG10_E * (10 ^ logMagnitude)
			if resultLog == -math.huge then return {0, 0} end
			return {1, resultLog}
		end
		return {1, 0}
	end
	if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
	return if sign < 0 then {0, 0} else {1, math.huge}
end

--[[
Returns 10^value where value itself is a Bnum.
Example: 3 -> 1000
]]
function Bnum.exp10(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
	if sign == 0 then return {1, 0} end
	if logMagnitude == math.huge or logMagnitude > MAX_LOG10_DOUBLE then
		return if sign < 0 then {0, 0} else {1, math.huge}
	end
	local exponent = 10 ^ logMagnitude
	if sign < 0 then exponent = -exponent end
	if exponent == -math.huge then return {0, 0} end
	if exponent == math.huge then return {1, math.huge} end
	return {1, exponent}
end

--[[
Returns 2^value where value itself is a Bnum.
Example: 10 -> 1024
]]
function Bnum.exp2(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
	if sign == 0 then return {1, 0} end
	if logMagnitude == math.huge or logMagnitude > MAX_LOG10_DOUBLE then
		return if sign < 0 then {0, 0} else {1, math.huge}
	end
	local exponent = 10 ^ logMagnitude
	if sign < 0 then exponent = -exponent end
	local resultLog = exponent * LOG10_2
	if resultLog == -math.huge then return {0, 0} end
	if resultLog == math.huge then return {1, math.huge} end
	return {1, resultLog}
end

--[[
Raises a Bnum to a power that is also stored as a Bnum.
Example: 2 ^ 10 -> 1024
]]
function Bnum.powValue(val: Value, power: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	local ps = power[1]
	local pl = power[2]

	if sign > 0 and ps ~= 0 and logMagnitude == logMagnitude and pl < math.huge then
		local scalarPower = ps * (10 ^ pl)
		local resultLog = logMagnitude * scalarPower
		if resultLog == resultLog then
			if resultLog == -math.huge then return {0, 0} end
			return {1, resultLog}
		end
		if logMagnitude == 0 and (scalarPower == math.huge or scalarPower == -math.huge) then return {1, 0} end
		return {0, 0 / 0}
	end

	if pl ~= pl or logMagnitude ~= logMagnitude then return {0, 0 / 0} end
	if ps == 0 then return {1, 0} end
	if pl == math.huge or pl > MAX_LOG10_DOUBLE then
		if sign < 0 then return {0, 0 / 0} end
		if sign == 0 then return if ps > 0 then {0, 0} else {1, math.huge} end
		if logMagnitude == 0 then return {1, 0} end
		local grows = (ps > 0 and logMagnitude > 0) or (ps < 0 and logMagnitude < 0)
		return if grows then {1, math.huge} else {0, 0}
	end

	local scalarPower = ps * (10 ^ pl)
	if scalarPower ~= math.huge and scalarPower ~= -math.huge then
		local absPower = math.abs(scalarPower)
		if absPower >= 1 and absPower <= MAX_EXACT_INTEGER then
			local nearest = math.round(scalarPower)
			if math.abs(scalarPower - nearest) <= absPower * INTEGER_SNAP_REL then scalarPower = nearest end
		end
	end
	if scalarPower ~= scalarPower then return {0, 0 / 0} end
	if scalarPower == 0 then return {1, 0} end
	if sign == 0 then return if scalarPower > 0 then {0, 0} else {1, math.huge} end
	if scalarPower == math.huge or scalarPower == -math.huge then
		if sign < 0 then return {0, 0 / 0} end
		if logMagnitude == 0 then return {1, 0} end
		local grows = (scalarPower > 0 and logMagnitude > 0) or (scalarPower < 0 and logMagnitude < 0)
		return if grows then {1, math.huge} else {0, 0}
	end
	if sign < 0 and scalarPower % 1 ~= 0 then return {0, 0 / 0} end

	local resultLog = logMagnitude * scalarPower
	if resultLog ~= resultLog then return {0, 0 / 0} end
	if resultLog == -math.huge then return {0, 0} end
	if sign < 0 then return {if scalarPower % 2 == 0 then 1 else -1, resultLog} end
	return {1, resultLog}
end

--[[
Computes ln(1 + x) with extra care for tiny x values.
Example: x near 0 -> approximately x
]]
function Bnum.log1p(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end
	if sign == 0 then
		return {0, 0}
	end
	if sign < 0 then
		if logMagnitude > 0 then
			return {0, 0 / 0}
		end
		if logMagnitude == 0 then
			return {-1, math.huge}
		end
	end
	if logMagnitude < -8 then
		return {sign, logMagnitude}
	end
	if logMagnitude <= 15 then
		local x = sign * (10 ^ logMagnitude)
		local result
		if math.abs(x) < 1e-4 then
			local x2 = x * x
			result = x - x2 * 0.5 + x2 * x / 3 - x2 * x2 * 0.25
		else
			result = math.log(1 + x)
		end
		if result == 0 then
			return {0, 0}
		end
		return {math.sign(result), math.log10(math.abs(result))}
	end

	-- Direct ln(val): ln(x) = log10(x) * ln(10).
	if logMagnitude == math.huge then
		return {1, math.huge}
	end
	if logMagnitude == 0 then
		return {0, 0}
	end
	if logMagnitude < 0 then
		return {-1, math.log10(-logMagnitude) + LOG10_LN10}
	end
	return {1, math.log10(logMagnitude) + LOG10_LN10}
end

--[[
Computes e^x - 1 with extra care for tiny x values.
Example: x near 0 -> approximately x
]]
function Bnum.expm1(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end
	if sign == 0 then
		return {0, 0}
	end
	if logMagnitude < -8 then
		return {sign, logMagnitude}
	end
	if logMagnitude <= 2 then
		local x = sign * (10 ^ logMagnitude)
		if x < -40 then
			return {-1, 0}
		end
		if math.abs(x) < 1e-4 then
			local x2 = x * x
			local result = x + x2 * 0.5 + x2 * x / 6 + x2 * x2 / 24
			if result == 0 then
				return {0, 0}
			end
			return {math.sign(result), math.log10(math.abs(result))}
		end
		local result = math.exp(x) - 1
		if result == 0 then
			return {0, 0}
		end
		if result == math.huge then
			return {1, math.huge}
		end
		return {math.sign(result), math.log10(math.abs(result))}
	end
	if sign < 0 then
		return {-1, 0}
	end

	-- Direct exponential path without a public API call.
	if logMagnitude == math.huge then
		return {1, math.huge}
	end
	local resultLogPower = logMagnitude + LOG10_LOG10_E
	if resultLogPower > MAX_LOG10_DOUBLE then
		return {1, math.huge}
	end
	local resultLog = 10 ^ resultLogPower
	if resultLog == math.huge then
		return {1, math.huge}
	end
	return {1, resultLog}
end

--[[
Computes sqrt(a² + b²) in Bnum space.
Example: 3, 4 -> 5
]]
function Bnum.hypot(a: Value, b: Value): Value
	local sa = a[1]
	local la = a[2]
	local sb = b[1]
	local lb = b[2]

	if la ~= la or lb ~= lb then
		return {0, 0 / 0}
	end
	if sa == 0 then
		return {if sb < 0 then 1 else sb, lb}
	end
	if sb == 0 then
		return {if sa < 0 then 1 else sa, la}
	end
	if la == math.huge or lb == math.huge then
		return {1, math.huge}
	end

	local hi = if la > lb then la else lb
	local lo = if la > lb then lb else la
	local delta = (lo - hi) * 2
	if delta < ADD_CUTOFF then
		return {1, hi}
	end
	return {1, hi + 0.5 * math.log10(1 + 10 ^ delta)}
end

--[[
Computes n! for non-negative integer Bnum inputs.
Example: 5! -> 120
]]
function Bnum.factorial(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude or sign < 0 then return {0, 0 / 0} end
	if sign == 0 then return {1, 0} end
	if logMagnitude == math.huge then return {1, math.huge} end

	if logMagnitude <= LOG10_170 then
		local n = 10 ^ logMagnitude
		local nearest = math.round(n)
		if nearest < 1 or math.abs(n - nearest) > n * INTEGER_SNAP_REL then return {0, 0 / 0} end
		return {1, factorialLogs[nearest + 1]}
	end

	if logMagnitude > MAX_LOG10_DOUBLE then return {1, math.huge} end
	local n = 10 ^ logMagnitude
	if n ~= n then return {0, 0 / 0} end
	if n == math.huge then return {1, math.huge} end
	if n <= MAX_EXACT_INTEGER then
		local nearest = math.round(n)
		if math.abs(n - nearest) <= n * INTEGER_SNAP_REL then
			n = nearest
		elseif n % 1 ~= 0 then
			return {0, 0 / 0}
		end
	elseif n % 1 ~= 0 then
		return {0, 0 / 0}
	end

	local inv = 1 / n
	local inv3 = inv * inv * inv
	local logFact = (n + 0.5) * math.log10(n) - n / LN10 + 0.3990899341790575 + inv / (12 * LN10) - inv3 / (360 * LN10)
	return {1, logFact}
end

--==============================================================
-- Comparison
--==============================================================

--[[
Compares two Bnums and returns -1, 0, or 1.
Example: 2 compared with 5 -> -1
]]
function Bnum.compare(val1: Value, val2: Value): number?
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 then
		return nil
	end

	if s1 < s2 then
		return -1
	end

	if s1 > s2 then
		return 1
	end

	if s1 == 0 then
		return 0
	end

	if s1 > 0 then
		if l1 < l2 then
			return -1
		elseif l1 > l2 then
			return 1
		end
	else
		if l1 > l2 then
			return -1
		elseif l1 < l2 then
			return 1
		end
	end

	return 0
end

--[[
Returns true when two Bnums represent exactly the same canonical value.
Example: 5 == 5 -> true
]]
function Bnum.eq(val1: Value, val2: Value): boolean
	return val1[1] == val2[1] and val1[2] == val2[2]
end

--[[
Returns true when two Bnums represent different canonical values.
Example: 5 ~= 6 -> true
]]
function Bnum.neq(val1: Value, val2: Value): boolean
	return val1[1] ~= val2[1] or val1[2] ~= val2[2]
end

--[[
Returns true when the first Bnum is less than the second.
Example: 2 < 5 -> true
]]
function Bnum.lt(val1: Value, val2: Value): boolean
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 then
		return false
	end

	if s1 == s2 then
		if s1 > 0 then
			return l1 < l2
		end

		if s1 < 0 then
			return l1 > l2
		end

		return false
	end

	return s1 < s2
end

--[[
Returns true when the first Bnum is less than or equal to the second.
Example: 5 <= 5 -> true
]]
function Bnum.lte(val1: Value, val2: Value): boolean
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 then
		return false
	end

	if s1 ~= s2 then
		return s1 < s2
	end

	if s1 == 0 then
		return true
	end

	if s1 > 0 then
		return l1 <= l2
	end

	return l1 >= l2
end

--[[
Returns true when the first Bnum is greater than the second.
Example: 10 > 5 -> true
]]
function Bnum.gt(val1: Value, val2: Value): boolean
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 then
		return false
	end

	if s1 ~= s2 then
		return s1 > s2
	end

	if s1 == 0 then
		return false
	end

	if s1 > 0 then
		return l1 > l2
	end

	return l1 < l2
end

--[[
Returns true when the first Bnum is greater than or equal to the second.
Example: 5 >= 5 -> true
]]
function Bnum.gte(val1: Value, val2: Value): boolean
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 then
		return false
	end

	if s1 ~= s2 then
		return s1 > s2
	end

	if s1 == 0 then
		return true
	end

	if s1 > 0 then
		return l1 >= l2
	end

	return l1 <= l2
end


--==============================================================
-- Min / max / clamp
--==============================================================

--[[
Returns the smallest Bnum from the supplied values.
Example: min(3, 1, 2) -> 1
]]
function Bnum.min(val1: Value, val2: Value?, ...: Value): Value
	local bestSign = val1[1]
	local bestLog = val1[2]
	if bestLog ~= bestLog then return {0, 0 / 0} end
	if val2 == nil then return {bestSign, bestLog} end
	local count = select("#", ...) + 1
	for i = 1, count do
		local current: Value = if i == 1 then (val2 :: Value) else select(i - 1, ...)
		local sign = current[1]
		local logMagnitude = current[2]
		if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
		if sign < bestSign or (sign == bestSign and sign ~= 0 and ((sign > 0 and logMagnitude < bestLog) or (sign < 0 and logMagnitude > bestLog))) then
			bestSign = sign
			bestLog = logMagnitude
		end
	end
	return {bestSign, bestLog}
end

--[[
Returns the largest Bnum from the supplied values.
Example: max(3, 1, 2) -> 3
]]
function Bnum.max(val1: Value, val2: Value?, ...: Value): Value
	local bestSign = val1[1]
	local bestLog = val1[2]
	if bestLog ~= bestLog then return {0, 0 / 0} end
	if val2 == nil then return {bestSign, bestLog} end
	local count = select("#", ...) + 1
	for i = 1, count do
		local current: Value = if i == 1 then (val2 :: Value) else select(i - 1, ...)
		local sign = current[1]
		local logMagnitude = current[2]
		if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
		if sign > bestSign or (sign == bestSign and sign ~= 0 and ((sign > 0 and logMagnitude > bestLog) or (sign < 0 and logMagnitude < bestLog))) then
			bestSign = sign
			bestLog = logMagnitude
		end
	end
	return {bestSign, bestLog}
end

--[[
Clamps a Bnum between a minimum and maximum value.
Example: clamp(15, 0, 10) -> 10
]]
function Bnum.clamp(val: Value, minimum: Value, maximum: Value): Value
	local s = val[1]
	local l = val[2]
	local minS = minimum[1]
	local minL = minimum[2]
	local maxS = maximum[1]
	local maxL = maximum[2]
	if l ~= l or minL ~= minL or maxL ~= maxL then
		return {0, 0 / 0}
	end

	local inverted
	if minS ~= maxS then
		inverted = minS > maxS
	elseif minS == 0 then
		inverted = false
	elseif minS > 0 then
		inverted = minL > maxL
	else
		inverted = minL < maxL
	end
	if inverted then
		return {0, 0 / 0}
	end

	if s < minS or (s == minS and s ~= 0 and ((s > 0 and l < minL) or (s < 0 and l > minL))) then
		return {minS, minL}
	end
	if s > maxS or (s == maxS and s ~= 0 and ((s > 0 and l > maxL) or (s < 0 and l < maxL))) then
		return {maxS, maxL}
	end
	return {s, l}
end

--[[
Rounds a Bnum down toward negative infinity.
Example: 12.9 -> 12
]]
function Bnum.floor(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if sign == 0 then return {0, logMagnitude} end
	if logMagnitude == math.huge or logMagnitude >= MAX_EXACT_INTEGER_LOG10 then return {sign, logMagnitude} end
	if logMagnitude < 0 then return if sign > 0 then {0, 0} else {-1, 0} end

	local magnitude = 10 ^ logMagnitude
	local nearest = math.round(magnitude)
	if math.abs(magnitude - nearest) <= magnitude * INTEGER_SNAP_REL then
		magnitude = nearest
	elseif sign > 0 then
		magnitude = math.floor(magnitude)
	else
		magnitude = math.ceil(magnitude)
	end
	return {sign, math.log10(magnitude)}
end

--[[
Rounds a Bnum up toward positive infinity.
Example: 12.1 -> 13
]]
function Bnum.ceil(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if sign == 0 then return {0, logMagnitude} end
	if logMagnitude == math.huge or logMagnitude >= MAX_EXACT_INTEGER_LOG10 then return {sign, logMagnitude} end
	if logMagnitude < 0 then return if sign > 0 then {1, 0} else {0, 0} end

	local magnitude = 10 ^ logMagnitude
	local nearest = math.round(magnitude)
	if math.abs(magnitude - nearest) <= magnitude * INTEGER_SNAP_REL then
		magnitude = nearest
	elseif sign > 0 then
		magnitude = math.ceil(magnitude)
	else
		magnitude = math.floor(magnitude)
	end
	return {sign, math.log10(magnitude)}
end

--[[
Rounds a Bnum to the requested decimal digit count.
Example: 12.345 with 2 digits -> 12.35
]]
function Bnum.round(val: Value, digits: number?): Value
	local sign = val[1]
	local logMagnitude = val[2]
	local places = digits or 0
	if logMagnitude ~= logMagnitude or places ~= places then return {0, 0 / 0} end
	if sign == 0 then return {0, 0} end
	if logMagnitude == math.huge then return {sign, math.huge} end
	if places == 0 and logMagnitude < 0 then
		if logMagnitude < -LOG10_2 then return {0, 0} end
		return {sign, 0}
	end

	places = math.floor(places)
	if logMagnitude + places >= MAX_EXACT_INTEGER_LOG10 then return {sign, logMagnitude} end
	if logMagnitude < -places - LOG10_2 then return {0, 0} end
	local rounded = math.round(sign * (10 ^ (logMagnitude + places)))
	if rounded == 0 then return {0, 0} end
	if rounded < 0 then return {-1, math.log10(-rounded) - places} end
	return {1, math.log10(rounded) - places}
end

--==============================================================
-- Modulo
--==============================================================

--[[
Returns the remainder of integer-style division between two Bnums.
Example: 17 mod 5 -> 2
]]
function Bnum.mod(val1: Value, val2: Value): Value
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = val2[1]
	local l2 = val2[2]
	if l1 ~= l1 or l2 ~= l2 or s2 == 0 then return {0, 0 / 0} end
	if s1 == 0 then return {0, 0} end
	if l1 > MAX_EXACT_INTEGER_LOG10 or l2 > MAX_EXACT_INTEGER_LOG10 or l1 < -308 or l2 < -308 then return {0, 0 / 0} end

	local n1 = s1 * (10 ^ l1)
	local n2 = s2 * (10 ^ l2)
	local near1 = math.round(n1)
	local near2 = math.round(n2)
	local abs1 = math.abs(n1)
	local abs2 = math.abs(n2)
	if abs1 >= 1 and math.abs(n1 - near1) <= abs1 * INTEGER_SNAP_REL then n1 = near1 end
	if abs2 >= 1 and math.abs(n2 - near2) <= abs2 * INTEGER_SNAP_REL then n2 = near2 end
	if n2 == 0 then return {0, 0 / 0} end
	local result = n1 % n2
	if result == 0 then return {0, 0} end
	if result < 0 then return {-1, math.log10(-result)} end
	return {1, math.log10(result)}
end


--[[
Removes the fractional part of a Bnum by rounding toward zero.
Example: -12.9 -> -12
]]
function Bnum.trunc(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then return {0, logMagnitude} end
	if sign == 0 then return {0, 0} end
	if logMagnitude == math.huge or logMagnitude >= MAX_EXACT_INTEGER_LOG10 then return {sign, logMagnitude} end
	if logMagnitude < 0 then return {0, 0} end

	local magnitude = 10 ^ logMagnitude
	local nearest = math.round(magnitude)
	if math.abs(magnitude - nearest) <= magnitude * INTEGER_SNAP_REL then
		magnitude = nearest
	else
		magnitude = math.floor(magnitude)
	end
	if magnitude == 0 then return {0, 0} end
	return {sign, math.log10(magnitude)}
end

--[[
Returns only the signed fractional part using direct inline math.
Example: 12.75 -> 0.75
]]
function Bnum.fract(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then return {0, 0 / 0} end
	if sign == 0 or logMagnitude == math.huge or logMagnitude >= MAX_EXACT_INTEGER_LOG10 then return {0, 0} end
	if logMagnitude < 0 then return {sign, logMagnitude} end

	local magnitude = 10 ^ logMagnitude
	local nearest = math.round(magnitude)
	if math.abs(magnitude - nearest) <= magnitude * INTEGER_SNAP_REL then return {0, 0} end
	local fraction = magnitude - math.floor(magnitude)
	if fraction == 0 then return {0, 0} end
	return {sign, math.log10(fraction)}
end

--[[
Checks whether a finite Bnum represents an exact integer in the supported precision range.
Example: 12 -> true
]]
function Bnum.isInteger(val: Value): boolean
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude or logMagnitude == math.huge then return false end
	if sign == 0 then return true end
	if logMagnitude < 0 then return false end
	if logMagnitude <= MAX_LOG10_DOUBLE then
		local n = 10 ^ logMagnitude
		if n == math.huge then return false end
		if n <= MAX_EXACT_INTEGER then
			local nearest = math.round(n)
			if math.abs(n - nearest) <= n * INTEGER_SNAP_REL then n = nearest end
		end
		return n % 1 == 0
	end
	return logMagnitude % 1 == 0
end

--[[
Checks whether a Bnum lies inclusively between two bounds.
Example: 5 between 1 and 10 -> true
]]
function Bnum.between(val: Value, minimum: Value, maximum: Value): boolean
	local s = val[1]
	local l = val[2]
	local minS = minimum[1]
	local minL = minimum[2]
	local maxS = maximum[1]
	local maxL = maximum[2]
	if l ~= l or minL ~= minL or maxL ~= maxL then
		return false
	end

	local aboveMin
	if s ~= minS then
		aboveMin = s > minS
	elseif s == 0 then
		aboveMin = true
	elseif s > 0 then
		aboveMin = l >= minL
	else
		aboveMin = l <= minL
	end
	if not aboveMin then
		return false
	end

	if s ~= maxS then
		return s < maxS
	end
	if s == 0 then
		return true
	end
	if s > 0 then
		return l <= maxL
	end
	return l >= maxL
end

--[[
Returns the absolute distance between two Bnums.
Example: distance(10, 4) -> 6
]]
function Bnum.distance(a: Value, b: Value): Value
	local s1 = a[1]
	local l1 = a[2]
	local s2 = -b[1]
	local l2 = b[2]
	if s1 == b[1] and l1 == l2 then
		return {0, 0}
	end
	local resultSign
	local resultLog
	if l1 ~= l1 or l2 ~= l2 then
		resultSign = 0
		resultLog = 0 / 0
	elseif s1 == 0 then
		resultSign = s2
		resultLog = l2
	elseif s2 == 0 then
		resultSign = s1
		resultLog = l1
	elseif s1 == s2 then
		resultSign = s1
		if l1 == l2 then
			resultLog = l1 + LOG10_2
		elseif l1 >= l2 then
			if l1 == math.huge then
				resultLog = l1
			else
				local delta = l2 - l1
				if delta < ADD_CUTOFF then
					resultLog = l1
				else
					resultLog = l1 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if l2 == math.huge then
				resultLog = l2
			else
				local delta = l1 - l2
				if delta < ADD_CUTOFF then
					resultLog = l2
				else
					resultLog = l2 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if l1 == l2 then
			if l1 == math.huge then
				resultSign = 0
				resultLog = 0 / 0
			else
				resultSign = 0
				resultLog = 0
			end
		elseif l1 > l2 then
			resultSign = s1
			local delta = l2 - l1
			if delta < ADD_CUTOFF then
				resultLog = l1
			elseif delta > -1e-300 then
				resultLog = l1 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultSign = 0
					resultLog = 0
				else
					resultLog = l1 + math.log10(difference)
				end
			end
		else
			resultSign = s2
			local delta = l1 - l2
			if delta < ADD_CUTOFF then
				resultLog = l2
			elseif delta > -1e-300 then
				resultLog = l2 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultSign = 0
					resultLog = 0
				else
					resultLog = l2 + math.log10(difference)
				end
			end
		end
	end
	if resultLog ~= resultLog then
		return {0, 0 / 0}
	end
	if resultSign == 0 then
		return {0, resultLog}
	end
	return {1, resultLog}
end

--[[
Returns the absolute difference relative to the larger absolute input.
Example: 100 vs 90 -> 0.1
]]
function Bnum.relativeDifference(a: Value, b: Value): Value
	local as = a[1]
	local al = a[2]
	local bs = b[1]
	local bl = b[2]
	if as == bs and al == bl then
		return {0, 0}
	end
	if al ~= al or bl ~= bl then
		return {0, 0 / 0}
	end

	local s1 = as
	local l1 = al
	local s2 = -bs
	local l2 = bl
	local differenceSign
	local differenceLog
	if l1 ~= l1 or l2 ~= l2 then
		differenceSign = 0
		differenceLog = 0 / 0
	elseif s1 == 0 then
		differenceSign = s2
		differenceLog = l2
	elseif s2 == 0 then
		differenceSign = s1
		differenceLog = l1
	elseif s1 == s2 then
		differenceSign = s1
		if l1 == l2 then
			differenceLog = l1 + LOG10_2
		elseif l1 >= l2 then
			if l1 == math.huge then
				differenceLog = l1
			else
				local delta = l2 - l1
				if delta < ADD_CUTOFF then
					differenceLog = l1
				else
					differenceLog = l1 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if l2 == math.huge then
				differenceLog = l2
			else
				local delta = l1 - l2
				if delta < ADD_CUTOFF then
					differenceLog = l2
				else
					differenceLog = l2 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if l1 == l2 then
			if l1 == math.huge then
				differenceSign = 0
				differenceLog = 0 / 0
			else
				differenceSign = 0
				differenceLog = 0
			end
		elseif l1 > l2 then
			differenceSign = s1
			local delta = l2 - l1
			if delta < ADD_CUTOFF then
				differenceLog = l1
			elseif delta > -1e-300 then
				differenceLog = l1 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					differenceSign = 0
					differenceLog = 0
				else
					differenceLog = l1 + math.log10(difference)
				end
			end
		else
			differenceSign = s2
			local delta = l1 - l2
			if delta < ADD_CUTOFF then
				differenceLog = l2
			elseif delta > -1e-300 then
				differenceLog = l2 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					differenceSign = 0
					differenceLog = 0
				else
					differenceLog = l2 + math.log10(difference)
				end
			end
		end
	end
	if differenceLog ~= differenceLog then
		return {0, 0 / 0}
	end
	if differenceSign == 0 then
		return {0, 0}
	end

	local scaleLog
	if as == 0 then
		scaleLog = bl
	elseif bs == 0 then
		scaleLog = al
	elseif al >= bl then
		scaleLog = al
	else
		scaleLog = bl
	end
	if scaleLog == nil then
		return {0, 0}
	end

	local resultLog = differenceLog - scaleLog
	if resultLog ~= resultLog then
		return {0, 0 / 0}
	end
	if resultLog == -math.huge then
		return {0, 0}
	end
	return {1, resultLog}
end

--[[
Checks approximate equality using relative and absolute tolerances.
Example: 1 and 1.000000001 -> tolerance-dependent
]]
function Bnum.approxEq(a: Value, b: Value, relTolerance: number?, absTolerance: number?): boolean
	local as = a[1]
	local al = a[2]
	local bs = b[1]
	local bl = b[2]
	if as == bs and al == bl then
		return true
	end
	if al ~= al or bl ~= bl then
		return false
	end
	if al == math.huge or bl == math.huge then
		return false
	end

	local absTol = absTolerance or 0
	local relTol = relTolerance or 1e-12
	if absTol ~= absTol or relTol ~= relTol or absTol < 0 or relTol < 0 then
		return false
	end

	local s1 = as
	local l1 = al
	local s2 = -bs
	local l2 = bl
	local differenceSign
	local differenceLog
	if l1 ~= l1 or l2 ~= l2 then
		differenceSign = 0
		differenceLog = 0 / 0
	elseif s1 == 0 then
		differenceSign = s2
		differenceLog = l2
	elseif s2 == 0 then
		differenceSign = s1
		differenceLog = l1
	elseif s1 == s2 then
		differenceSign = s1
		if l1 == l2 then
			differenceLog = l1 + LOG10_2
		elseif l1 >= l2 then
			if l1 == math.huge then
				differenceLog = l1
			else
				local delta = l2 - l1
				if delta < ADD_CUTOFF then
					differenceLog = l1
				else
					differenceLog = l1 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if l2 == math.huge then
				differenceLog = l2
			else
				local delta = l1 - l2
				if delta < ADD_CUTOFF then
					differenceLog = l2
				else
					differenceLog = l2 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if l1 == l2 then
			if l1 == math.huge then
				differenceSign = 0
				differenceLog = 0 / 0
			else
				differenceSign = 0
				differenceLog = 0
			end
		elseif l1 > l2 then
			differenceSign = s1
			local delta = l2 - l1
			if delta < ADD_CUTOFF then
				differenceLog = l1
			elseif delta > -1e-300 then
				differenceLog = l1 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					differenceSign = 0
					differenceLog = 0
				else
					differenceLog = l1 + math.log10(difference)
				end
			end
		else
			differenceSign = s2
			local delta = l1 - l2
			if delta < ADD_CUTOFF then
				differenceLog = l2
			elseif delta > -1e-300 then
				differenceLog = l2 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					differenceSign = 0
					differenceLog = 0
				else
					differenceLog = l2 + math.log10(difference)
				end
			end
		end
	end
	if differenceLog ~= differenceLog then
		return false
	end
	if differenceSign == 0 then
		return true
	end

	if absTol > 0 then
		local absTolLog = math.log10(absTol)
		if differenceLog <= absTolLog then
			return true
		end
	end

	local scaleLog
	if as == 0 then
		scaleLog = bl
	elseif bs == 0 then
		scaleLog = al
	elseif al >= bl then
		scaleLog = al
	else
		scaleLog = bl
	end
	if scaleLog == nil then
		return true
	end
	if relTol == 0 then
		return false
	end
	if relTol == math.huge then
		return true
	end
	local thresholdLog = scaleLog + math.log10(relTol)
	return differenceLog <= thresholdLog
end

--[[
Linearly interpolates between two Bnums using a normal numeric alpha.
Example: lerp(0, 10, 0.5) -> 5
]]
function Bnum.lerp(a: Value, b: Value, alpha: number): Value
	if alpha ~= alpha then
		return {0, 0 / 0}
	end
	local as = a[1]
	local al = a[2]
	local bs = b[1]
	local bl = b[2]
	if alpha == 0 then
		return {as, al}
	end
	if alpha == 1 then
		return {bs, bl}
	end
	if as == bs and al == bl then
		return {as, al}
	end

	local negAs = -as
	local deltaSign
	local deltaLog
	if bl ~= bl or al ~= al then
		deltaSign = 0
		deltaLog = 0 / 0
	elseif bs == 0 then
		deltaSign = negAs
		deltaLog = al
	elseif negAs == 0 then
		deltaSign = bs
		deltaLog = bl
	elseif bs == negAs then
		deltaSign = bs
		if bl == al then
			deltaLog = bl + LOG10_2
		elseif bl >= al then
			if bl == math.huge then
				deltaLog = bl
			else
				local delta = al - bl
				if delta < ADD_CUTOFF then
					deltaLog = bl
				else
					deltaLog = bl + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if al == math.huge then
				deltaLog = al
			else
				local delta = bl - al
				if delta < ADD_CUTOFF then
					deltaLog = al
				else
					deltaLog = al + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if bl == al then
			if bl == math.huge then
				deltaSign = 0
				deltaLog = 0 / 0
			else
				deltaSign = 0
				deltaLog = 0
			end
		elseif bl > al then
			deltaSign = bs
			local delta = al - bl
			if delta < ADD_CUTOFF then
				deltaLog = bl
			elseif delta > -1e-300 then
				deltaLog = bl + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					deltaSign = 0
					deltaLog = 0
				else
					deltaLog = bl + math.log10(difference)
				end
			end
		else
			deltaSign = negAs
			local delta = bl - al
			if delta < ADD_CUTOFF then
				deltaLog = al
			elseif delta > -1e-300 then
				deltaLog = al + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					deltaSign = 0
					deltaLog = 0
				else
					deltaLog = al + math.log10(difference)
				end
			end
		end
	end
	if deltaLog ~= deltaLog then
		return {0, 0 / 0}
	end

	local scaledSign
	local scaledLog
	if alpha == 0 or deltaSign == 0 then
		if deltaLog == math.huge and alpha == 0 then
			return {0, 0 / 0}
		end
		scaledSign = 0
		scaledLog = 0
	else
		scaledSign = if alpha < 0 then -deltaSign else deltaSign
		scaledLog = deltaLog + math.log10(if alpha < 0 then -alpha else alpha)
		if scaledLog ~= scaledLog then
			return {0, 0 / 0}
		end
		if scaledLog == -math.huge then
			scaledSign = 0
			scaledLog = 0
		end
	end
	local resultSign
	local resultLog
	if al ~= al or scaledLog ~= scaledLog then
		resultSign = 0
		resultLog = 0 / 0
	elseif as == 0 then
		resultSign = scaledSign
		resultLog = scaledLog
	elseif scaledSign == 0 then
		resultSign = as
		resultLog = al
	elseif as == scaledSign then
		resultSign = as
		if al == scaledLog then
			resultLog = al + LOG10_2
		elseif al >= scaledLog then
			if al == math.huge then
				resultLog = al
			else
				local delta = scaledLog - al
				if delta < ADD_CUTOFF then
					resultLog = al
				else
					resultLog = al + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if scaledLog == math.huge then
				resultLog = scaledLog
			else
				local delta = al - scaledLog
				if delta < ADD_CUTOFF then
					resultLog = scaledLog
				else
					resultLog = scaledLog + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if al == scaledLog then
			if al == math.huge then
				resultSign = 0
				resultLog = 0 / 0
			else
				resultSign = 0
				resultLog = 0
			end
		elseif al > scaledLog then
			resultSign = as
			local delta = scaledLog - al
			if delta < ADD_CUTOFF then
				resultLog = al
			elseif delta > -1e-300 then
				resultLog = al + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultSign = 0
					resultLog = 0
				else
					resultLog = al + math.log10(difference)
				end
			end
		else
			resultSign = scaledSign
			local delta = al - scaledLog
			if delta < ADD_CUTOFF then
				resultLog = scaledLog
			elseif delta > -1e-300 then
				resultLog = scaledLog + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultSign = 0
					resultLog = 0
				else
					resultLog = scaledLog + math.log10(difference)
				end
			end
		end
	end
	return {resultSign, resultLog}
end

--[[
Returns the interpolation alpha of a value between two Bnum endpoints.
Example: inverseLerp(0, 10, 5) -> 0.5
]]
function Bnum.inverseLerp(a: Value, b: Value, val: Value): Value
	local as = a[1]
	local al = a[2]
	local bs = b[1]
	local bl = b[2]
	local vs = val[1]
	local vl = val[2]

	local negAs = -as
	local numSign
	local numLog
	if vl ~= vl or al ~= al then
		numSign = 0
		numLog = 0 / 0
	elseif vs == 0 then
		numSign = negAs
		numLog = al
	elseif negAs == 0 then
		numSign = vs
		numLog = vl
	elseif vs == negAs then
		numSign = vs
		if vl == al then
			numLog = vl + LOG10_2
		elseif vl >= al then
			if vl == math.huge then
				numLog = vl
			else
				local delta = al - vl
				if delta < ADD_CUTOFF then
					numLog = vl
				else
					numLog = vl + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if al == math.huge then
				numLog = al
			else
				local delta = vl - al
				if delta < ADD_CUTOFF then
					numLog = al
				else
					numLog = al + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if vl == al then
			if vl == math.huge then
				numSign = 0
				numLog = 0 / 0
			else
				numSign = 0
				numLog = 0
			end
		elseif vl > al then
			numSign = vs
			local delta = al - vl
			if delta < ADD_CUTOFF then
				numLog = vl
			elseif delta > -1e-300 then
				numLog = vl + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					numSign = 0
					numLog = 0
				else
					numLog = vl + math.log10(difference)
				end
			end
		else
			numSign = negAs
			local delta = vl - al
			if delta < ADD_CUTOFF then
				numLog = al
			elseif delta > -1e-300 then
				numLog = al + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					numSign = 0
					numLog = 0
				else
					numLog = al + math.log10(difference)
				end
			end
		end
	end
	local negAs2 = -as
	local denSign
	local denLog
	if bl ~= bl or al ~= al then
		denSign = 0
		denLog = 0 / 0
	elseif bs == 0 then
		denSign = negAs2
		denLog = al
	elseif negAs2 == 0 then
		denSign = bs
		denLog = bl
	elseif bs == negAs2 then
		denSign = bs
		if bl == al then
			denLog = bl + LOG10_2
		elseif bl >= al then
			if bl == math.huge then
				denLog = bl
			else
				local delta = al - bl
				if delta < ADD_CUTOFF then
					denLog = bl
				else
					denLog = bl + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if al == math.huge then
				denLog = al
			else
				local delta = bl - al
				if delta < ADD_CUTOFF then
					denLog = al
				else
					denLog = al + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if bl == al then
			if bl == math.huge then
				denSign = 0
				denLog = 0 / 0
			else
				denSign = 0
				denLog = 0
			end
		elseif bl > al then
			denSign = bs
			local delta = al - bl
			if delta < ADD_CUTOFF then
				denLog = bl
			elseif delta > -1e-300 then
				denLog = bl + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					denSign = 0
					denLog = 0
				else
					denLog = bl + math.log10(difference)
				end
			end
		else
			denSign = negAs2
			local delta = bl - al
			if delta < ADD_CUTOFF then
				denLog = al
			elseif delta > -1e-300 then
				denLog = al + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					denSign = 0
					denLog = 0
				else
					denLog = al + math.log10(difference)
				end
			end
		end
	end

	local resultLog = numLog - denLog
	if resultLog ~= resultLog then
		return {0, 0 / 0}
	end
	if denSign == 0 then
		if numSign == 0 then
			return {0, 0 / 0}
		end
		return {numSign, math.huge}
	end
	if numSign == 0 or resultLog == -math.huge then
		return {0, 0}
	end
	return {numSign * denSign, resultLog}
end

--[[
Maps a Bnum from one numeric range into another range.
Example: 5 from [0,10] to [0,100] -> 50
]]
function Bnum.remap(val: Value, inMin: Value, inMax: Value, outMin: Value, outMax: Value): Value
	local vs = val[1]
	local vl = val[2]
	local inMinS = inMin[1]
	local inMinL = inMin[2]
	local inMaxS = inMax[1]
	local inMaxL = inMax[2]
	local outMinS = outMin[1]
	local outMinL = outMin[2]
	local outMaxS = outMax[1]
	local outMaxL = outMax[2]

	local negInMinS = -inMinS
	local alphaNumS
	local alphaNumL
	if vl ~= vl or inMinL ~= inMinL then
		alphaNumS = 0
		alphaNumL = 0 / 0
	elseif vs == 0 then
		alphaNumS = negInMinS
		alphaNumL = inMinL
	elseif negInMinS == 0 then
		alphaNumS = vs
		alphaNumL = vl
	elseif vs == negInMinS then
		alphaNumS = vs
		if vl == inMinL then
			alphaNumL = vl + LOG10_2
		elseif vl >= inMinL then
			if vl == math.huge then
				alphaNumL = vl
			else
				local delta = inMinL - vl
				if delta < ADD_CUTOFF then
					alphaNumL = vl
				else
					alphaNumL = vl + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if inMinL == math.huge then
				alphaNumL = inMinL
			else
				local delta = vl - inMinL
				if delta < ADD_CUTOFF then
					alphaNumL = inMinL
				else
					alphaNumL = inMinL + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if vl == inMinL then
			if vl == math.huge then
				alphaNumS = 0
				alphaNumL = 0 / 0
			else
				alphaNumS = 0
				alphaNumL = 0
			end
		elseif vl > inMinL then
			alphaNumS = vs
			local delta = inMinL - vl
			if delta < ADD_CUTOFF then
				alphaNumL = vl
			elseif delta > -1e-300 then
				alphaNumL = vl + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					alphaNumS = 0
					alphaNumL = 0
				else
					alphaNumL = vl + math.log10(difference)
				end
			end
		else
			alphaNumS = negInMinS
			local delta = vl - inMinL
			if delta < ADD_CUTOFF then
				alphaNumL = inMinL
			elseif delta > -1e-300 then
				alphaNumL = inMinL + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					alphaNumS = 0
					alphaNumL = 0
				else
					alphaNumL = inMinL + math.log10(difference)
				end
			end
		end
	end
	local negInMinS2 = -inMinS
	local alphaDenS
	local alphaDenL
	if inMaxL ~= inMaxL or inMinL ~= inMinL then
		alphaDenS = 0
		alphaDenL = 0 / 0
	elseif inMaxS == 0 then
		alphaDenS = negInMinS2
		alphaDenL = inMinL
	elseif negInMinS2 == 0 then
		alphaDenS = inMaxS
		alphaDenL = inMaxL
	elseif inMaxS == negInMinS2 then
		alphaDenS = inMaxS
		if inMaxL == inMinL then
			alphaDenL = inMaxL + LOG10_2
		elseif inMaxL >= inMinL then
			if inMaxL == math.huge then
				alphaDenL = inMaxL
			else
				local delta = inMinL - inMaxL
				if delta < ADD_CUTOFF then
					alphaDenL = inMaxL
				else
					alphaDenL = inMaxL + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if inMinL == math.huge then
				alphaDenL = inMinL
			else
				local delta = inMaxL - inMinL
				if delta < ADD_CUTOFF then
					alphaDenL = inMinL
				else
					alphaDenL = inMinL + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if inMaxL == inMinL then
			if inMaxL == math.huge then
				alphaDenS = 0
				alphaDenL = 0 / 0
			else
				alphaDenS = 0
				alphaDenL = 0
			end
		elseif inMaxL > inMinL then
			alphaDenS = inMaxS
			local delta = inMinL - inMaxL
			if delta < ADD_CUTOFF then
				alphaDenL = inMaxL
			elseif delta > -1e-300 then
				alphaDenL = inMaxL + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					alphaDenS = 0
					alphaDenL = 0
				else
					alphaDenL = inMaxL + math.log10(difference)
				end
			end
		else
			alphaDenS = negInMinS2
			local delta = inMaxL - inMinL
			if delta < ADD_CUTOFF then
				alphaDenL = inMinL
			elseif delta > -1e-300 then
				alphaDenL = inMinL + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					alphaDenS = 0
					alphaDenL = 0
				else
					alphaDenL = inMinL + math.log10(difference)
				end
			end
		end
	end

	local alphaL = alphaNumL - alphaDenL
	local alphaS
	if alphaL ~= alphaL then
		return {0, 0 / 0}
	end
	if alphaDenS == 0 then
		if alphaNumS == 0 then
			return {0, 0 / 0}
		end
		alphaS = alphaNumS
		alphaL = math.huge
	elseif alphaNumS == 0 or alphaL == -math.huge then
		alphaS = 0
		alphaL = 0
	else
		alphaS = alphaNumS * alphaDenS
	end

	local negOutMinS = -outMinS
	local outDeltaS
	local outDeltaL
	if outMaxL ~= outMaxL or outMinL ~= outMinL then
		outDeltaS = 0
		outDeltaL = 0 / 0
	elseif outMaxS == 0 then
		outDeltaS = negOutMinS
		outDeltaL = outMinL
	elseif negOutMinS == 0 then
		outDeltaS = outMaxS
		outDeltaL = outMaxL
	elseif outMaxS == negOutMinS then
		outDeltaS = outMaxS
		if outMaxL == outMinL then
			outDeltaL = outMaxL + LOG10_2
		elseif outMaxL >= outMinL then
			if outMaxL == math.huge then
				outDeltaL = outMaxL
			else
				local delta = outMinL - outMaxL
				if delta < ADD_CUTOFF then
					outDeltaL = outMaxL
				else
					outDeltaL = outMaxL + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if outMinL == math.huge then
				outDeltaL = outMinL
			else
				local delta = outMaxL - outMinL
				if delta < ADD_CUTOFF then
					outDeltaL = outMinL
				else
					outDeltaL = outMinL + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if outMaxL == outMinL then
			if outMaxL == math.huge then
				outDeltaS = 0
				outDeltaL = 0 / 0
			else
				outDeltaS = 0
				outDeltaL = 0
			end
		elseif outMaxL > outMinL then
			outDeltaS = outMaxS
			local delta = outMinL - outMaxL
			if delta < ADD_CUTOFF then
				outDeltaL = outMaxL
			elseif delta > -1e-300 then
				outDeltaL = outMaxL + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					outDeltaS = 0
					outDeltaL = 0
				else
					outDeltaL = outMaxL + math.log10(difference)
				end
			end
		else
			outDeltaS = negOutMinS
			local delta = outMaxL - outMinL
			if delta < ADD_CUTOFF then
				outDeltaL = outMinL
			elseif delta > -1e-300 then
				outDeltaL = outMinL + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					outDeltaS = 0
					outDeltaL = 0
				else
					outDeltaL = outMinL + math.log10(difference)
				end
			end
		end
	end

	local scaledS
	local scaledL = outDeltaL + alphaL
	if scaledL ~= scaledL then
		return {0, 0 / 0}
	end
	if outDeltaS == 0 or alphaS == 0 then
		if scaledL == math.huge then
			return {0, 0 / 0}
		end
		scaledS = 0
		scaledL = 0
	else
		scaledS = outDeltaS * alphaS
		if scaledL == -math.huge then
			scaledS = 0
			scaledL = 0
		end
	end
	local resultS
	local resultL
	if outMinL ~= outMinL or scaledL ~= scaledL then
		resultS = 0
		resultL = 0 / 0
	elseif outMinS == 0 then
		resultS = scaledS
		resultL = scaledL
	elseif scaledS == 0 then
		resultS = outMinS
		resultL = outMinL
	elseif outMinS == scaledS then
		resultS = outMinS
		if outMinL == scaledL then
			resultL = outMinL + LOG10_2
		elseif outMinL >= scaledL then
			if outMinL == math.huge then
				resultL = outMinL
			else
				local delta = scaledL - outMinL
				if delta < ADD_CUTOFF then
					resultL = outMinL
				else
					resultL = outMinL + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if scaledL == math.huge then
				resultL = scaledL
			else
				local delta = outMinL - scaledL
				if delta < ADD_CUTOFF then
					resultL = scaledL
				else
					resultL = scaledL + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if outMinL == scaledL then
			if outMinL == math.huge then
				resultS = 0
				resultL = 0 / 0
			else
				resultS = 0
				resultL = 0
			end
		elseif outMinL > scaledL then
			resultS = outMinS
			local delta = scaledL - outMinL
			if delta < ADD_CUTOFF then
				resultL = outMinL
			elseif delta > -1e-300 then
				resultL = outMinL + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultS = 0
					resultL = 0
				else
					resultL = outMinL + math.log10(difference)
				end
			end
		else
			resultS = scaledS
			local delta = outMinL - scaledL
			if delta < ADD_CUTOFF then
				resultL = scaledL
			elseif delta > -1e-300 then
				resultL = scaledL + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultS = 0
					resultL = 0
				else
					resultL = scaledL + math.log10(difference)
				end
			end
		end
	end
	return {resultS, resultL}
end

--[[
Adds every Bnum in an array using an inline accumulator.
Example: {1, 2, 3} -> 6
]]
function Bnum.sum(values: {Value}): Value
	local count = #values
	if count == 0 then
		return {0, 0}
	end

	local accSign = 0
	local accLog = 0
	for i = 1, count do
		local current = values[i]
		local valueSign = current[1]
		local valueLog = current[2]
		local nextSign
		local nextLog
		if accLog ~= accLog or valueLog ~= valueLog then
			nextSign = 0
			nextLog = 0 / 0
		elseif accSign == 0 then
			nextSign = valueSign
			nextLog = valueLog
		elseif valueSign == 0 then
			nextSign = accSign
			nextLog = accLog
		elseif accSign == valueSign then
			nextSign = accSign
			if accLog == valueLog then
				nextLog = accLog + LOG10_2
			elseif accLog >= valueLog then
				if accLog == math.huge then
					nextLog = accLog
				else
					local delta = valueLog - accLog
					if delta < ADD_CUTOFF then
						nextLog = accLog
					else
						nextLog = accLog + math.log10(1 + math.exp(delta * LN10))
					end
				end
			else
				if valueLog == math.huge then
					nextLog = valueLog
				else
					local delta = accLog - valueLog
					if delta < ADD_CUTOFF then
						nextLog = valueLog
					else
						nextLog = valueLog + math.log10(1 + math.exp(delta * LN10))
					end
				end
			end
		else
			if accLog == valueLog then
				if accLog == math.huge then
					nextSign = 0
					nextLog = 0 / 0
				else
					nextSign = 0
					nextLog = 0
				end
			elseif accLog > valueLog then
				nextSign = accSign
				local delta = valueLog - accLog
				if delta < ADD_CUTOFF then
					nextLog = accLog
				elseif delta > -1e-300 then
					nextLog = accLog + math.log10(-delta) + LOG10_LN10
				else
					local difference
					if delta > CLOSE_CANCEL then
						local x = -delta * LN10
						difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
					else
						difference = 1 - math.exp(delta * LN10)
					end
					if difference <= 0 then
						nextSign = 0
						nextLog = 0
					else
						nextLog = accLog + math.log10(difference)
					end
				end
			else
				nextSign = valueSign
				local delta = accLog - valueLog
				if delta < ADD_CUTOFF then
					nextLog = valueLog
				elseif delta > -1e-300 then
					nextLog = valueLog + math.log10(-delta) + LOG10_LN10
				else
					local difference
					if delta > CLOSE_CANCEL then
						local x = -delta * LN10
						difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
					else
						difference = 1 - math.exp(delta * LN10)
					end
					if difference <= 0 then
						nextSign = 0
						nextLog = 0
					else
						nextLog = valueLog + math.log10(difference)
					end
				end
			end
		end
		accSign = nextSign
		accLog = nextLog
	end
	return {accSign, accLog}
end

--[[
Multiplies every Bnum in an array using an inline accumulator.
Example: {2, 3, 4} -> 24
]]
function Bnum.product(values: {Value}): Value
	local count = #values
	if count == 0 then
		return {1, 0}
	end

	local accSign = 1
	local accLog = 0
	for i = 1, count do
		local current = values[i]
		local valueSign = current[1]
		local valueLog = current[2]
		local nextLog = accLog + valueLog
		if nextLog ~= nextLog then
			return {0, 0 / 0}
		end
		if accSign == 0 or valueSign == 0 then
			if nextLog == math.huge then
				return {0, 0 / 0}
			end
			accSign = 0
			accLog = 0
		elseif nextLog == -math.huge then
			accSign = 0
			accLog = 0
		else
			accSign *= valueSign
			accLog = nextLog
		end
	end
	return {accSign, accLog}
end

--[[
Returns the arithmetic mean of all Bnums in an array.
Example: {2, 4, 6} -> 4
]]
function Bnum.mean(values: {Value}): Value
	local count = #values
	if count == 0 then
		return {0, 0 / 0}
	end

	local accSign = 0
	local accLog = 0
	for i = 1, count do
		local current = values[i]
		local valueSign = current[1]
		local valueLog = current[2]
		local nextSign
		local nextLog
		if accLog ~= accLog or valueLog ~= valueLog then
			nextSign = 0
			nextLog = 0 / 0
		elseif accSign == 0 then
			nextSign = valueSign
			nextLog = valueLog
		elseif valueSign == 0 then
			nextSign = accSign
			nextLog = accLog
		elseif accSign == valueSign then
			nextSign = accSign
			if accLog == valueLog then
				nextLog = accLog + LOG10_2
			elseif accLog >= valueLog then
				if accLog == math.huge then
					nextLog = accLog
				else
					local delta = valueLog - accLog
					if delta < ADD_CUTOFF then
						nextLog = accLog
					else
						nextLog = accLog + math.log10(1 + math.exp(delta * LN10))
					end
				end
			else
				if valueLog == math.huge then
					nextLog = valueLog
				else
					local delta = accLog - valueLog
					if delta < ADD_CUTOFF then
						nextLog = valueLog
					else
						nextLog = valueLog + math.log10(1 + math.exp(delta * LN10))
					end
				end
			end
		else
			if accLog == valueLog then
				if accLog == math.huge then
					nextSign = 0
					nextLog = 0 / 0
				else
					nextSign = 0
					nextLog = 0
				end
			elseif accLog > valueLog then
				nextSign = accSign
				local delta = valueLog - accLog
				if delta < ADD_CUTOFF then
					nextLog = accLog
				elseif delta > -1e-300 then
					nextLog = accLog + math.log10(-delta) + LOG10_LN10
				else
					local difference
					if delta > CLOSE_CANCEL then
						local x = -delta * LN10
						difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
					else
						difference = 1 - math.exp(delta * LN10)
					end
					if difference <= 0 then
						nextSign = 0
						nextLog = 0
					else
						nextLog = accLog + math.log10(difference)
					end
				end
			else
				nextSign = valueSign
				local delta = accLog - valueLog
				if delta < ADD_CUTOFF then
					nextLog = valueLog
				elseif delta > -1e-300 then
					nextLog = valueLog + math.log10(-delta) + LOG10_LN10
				else
					local difference
					if delta > CLOSE_CANCEL then
						local x = -delta * LN10
						difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
					else
						difference = 1 - math.exp(delta * LN10)
					end
					if difference <= 0 then
						nextSign = 0
						nextLog = 0
					else
						nextLog = valueLog + math.log10(difference)
					end
				end
			end
		end
		accSign = nextSign
		accLog = nextLog
	end

	if accLog ~= accLog then
		return {0, 0 / 0}
	end
	if accSign == 0 then
		return {0, 0}
	end
	local resultLog = accLog - math.log10(count)
	if resultLog == -math.huge then
		return {0, 0}
	end
	return {accSign, resultLog}
end

--[[
Returns part / whole × 100 as a Bnum.
Example: 25 of 100 -> 25
]]
function Bnum.percent(part: Value, whole: Value): Value
	local partSign = part[1]
	local partLog = part[2]
	local wholeSign = whole[1]
	local wholeLog = whole[2]
	local resultLog = partLog - wholeLog + 2

	if resultLog ~= resultLog then
		return {0, 0 / 0}
	end
	if wholeSign == 0 then
		if partSign == 0 then
			return {0, 0 / 0}
		end
		return {partSign, math.huge}
	end
	if partSign == 0 or resultLog == -math.huge then
		return {0, 0}
	end
	return {partSign * wholeSign, resultLog}
end

--[[
Returns the percentage change from an old Bnum to a new Bnum.
Example: 100 -> 125 gives 25
]]
function Bnum.percentChange(oldValue: Value, newValue: Value): Value
	local oldS = oldValue[1]
	local oldL = oldValue[2]
	local newS = newValue[1]
	local newL = newValue[2]
	if oldL ~= oldL or newL ~= newL then
		return {0, 0 / 0}
	end
	if oldS == newS and oldL == newL then
		return {0, 0}
	end
	if oldS == 0 then
		local newSign = math.sign(newS)
		if newSign == 0 then
			return {0, 0 / 0}
		end
		return {newSign, math.huge}
	end

	local negOldS = -oldS
	local deltaS
	local deltaL
	if newL ~= newL or oldL ~= oldL then
		deltaS = 0
		deltaL = 0 / 0
	elseif newS == 0 then
		deltaS = negOldS
		deltaL = oldL
	elseif negOldS == 0 then
		deltaS = newS
		deltaL = newL
	elseif newS == negOldS then
		deltaS = newS
		if newL == oldL then
			deltaL = newL + LOG10_2
		elseif newL >= oldL then
			if newL == math.huge then
				deltaL = newL
			else
				local delta = oldL - newL
				if delta < ADD_CUTOFF then
					deltaL = newL
				else
					deltaL = newL + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if oldL == math.huge then
				deltaL = oldL
			else
				local delta = newL - oldL
				if delta < ADD_CUTOFF then
					deltaL = oldL
				else
					deltaL = oldL + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if newL == oldL then
			if newL == math.huge then
				deltaS = 0
				deltaL = 0 / 0
			else
				deltaS = 0
				deltaL = 0
			end
		elseif newL > oldL then
			deltaS = newS
			local delta = oldL - newL
			if delta < ADD_CUTOFF then
				deltaL = newL
			elseif delta > -1e-300 then
				deltaL = newL + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					deltaS = 0
					deltaL = 0
				else
					deltaL = newL + math.log10(difference)
				end
			end
		else
			deltaS = negOldS
			local delta = newL - oldL
			if delta < ADD_CUTOFF then
				deltaL = oldL
			elseif delta > -1e-300 then
				deltaL = oldL + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					deltaS = 0
					deltaL = 0
				else
					deltaL = oldL + math.log10(difference)
				end
			end
		end
	end
	if deltaL ~= deltaL then
		return {0, 0 / 0}
	end
	if deltaS == 0 then
		return {0, 0}
	end

	local resultLog = deltaL - oldL + 2
	if resultLog ~= resultLog then
		return {0, 0 / 0}
	end
	if resultLog == -math.huge then
		return {0, 0}
	end
	return {deltaS * oldS, resultLog}
end

--[[
Checks whether a Bnum is canonical zero.
Example: {0, 0} -> true
]]
function Bnum.isZero(val: Value): boolean
	return val[1] == 0 and val[2] == 0
end

--[[
Checks whether a Bnum stores NaN.
Example: {0, NaN} -> true
]]
function Bnum.isNaN(val: Value): boolean
	return val[2] ~= val[2]
end

--[[
Checks whether a Bnum represents positive or negative infinity.
Example: {1, inf} -> true
]]
function Bnum.isInfinite(val: Value): boolean
	return val[1] ~= 0 and val[2] == math.huge
end

--[[
Checks whether a Bnum is finite and not NaN.
Example: 123 -> true
]]
function Bnum.isFinite(val: Value): boolean
	local logMagnitude = val[2]
	return logMagnitude == logMagnitude and logMagnitude ~= math.huge
end

--[[
Checks whether a Bnum is strictly greater than zero.
Example: 5 -> true
]]
function Bnum.isPositive(val: Value): boolean
	return val[1] > 0
end

--[[
Checks whether a Bnum is strictly less than zero.
Example: -5 -> true
]]
function Bnum.isNegative(val: Value): boolean
	return val[1] == -1
end

--[[
Returns -1, 0, or 1 for the Bnum sign.
Example: -25 -> -1
]]
function Bnum.sign(val: Value): number
	return val[1]
end

Bnum.DEFAULT_FORMAT = "standard"
Bnum.DEFAULT_PRECISION = 2
Bnum.MAX_PRECISION = 8
Bnum.E_NOTATION_START = 3000
Bnum.FORMAT_PRECISION_MODE = "decimal-places"
Bnum.ROMAN_CLASSICAL_MAX = 3999
Bnum.ROMAN_EXTENDED_MAX = 9007199254740991

Bnum.FormatTypes = table.freeze({
	Auto = "Auto",
	Suffix = "Suffix",
	SuffixLong = "SuffixLong",
	Scientific = "Scientific",
	Engineering = "Engineering",
	Standard = "Standard",
	Comma = "Comma",
	Logarithm = "Logarithm",
	Raw = "Raw",
	StandardSuffix = "standard",
	Extended = "extended",
	Hybrid = "hybrid",
	Alphabetic = "alphabetic",
	Metric = "metric",
	Exponent = "exponent",
	Roman = "roman",
	RomanExtended = "romanextended",
	Plain = "plain",
})

Bnum.SuffixTypes = table.freeze({
	standard = true,
	extended = true,
	hybrid = true,
	alphabetic = true,
	metric = true,
	exponent = true,
	scientific = true,
	engineering = true,
	roman = true,
	romanextended = true,
})

local FORMAT_FIXED = table.freeze({
	"%.0f", "%.1f", "%.2f", "%.3f", "%.4f", "%.5f", "%.6f", "%.7f", "%.8f",
})

local FORMAT_FACTORS = table.freeze({
	1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000,
})

local FORMAT_STANDARD_SUFFIXES = {
	"k", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod",
}

local FORMAT_STANDARD_FAMILIES = {
	{21, "Vg", "vg"},
	{31, "Tg", "tg"},
	{41, "Qag", "qag"},
	{51, "Qig", "qig"},
	{61, "Sxg", "sxg"},
	{71, "Spg", "spg"},
	{81, "Og", "og"},
	{91, "Ng", "ng"},
}

local FORMAT_STANDARD_UNIT_PREFIXES = {"U", "D", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"}

for _, family in FORMAT_STANDARD_FAMILIES do
	local baseIndex = family[1]
	FORMAT_STANDARD_SUFFIXES[baseIndex] = family[2]
	local tail = family[3]
	for unit = 1, 9 do
		FORMAT_STANDARD_SUFFIXES[baseIndex + unit] = FORMAT_STANDARD_UNIT_PREFIXES[unit] .. tail
	end
end

FORMAT_STANDARD_SUFFIXES[101] = "Ce"

-- Continue the standard suffix ladder with the module's generated suffixes.
-- This lets very large E-notation exponents stay readable:
-- 1e306 -> 1UCe, 1e307 -> 10UCe, 1e308 -> 100UCe.
for tier = 102, 999 do
	FORMAT_STANDARD_SUFFIXES[tier] = suffixes[tier + 1]
end

local FORMAT_METRIC_SUFFIXES = {"k", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q"}
local FORMAT_ALPHABETIC_CACHE: {[number]: string} = {}
local FORMAT_SAFE_INTEGER = 9007199254740991
local FORMAT_DIRECT_LOG_MAX = 308.25471555991675
local FORMAT_DIRECT_LOG_MIN = -323.3062153431158

local ROMAN_VALUES = {1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1}
local ROMAN_SYMBOLS = {"M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"}

local FORMAT_KIND_ALIASES = table.freeze({
	auto = "standard",
	suffix = "standard",
	suffixlong = "long",
	scientific = "scientific",
	engineering = "engineering",
	standard = "standard",
	comma = "comma",
	logarithm = "logarithm",
	raw = "raw",
	plain = "plain",
	extended = "extended",
	hybrid = "hybrid",
	alphabetic = "alphabetic",
	metric = "metric",
	exponent = "exponent",
	roman = "roman",
	romanextended = "romanextended",
	long = "long",
})

local function resolveFormatPrecision(value: number?): number
	if value == nil then return Bnum.DEFAULT_PRECISION end
	if value ~= value then return Bnum.DEFAULT_PRECISION end
	local places = math.floor(value)
	if places < 0 then return 0 end
	if places > Bnum.MAX_PRECISION then return Bnum.MAX_PRECISION end
	return places
end

local function trimFormatZeros(text: string): string
	local dot = string.find(text, ".", 1, true)
	if dot == nil then return text end
	local i = #text
	while i > dot and string.byte(text, i) == 48 do i -= 1 end
	if i == dot then i -= 1 end
	if i == #text then return text end
	return string.sub(text, 1, i)
end

local function shortFormatNumber(value: number, precision: number): string
	return trimFormatZeros(string.format(FORMAT_FIXED[precision + 1], value))
end

local function resolveFormatKind(formatType: string?): string
	if formatType == nil then return Bnum.DEFAULT_FORMAT end
	local lowered = string.lower(formatType)
	return FORMAT_KIND_ALIASES[lowered] or Bnum.DEFAULT_FORMAT
end

local function alphabeticFormatSuffix(index: number): string?
	if index < 1 or index ~= math.floor(index) or index > FORMAT_SAFE_INTEGER then return nil end
	local cached = FORMAT_ALPHABETIC_CACHE[index]
	if cached ~= nil then return cached end
	local n = index - 1
	local length = 2
	local block = 26 ^ length
	while n >= block do
		n -= block
		length += 1
		if length > 11 then return nil end
		block = 26 ^ length
	end
	local chars = table.create(length, "a")
	for pos = length, 1, -1 do
		local digit = n % 26
		chars[pos] = string.char(97 + digit)
		n = math.floor(n / 26)
	end
	local result = table.concat(chars)
	if index <= 4096 then FORMAT_ALPHABETIC_CACHE[index] = result end
	return result
end

local function formatSuffixForIndex(index: number, kind: string): string?
	if index < 1 or index ~= math.floor(index) then return nil end
	if kind == "standard" then return FORMAT_STANDARD_SUFFIXES[index] end
	if kind == "metric" then return FORMAT_METRIC_SUFFIXES[index] end
	if kind == "alphabetic" then return alphabeticFormatSuffix(index) end
	if kind == "extended" then
		if index <= 101 then return FORMAT_STANDARD_SUFFIXES[index] end
		if index < 1000 then return alphabeticFormatSuffix(index - 101) end
		return nil
	end
	if kind == "hybrid" then
		if index <= 101 then return FORMAT_STANDARD_SUFFIXES[index] end
		return alphabeticFormatSuffix(index - 101)
	end
	return nil
end

local function roundedPositive(value: number, precision: number): number
	local factor = FORMAT_FACTORS[precision + 1]
	return math.round(value * factor) / factor
end

local function scientificFormatText(mantissa: number, exponent: number, precision: number): string
	local rounded = roundedPositive(mantissa, precision)
	if rounded >= 10 then
		rounded *= 0.1
		exponent += 1
	elseif rounded > 0 and rounded < 1 then
		rounded *= 10
		exponent -= 1
	end
	return shortFormatNumber(rounded, precision) .. "e" .. tostring(exponent)
end

local function engineeringFormatText(mantissa: number, exponent: number, precision: number): string
	local engineeringExponent = math.floor(exponent / 3) * 3
	local scaled = mantissa * 10 ^ (exponent - engineeringExponent)
	scaled = roundedPositive(scaled, precision)
	if scaled >= 1000 then
		scaled *= 0.001
		engineeringExponent += 3
	end
	return shortFormatNumber(scaled, precision) .. "e" .. tostring(engineeringExponent)
end

local function normalFormatParts(mantissa: number, exponent: number, precision: number, kind: string): string
	if kind == "scientific" then return scientificFormatText(mantissa, exponent, precision) end
	if kind == "engineering" then return engineeringFormatText(mantissa, exponent, precision) end
	if kind == "exponent" then
		local rounded = roundedPositive(mantissa, precision)
		if rounded >= 10 then
			rounded *= 0.1
			exponent += 1
		end
		return shortFormatNumber(rounded, precision) .. "E" .. tostring(exponent)
	end
	if exponent < 3 and exponent >= 0 then
		return shortFormatNumber(mantissa * 10 ^ exponent, precision)
	end
	if exponent >= 3 then
		local index = math.floor(exponent / 3)
		local suffix = formatSuffixForIndex(index, kind)
		if suffix ~= nil then
			local scaled = roundedPositive(mantissa * 10 ^ (exponent - index * 3), precision)
			if scaled >= 1000 then
				scaled *= 0.001
				index += 1
				suffix = formatSuffixForIndex(index, kind)
				if suffix == nil then return scientificFormatText(mantissa, exponent, precision) end
			end
			return shortFormatNumber(scaled, precision) .. suffix
		end
	end
	if exponent < 0 then
		local inverseMantissa = 10 / mantissa
		local inverseExponent = -exponent - 1
		return "1/" .. normalFormatParts(inverseMantissa, inverseExponent, precision, kind)
	end
	return scientificFormatText(mantissa, exponent, precision)
end

local function formatDisplayScalar(value: number, precision: number): string
	if value ~= value then return "NaN" end
	if value == math.huge then return "inf" end
	if value == -math.huge then return "-inf" end
	if value == 0 then return "0" end
	local negative = value < 0
	local magnitude = negative and -value or value
	local text
	if magnitude < 1000 then
		text = shortFormatNumber(magnitude, precision)
	else
		local exponent = math.floor(math.log10(magnitude))
		local mantissa = magnitude / 10 ^ exponent
		text = normalFormatParts(mantissa, exponent, precision, "standard")
	end
	return negative and "-" .. text or text
end

local function romanClassical(value: number): string
	local out = table.create(16)
	local count = 0
	for i = 1, #ROMAN_VALUES do
		while value >= ROMAN_VALUES[i] do
			value -= ROMAN_VALUES[i]
			count += 1
			out[count] = ROMAN_SYMBOLS[i]
		end
	end
	return table.concat(out, "", 1, count)
end

local function romanExtended(value: number): string
	if value <= 3999 then return romanClassical(value) end
	local groups = {}
	local depth = 0
	while value > 0 do
		local nextValue = math.floor(value / 1000)
		local group = value - nextValue * 1000
		if group > 0 then
			local text = romanClassical(group)
			if depth > 0 then text = string.rep("(", depth) .. text .. string.rep(")", depth) end
			table.insert(groups, 1, text)
		end
		value = nextValue
		depth += 1
	end
	return table.concat(groups)
end

local function formatRomanInteger(value: number, extended: boolean): string?
	local nearest = math.round(value)
	if math.abs(value - nearest) > math.max(1, math.abs(value)) * INTEGER_SNAP_REL then return nil end
	value = nearest
	if math.abs(value) > FORMAT_SAFE_INTEGER then return nil end
	if value == 0 then return "N" end
	local negative = value < 0
	local magnitude = negative and -value or value
	if not extended and magnitude > Bnum.ROMAN_CLASSICAL_MAX then return nil end
	local text = extended and romanExtended(magnitude) or romanClassical(magnitude)
	return negative and "-" .. text or text
end

local function bnumFormatCore(val: Value, precision: number, kind: string): string
	local sign = val[1]
	local logMagnitude = val[2]
	if kind == "raw" then return "{" .. tostring(sign) .. ", " .. tostring(logMagnitude) .. "}" end
	if logMagnitude ~= logMagnitude then return "NaN" end
	if sign == 0 then return "0" end
	if logMagnitude == math.huge then return sign < 0 and "-inf" or "inf" end

	local negative = sign < 0

	if logMagnitude >= FORMAT_DIRECT_LOG_MIN and logMagnitude <= FORMAT_DIRECT_LOG_MAX then
		local magnitude = 10 ^ logMagnitude
		if magnitude ~= 0 and magnitude < math.huge then
			local value = negative and -magnitude or magnitude
			if kind == "roman" or kind == "romanextended" then
				local roman = formatRomanInteger(value, kind == "romanextended")
				if roman ~= nil then return roman end
				kind = "standard"
			end
			if kind == "plain" then return shortFormatNumber(value, precision) end
			if kind == "comma" then
				local text = shortFormatNumber(value, precision)
				local dot = string.find(text, ".", 1, true)
				local integerEnd = if dot then dot - 1 else #text
				local first = if negative then 2 else 1
				local digitsCount = integerEnd - first + 1
				if digitsCount <= 3 then return text end
				local firstGroup = digitsCount % 3
				if firstGroup == 0 then firstGroup = 3 end
				local out = negative and "-" or ""
				local cursor = first
				out ..= string.sub(text, cursor, cursor + firstGroup - 1)
				cursor += firstGroup
				while cursor <= integerEnd do
					out ..= "," .. string.sub(text, cursor, cursor + 2)
					cursor += 3
				end
				if dot then out ..= string.sub(text, dot) end
				return out
			end
			if kind == "logarithm" then
				return (negative and "-10^" or "10^") .. shortFormatNumber(logMagnitude, precision)
			end
			local exponent = math.floor(logMagnitude)
			local mantissa = 10 ^ (logMagnitude - exponent)
			local text = normalFormatParts(mantissa, exponent, precision, kind)
			return negative and "-" .. text or text
		end
	end

	if kind == "logarithm" then
		return (negative and "-10^" or "10^") .. formatDisplayScalar(logMagnitude, precision)
	end
	if kind == "comma" or kind == "plain" then kind = "standard" end
	if kind == "roman" or kind == "romanextended" then kind = "standard" end

	local reciprocal = logMagnitude < 0
	local exponentMagnitude = reciprocal and -logMagnitude or logMagnitude
	local text
	if exponentMagnitude >= Bnum.E_NOTATION_START then
		text = "E" .. formatDisplayScalar(exponentMagnitude, precision)
	else
		local integerExponent = math.floor(exponentMagnitude)
		local mantissa = 10 ^ (exponentMagnitude - integerExponent)
		text = normalFormatParts(mantissa, integerExponent, precision, kind)
	end
	if reciprocal then text = "1/" .. text end
	return negative and "-" .. text or text
end

local function longFormatCore(val: Value, precision: number): string
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then return "NaN" end
	if sign == 0 then return "0" end
	if logMagnitude == math.huge then return sign < 0 and "-inf" or "inf" end
	if logMagnitude < 3 or logMagnitude >= Bnum.E_NOTATION_START then
		return bnumFormatCore(val, precision, "standard")
	end
	local tier = math.floor(logMagnitude / 3)
	if tier < 1 or tier >= #longSuffixes then return bnumFormatCore(val, precision, "standard") end
	local scaled = math.round(sign * (10 ^ (logMagnitude - tier * 3)) * FORMAT_FACTORS[precision + 1]) / FORMAT_FACTORS[precision + 1]
	if scaled >= 1000 or scaled <= -1000 then
		scaled *= 0.001
		tier += 1
		if tier >= #longSuffixes then return bnumFormatCore(val, precision, "standard") end
	end
	return shortFormatNumber(scaled, precision) .. " " .. longSuffixes[tier + 1]
end

--[[
Returns the suffix used by the standard formatter through tier 999.
Examples: tier 1 -> "k", tier 101 -> "Ce", tier 102 -> "UCe"
]]
function Bnum.getSuffix(tier: number): string?
	if tier ~= tier then return nil end
	tier = math.floor(tier)
	if tier < 1 then return nil end
	return FORMAT_STANDARD_SUFFIXES[tier]
end

--[[
Checks whether a formatter notation name is supported.
]]
function Bnum.isFormatType(formatType: string): boolean
	return FORMAT_KIND_ALIASES[string.lower(formatType)] ~= nil
end

--[[
Sets the default notation used by Bnum.format().
]]
function Bnum.setDefaultFormat(formatType: string): boolean
	local kind = resolveFormatKind(formatType)
	if FORMAT_KIND_ALIASES[string.lower(formatType)] == nil then return false end
	Bnum.DEFAULT_FORMAT = kind
	return true
end

--[[
NanoNum-style default formatter.
Examples: 1250000 -> "1.25M", 10^3000 -> "E3k"
]]
function Bnum.format(val: Value, decimalPlaces: number?, formatType: FormatType?): string
	local precision = resolveFormatPrecision(decimalPlaces)
	local kind = resolveFormatKind(formatType)
	if kind == "long" then return longFormatCore(val, precision) end
	return bnumFormatCore(val, precision, kind)
end

--[[
Formats with the standard suffix ladder.
]]
function Bnum.formatStandard(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "standard")
end

--[[
Formats with standard suffixes through Ce, then alphabetic suffixes through tier 999.
]]
function Bnum.formatExtended(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "extended")
end

--[[
Formats with standard suffixes first and alphabetic suffixes beyond the standard ladder.
]]
function Bnum.formatHybrid(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "hybrid")
end

--[[
Formats 10^3 tiers as aa, ab, ac, ...
]]
function Bnum.formatAlphabetic(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "alphabetic")
end

--[[
Formats using SI-style metric suffixes k, M, G, T, ...
]]
function Bnum.formatMetric(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "metric")
end

--[[
Formats as mantissa E exponent.
]]
function Bnum.formatExponent(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "exponent")
end

--[[
Formats in scientific notation.
]]
function Bnum.formatScientific(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "scientific")
end

--[[
Formats in engineering notation.
]]
function Bnum.formatEngineering(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "engineering")
end

--[[
Formats exact integers as classical Roman numerals when possible.
Falls back to standard notation when the value is not a supported integer.
]]
function Bnum.formatRoman(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "roman")
end

--[[
Formats exact integers with parenthesized extended Roman numerals.
Falls back to standard notation when the value is not a supported integer.
]]
function Bnum.formatRomanExtended(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "romanextended")
end

--[[
Legacy alias for the standard suffix formatter.
]]
function Bnum.formatSuffix(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "standard")
end

--[[
Legacy long-name suffix formatter.
Example: 2000000 -> "2 Million"
]]
function Bnum.formatSuffixLong(val: Value, decimalPlaces: number?): string
	return longFormatCore(val, resolveFormatPrecision(decimalPlaces))
end

--[[
Formats as a fixed decimal when representable.
Large values fall back to the standard display ladder.
]]
function Bnum.formatPlain(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "plain")
end

--[[
Formats normal-sized values with comma grouping.
Large values fall back to the standard display ladder.
]]
function Bnum.formatComma(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "comma")
end

--[[
Formats as 10^logMagnitude.
]]
function Bnum.formatLogarithm(val: Value, decimalPlaces: number?): string
	return bnumFormatCore(val, resolveFormatPrecision(decimalPlaces), "logarithm")
end

--[[
Returns the raw {sign, logMagnitude} representation.
]]
function Bnum.formatRaw(val: Value): string
	return "{" .. tostring(val[1]) .. ", " .. tostring(val[2]) .. "}"
end

--[[
Compatibility entry point. The NanoNum-style standard formatter is now the default.
Existing option fields are retained where they map cleanly to the new formatter.
]]
function Bnum.autoFormat(val: Value, digits: number?, options: AutoFormatOptions?): string
	local precision = digits
	local kind = Bnum.DEFAULT_FORMAT
	if options ~= nil then
		if precision == nil then precision = options.Digits end
		if options.LongSuffix == true then kind = "long" end
	end
	if kind == "long" then return longFormatCore(val, resolveFormatPrecision(precision)) end
	return bnumFormatCore(val, resolveFormatPrecision(precision), kind)
end

--[[
Adds two Bnums and writes the result into an existing output table.
Example: reuses out instead of allocating a new result
]]
function Bnum.addInto(out: Value, val1: Value, val2: Value): Value
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	if s1 == 0 then
		out[1] = s2
		out[2] = l2
		return out
	end

	if s2 == 0 then
		out[1] = s1
		out[2] = l1
		return out
	end

	if s1 == s2 then
		if l1 == l2 then
			out[1] = s1
			out[2] = l1 + LOG10_2
			return out
		end

		if l1 >= l2 then
			if l1 == math.huge then
				out[1] = s1
				out[2] = l1
				return out
			end

			local delta = l2 - l1

			if delta < ADD_CUTOFF then
				out[1] = s1
				out[2] = l1
				return out
			end

			out[1] = s1
			out[2] = l1 + math.log10(1 + math.exp(delta * LN10))
			return out
		end

		if l2 == math.huge then
			out[1] = s1
			out[2] = l2
			return out
		end

		local delta = l1 - l2

		if delta < ADD_CUTOFF then
			out[1] = s1
			out[2] = l2
			return out
		end

		out[1] = s1
		out[2] = l2 + math.log10(1 + math.exp(delta * LN10))
		return out
	end

	if l1 == l2 then
		if l1 == math.huge then
			out[1] = 0
			out[2] = 0 / 0
			return out
		end

		out[1] = 0
		out[2] = 0
		return out
	end

	if l1 > l2 then
		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			out[1] = s1
			out[2] = l1
			return out
		end

		local difference

		if delta > CLOSE_CANCEL then
			if delta > -1e-300 then
				out[1] = s1
				out[2] = l1 + (math.log10(-delta) + LOG10_LN10)
				return out
			end

			local x = -delta * LN10
			difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
		else
			difference = 1 - math.exp(delta * LN10)
		end

		if difference <= 0 then
			out[1] = 0
			out[2] = 0
			return out
		end

		out[1] = s1
		out[2] = l1 + math.log10(difference)
		return out
	end

	local delta = l1 - l2

	if delta < ADD_CUTOFF then
		out[1] = s2
		out[2] = l2
		return out
	end

	local difference

	if delta > CLOSE_CANCEL then
		if delta > -1e-300 then
			out[1] = s2
			out[2] = l2 + (math.log10(-delta) + LOG10_LN10)
			return out
		end

		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end

	if difference <= 0 then
		out[1] = 0
		out[2] = 0
		return out
	end

	out[1] = s2
	out[2] = l2 + math.log10(difference)
	return out
end

--[[
Subtracts two Bnums and writes the result into an existing output table.
Example: reuses out instead of allocating a new result
]]
function Bnum.subInto(out: Value, val1: Value, val2: Value): Value
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = -val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	if s1 == 0 then
		out[1] = s2
		out[2] = l2
		return out
	end

	if s2 == 0 then
		out[1] = s1
		out[2] = l1
		return out
	end

	if s1 == s2 then
		if l1 == l2 then
			out[1] = s1
			out[2] = l1 + LOG10_2
			return out
		end

		if l2 > l1 then
			l1, l2 = l2, l1
		end

		if l1 == math.huge then
			out[1] = s1
			out[2] = l1
			return out
		end

		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			out[1] = s1
			out[2] = l1
			return out
		end

		out[1] = s1
		out[2] = l1 + math.log10(1 + math.exp(delta * LN10))
		return out
	end

	if l1 == l2 then
		if l1 == math.huge then
			out[1] = 0
			out[2] = 0 / 0
			return out
		end

		out[1] = 0
		out[2] = 0
		return out
	end

	if l1 > l2 then
		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			out[1] = s1
			out[2] = l1
			return out
		end

		local difference

		if delta > CLOSE_CANCEL then
			if delta > -1e-300 then
				out[1] = s1
				out[2] = l1 + (math.log10(-delta) + LOG10_LN10)
				return out
			end

			local x = -delta * LN10
			difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
		else
			difference = 1 - math.exp(delta * LN10)
		end

		if difference <= 0 then
			out[1] = 0
			out[2] = 0
			return out
		end

		out[1] = s1
		out[2] = l1 + math.log10(difference)
		return out
	end

	local delta = l1 - l2

	if delta < ADD_CUTOFF then
		out[1] = s2
		out[2] = l2
		return out
	end

	local difference

	if delta > CLOSE_CANCEL then
		if delta > -1e-300 then
			out[1] = s2
			out[2] = l2 + (math.log10(-delta) + LOG10_LN10)
			return out
		end

		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end

	if difference <= 0 then
		out[1] = 0
		out[2] = 0
		return out
	end

	out[1] = s2
	out[2] = l2 + math.log10(difference)
	return out
end

--[[
Multiplies two Bnums and writes the result into an existing output table.
Example: reuses out instead of allocating a new result
]]
function Bnum.mulInto(out: Value, val1: Value, val2: Value): Value
	local s1 = val1[1]
	local s2 = val2[1]
	local logMagnitude = val1[2] + val2[2]

	if logMagnitude ~= logMagnitude then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	if s1 == 0 or s2 == 0 then
		if logMagnitude == math.huge then
			out[1] = 0
			out[2] = 0 / 0
			return out
		end

		out[1] = 0
		out[2] = 0
		return out
	end

	if logMagnitude == -math.huge then
		out[1] = 0
		out[2] = 0
		return out
	end

	out[1] = s1 * s2
	out[2] = logMagnitude
	return out
end

--[[
Divides two Bnums and writes the result into an existing output table.
Example: reuses out instead of allocating a new result
]]
function Bnum.divInto(out: Value, val1: Value, val2: Value): Value
	local s1 = val1[1]
	local s2 = val2[1]
	local logMagnitude = val1[2] - val2[2]

	if logMagnitude ~= logMagnitude then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	if s2 == 0 then
		if s1 == 0 then
			out[1] = 0
			out[2] = 0 / 0
			return out
		end

		out[1] = s1
		out[2] = math.huge
		return out
	end

	if s1 == 0 or logMagnitude == -math.huge then
		out[1] = 0
		out[2] = 0
		return out
	end

	out[1] = s1 * s2
	out[2] = logMagnitude
	return out
end

--[[
Raises a Bnum to a numeric power and writes into an existing output table.
Example: reuses out for power results
]]
function Bnum.powInto(out: Value, val: Value, power: number): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if power ~= power then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end
	if power == 0 then
		out[1] = 1
		out[2] = 0
		return out
	end
	if logMagnitude ~= logMagnitude then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end
	if sign == 0 then
		if power > 0 then
			out[1] = 0
			out[2] = 0
		else
			out[1] = 1
			out[2] = math.huge
		end
		return out
	end
	if power == math.huge or power == -math.huge then
		if sign < 0 then
			out[1] = 0
			out[2] = 0 / 0
			return out
		end
		if logMagnitude == 0 then
			out[1] = 1
			out[2] = 0
			return out
		end
		local grows = (power > 0 and logMagnitude > 0) or (power < 0 and logMagnitude < 0)
		if grows then
			out[1] = 1
			out[2] = math.huge
		else
			out[1] = 0
			out[2] = 0
		end
		return out
	end
	if sign < 0 and power % 1 ~= 0 then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end
	local resultLog = logMagnitude * power
	if resultLog ~= resultLog then
		out[1] = 0
		out[2] = 0 / 0
	elseif resultLog == -math.huge then
		out[1] = 0
		out[2] = 0
	elseif sign < 0 then
		out[1] = if power % 2 == 0 then 1 else -1
		out[2] = resultLog
	else
		out[1] = 1
		out[2] = resultLog
	end
	return out
end

--[[
Adds a normal number to a Bnum and writes into an existing output table.
Example: Bnum + number without a result allocation
]]
function Bnum.addNumberInto(out: Value, val: Value, n: number): Value
	local s1 = val[1]
	local l1 = val[2]

	if n ~= n then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	if n == 0 then
		out[1] = s1
		out[2] = l1
		return out
	end

	local s2 = math.sign(n)
	local l2 = math.log10(if n < 0 then -n else n)

	if l1 ~= l1 or l2 ~= l2 then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	if s1 == 0 then
		out[1] = s2
		out[2] = l2
		return out
	end

	if s2 == 0 then
		out[1] = s1
		out[2] = l1
		return out
	end

	if s1 == s2 then
		if l1 == l2 then
			out[1] = s1
			out[2] = l1 + LOG10_2
			return out
		end

		if l1 >= l2 then
			if l1 == math.huge then
				out[1] = s1
				out[2] = l1
				return out
			end

			local delta = l2 - l1

			if delta < ADD_CUTOFF then
				out[1] = s1
				out[2] = l1
				return out
			end

			out[1] = s1
			out[2] = l1 + math.log10(1 + math.exp(delta * LN10))
			return out
		end

		if l2 == math.huge then
			out[1] = s1
			out[2] = l2
			return out
		end

		local delta = l1 - l2

		if delta < ADD_CUTOFF then
			out[1] = s1
			out[2] = l2
			return out
		end

		out[1] = s1
		out[2] = l2 + math.log10(1 + math.exp(delta * LN10))
		return out
	end

	if l1 == l2 then
		if l1 == math.huge then
			out[1] = 0
			out[2] = 0 / 0
			return out
		end

		out[1] = 0
		out[2] = 0
		return out
	end

	if l1 > l2 then
		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			out[1] = s1
			out[2] = l1
			return out
		end

		local difference

		if delta > CLOSE_CANCEL then
			if delta > -1e-300 then
				out[1] = s1
				out[2] = l1 + (math.log10(-delta) + LOG10_LN10)
				return out
			end

			local x = -delta * LN10
			difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
		else
			difference = 1 - math.exp(delta * LN10)
		end

		if difference <= 0 then
			out[1] = 0
			out[2] = 0
			return out
		end

		out[1] = s1
		out[2] = l1 + math.log10(difference)
		return out
	end

	local delta = l1 - l2

	if delta < ADD_CUTOFF then
		out[1] = s2
		out[2] = l2
		return out
	end

	local difference

	if delta > CLOSE_CANCEL then
		if delta > -1e-300 then
			out[1] = s2
			out[2] = l2 + (math.log10(-delta) + LOG10_LN10)
			return out
		end

		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end

	if difference <= 0 then
		out[1] = 0
		out[2] = 0
		return out
	end

	out[1] = s2
	out[2] = l2 + math.log10(difference)
	return out
end

--[[
Subtracts a normal number from a Bnum and writes into an existing output table.
Example: Bnum - number without a result allocation
]]
function Bnum.subNumberInto(out: Value, val: Value, n: number): Value
	local s1 = val[1]
	local l1 = val[2]

	if n ~= n then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	if n == 0 then
		out[1] = s1
		out[2] = l1
		return out
	end

	local s2 = -math.sign(n)
	local l2 = math.log10(if n < 0 then -n else n)

	if l1 ~= l1 or l2 ~= l2 then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	if s1 == 0 then
		out[1] = s2
		out[2] = l2
		return out
	end

	if s2 == 0 then
		out[1] = s1
		out[2] = l1
		return out
	end

	if s1 == s2 then
		if l1 == l2 then
			out[1] = s1
			out[2] = l1 + LOG10_2
			return out
		end

		if l2 > l1 then
			l1, l2 = l2, l1
		end

		if l1 == math.huge then
			out[1] = s1
			out[2] = l1
			return out
		end

		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			out[1] = s1
			out[2] = l1
			return out
		end

		out[1] = s1
		out[2] = l1 + math.log10(1 + math.exp(delta * LN10))
		return out
	end

	if l1 == l2 then
		if l1 == math.huge then
			out[1] = 0
			out[2] = 0 / 0
			return out
		end

		out[1] = 0
		out[2] = 0
		return out
	end

	if l1 > l2 then
		local delta = l2 - l1

		if delta < ADD_CUTOFF then
			out[1] = s1
			out[2] = l1
			return out
		end

		local difference

		if delta > CLOSE_CANCEL then
			if delta > -1e-300 then
				out[1] = s1
				out[2] = l1 + (math.log10(-delta) + LOG10_LN10)
				return out
			end

			local x = -delta * LN10
			difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
		else
			difference = 1 - math.exp(delta * LN10)
		end

		if difference <= 0 then
			out[1] = 0
			out[2] = 0
			return out
		end

		out[1] = s1
		out[2] = l1 + math.log10(difference)
		return out
	end

	local delta = l1 - l2

	if delta < ADD_CUTOFF then
		out[1] = s2
		out[2] = l2
		return out
	end

	local difference

	if delta > CLOSE_CANCEL then
		if delta > -1e-300 then
			out[1] = s2
			out[2] = l2 + (math.log10(-delta) + LOG10_LN10)
			return out
		end

		local x = -delta * LN10
		difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
	else
		difference = 1 - math.exp(delta * LN10)
	end

	if difference <= 0 then
		out[1] = 0
		out[2] = 0
		return out
	end

	out[1] = s2
	out[2] = l2 + math.log10(difference)
	return out
end

--[[
Multiplies a Bnum by a normal number and writes into an existing output table.
Example: Bnum × number without a result allocation
]]
function Bnum.mulNumberInto(out: Value, val: Value, n: number): Value
	local s1 = val[1]
	local l1 = val[2]

	if l1 ~= l1 or n ~= n then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end
	if n == 0 then
		if s1 ~= 0 and l1 == math.huge then
			out[1] = 0
			out[2] = 0 / 0
		else
			out[1] = 0
			out[2] = 0
		end
		return out
	end
	if s1 == 0 then
		out[1] = 0
		out[2] = if n == math.huge or n == -math.huge then 0 / 0 else 0
		return out
	end

	local resultLog = l1 + math.log10(if n < 0 then -n else n)
	if resultLog ~= resultLog then
		out[1] = 0
		out[2] = 0 / 0
	elseif resultLog == -math.huge then
		out[1] = 0
		out[2] = 0
	else
		out[1] = if n < 0 then -s1 else s1
		out[2] = resultLog
	end
	return out
end

--[[
Divides a Bnum by a normal number and writes into an existing output table.
Example: Bnum / number without a result allocation
]]
function Bnum.divNumberInto(out: Value, val: Value, n: number): Value
	local s1 = val[1]
	local l1 = val[2]

	if l1 ~= l1 or n ~= n then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end
	if n == 0 then
		if s1 == 0 then
			out[1] = 0
			out[2] = 0 / 0
		else
			out[1] = s1
			out[2] = math.huge
		end
		return out
	end
	if s1 == 0 then
		out[1] = 0
		out[2] = 0
		return out
	end

	local resultLog = l1 - math.log10(if n < 0 then -n else n)
	if resultLog ~= resultLog then
		out[1] = 0
		out[2] = 0 / 0
	elseif resultLog == -math.huge then
		out[1] = 0
		out[2] = 0
	else
		out[1] = if n < 0 then -s1 else s1
		out[2] = resultLog
	end
	return out
end

--[[
Scales a Bnum by 10^exponent and writes into an existing output table.
Example: log magnitude is shifted in-place through out
]]
function Bnum.scale10Into(out: Value, val: Value, exponent: number): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude or exponent ~= exponent then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end
	if sign == 0 then
		out[1] = 0
		out[2] = 0
		return out
	end

	local resultLog = logMagnitude + exponent
	if resultLog ~= resultLog then
		out[1] = 0
		out[2] = 0 / 0
	elseif resultLog == -math.huge then
		out[1] = 0
		out[2] = 0
	else
		out[1] = sign
		out[2] = resultLog
	end
	return out
end

--[[
Squares a Bnum and writes into an existing output table.
Example: x² without allocating a result table
]]
function Bnum.squareInto(out: Value, val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then
		out[1] = 0
		out[2] = logMagnitude
	elseif sign == 0 then
		out[1] = 0
		out[2] = 0
	else
		out[1] = 1
		out[2] = logMagnitude * 2
	end
	return out
end

--[[
Cubes a Bnum and writes into an existing output table.
Example: x³ without allocating a result table
]]
function Bnum.cubeInto(out: Value, val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]
	if logMagnitude ~= logMagnitude then
		out[1] = 0
		out[2] = logMagnitude
	elseif sign == 0 then
		out[1] = 0
		out[2] = 0
	else
		out[1] = sign
		out[2] = logMagnitude * 3
	end
	return out
end

--[[
Computes a × b + c directly into an existing output table.
Example: fused reusable-output math
]]
function Bnum.mulAddInto(out: Value, a: Value, b: Value, c: Value): Value
	local aSign = a[1]
	local bSign = b[1]
	local s1 = aSign * bSign
	local l1 = a[2] + b[2]
	local s2 = c[1]
	local l2 = c[2]
	if l1 ~= l1 or l2 ~= l2 then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end
	if aSign == 0 or bSign == 0 then
		if l1 == math.huge then
			out[1] = 0
			out[2] = 0 / 0
			return out
		end
		s1 = 0
		l1 = 0
	end
	local resultSign
	local resultLog
	if l1 ~= l1 or l2 ~= l2 then
		resultSign = 0
		resultLog = 0 / 0
	elseif s1 == 0 then
		resultSign = s2
		resultLog = l2
	elseif s2 == 0 then
		resultSign = s1
		resultLog = l1
	elseif s1 == s2 then
		resultSign = s1
		if l1 == l2 then
			resultLog = l1 + LOG10_2
		elseif l1 >= l2 then
			if l1 == math.huge then
				resultLog = l1
			else
				local delta = l2 - l1
				if delta < ADD_CUTOFF then
					resultLog = l1
				else
					resultLog = l1 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if l2 == math.huge then
				resultLog = l2
			else
				local delta = l1 - l2
				if delta < ADD_CUTOFF then
					resultLog = l2
				else
					resultLog = l2 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if l1 == l2 then
			if l1 == math.huge then
				resultSign = 0
				resultLog = 0 / 0
			else
				resultSign = 0
				resultLog = 0
			end
		elseif l1 > l2 then
			resultSign = s1
			local delta = l2 - l1
			if delta < ADD_CUTOFF then
				resultLog = l1
			elseif delta > -1e-300 then
				resultLog = l1 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultSign = 0
					resultLog = 0
				else
					resultLog = l1 + math.log10(difference)
				end
			end
		else
			resultSign = s2
			local delta = l1 - l2
			if delta < ADD_CUTOFF then
				resultLog = l2
			elseif delta > -1e-300 then
				resultLog = l2 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultSign = 0
					resultLog = 0
				else
					resultLog = l2 + math.log10(difference)
				end
			end
		end
	end
	out[1] = resultSign
	out[2] = resultLog
	return out
end

--[[
Computes a + b × c directly into an existing output table.
Example: fused reusable-output math
]]
function Bnum.addMulInto(out: Value, a: Value, b: Value, c: Value): Value
	local bSign = b[1]
	local cSign = c[1]
	local s1 = bSign * cSign
	local l1 = b[2] + c[2]
	local s2 = a[1]
	local l2 = a[2]
	if l1 ~= l1 or l2 ~= l2 then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end
	if bSign == 0 or cSign == 0 then
		if l1 == math.huge then
			out[1] = 0
			out[2] = 0 / 0
			return out
		end
		s1 = 0
		l1 = 0
	end
	local resultSign
	local resultLog
	if l1 ~= l1 or l2 ~= l2 then
		resultSign = 0
		resultLog = 0 / 0
	elseif s1 == 0 then
		resultSign = s2
		resultLog = l2
	elseif s2 == 0 then
		resultSign = s1
		resultLog = l1
	elseif s1 == s2 then
		resultSign = s1
		if l1 == l2 then
			resultLog = l1 + LOG10_2
		elseif l1 >= l2 then
			if l1 == math.huge then
				resultLog = l1
			else
				local delta = l2 - l1
				if delta < ADD_CUTOFF then
					resultLog = l1
				else
					resultLog = l1 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		else
			if l2 == math.huge then
				resultLog = l2
			else
				local delta = l1 - l2
				if delta < ADD_CUTOFF then
					resultLog = l2
				else
					resultLog = l2 + math.log10(1 + math.exp(delta * LN10))
				end
			end
		end
	else
		if l1 == l2 then
			if l1 == math.huge then
				resultSign = 0
				resultLog = 0 / 0
			else
				resultSign = 0
				resultLog = 0
			end
		elseif l1 > l2 then
			resultSign = s1
			local delta = l2 - l1
			if delta < ADD_CUTOFF then
				resultLog = l1
			elseif delta > -1e-300 then
				resultLog = l1 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultSign = 0
					resultLog = 0
				else
					resultLog = l1 + math.log10(difference)
				end
			end
		else
			resultSign = s2
			local delta = l1 - l2
			if delta < ADD_CUTOFF then
				resultLog = l2
			elseif delta > -1e-300 then
				resultLog = l2 + math.log10(-delta) + LOG10_LN10
			else
				local difference
				if delta > CLOSE_CANCEL then
					local x = -delta * LN10
					difference = x * (1 + x * (-0.5 + x * (0.16666666666666666 + x * (-0.041666666666666664 + x * 0.008333333333333333))))
				else
					difference = 1 - math.exp(delta * LN10)
				end
				if difference <= 0 then
					resultSign = 0
					resultLog = 0
				else
					resultLog = l2 + math.log10(difference)
				end
			end
		end
	end
	out[1] = resultSign
	out[2] = resultLog
	return out
end

--==============================================================
-- Convenience API
--==============================================================

--[[
Converts a number, string, or Bnum-like table into a canonical Bnum for the
PascalCase convenience API. Unsupported values become NaN instead of causing
the wrapper to index nil.
]]
local function convertAny(value: any): Value
	local converted = Bnum.convert(value)
	if converted == nil then
		return {0, 0 / 0}
	end
	return converted
end
--[[
Adds two supported values without requiring Bnum.convert at the call site.
Example: Bnum.Add(10, "25") -> 35
Hot path note: use Bnum.add when both inputs are already Bnums.
]]
function Bnum.Add(a: any, b: any): Value
	return Bnum.add(convertAny(a), convertAny(b))
end

--[[
Subtracts b from a after converting both inputs automatically.
Example: Bnum.Sub(100, "25") -> 75
]]
function Bnum.Sub(a: any, b: any): Value
	return Bnum.sub(convertAny(a), convertAny(b))
end

--[[
Subtracts b from a and clamps negative results to zero.
Example: Bnum.SubZ(5, 10) -> 0
]]
function Bnum.SubZ(a: any, b: any): Value
	local result = Bnum.sub(convertAny(a), convertAny(b))
	if result[1] < 0 then
		return Bnum.zero
	end
	return result
end

--[[
Multiplies two supported values after converting both inputs automatically.
Example: Bnum.Mul(12, "5") -> 60
]]
function Bnum.Mul(a: any, b: any): Value
	return Bnum.mul(convertAny(a), convertAny(b))
end

--[[
Divides a by b after converting both inputs automatically.
Example: Bnum.Div(100, "4") -> 25
]]
function Bnum.Div(a: any, b: any): Value
	return Bnum.div(convertAny(a), convertAny(b))
end

--[[
Adds a normal Luau number to any supported Bnum input.
Example: Bnum.AddNumber("1e6", 5) -> 1000005
]]
function Bnum.AddNumber(value: any, n: number): Value
	return Bnum.addNumber(convertAny(value), n)
end

--[[
Subtracts a normal Luau number from any supported Bnum input.
]]
function Bnum.SubNumber(value: any, n: number): Value
	return Bnum.subNumber(convertAny(value), n)
end

--[[
Multiplies any supported Bnum input by a normal Luau number.
]]
function Bnum.MulNumber(value: any, n: number): Value
	return Bnum.mulNumber(convertAny(value), n)
end

--[[
Divides any supported Bnum input by a normal Luau number.
]]
function Bnum.DivNumber(value: any, n: number): Value
	return Bnum.divNumber(convertAny(value), n)
end

--[[
Multiplies any supported input by 10^exponent.
Example: Bnum.Scale10(9.5, 3) -> 9500
]]
function Bnum.Scale10(value: any, exponent: number): Value
	return Bnum.scale10(convertAny(value), exponent)
end

--[[
Squares any supported input.
Example: Bnum.Square(12) -> 144
]]
function Bnum.Square(value: any): Value
	return Bnum.square(convertAny(value))
end

--[[
Cubes any supported input.
Example: Bnum.Cube(5) -> 125
]]
function Bnum.Cube(value: any): Value
	return Bnum.cube(convertAny(value))
end

--[[
Computes a × b + c after converting all three inputs automatically.
Example: Bnum.MulAdd(2, 3, 4) -> 10
]]
function Bnum.MulAdd(a: any, b: any, c: any): Value
	return Bnum.mulAdd(convertAny(a), convertAny(b), convertAny(c))
end

--[[
Computes a + b × c after converting all three inputs automatically.
Example: Bnum.AddMul(2, 3, 4) -> 14
]]
function Bnum.AddMul(a: any, b: any, c: any): Value
	return Bnum.addMul(convertAny(a), convertAny(b), convertAny(c))
end

--[[
Returns 1 / value after converting the input automatically.
Example: Bnum.Reciprocal(4) -> 0.25
]]
function Bnum.Reciprocal(value: any): Value
	return Bnum.reciprocal(convertAny(value))
end

--[[
Raises any supported input to a normal numeric power.
Example: Bnum.Pow(10, 3) -> 1000
]]
function Bnum.Pow(value: any, power: number): Value
	return Bnum.pow(convertAny(value), power)
end

--[[
Returns the square root of any supported input.
Example: Bnum.Sqrt(144) -> 12
]]
function Bnum.Sqrt(value: any): Value
	return Bnum.sqrt(convertAny(value))
end

--[[
Returns the real cube root of any supported input.
Example: Bnum.Cbrt(-125) -> -5
]]
function Bnum.Cbrt(value: any): Value
	return Bnum.cbrt(convertAny(value))
end

--[[
Returns the real nth root of any supported input.
Example: Bnum.Root(32, 5) -> 2
]]
function Bnum.Root(value: any, degree: number): Value
	return Bnum.root(convertAny(value), degree)
end

--[[
Returns the absolute value of any supported input.
Example: Bnum.Abs("-25") -> 25
]]
function Bnum.Abs(value: any): Value
	return Bnum.abs(convertAny(value))
end

--[[
Negates any supported input.
Example: Bnum.Neg(25) -> -25
]]
function Bnum.Neg(value: any): Value
	return Bnum.neg(convertAny(value))
end

--[[
Returns log10(value) after converting the input automatically.
]]
function Bnum.Log10(value: any): Value
	return Bnum.log10(convertAny(value))
end

--[[
Returns the natural logarithm of any supported input.
]]
function Bnum.Ln(value: any): Value
	return Bnum.ln(convertAny(value))
end

--[[
Returns log2(value) after converting the input automatically.
]]
function Bnum.Log2(value: any): Value
	return Bnum.log2(convertAny(value))
end

--[[
Returns log_base(value) after converting both value and base automatically.
Example: Bnum.Log(1000, 10) -> 3
]]
function Bnum.Log(value: any, base: any): Value
	return Bnum.log(convertAny(value), convertAny(base))
end

--[[
Returns e^value after converting the input automatically.
]]
function Bnum.Exp(value: any): Value
	return Bnum.exp(convertAny(value))
end

--[[
Returns 10^value where value can be any supported Bnum input.
]]
function Bnum.Exp10(value: any): Value
	return Bnum.exp10(convertAny(value))
end

--[[
Returns 2^value where value can be any supported Bnum input.
]]
function Bnum.Exp2(value: any): Value
	return Bnum.exp2(convertAny(value))
end

--[[
Raises value to a power that can also be a Bnum/string/number input.
Example: Bnum.PowValue(2, "10") -> 1024
]]
function Bnum.PowValue(value: any, power: any): Value
	return Bnum.powValue(convertAny(value), convertAny(power))
end

--[[
Computes ln(1 + value) after converting the input automatically.
]]
function Bnum.Log1p(value: any): Value
	return Bnum.log1p(convertAny(value))
end

--[[
Computes e^value - 1 after converting the input automatically.
]]
function Bnum.Expm1(value: any): Value
	return Bnum.expm1(convertAny(value))
end

--[[
Computes sqrt(a^2 + b^2) after converting both inputs automatically.
Example: Bnum.Hypot(3, 4) -> 5
]]
function Bnum.Hypot(a: any, b: any): Value
	return Bnum.hypot(convertAny(a), convertAny(b))
end

--[[
Computes factorial(value) after converting the input automatically.
Example: Bnum.Factorial(5) -> 120
]]
function Bnum.Factorial(value: any): Value
	return Bnum.factorial(convertAny(value))
end

--[[
Compares two supported values and returns -1, 0, or 1 when comparable.
]]
function Bnum.Compare(a: any, b: any): number?
	return Bnum.compare(convertAny(a), convertAny(b))
end

--[[
Checks exact Bnum equality after converting both inputs automatically.
Example: Bnum.Eq(1000, "1e3") -> true
]]
function Bnum.Eq(a: any, b: any): boolean
	return Bnum.eq(convertAny(a), convertAny(b))
end

--[[
Checks whether two converted values are different.
]]
function Bnum.Neq(a: any, b: any): boolean
	return Bnum.neq(convertAny(a), convertAny(b))
end

--[[
Checks whether a < b after converting both inputs automatically.
]]
function Bnum.Lt(a: any, b: any): boolean
	return Bnum.lt(convertAny(a), convertAny(b))
end

--[[
Checks whether a <= b after converting both inputs automatically.
]]
function Bnum.Lte(a: any, b: any): boolean
	return Bnum.lte(convertAny(a), convertAny(b))
end

--[[
Checks whether a > b after converting both inputs automatically.
]]
function Bnum.Gt(a: any, b: any): boolean
	return Bnum.gt(convertAny(a), convertAny(b))
end

--[[
Checks whether a >= b after converting both inputs automatically.
]]
function Bnum.Gte(a: any, b: any): boolean
	return Bnum.gte(convertAny(a), convertAny(b))
end

--[[
Returns the smallest converted input.
Supports the same vararg shape as Bnum.min.
Example: Bnum.Min(10, "2", 5) -> 2
]]
function Bnum.Min(a: any, b: any?, ...: any): Value
	local first = convertAny(a)
	if b == nil then
		return Bnum.min(first)
	end
	local rest = {...}
	for i = 1, #rest do
		rest[i] = convertAny(rest[i])
	end
	return Bnum.min(first, convertAny(b), table.unpack(rest))
end

--[[
Returns the largest converted input.
Supports the same vararg shape as Bnum.max.
Example: Bnum.Max(10, "2", 5) -> 10
]]
function Bnum.Max(a: any, b: any?, ...: any): Value
	local first = convertAny(a)
	if b == nil then
		return Bnum.max(first)
	end
	local rest = {...}
	for i = 1, #rest do
		rest[i] = convertAny(rest[i])
	end
	return Bnum.max(first, convertAny(b), table.unpack(rest))
end

--[[
Clamps value between minimum and maximum after converting all inputs automatically.
]]
function Bnum.Clamp(value: any, minimum: any, maximum: any): Value
	return Bnum.clamp(convertAny(value), convertAny(minimum), convertAny(maximum))
end

--[[
Rounds any supported input down toward negative infinity.
]]
function Bnum.Floor(value: any): Value
	return Bnum.floor(convertAny(value))
end

--[[
Rounds any supported input up toward positive infinity.
]]
function Bnum.Ceil(value: any): Value
	return Bnum.ceil(convertAny(value))
end

--[[
Rounds any supported input to the requested decimal precision.
]]
function Bnum.Round(value: any, digits: number?): Value
	return Bnum.round(convertAny(value), digits)
end

--[[
Returns a modulo b after converting both inputs automatically.
]]
function Bnum.Mod(a: any, b: any): Value
	return Bnum.mod(convertAny(a), convertAny(b))
end

--[[
Truncates the fractional part of any supported input.
]]
function Bnum.Trunc(value: any): Value
	return Bnum.trunc(convertAny(value))
end

--[[
Returns only the signed fractional part of any supported input.
]]
function Bnum.Fract(value: any): Value
	return Bnum.fract(convertAny(value))
end

--[[
Checks whether any supported input represents an integer.
]]
function Bnum.IsInteger(value: any): boolean
	return Bnum.isInteger(convertAny(value))
end

--[[
Checks whether value lies inclusively between minimum and maximum.
]]
function Bnum.Between(value: any, minimum: any, maximum: any): boolean
	return Bnum.between(convertAny(value), convertAny(minimum), convertAny(maximum))
end

--[[
Returns the absolute distance between two converted values.
]]
function Bnum.Distance(a: any, b: any): Value
	return Bnum.distance(convertAny(a), convertAny(b))
end

--[[
Returns the relative difference between two converted values.
]]
function Bnum.RelativeDifference(a: any, b: any): Value
	return Bnum.relativeDifference(convertAny(a), convertAny(b))
end

--[[
Checks approximate equality after converting both values automatically.
]]
function Bnum.ApproxEq(a: any, b: any, relTolerance: number?, absTolerance: number?): boolean
	return Bnum.approxEq(convertAny(a), convertAny(b), relTolerance, absTolerance)
end

--[[
Linearly interpolates between two converted values.
Example: Bnum.Lerp(0, 10, 0.5) -> 5
]]
function Bnum.Lerp(a: any, b: any, alpha: number): Value
	return Bnum.lerp(convertAny(a), convertAny(b), alpha)
end

--[[
Returns the interpolation alpha of value between a and b.
]]
function Bnum.InverseLerp(a: any, b: any, value: any): Value
	return Bnum.inverseLerp(convertAny(a), convertAny(b), convertAny(value))
end

--[[
Remaps value from one converted input range into another.
]]
function Bnum.Remap(value: any, inMin: any, inMax: any, outMin: any, outMax: any): Value
	return Bnum.remap(convertAny(value), convertAny(inMin), convertAny(inMax), convertAny(outMin), convertAny(outMax))
end

--[[
Adds every item in an array after converting each item automatically.
Example: Bnum.Sum({1, "2", 3}) -> 6
]]
function Bnum.Sum(values: {any}): Value
	local converted = table.create(#values)
	for i = 1, #values do
		converted[i] = convertAny(values[i])
	end
	return Bnum.sum(converted)
end

--[[
Multiplies every item in an array after converting each item automatically.
Example: Bnum.Product({2, "3", 4}) -> 24
]]
function Bnum.Product(values: {any}): Value
	local converted = table.create(#values)
	for i = 1, #values do
		converted[i] = convertAny(values[i])
	end
	return Bnum.product(converted)
end

--[[
Returns the arithmetic mean after converting every array item automatically.
Example: Bnum.Mean({2, "4", 6}) -> 4
]]
function Bnum.Mean(values: {any}): Value
	local converted = table.create(#values)
	for i = 1, #values do
		converted[i] = convertAny(values[i])
	end
	return Bnum.mean(converted)
end

--[[
Returns part / whole × 100 after converting both values automatically.
]]
function Bnum.Percent(part: any, whole: any): Value
	return Bnum.percent(convertAny(part), convertAny(whole))
end

--[[
Returns percentage change from oldValue to newValue after automatic conversion.
]]
function Bnum.PercentChange(oldValue: any, newValue: any): Value
	return Bnum.percentChange(convertAny(oldValue), convertAny(newValue))
end
--[[
Formats any supported input using the selected format mode.
Example: Bnum.Format("1250000", 2, "standard") -> formatted text
]]
function Bnum.Format(value: any, decimalPlaces: number?, formatType: FormatType?): string
	return Bnum.format(convertAny(value), decimalPlaces, formatType)
end

--[[
Formats any supported input using standard notation.
]]
function Bnum.FormatStandard(value: any, decimalPlaces: number?): string
	return Bnum.formatStandard(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using extended notation.
]]
function Bnum.FormatExtended(value: any, decimalPlaces: number?): string
	return Bnum.formatExtended(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using hybrid notation.
]]
function Bnum.FormatHybrid(value: any, decimalPlaces: number?): string
	return Bnum.formatHybrid(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using alphabetic notation.
]]
function Bnum.FormatAlphabetic(value: any, decimalPlaces: number?): string
	return Bnum.formatAlphabetic(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using metric notation.
]]
function Bnum.FormatMetric(value: any, decimalPlaces: number?): string
	return Bnum.formatMetric(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using exponent notation.
]]
function Bnum.FormatExponent(value: any, decimalPlaces: number?): string
	return Bnum.formatExponent(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using scientific notation.
]]
function Bnum.FormatScientific(value: any, decimalPlaces: number?): string
	return Bnum.formatScientific(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using engineering notation.
]]
function Bnum.FormatEngineering(value: any, decimalPlaces: number?): string
	return Bnum.formatEngineering(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using Roman numeral notation.
]]
function Bnum.FormatRoman(value: any, decimalPlaces: number?): string
	return Bnum.formatRoman(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using extended Roman numeral notation.
]]
function Bnum.FormatRomanExtended(value: any, decimalPlaces: number?): string
	return Bnum.formatRomanExtended(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using the short suffix notation.
]]
function Bnum.FormatSuffix(value: any, decimalPlaces: number?): string
	return Bnum.formatSuffix(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using long suffix names.
]]
function Bnum.FormatSuffixLong(value: any, decimalPlaces: number?): string
	return Bnum.formatSuffixLong(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input as a plain decimal string when practical.
]]
function Bnum.FormatPlain(value: any, decimalPlaces: number?): string
	return Bnum.formatPlain(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input with comma grouping.
]]
function Bnum.FormatComma(value: any, decimalPlaces: number?): string
	return Bnum.formatComma(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input using logarithmic notation.
]]
function Bnum.FormatLogarithm(value: any, decimalPlaces: number?): string
	return Bnum.formatLogarithm(convertAny(value), decimalPlaces)
end

--[[
Formats any supported input as its raw Bnum representation.
]]
function Bnum.FormatRaw(value: any): string
	return Bnum.formatRaw(convertAny(value))
end

--[[
Automatically selects a suitable notation for any supported input.
]]
function Bnum.AutoFormat(value: any, digits: number?, options: AutoFormatOptions?): string
	return Bnum.autoFormat(convertAny(value), digits, options)
end

return Bnum
