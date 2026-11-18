-- Remotes.lua
-- Declares every RemoteEvent / RemoteFunction. The server creates them, the
-- client waits for them. All client->server traffic goes through `Action`
-- (validated & rate limited on the server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"FullState", -- server -> client: complete player state snapshot
	"Stats", -- server -> client: lightweight stats every tick
	"Notify", -- server -> client: toast message
	"Alarm", -- server -> client: your base is being robbed
	"Announce", -- server -> all: big banner (events, legendary pulls)
	"TradeUpdate", -- server -> client: trade session state
	"TradeRequest", -- server -> client: incoming trade request
	"Leaderboard", -- server -> client: leaderboard data
	"Effect", -- server -> client: play a local effect (dash, knockback, confetti)
	"EventState", -- server -> all: current world event
}

local FUNCTIONS = {
	"Action", -- client -> server: every request
}

local Remotes = {}

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
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

for _, name in ipairs(EVENTS) do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in ipairs(FUNCTIONS) do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
