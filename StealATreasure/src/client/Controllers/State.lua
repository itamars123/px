-- State.lua
-- Client mirror of the server state + a request helper.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = {}
State.Full = nil
State.Stats = nil
State.Leaderboard = nil
State.FullChanged = Instance.new("BindableEvent")
State.StatsChanged = Instance.new("BindableEvent")
State.LeaderboardChanged = Instance.new("BindableEvent")

local notifier -- set by Notifications to show request messages

function State.SetNotifier(fn)
	notifier = fn
end

function State.Now(): number
	return workspace:GetServerTimeNow()
end

-- Sends an action to the server. Shows the returned message as a toast
-- unless `silent` is true. Returns ok, msg, data.
function State.Request(action: string, ...)
	local ok, result = pcall(function(...)
		return Remotes.Action:InvokeServer(action, ...)
	end, ...)
	if not ok or typeof(result) ~= "table" then
		if notifier then
			notifier("Connection problem, try again", "error")
		end
		return false, "Connection problem"
	end
	if result.msg and result.msg ~= "" and notifier then
		notifier(result.msg, result.ok and "success" or "error")
	end
	return result.ok, result.msg, result.data
end

-- Silent variant
function State.Ask(action: string, ...)
	local ok, result = pcall(function(...)
		return Remotes.Action:InvokeServer(action, ...)
	end, ...)
	if not ok or typeof(result) ~= "table" then
		return false
	end
	return result.ok, result.msg, result.data
end

function State.Init()
	Remotes.FullState.OnClientEvent:Connect(function(snap)
		State.Full = snap
		State.FullChanged:Fire(snap)
	end)
	Remotes.Stats.OnClientEvent:Connect(function(stats)
		State.Stats = stats
		if State.Full then
			State.Full.Money = stats.Money
			State.Full.Gems = stats.Gems
			State.Full.Vault = stats.Vault
			State.Full.Level = stats.Level
			State.Full.XP = stats.XP
			State.Full.XPNext = stats.XPNext
		end
		State.StatsChanged:Fire(stats)
	end)
	Remotes.Leaderboard.OnClientEvent:Connect(function(board)
		State.Leaderboard = board
		State.LeaderboardChanged:Fire(board)
	end)
	task.spawn(function()
		-- ask for a fresh state in case we missed the first send
		while not State.Full do
			State.Ask("RequestState")
			task.wait(2)
		end
	end)
end

return State
