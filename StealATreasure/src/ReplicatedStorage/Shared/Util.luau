-- Util.lua
-- Small helpers shared by client and server.

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Util.Abbreviate(n: number): string
	n = tonumber(n) or 0
	local neg = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = (n == math.floor(n)) and tostring(math.floor(n)) or string.format("%.1f", n)
		return (neg and "-" or "") .. s
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local fmt = n >= 100 and "%.0f" or (n >= 10 and "%.1f" or "%.2f")
	local s = string.format(fmt, n)
	if s:find("%.") then
		s = s:gsub("0+$", "") -- only strip zeros after a decimal point
		s = s:gsub("%.$", "")
	end
	return (neg and "-" or "") .. s .. SUFFIXES[i]
end

function Util.Money(n: number): string
	return "$" .. Util.Abbreviate(n)
end

function Util.Commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function Util.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m >= 60 then
		return string.format("%dh %02dm", math.floor(m / 60), m % 60)
	end
	return string.format("%d:%02d", m, s)
end

function Util.DeepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = Util.DeepCopy(v)
	end
	return c
end

-- Fills missing keys in `data` from `template` (recursive).
function Util.Reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = Util.DeepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			Util.Reconcile(data[k], v)
		end
	end
	return data
end

local counter = 0
function Util.NewUid(): string
	counter += 1
	return string.format("%x%x%x", os.time(), math.random(0, 0xFFFFFF), counter)
end

return Util
