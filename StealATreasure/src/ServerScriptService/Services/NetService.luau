-- NetService.luau
-- The single gateway for client requests (skill: RemoteHandler pattern).
--   * every action declares an argument schema (types, ranges, NaN, length)
--   * extra arguments are rejected
--   * per-player global rate limit + per-action cooldown
--   * suspicious requests are logged with the player's name and id
--   * handlers run in pcall; they return (ok, message?, data?)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local RemoteValidator = require(ServerScriptService.Modules.RemoteValidator)

local NetService = {}

type Handler = {
	Schema: { any },
	Fn: (Player, ...any) -> (boolean?, string?, any?),
	Cooldown: number,
}

local handlers: { [string]: Handler } = {}
local buckets: { [Player]: { Start: number, Count: number } } = {}
local lastUse: { [Player]: { [string]: number } } = {}
local strikes: { [Player]: number } = {}

-- Default per-action cooldowns (seconds). Anything not listed uses 0.05.
local COOLDOWNS = {
	HatchEgg = 0.4,
	Rebirth = 2,
	TradeRequest = 1,
	Emote = 0.8,
	Grapple = 0.5,
	UpdateSettings = 0.2,
	BuyUpgrade = 0.25,
	BuyAbility = 0.5,
	BuyGemItem = 0.5,
	BuyGear = 0.5,
	Sell = 0.2,
	Store = 0.15,
	Place = 0.15,
	Collect = 0.3,
	TradeOffer = 0.25,
	TradeRespond = 0.5,
	SetBaseColor = 0.5,
	SetTitle = 0.5,
	DeletePet = 0.25,
	GetLeaderboard = 2,
	RequestState = 1,
	SellStorage = 1,
	PlaceAll = 1,
}

local function suspicious(player: Player, action: string, why: string)
	strikes[player] = (strikes[player] or 0) + 1
	warn(("[Net] rejected %s from %s (%d): %s [strike %d]"):format(action, player.Name, player.UserId, why, strikes[player]))
	-- repeated malformed requests are an exploit signature, not a lag spike
	if strikes[player] >= 25 then
		player:Kick("Too many invalid requests.")
	end
end

local function globalAllowed(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b or now - b.Start > Config.RateLimit.Window then
		buckets[player] = { Start = now, Count = 1 }
		return true
	end
	b.Count += 1
	return b.Count <= Config.RateLimit.MaxRequests
end

-- Registers an action. schema: list of RemoteValidator specs.
function NetService.Handle(action: string, schema: { any }, fn, cooldown: number?)
	assert(handlers[action] == nil, "Duplicate handler " .. action)
	handlers[action] = { Schema = schema, Fn = fn, Cooldown = cooldown or COOLDOWNS[action] or 0.05 }
end

function NetService.Notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function NetService.Init()
	Remotes.Init()
end

function NetService.Start()
	Remotes.Action.OnServerInvoke = function(player: Player, action: any, ...)
		if typeof(action) ~= "string" or #action > 32 then
			suspicious(player, tostring(action), "bad action name")
			return { ok = false }
		end
		local h = handlers[action]
		if not h then
			suspicious(player, action, "unknown action")
			return { ok = false }
		end
		if not globalAllowed(player) then
			return { ok = false, msg = "Slow down!" }
		end
		local now = os.clock()
		local uses = lastUse[player]
		if not uses then
			uses = {}
			lastUse[player] = uses
		end
		if uses[action] and now - uses[action] < h.Cooldown then
			return { ok = false }
		end
		uses[action] = now
		local count = select("#", ...)
		local ok, why = RemoteValidator.Validate(h.Schema, count, { ... })
		if not ok then
			suspicious(player, action, why or "invalid")
			return { ok = false, msg = "Invalid request" }
		end
		local success, result, msg, extra = pcall(h.Fn, player, ...)
		if not success then
			warn(("[Net] %s failed for %s: %s"):format(action, player.Name, tostring(result)))
			return { ok = false, msg = "Something went wrong" }
		end
		return { ok = result == true, msg = msg, data = extra }
	end
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
		lastUse[p] = nil
		strikes[p] = nil
	end)
end

return NetService
