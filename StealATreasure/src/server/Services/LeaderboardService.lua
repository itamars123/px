-- LeaderboardService.lua
-- Global leaderboards (OrderedDataStore) for Richest players and Most
-- Rebirths, plus a live server board. Shown in the UI and on the physical
-- board in the marketplace.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local S

local LeaderboardService = {}
LeaderboardService.Cache = { Richest = {}, Rebirths = {}, Server = {} }

local UPDATE_INTERVAL = 120
local MAX_SAFE = 2 ^ 52

local stores = {}
local nameCache: { [number]: string } = {}

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = ok and name or ("Player" .. userId)
	return nameCache[userId]
end

local function pushScores()
	if not stores.Richest then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local data = S.DataService.Get(player)
		if data then
			local key = tostring(player.UserId)
			pcall(function()
				stores.Richest:SetAsync(key, math.floor(math.min(data.Money, MAX_SAFE)))
			end)
			pcall(function()
				stores.Rebirths:SetAsync(key, data.Rebirths)
			end)
		end
	end
end

local function fetch(store): { any }
	local list = {}
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 50)
	end)
	if not ok or not pages then
		return list
	end
	local okPage, entries = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage then
		return list
	end
	for rank, entry in ipairs(entries) do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(list, { Rank = rank, UserId = userId, Name = nameFor(userId), Value = entry.value })
		end
	end
	return list
end

local function buildServer()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = S.DataService.Get(player)
		local ses = S.DataService.Session(player)
		if data then
			table.insert(list, {
				UserId = player.UserId,
				Name = player.DisplayName,
				Value = data.Money,
				MPS = ses and ses.MPS or 0,
				Rebirths = data.Rebirths,
				Level = data.Level,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.Value > b.Value
	end)
	for i, e in ipairs(list) do
		e.Rank = i
	end
	return list
end

local boardRows: { TextLabel } = {}
local function buildBoard()
	local board = S.MapBuilder.Map.LeaderboardBoard
	if not board then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	title.Size = UDim2.fromScale(1, 0.12)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(40, 25, 0)
	title.Text = "🏆 RICHEST PLAYERS (GLOBAL)"
	title.Parent = gui
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = i % 2 == 0 and 0.85 or 1
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.Position = UDim2.fromScale(0.03, 0.13 + (i - 1) * 0.086)
		row.Size = UDim2.fromScale(0.94, 0.08)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 80) or (i == 2 and Color3.fromRGB(220, 220, 235) or (i == 3 and Color3.fromRGB(230, 150, 90) or Color3.new(1, 1, 1)))
		row.Text = ""
		row.Parent = gui
		boardRows[i] = row
	end
end

local function updateBoard()
	local list = LeaderboardService.Cache.Richest
	if #list == 0 then
		list = LeaderboardService.Cache.Server
	end
	for i, row in ipairs(boardRows) do
		local e = list[i]
		row.Text = e and ("  #%d  %s  —  %s"):format(i, e.Name, Util.Money(e.Value)) or ""
	end
end

local function broadcast(target: Player?)
	if target then
		Remotes.Leaderboard:FireClient(target, LeaderboardService.Cache)
	else
		Remotes.Leaderboard:FireAllClients(LeaderboardService.Cache)
	end
end

function LeaderboardService.Init(services)
	S = services
	local ok = pcall(function()
		stores.Richest = DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
		stores.Rebirths = DataStoreService:GetOrderedDataStore(Config.RebirthBoardStoreName)
	end)
	if not ok or not S.DataService.CanSave() then
		stores = {}
	end
end

function LeaderboardService.Start()
	buildBoard()
	S.NetService.Handle("GetLeaderboard", function(player)
		LeaderboardService.Cache.Server = buildServer()
		broadcast(player)
		return true
	end)
	-- live server board every 5s
	task.spawn(function()
		while true do
			LeaderboardService.Cache.Server = buildServer()
			updateBoard()
			task.wait(5)
		end
	end)
	-- global boards
	task.spawn(function()
		task.wait(10)
		while true do
			pushScores()
			if stores.Richest then
				LeaderboardService.Cache.Richest = fetch(stores.Richest)
				LeaderboardService.Cache.Rebirths = fetch(stores.Rebirths)
			end
			updateBoard()
			broadcast()
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return LeaderboardService
