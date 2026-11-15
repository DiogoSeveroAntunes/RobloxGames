-- Formatação de números e tempo (compartilhado entre cliente e servidor)
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }

-- 1234 -> "1.23K", 999 -> "999", 1500000 -> "1.5M"
function Format.Abbreviate(n: number): string
	if n ~= n then return "0" end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = (n % 1 == 0) and tostring(math.floor(n)) or string.format("%.1f", n)
		return (negative and "-" or "") .. s
	end
	local index = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (index * 3)
	local s
	if scaled >= 100 then
		s = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		s = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		s = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	s = s:gsub("%.?0+$", "")
	return (negative and "-" or "") .. s .. SUFFIXES[index + 1]
end

function Format.Cash(n: number): string
	return "$" .. Format.Abbreviate(n)
end

-- 1234567 -> "1.234.567"
function Format.Commas(n: number): string
	local s = tostring(math.floor(n))
	local result = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (result:gsub("^%.", ""))
end

-- 3725 -> "1h 2min"
function Format.Duration(seconds: number): string
	seconds = math.floor(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

return Format
