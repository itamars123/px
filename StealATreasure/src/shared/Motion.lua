-- Motion.lua
-- Deterministic "wander" movement for treasures roaming the world. The
-- position is a pure function of (seed, server time), so every client animates
-- the exact same walk/run/jump path without any network traffic, and the
-- server uses the same function to validate pickups.
--
-- Each 2*SEG seconds is one cycle: move from waypoint p to p+1 (walk or run),
-- then stay there doing an action (idle, dance or jump).

local Motion = {}

local SEG = 3
local cache = {} -- [seed] = current cycle (avoids re-rolling every frame)
local cacheCount = 0

local function waypoint(seed: number, p: number, radius: number): Vector3
	local r = Random.new(seed * 7919 + p * 104729)
	local a = r:NextNumber(0, math.pi * 2)
	local d = math.sqrt(r:NextNumber()) * radius
	return Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
end

local function cycleKind(seed: number, p: number)
	local r = Random.new(seed * 31 + p * 7)
	local move = r:NextNumber() < 0.7 and "Walk" or "Run"
	local roll = r:NextNumber()
	local stay = roll < 0.45 and "Idle" or (roll < 0.75 and "Dance" or "Jump")
	return move, stay
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- Returns offset (Vector3, relative to home), state string, yaw (radians)
function Motion.Sample(seed: number, t: number, radius: number)
	local p = math.floor(t / (SEG * 2))
	local u = t - p * SEG * 2
	local c = cache[seed]
	if not c or c.P ~= p or c.R ~= radius then
		local move, stay = cycleKind(seed, p)
		c = { P = p, R = radius, A = waypoint(seed, p, radius), B = waypoint(seed, p + 1, radius), Move = move, Stay = stay }
		cache[seed] = c
		cacheCount += 1
		if cacheCount > 2000 then
			table.clear(cache)
			cacheCount = 0
		end
	end
	local a, b, move, stay = c.A, c.B, c.Move, c.Stay
	local dir = b - a
	local yaw = (dir.Magnitude > 0.01) and math.atan2(dir.X, dir.Z) or 0
	if u < SEG then
		local duration = move == "Run" and SEG * 0.45 or SEG
		local f = math.clamp(u / duration, 0, 1)
		local pos = a:Lerp(b, smooth(f))
		if f >= 1 then
			return pos, "Idle", yaw
		end
		local hop = move == "Run" and math.abs(math.sin(u * 14)) * 0.35 or math.abs(math.sin(u * 8)) * 0.15
		return pos + Vector3.new(0, hop, 0), move, yaw
	end
	local v = u - SEG
	if stay == "Jump" then
		local h = math.abs(math.sin(v / SEG * math.pi * 3)) * 2.2
		return b + Vector3.new(0, h, 0), "Jump", yaw
	end
	return b, stay, yaw
end

-- World position for a wandering treasure model / record.
function Motion.Position(home: CFrame, seed: number, t: number, radius: number): Vector3
	local offset = Motion.Sample(seed, t, radius)
	return home.Position + offset
end

return Motion
