--!native
--!optimize 2

local Bnum = {}

Bnum.Version = "0.5.5"

export type Value = {number}
export type FormatType = "Auto" | "Suffix" | "SuffixLong" | "Scientific" | "Engineering" | "Standard" | "Comma" | "Logarithm" | "Raw"

local LN10 = 2.302585092994046
local LOG10_2 = 0.3010299956639812
local LOG10_LN10 = 0.36221568869946325
local LOG10_INV_LOG10_2 = 0.5213902276543247
local LOG10_LOG10_E = -0.36221568869946325
local MAX_LOG10_DOUBLE = 308.25471555991675
local ADD_CUTOFF = -16
local CLOSE_CANCEL = -1e-4

Bnum.zero = table.freeze({0, 0})
Bnum.one = table.freeze({1, 0})
Bnum.ten = table.freeze({1, 1})
Bnum.inf = table.freeze({1, math.huge})
Bnum.ninf = table.freeze({-1, math.huge})
Bnum.nan = table.freeze({0, 0 / 0})

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

function Bnum.raw(sign: number, logMagnitude: number): Value
	if logMagnitude ~= logMagnitude then
		return {0, logMagnitude}
	end

	if sign == 0 or logMagnitude == -math.huge then
		return {0, 0}
	end

	return {if sign < 0 then -1 else 1, logMagnitude}
end

function Bnum.clone(val: Value): Value
	return {val[1], val[2]}
end

function Bnum.read(val: Value): (number, number)
	return val[1], val[2]
end

function Bnum.fromNumber(n: number): Value
	if n == 0 then
		return {0, 0}
	end

	if n ~= n then
		return {0, n}
	end

	if n < 0 then
		return {-1, math.log10(-n)}
	end

	return {1, math.log10(n)}
end

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

function Bnum.fromLog10(logMagnitude: number, sign: number?): Value
	if logMagnitude ~= logMagnitude then
		return {0, logMagnitude}
	end

	if logMagnitude == -math.huge then
		return {0, 0}
	end

	local s = sign or 1

	if s == 0 then
		return {0, 0}
	end

	return {if s < 0 then -1 else 1, logMagnitude}
end

function Bnum.pow10(exp: number): Value
	if exp ~= exp then
		return {0, exp}
	end

	if exp == -math.huge then
		return {0, 0}
	end

	return {1, exp}
end

function Bnum.fromString(str: string): Value
	local length = #str

	if length == 0 then
		return {0, 0 / 0}
	end

	local i = 1
	local c = string.byte(str, 1)

	while c == 32 or c == 9 or c == 10 or c == 13 do
		i += 1

		if i > length then
			return {0, 0 / 0}
		end

		c = string.byte(str, i)
	end

	local sign = 1

	if c == 45 then
		sign = -1
		i += 1

		if i > length then
			return {0, 0 / 0}
		end

		c = string.byte(str, i)
	elseif c == 43 then
		i += 1

		if i > length then
			return {0, 0 / 0}
		end

		c = string.byte(str, i)
	end

	local significant = 0
	local significantDigits = 0
	local scale = 0

	if c >= 48 and c <= 57 then
		while c == 48 do
			i += 1

			if i > length then
				return {0, 0}
			end

			c = string.byte(str, i)
		end

		if c >= 49 and c <= 57 then
			significant = c - 48
			significantDigits = 1
			i += 1
			while i <= length do
				c = string.byte(str, i)

				if c < 48 or c > 57 then
					break
				end

				scale += 1

				if significantDigits < 17 then
					significant = significant * 10 + (c - 48)
					significantDigits += 1
				end

				i += 1
			end
		end

		if i <= length and c == 46 then
			i += 1

			if significantDigits == 0 then
				while i <= length do
					c = string.byte(str, i)

					if c ~= 48 then
						break
					end

					scale -= 1
					i += 1
				end

				if i <= length and c >= 49 and c <= 57 then
					scale -= 1
					significant = c - 48
					significantDigits = 1
					i += 1
				end
			end
			if significantDigits ~= 0 then
				while i <= length do
					c = string.byte(str, i)

					if c < 48 or c > 57 then
						break
					end

					if significantDigits < 17 then
						significant = significant * 10 + (c - 48)
						significantDigits += 1
					end

					i += 1
				end
			end
		end
	elseif c == 46 then
		i += 1

		if i > length then
			return {0, 0 / 0}
		end

		c = string.byte(str, i)

		if c < 48 or c > 57 then
			return {0, 0 / 0}
		end

		while c == 48 do
			scale -= 1
			i += 1

			if i > length then
				return {0, 0}
			end

			c = string.byte(str, i)
		end

		if c >= 49 and c <= 57 then
			scale -= 1
			significant = c - 48
			significantDigits = 1
			i += 1

			while i <= length do
				c = string.byte(str, i)

				if c < 48 or c > 57 then
					break
				end

				if significantDigits < 17 then
					significant = significant * 10 + (c - 48)
					significantDigits += 1
				end

				i += 1
			end
		end
	else
		if c == 110 or c == 78 then
			if
				i + 2 <= length
				and (string.byte(str, i + 1) == 97 or string.byte(str, i + 1) == 65)
				and (string.byte(str, i + 2) == 110 or string.byte(str, i + 2) == 78)
			then
				i += 3

				while i <= length do
					c = string.byte(str, i)

					if c ~= 32 and c ~= 9 and c ~= 10 and c ~= 13 then
						return {0, 0 / 0}
					end

					i += 1
				end

				return {0, 0 / 0}
			end

			return {0, 0 / 0}
		end

		if c == 105 or c == 73 then
			if
				i + 2 <= length
				and (string.byte(str, i + 1) == 110 or string.byte(str, i + 1) == 78)
				and (string.byte(str, i + 2) == 102 or string.byte(str, i + 2) == 70)
			then
				i += 3

				if i + 4 <= length then
					local c1 = string.byte(str, i)
					local c2 = string.byte(str, i + 1)
					local c3 = string.byte(str, i + 2)
					local c4 = string.byte(str, i + 3)
					local c5 = string.byte(str, i + 4)

					if
						(c1 == 105 or c1 == 73)
						and (c2 == 110 or c2 == 78)
						and (c3 == 105 or c3 == 73)
						and (c4 == 116 or c4 == 84)
						and (c5 == 121 or c5 == 89)
					then
						i += 5
					end
				end

				while i <= length do
					c = string.byte(str, i)

					if c ~= 32 and c ~= 9 and c ~= 10 and c ~= 13 then
						return {0, 0 / 0}
					end

					i += 1
				end

				return {sign, math.huge}
			end
		end

		return {0, 0 / 0}
	end

	local explicitExponent = 0

	if i <= length then
		c = string.byte(str, i)

		if c == 69 or c == 101 then
			i += 1

			if i > length then
				return {0, 0 / 0}
			end

			c = string.byte(str, i)

			local exponentSign = 1

			if c == 45 then
				exponentSign = -1
				i += 1

				if i > length then
					return {0, 0 / 0}
				end

				c = string.byte(str, i)
			elseif c == 43 then
				i += 1

				if i > length then
					return {0, 0 / 0}
				end

				c = string.byte(str, i)
			end

			if c < 48 or c > 57 then
				return {0, 0 / 0}
			end

			explicitExponent = c - 48
			i += 1

			while i <= length do
				c = string.byte(str, i)

				if c < 48 or c > 57 then
					break
				end

				explicitExponent = explicitExponent * 10 + (c - 48)
				i += 1
			end

			if exponentSign < 0 then
				explicitExponent = -explicitExponent
			end
		end
	end

	while i <= length do
		c = string.byte(str, i)

		if c ~= 32 and c ~= 9 and c ~= 10 and c ~= 13 then
			return {0, 0 / 0}
		end

		i += 1
	end

	if significantDigits == 0 then
		return {0, 0}
	end

	local logMagnitude = explicitExponent + (scale + (math.log10(significant) - (significantDigits - 1)))

	if logMagnitude == -math.huge then
		return {0, 0}
	end

	return {sign, logMagnitude}
end

function Bnum.toNumber(val: Value): number
	return val[1] * (10 ^ val[2])
end

function Bnum.toScientific(val: Value): (number, number)
	local sign = val[1]
	local logMagnitude = val[2]

	if sign == 0 then
		if logMagnitude ~= logMagnitude then
			return logMagnitude, 0
		end

		return 0, 0
	end

	if logMagnitude == math.huge then
		return sign * math.huge, 0
	end

	local exp = math.floor(logMagnitude)
	return sign * (10 ^ (logMagnitude - exp)), exp
end

function Bnum.mantissa(val: Value): number
	local sign = val[1]
	local logMagnitude = val[2]

	if sign == 0 then
		if logMagnitude ~= logMagnitude then
			return logMagnitude
		end

		return 0
	end

	if logMagnitude == math.huge then
		return sign * math.huge
	end

	return sign * (10 ^ (logMagnitude - math.floor(logMagnitude)))
end

function Bnum.exponent(val: Value): number
	local sign = val[1]
	local logMagnitude = val[2]

	if sign == 0 then
		if logMagnitude ~= logMagnitude then
			return logMagnitude
		end

		return 0
	end

	return math.floor(logMagnitude)
end

function Bnum.convert(val: any)
	if typeof(val) == 'string' then
		return Bnum.fromString(val)
	elseif typeof(val) == 'number' then
		return Bnum.fromNumber(val)
	end
end

function Bnum.toString(val: Value): string
	local sign = val[1]
	local logMagnitude = val[2]

	if sign == 0 then
		if logMagnitude ~= logMagnitude then
			return "nan"
		end

		return "0"
	end

	if logMagnitude == math.huge then
		return if sign < 0 then "-inf" else "inf"
	end

	local exp = math.floor(logMagnitude)
	return sign * (10 ^ (logMagnitude - exp)) .. "e" .. exp
end

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

function Bnum.reciprocal(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if sign ~= 0 then
		if logMagnitude == math.huge then
			return {0, 0}
		end

		if logMagnitude ~= logMagnitude then
			return {0, logMagnitude}
		end

		return {sign, -logMagnitude}
	end

	if logMagnitude ~= logMagnitude then
		return {0, logMagnitude}
	end

	return {1, math.huge}
end

function Bnum.pow(val: Value, power: number): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if power ~= power or logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end

	if sign > 0 then
		if power == 0 then
			return {1, 0}
		end

		if power ~= math.huge and power ~= -math.huge then
			local resultLog = logMagnitude * power

			if resultLog == -math.huge then
				return {0, 0}
			end

			return {1, resultLog}
		end

		if logMagnitude == 0 then
			return {1, 0}
		end

		if (power > 0) == (logMagnitude > 0) then
			return {1, math.huge}
		end

		return {0, 0}
	end

	if power == 0 then
		return {1, 0}
	end

	if sign == 0 then
		if power > 0 then
			return {0, 0}
		end

		return {1, math.huge}
	end

	if power == math.huge or power == -math.huge or power % 1 ~= 0 then
		return {0, 0 / 0}
	end

	local resultLog = logMagnitude * power

	if resultLog == -math.huge then
		return {0, 0}
	end

	return {if power % 2 == 0 then 1 else -1, resultLog}
end

function Bnum.sqrt(val: Value): Value
	local sign = val[1]

	if sign < 0 then
		return {0, 0 / 0}
	end

	return {sign, val[2] * 0.5}
end

function Bnum.cbrt(val: Value): Value
	return {val[1], val[2] / 3}
end

function Bnum.root(val: Value, degree: number): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if sign > 0 and degree ~= 0 and degree == degree and logMagnitude == logMagnitude then
		local resultLog = logMagnitude / degree

		if resultLog ~= resultLog then
			return {0, 0 / 0}
		end

		if resultLog == -math.huge then
			return {0, 0}
		end

		return {1, resultLog}
	end

	if degree ~= degree or degree == 0 or logMagnitude ~= logMagnitude then
		return {0, 0 / 0}
	end

	if sign == 0 then
		if degree > 0 then
			return {0, 0}
		end

		return {1, math.huge}
	end

	if degree == math.huge or degree == -math.huge or degree % 1 ~= 0 or degree % 2 == 0 then
		return {0, 0 / 0}
	end

	local resultLog = logMagnitude / degree

	if resultLog == -math.huge then
		return {0, 0}
	end

	return {-1, resultLog}
end

function Bnum.abs(val: Value): Value
	local sign = val[1]
	return {if sign < 0 then 1 else sign, val[2]}
end

function Bnum.neg(val: Value): Value
	return {-val[1], val[2]}
end

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

function Bnum.log(val: Value, base: Value): Value
	local sign = val[1]
	local baseSign = base[1]
	local logMagnitude = val[2]
	local baseLogMagnitude = base[2]

	if sign > 0 and baseSign > 0 and baseLogMagnitude ~= 0 and baseLogMagnitude ~= math.huge then
		local result = logMagnitude / baseLogMagnitude

		if result > 0 then
			if result == math.huge and logMagnitude ~= math.huge then
				return {if (logMagnitude < 0) == (baseLogMagnitude < 0) then 1 else -1, math.log10(math.abs(logMagnitude)) - math.log10(math.abs(baseLogMagnitude))}
			end

			return {1, math.log10(result)}
		end

		if result < 0 then
			if result == -math.huge and logMagnitude ~= math.huge then
				return {if (logMagnitude < 0) == (baseLogMagnitude < 0) then 1 else -1, math.log10(math.abs(logMagnitude)) - math.log10(math.abs(baseLogMagnitude))}
			end

			return {-1, math.log10(-result)}
		end

		if result == 0 then
			if logMagnitude ~= 0 then
				return {if (logMagnitude < 0) == (baseLogMagnitude < 0) then 1 else -1, math.log10(math.abs(logMagnitude)) - math.log10(math.abs(baseLogMagnitude))}
			end

			return {0, 0}
		end

		return {0, 0 / 0}
	end

	if logMagnitude ~= logMagnitude or baseLogMagnitude ~= baseLogMagnitude then
		return {0, 0 / 0}
	end

	if sign < 0 or baseSign <= 0 or baseLogMagnitude == 0 or baseLogMagnitude == math.huge then
		return {0, 0 / 0}
	end

	if sign == 0 then
		return {if baseLogMagnitude > 0 then -1 else 1, math.huge}
	end

	if logMagnitude == math.huge then
		return {if baseLogMagnitude > 0 then 1 else -1, math.huge}
	end

	local result = logMagnitude / baseLogMagnitude

	if result == 0 then
		return {0, 0}
	end

	if result < 0 then
		return {-1, math.log10(-result)}
	end

	return {1, math.log10(result)}
end

function Bnum.exp(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return {0, logMagnitude}
	end

	if sign == 0 then
		return {1, 0}
	end

	if logMagnitude == math.huge then
		if sign < 0 then
			return {0, 0}
		end

		return {1, math.huge}
	end

	local resultLogPower = logMagnitude + LOG10_LOG10_E

	if resultLogPower > MAX_LOG10_DOUBLE then
		if sign < 0 then
			return {0, 0}
		end

		return {1, math.huge}
	end

	local resultLog = 10 ^ resultLogPower

	if resultLog == math.huge then
		return {if sign < 0 then 0 else 1, if sign < 0 then 0 else math.huge}
	end

	if sign < 0 then
		resultLog = -resultLog
	end

	return {1, resultLog}
end

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

function Bnum.eq(val1: Value, val2: Value): boolean
	return val1[1] == val2[1] and val1[2] == val2[2]
end

function Bnum.neq(val1: Value, val2: Value): boolean
	return val1[1] ~= val2[1] or val1[2] ~= val2[2]
end

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

Bnum.equal = Bnum.eq
Bnum.notEqual = Bnum.neq
Bnum.lessThan = Bnum.lt
Bnum.lessThanOrEqual = Bnum.lte
Bnum.greaterThan = Bnum.gt
Bnum.greaterThanOrEqual = Bnum.gte

function Bnum.min(val1: Value, val2: Value?, ...: Value): Value
	local bestSign = val1[1]
	local bestLog = val1[2]

	if val2 == nil then
		return {bestSign, bestLog}
	end

	local sign = val2[1]
	local logMagnitude = val2[2]

	if bestLog ~= bestLog then
		bestSign = sign
		bestLog = logMagnitude
	elseif logMagnitude == logMagnitude then
		if sign < bestSign then
			bestSign = sign
			bestLog = logMagnitude
		elseif sign == bestSign then
			if (sign > 0 and logMagnitude < bestLog) or (sign < 0 and logMagnitude > bestLog) then
				bestLog = logMagnitude
			end
		end
	end

	local count = select("#", ...)

	if count == 0 then
		return {bestSign, bestLog}
	end

	for i = 1, count do
		local current: Value = select(i, ...)
		sign = current[1]
		logMagnitude = current[2]

		if bestLog ~= bestLog then
			bestSign = sign
			bestLog = logMagnitude
		elseif logMagnitude == logMagnitude then
			if sign < bestSign then
				bestSign = sign
				bestLog = logMagnitude
			elseif sign == bestSign then
				if (sign > 0 and logMagnitude < bestLog) or (sign < 0 and logMagnitude > bestLog) then
					bestLog = logMagnitude
				end
			end
		end
	end

	return {bestSign, bestLog}
end

function Bnum.max(val1: Value, val2: Value?, ...: Value): Value
	local bestSign = val1[1]
	local bestLog = val1[2]

	if val2 == nil then
		return {bestSign, bestLog}
	end

	local sign = val2[1]
	local logMagnitude = val2[2]

	if bestLog ~= bestLog then
		bestSign = sign
		bestLog = logMagnitude
	elseif logMagnitude == logMagnitude then
		if sign > bestSign then
			bestSign = sign
			bestLog = logMagnitude
		elseif sign == bestSign then
			if (sign > 0 and logMagnitude > bestLog) or (sign < 0 and logMagnitude < bestLog) then
				bestLog = logMagnitude
			end
		end
	end

	local count = select("#", ...)

	if count == 0 then
		return {bestSign, bestLog}
	end

	for i = 1, count do
		local current: Value = select(i, ...)
		sign = current[1]
		logMagnitude = current[2]

		if bestLog ~= bestLog then
			bestSign = sign
			bestLog = logMagnitude
		elseif logMagnitude == logMagnitude then
			if sign > bestSign then
				bestSign = sign
				bestLog = logMagnitude
			elseif sign == bestSign then
				if (sign > 0 and logMagnitude > bestLog) or (sign < 0 and logMagnitude < bestLog) then
					bestLog = logMagnitude
				end
			end
		end
	end

	return {bestSign, bestLog}
end

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

	if s < minS then
		return {minS, minL}
	end

	if s > maxS then
		return {maxS, maxL}
	end

	if s == minS and s ~= 0 then
		if (s > 0 and l < minL) or (s < 0 and l > minL) then
			return {minS, minL}
		end
	end

	if s == maxS and s ~= 0 then
		if (s > 0 and l > maxL) or (s < 0 and l < maxL) then
			return {maxS, maxL}
		end
	end

	return {s, l}
end

function Bnum.floor(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if sign == 0 then
		return {0, logMagnitude}
	end

	if logMagnitude == math.huge or logMagnitude >= 15 then
		return {sign, logMagnitude}
	end

	if logMagnitude < 0 then
		if sign > 0 then
			return {0, 0}
		end

		return {-1, 0}
	end

	local magnitude = 10 ^ logMagnitude

	if sign > 0 then
		magnitude = math.floor(magnitude)
		return {1, math.log10(magnitude)}
	end

	magnitude = math.ceil(magnitude)
	return {-1, math.log10(magnitude)}
end

function Bnum.ceil(val: Value): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if sign == 0 then
		return {0, logMagnitude}
	end

	if logMagnitude == math.huge or logMagnitude >= 15 then
		return {sign, logMagnitude}
	end

	if logMagnitude < 0 then
		if sign > 0 then
			return {1, 0}
		end

		return {0, 0}
	end

	local magnitude = 10 ^ logMagnitude

	if sign > 0 then
		magnitude = math.ceil(magnitude)
		return {1, math.log10(magnitude)}
	end

	magnitude = math.floor(magnitude)
	return {-1, math.log10(magnitude)}
end

function Bnum.round(val: Value, digits: number?): Value
	local sign = val[1]
	local logMagnitude = val[2]
	local places = digits or 0

	if sign == 0 then
		return {0, logMagnitude}
	end

	if logMagnitude ~= logMagnitude or places ~= places then
		return {0, 0 / 0}
	end

	if logMagnitude == math.huge then
		return {sign, logMagnitude}
	end

	if logMagnitude + places >= 15 then
		return {sign, logMagnitude}
	end

	if logMagnitude < -places - LOG10_2 then
		return {0, 0}
	end

	local rounded = math.round(sign * (10 ^ (logMagnitude + places)))

	if rounded == 0 then
		return {0, 0}
	end

	if rounded < 0 then
		return {-1, math.log10(-rounded) - places}
	end

	return {1, math.log10(rounded) - places}
end

function Bnum.mod(val1: Value, val2: Value): Value
	local s1 = val1[1]
	local l1 = val1[2]
	local s2 = val2[1]
	local l2 = val2[2]

	if l1 ~= l1 or l2 ~= l2 or s2 == 0 then
		return {0, 0 / 0}
	end

	if s1 == 0 then
		return {0, 0}
	end

	if l1 > 15 or l2 > 15 or l1 < -308 or l2 < -308 then
		return {0, 0 / 0}
	end

	local result = s1 * (10 ^ l1) % (s2 * (10 ^ l2))

	if result == 0 then
		return {0, 0}
	end

	if result < 0 then
		return {-1, math.log10(-result)}
	end

	return {1, math.log10(result)}
end

function Bnum.isZero(val: Value): boolean
	return val[1] == 0 and val[2] == val[2]
end

function Bnum.isNaN(val: Value): boolean
	return val[2] ~= val[2]
end

function Bnum.isInfinite(val: Value): boolean
	return val[1] ~= 0 and val[2] == math.huge
end

function Bnum.isFinite(val: Value): boolean
	local logMagnitude = val[2]
	return logMagnitude == logMagnitude and logMagnitude ~= math.huge
end

function Bnum.isPositive(val: Value): boolean
	return val[1] > 0
end

function Bnum.isNegative(val: Value): boolean
	return val[1] < 0
end

function Bnum.sign(val: Value): number
	return val[1]
end

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
})

local roundFactors = table.freeze({
	1,
	10,
	100,
	1000,
	10000,
	100000,
	1000000,
	10000000,
	100000000,
	1000000000,
	10000000000,
	100000000000,
	1000000000000,
	10000000000000,
	100000000000000,
	1000000000000000,
})

local fixedFormats = table.freeze({
	"%.0f",
	"%.1f",
	"%.2f",
	"%.3f",
	"%.4f",
	"%.5f",
	"%.6f",
	"%.7f",
	"%.8f",
	"%.9f",
	"%.10f",
	"%.11f",
	"%.12f",
	"%.13f",
	"%.14f",
	"%.15f",
})

local suffixBase = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
}

local suffixUnits = {"", "U", "D", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"}
local suffixTens = {"", "Dc", "Vg", "Tg", "Qag", "Qig", "Sxg", "Spg", "Ocg", "Nog"}
local suffixHundreds = {"", "Ce", "Dce", "Tce", "Qace", "Qice", "Sxce", "Spce", "Occe", "Noce"}

local suffixes = table.create(1000)

for tier = 0, 999 do
	if tier < #suffixBase then
		suffixes[tier + 1] = suffixBase[tier + 1]
	else
		local ones = tier % 10
		local tens = math.floor(tier / 10) % 10
		local hundreds = math.floor(tier / 100) % 10
		suffixes[tier + 1] = suffixUnits[ones + 1] .. suffixTens[tens + 1] .. suffixHundreds[hundreds + 1]
	end
end

local longSuffixes = {
	"", "Thousand", "Million", "Billion", "Trillion", "Quadrillion", "Quintillion",
	"Sextillion", "Septillion", "Octillion", "Nonillion", "Decillion",
	"Undecillion", "Duodecillion", "Tredecillion", "Quattuordecillion",
	"Quindecillion", "Sexdecillion", "Septendecillion", "Octodecillion",
	"Novemdecillion", "Vigintillion",
}

function Bnum.formatScientific(val: Value, digits: number?): string
	local places = 2

	if digits ~= nil then
		places = if digits ~= digits then 2 else math.floor(digits)
	end
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return "nan"
	end

	if sign == 0 then
		return "0"
	end

	if logMagnitude == math.huge then
		return if sign < 0 then "-inf" else "inf"
	end

	local exp = math.floor(logMagnitude)
	local man = sign * (10 ^ (logMagnitude - exp))

	if places > 15 then
		places = 15
	elseif places < 0 then
		places = 0
	end

	local factor = roundFactors[places + 1]
	man = math.round(man * factor) / factor

	if man >= 10 then
		man *= 0.1
		exp += 1
	elseif man <= -10 then
		man *= 0.1
		exp += 1
	end

	return tostring(man) .. "e" .. tostring(exp)
end

function Bnum.formatEngineering(val: Value, digits: number?): string
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return "nan"
	end

	if sign == 0 then
		return "0"
	end

	if logMagnitude == math.huge then
		return if sign < 0 then "-inf" else "inf"
	end

	local places = 2

	if digits ~= nil then
		places = if digits ~= digits then 2 else math.floor(digits)
	end

	if places < 0 then
		places = 0
	elseif places > 15 then
		places = 15
	end

	local exp = math.floor(logMagnitude / 3) * 3
	local factor = roundFactors[places + 1]
	local man = math.round(sign * (10 ^ (logMagnitude - exp)) * factor) / factor

	if man >= 1000 or man <= -1000 then
		man *= 0.001
		exp += 3
	end

	return tostring(man) .. "e" .. tostring(exp)
end

function Bnum.formatStandard(val: Value, digits: number?): string
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return "nan"
	end

	if sign == 0 then
		return "0"
	end

	if logMagnitude == math.huge then
		return if sign < 0 then "-inf" else "inf"
	end

	local places = 2

	if digits ~= nil then
		places = if digits ~= digits then 2 else math.floor(digits)
	end

	if places < 0 then
		places = 0
	elseif places > 15 then
		places = 15
	end

	if logMagnitude > 15 or logMagnitude < -6 then
		local exp = math.floor(logMagnitude)
		local factor = roundFactors[places + 1]
		local man = math.round(sign * (10 ^ (logMagnitude - exp)) * factor) / factor

		if man >= 10 or man <= -10 then
			man *= 0.1
			exp += 1
		end

		return tostring(man) .. "e" .. tostring(exp)
	end

	local text = string.format(fixedFormats[places + 1], sign * (10 ^ logMagnitude))

	if places > 0 then
		local last = #text

		while last > 0 and string.byte(text, last) == 48 do
			last -= 1
		end

		if string.byte(text, last) == 46 then
			last -= 1
		end

		if last < #text then
			return string.sub(text, 1, last)
		end
	end

	return text
end

function Bnum.Comma(val: Value, digits: number?): string
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return "nan"
	end

	if sign == 0 then
		return "0"
	end

	if logMagnitude == math.huge then
		return if sign < 0 then "-inf" else "inf"
	end

	local places = 2

	if digits ~= nil then
		places = if digits ~= digits then 2 else math.floor(digits)
	end

	if places < 0 then
		places = 0
	elseif places > 15 then
		places = 15
	end

	if logMagnitude > 15 or logMagnitude < -6 then
		local exp = math.floor(logMagnitude)
		local factor = roundFactors[places + 1]
		local man = math.round(sign * (10 ^ (logMagnitude - exp)) * factor) / factor

		if man >= 10 or man <= -10 then
			man *= 0.1
			exp += 1
		end

		return tostring(man) .. "e" .. tostring(exp)
	end

	local text = string.format(fixedFormats[places + 1], sign * (10 ^ logMagnitude))
	local length = #text
	local fractionEnd = length

	if places > 0 then
		while fractionEnd > 0 and string.byte(text, fractionEnd) == 48 do
			fractionEnd -= 1
		end

		if string.byte(text, fractionEnd) == 46 then
			fractionEnd -= 1
		end
	end

	local negative = string.byte(text, 1) == 45
	local first = if negative then 2 else 1
	local integerEnd = if places > 0 then length - places - 1 else length
	local integerDigits = integerEnd - first + 1

	if integerDigits <= 3 then
		if fractionEnd < length then
			return string.sub(text, 1, fractionEnd)
		end

		return text
	end

	local fraction = if fractionEnd > integerEnd then string.sub(text, integerEnd + 1, fractionEnd) else ""
	local prefix = if negative then "-" else ""
	local firstGroup = integerDigits % 3

	if firstGroup == 0 then
		firstGroup = 3
	end

	local a = first
	local b = a + firstGroup - 1
	local groups = math.floor((integerDigits - firstGroup) / 3)

	if groups == 1 then
		return prefix
			.. string.sub(text, a, b)
			.. ","
			.. string.sub(text, b + 1, integerEnd)
			.. fraction
	elseif groups == 2 then
		return prefix
			.. string.sub(text, a, b)
			.. ","
			.. string.sub(text, b + 1, b + 3)
			.. ","
			.. string.sub(text, b + 4, integerEnd)
			.. fraction
	elseif groups == 3 then
		return prefix
			.. string.sub(text, a, b)
			.. ","
			.. string.sub(text, b + 1, b + 3)
			.. ","
			.. string.sub(text, b + 4, b + 6)
			.. ","
			.. string.sub(text, b + 7, integerEnd)
			.. fraction
	end

	return prefix
		.. string.sub(text, a, b)
		.. ","
		.. string.sub(text, b + 1, b + 3)
		.. ","
		.. string.sub(text, b + 4, b + 6)
		.. ","
		.. string.sub(text, b + 7, b + 9)
		.. ","
		.. string.sub(text, b + 10, integerEnd)
		.. fraction
end

function Bnum.formatSuffix(val: Value, digits: number?): string
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return "nan"
	end

	if sign == 0 then
		return "0"
	end

	if logMagnitude == math.huge then
		return if sign < 0 then "-inf" else "inf"
	end

	local places = 2

	if digits ~= nil then
		places = if digits ~= digits then 2 else math.floor(digits)
	end

	if places < 0 then
		places = 0
	elseif places > 15 then
		places = 15
	end

	if logMagnitude < 3 then
		if logMagnitude < -6 then
			local exp = math.floor(logMagnitude)
			local factor = roundFactors[places + 1]
			local man = math.round(sign * (10 ^ (logMagnitude - exp)) * factor) / factor

			if man >= 10 or man <= -10 then
				man *= 0.1
				exp += 1
			end

			return tostring(man) .. "e" .. tostring(exp)
		end

		local text = string.format(fixedFormats[places + 1], sign * (10 ^ logMagnitude))

		if places > 0 then
			local last = #text

			while last > 0 and string.byte(text, last) == 48 do
				last -= 1
			end

			if string.byte(text, last) == 46 then
				last -= 1
			end

			if last < #text then
				return string.sub(text, 1, last)
			end
		end

		return text
	end

	local tier = math.floor(logMagnitude / 3)

	if tier > 999 then
		local exp = math.floor(logMagnitude)
		local factor = roundFactors[places + 1]
		local man = math.round(sign * (10 ^ (logMagnitude - exp)) * factor) / factor

		if man >= 10 or man <= -10 then
			man *= 0.1
			exp += 1
		end

		return tostring(man) .. "e" .. tostring(exp)
	end

	local factor = roundFactors[places + 1]
	local scaled = math.round(sign * (10 ^ (logMagnitude - tier * 3)) * factor) / factor

	if scaled >= 1000 or scaled <= -1000 then
		scaled *= 0.001
		tier += 1

		if tier > 999 then
			local exp = math.floor(logMagnitude)
			local man = math.round(sign * (10 ^ (logMagnitude - exp)) * factor) / factor

			if man >= 10 or man <= -10 then
				man *= 0.1
				exp += 1
			end

			return tostring(man) .. "e" .. tostring(exp)
		end
	end

	return tostring(scaled) .. suffixes[tier + 1]
end

function Bnum.formatSuffixLong(val: Value, digits: number?): string
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return "nan"
	end

	if sign == 0 then
		return "0"
	end

	if logMagnitude == math.huge then
		return if sign < 0 then "-inf" else "inf"
	end

	local places = 2

	if digits ~= nil then
		places = if digits ~= digits then 2 else math.floor(digits)
	end

	if places < 0 then
		places = 0
	elseif places > 15 then
		places = 15
	end

	if logMagnitude < 3 then
		return Bnum.formatStandard(val, places)
	end

	local tier = math.floor(logMagnitude / 3)

	if tier > 999 then
		return Bnum.formatScientific(val, places)
	end

	local factor = roundFactors[places + 1]
	local scaled = math.round(sign * (10 ^ (logMagnitude - tier * 3)) * factor) / factor

	if scaled >= 1000 or scaled <= -1000 then
		scaled *= 0.001
		tier += 1

		if tier > 999 then
			return Bnum.formatScientific(val, places)
		end
	end

	if tier < #longSuffixes then
		return tostring(scaled) .. " " .. longSuffixes[tier + 1]
	end

	return tostring(scaled) .. suffixes[tier + 1]
end

function Bnum.formatLogarithm(val: Value, digits: number?): string
	local sign = val[1]
	local logMagnitude = val[2]

	if logMagnitude ~= logMagnitude then
		return "nan"
	end

	if sign == 0 then
		return "0"
	end

	if logMagnitude == math.huge then
		return if sign < 0 then "-inf" else "inf"
	end

	local places = 2

	if digits ~= nil then
		places = if digits ~= digits then 2 else math.floor(digits)
	end

	if places < 0 then
		places = 0
	elseif places > 15 then
		places = 15
	end

	local factor = roundFactors[places + 1]
	local logText = if logMagnitude >= 1e15 or logMagnitude <= -1e15 then tostring(logMagnitude) else tostring(math.round(logMagnitude * factor) / factor)

	if sign < 0 then
		return "-10^" .. logText
	end

	return "10^" .. logText
end

function Bnum.formatRaw(val: Value): string
	return "{" .. tostring(val[1]) .. ", " .. tostring(val[2]) .. "}"
end

function Bnum.format(val: Value, digits: number?, formatType: FormatType?): string
	if formatType == "Scientific" then
		return Bnum.formatScientific(val, digits)
	end

	local kind = formatType or "Auto"

	if kind == "Suffix" then
		return Bnum.formatSuffix(val, digits)
	elseif kind == "Auto" then
		local sign = val[1]
		local logMagnitude = val[2]

		if logMagnitude ~= logMagnitude then
			return "nan"
		end

		if sign == 0 then
			return "0"
		end

		if logMagnitude == math.huge then
			return if sign < 0 then "-inf" else "inf"
		end

		local places = 2

		if digits ~= nil then
			places = if digits ~= digits then 2 else math.floor(digits)
		end

		if places < 0 then
			places = 0
		elseif places > 15 then
			places = 15
		end

		if logMagnitude >= 3 then
			local tier = math.floor(logMagnitude / 3)

			if tier <= 999 then
				local factor = roundFactors[places + 1]
				local scaled = math.round(sign * (10 ^ (logMagnitude - tier * 3)) * factor) / factor

				if scaled >= 1000 or scaled <= -1000 then
					scaled *= 0.001
					tier += 1
				end

				if tier <= 999 then
					return tostring(scaled) .. suffixes[tier + 1]
				end
			end

			local exp = math.floor(logMagnitude)
			local factor = roundFactors[places + 1]
			local man = math.round(sign * (10 ^ (logMagnitude - exp)) * factor) / factor

			if man >= 10 or man <= -10 then
				man *= 0.1
				exp += 1
			end

			return tostring(man) .. "e" .. tostring(exp)
		end

		if logMagnitude < -6 then
			local exp = math.floor(logMagnitude)
			local factor = roundFactors[places + 1]
			local man = math.round(sign * (10 ^ (logMagnitude - exp)) * factor) / factor

			if man >= 10 or man <= -10 then
				man *= 0.1
				exp += 1
			end

			return tostring(man) .. "e" .. tostring(exp)
		end

		local text = string.format(fixedFormats[places + 1], sign * (10 ^ logMagnitude))

		if places > 0 then
			local last = #text

			while last > 0 and string.byte(text, last) == 48 do
				last -= 1
			end

			if string.byte(text, last) == 46 then
				last -= 1
			end

			if last < #text then
				return string.sub(text, 1, last)
			end
		end

		return text
	elseif kind == "Engineering" then
		return Bnum.formatEngineering(val, digits)
	elseif kind == "Standard" then
		return Bnum.formatStandard(val, digits)
	elseif kind == "Comma" then
		return Bnum.Comma(val, digits)
	elseif kind == "Logarithm" then
		return Bnum.formatLogarithm(val, digits)
	elseif kind == "SuffixLong" then
		return Bnum.formatSuffixLong(val, digits)
	elseif kind == "Raw" then
		return Bnum.formatRaw(val)
	end

	return Bnum.format(val, digits, "Auto")
end

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

function Bnum.powInto(out: Value, val: Value, power: number): Value
	local sign = val[1]
	local logMagnitude = val[2]

	if power ~= power or logMagnitude ~= logMagnitude then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	if sign > 0 then
		if power == 0 then
			out[1] = 1
			out[2] = 0
			return out
		end

		if power ~= math.huge and power ~= -math.huge then
			local resultLog = logMagnitude * power

			if resultLog == -math.huge then
				out[1] = 0
				out[2] = 0
				return out
			end

			out[1] = 1
			out[2] = resultLog
			return out
		end

		if logMagnitude == 0 then
			out[1] = 1
			out[2] = 0
			return out
		end

		if (power > 0) == (logMagnitude > 0) then
			out[1] = 1
			out[2] = math.huge
			return out
		end

		out[1] = 0
		out[2] = 0
		return out
	end

	if power == 0 then
		out[1] = 1
		out[2] = 0
		return out
	end

	if sign == 0 then
		if power > 0 then
			out[1] = 0
			out[2] = 0
			return out
		end

		out[1] = 1
		out[2] = math.huge
		return out
	end

	if power == math.huge or power == -math.huge or power % 1 ~= 0 then
		out[1] = 0
		out[2] = 0 / 0
		return out
	end

	local resultLog = logMagnitude * power

	if resultLog == -math.huge then
		out[1] = 0
		out[2] = 0
		return out
	end

	out[1] = if power % 2 == 0 then 1 else -1
	out[2] = resultLog
	return out
end

return Bnum
