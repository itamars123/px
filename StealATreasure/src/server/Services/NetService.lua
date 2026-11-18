-- NetService.lua
-- Single entry point for all client requests. Every request is rate limited,
-- type checked by its handler and wrapped in pcall so a bad request can never
-- break the server. Handlers return (ok: boolean, message: string?, extra: any?).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local NetService = {}
NetService.Handlers = {} :: { [string]: (Player, ...any) -> (boolean, string?, any?) }

local buckets: { [Player]: { Start: number, Count: number } } = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b or now - b.Start > Config.RateLimit.Window then
		buckets[player] = { Start = now, Count = 1 }
		return true
	end
	b.Count += 1
	return b.Count <= Config.RateLimit.MaxRequests
end

function NetService.Handle(action: string, fn)
	assert(NetService.Handlers[action] == nil, "Duplicate handler " .. action)
	NetService.Handlers[action] = fn
end

function NetService.Notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

function NetService.Init() end

function NetService.Start()
	Remotes.Action.OnServerInvoke = function(player: Player, action: any, ...)
		if typeof(action) ~= "string" then
			return { ok = false, msg = "Bad request" }
		end
		if not allowed(player) then
			return { ok = false, msg = "Slow down!" }
		end
		local handler = NetService.Handlers[action]
		if not handler then
			return { ok = false, msg = "Unknown action" }
		end
		local success, ok, msg, extra = pcall(handler, player, ...)
		if not success then
			warn(("[Net] %s failed for %s: %s"):format(action, player.Name, tostring(ok)))
			return { ok = false, msg = "Something went wrong" }
		end
		return { ok = ok == true, msg = msg, data = extra }
	end
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

return NetService
