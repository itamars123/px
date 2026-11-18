-- Remotes.luau
-- Declares every remote. Following skill SE-8 the module body never yields:
-- call Remotes.Init() once (server: NetService.Init creates them; client:
-- Main.client waits for them) before using Remotes.<Name>.
-- All client -> server traffic goes through the single `Action` function,
-- which the server validates against a per-action schema.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"FullState", -- server -> client: complete state snapshot (on change)
	"Stats", -- server -> client: small frequent stats packet
	"Notify", -- server -> client: toast
	"Alarm", -- server -> client: your base is being robbed
	"Announce", -- server -> all: banner (events, rare pulls)
	"TradeUpdate", -- server -> client: trade session state
	"TradeRequest", -- server -> client: incoming trade request
	"Leaderboard", -- server -> client: leaderboard data
	"Effect", -- server -> client: local effect (dash, knockback, confetti...)
	"EventState", -- server -> all: world event changed
}
local FUNCTIONS = {
	"Action", -- client -> server: every request (validated + rate limited)
}

local Remotes = {}
local ready = false

function Remotes.Init()
	if ready then
		return
	end
	local folder: Folder
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(EVENTS) do
			if not folder:FindFirstChild(name) then
				local e = Instance.new("RemoteEvent")
				e.Name = name
				e.Parent = folder
			end
		end
		for _, name in ipairs(FUNCTIONS) do
			if not folder:FindFirstChild(name) then
				local f = Instance.new("RemoteFunction")
				f.Name = name
				f.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes", 60) :: Folder
		assert(folder, "[Remotes] server never created the Remotes folder")
	end
	for _, name in ipairs(EVENTS) do
		(Remotes :: any)[name] = folder:WaitForChild(name, 30)
	end
	for _, name in ipairs(FUNCTIONS) do
		(Remotes :: any)[name] = folder:WaitForChild(name, 30)
	end
	ready = true
end

return Remotes
