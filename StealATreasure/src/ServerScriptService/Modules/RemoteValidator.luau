-- RemoteValidator.luau
-- Schema validation for every client request (skill: security-hardening).
-- A schema is a list of argument specs:
--   "string" | "number" | "boolean" | "table" | "Vector3"
--   or { Type = ..., Optional = bool, Min = n, Max = n, Integer = bool,
--        MaxLen = n (strings), MaxItems = n (tables), ItemType = "string" }

local RemoteValidator = {}

export type Spec = string | {
	Type: string,
	Optional: boolean?,
	Min: number?,
	Max: number?,
	Integer: boolean?,
	MaxLen: number?,
	MaxItems: number?,
	ItemType: string?,
}

local DEFAULT_MAX_STRING = 64
local DEFAULT_MAX_ITEMS = 32

local function normalise(spec: Spec)
	if type(spec) == "string" then
		return { Type = spec }
	end
	return spec
end

local function checkOne(value: any, spec): (boolean, string?)
	local t = typeof(value)
	if value == nil then
		if spec.Optional then
			return true
		end
		return false, "missing argument"
	end
	if t ~= spec.Type then
		return false, ("expected %s, got %s"):format(spec.Type, t)
	end
	if t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return false, "NaN/inf number"
		end
		if spec.Integer and math.floor(value) ~= value then
			return false, "expected integer"
		end
		if spec.Min and value < spec.Min then
			return false, "number below minimum"
		end
		if spec.Max and value > spec.Max then
			return false, "number above maximum"
		end
	elseif t == "string" then
		if #value > (spec.MaxLen or DEFAULT_MAX_STRING) then
			return false, "string too long"
		end
	elseif t == "table" then
		local n = 0
		for k, v in pairs(value) do
			n += 1
			if n > (spec.MaxItems or DEFAULT_MAX_ITEMS) then
				return false, "table too large"
			end
			if spec.ItemType then
				if typeof(k) ~= "number" or typeof(v) ~= spec.ItemType then
					return false, "bad table item"
				end
				if spec.ItemType == "string" and #v > DEFAULT_MAX_STRING then
					return false, "table string too long"
				end
			end
		end
	elseif t == "Vector3" then
		if value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z then
			return false, "NaN vector"
		end
		if value.Magnitude > 1e5 then
			return false, "vector out of world"
		end
	end
	return true
end

-- Returns ok, reason. `count` is select("#", ...) so extra args are rejected.
function RemoteValidator.Validate(schema: { Spec }, count: number, args: { any }): (boolean, string?)
	if count > #schema then
		return false, ("too many arguments (%d > %d)"):format(count, #schema)
	end
	for i, raw in ipairs(schema) do
		local ok, why = checkOne(args[i], normalise(raw))
		if not ok then
			return false, ("arg %d: %s"):format(i, why or "invalid")
		end
	end
	return true
end

function RemoteValidator.CharacterAlive(player: Player): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

return RemoteValidator
