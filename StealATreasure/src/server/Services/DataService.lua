-- DataService.lua
-- Loads, holds and saves player progress with DataStoreService.
--  * UpdateAsync with a session lock so two servers never write the same save
--  * retries with backoff, autosave, save on leave and on shutdown
--  * works in Studio without API access (progress just isn't persisted)
--  * Sessions[player] holds non-saved runtime state (cooldowns, carrying, ...)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local DataService = {}

local TEMPLATE = {
	Version = Config.DataVersion,
	Money = Config.StartingMoney,
	TotalEarned = 0,
	Rebirths = 0,
	XP = 0,
	Level = 1,
	Gems = Config.Gems.Start,
	Vault = 0, -- uncollected income waiting on your collector pad
	Upgrades = { Speed = 0, Carry = 0, Base = 0, Protection = 0, Income = 0, Luck = 0, Security = 0, Walls = 0, Floors = 0 },
	Pets = {}, -- [uid] = { Id = string, Equipped = boolean }
	ExtraPetSlots = 0,
	AutoCollect = false,
	Boosts = {}, -- [name] = os.time() expiry
	Achievements = {}, -- [id] = true
	BaseColor = 0, -- 0 = slot default, otherwise index into UpgradeData.BaseColors
	Abilities = {},
	Treasures = {}, -- [uid] = { Id = string, Plot = number? }
	Index = {}, -- [treasureId] = true
	Secrets = {}, -- [secretName] = true
	Settings = { Music = true, Sfx = true, LowGfx = false, UIScale = 1, Effects = true, Weather = true, Intro = true },
	Stats = { Steals = 0, Robbed = 0, Collected = 0, Trades = 0, Defends = 0, Hatched = 0, ChestsOpened = 0, EventsJoined = 0 },
	Titles = {},
	Title = "",
	Trail = nil,
	LastOnline = 0,
	FirstJoin = 0,
}
DataService.Template = TEMPLATE

local SESSION_STALE = 30 * 60 -- a lock older than this is considered abandoned

local store: DataStore? = nil
local canSave = true

DataService.Profiles = {} :: { [Player]: any }
DataService.Sessions = {} :: { [Player]: any }
DataService.Loaded = Instance.new("BindableEvent")
DataService.Dirty = {} :: { [Player]: boolean } -- full-state resend pending

local function retry(fn, attempts: number)
	local lastErr
	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(math.min(2 ^ i, 8))
	end
	return false, lastErr
end

local function newSession(player: Player)
	return {
		Player = player,
		BaseIndex = nil,
		LockEnd = 0,
		LockCooldownEnd = 0,
		StealCooldownEnd = 0,
		ShieldEnd = workspace:GetServerTimeNow() + Config.Steal.NewPlayerShield,
		VictimCooldowns = {}, -- [victimUserId] = endTime
		Carrying = {}, -- list of carried items (CarryService)
		Stealing = {}, -- [uid] = thief Player   (my treasures being stolen right now)
		AbilityCooldowns = {},
		Cloaked = false,
		SuperJump = false,
		LastBonk = 0,
		Trade = nil,
		MPS = 0,
		JoinTime = os.time(),
		Stamina = Config.Sprint.MaxStamina,
		Sprinting = false,
		CameraAlerts = {}, -- [intruder] = last alert clock
		PetBonus = { Money = 0, Luck = 0, Speed = 0, Gems = 0 },
		Aura = 0,
	}
end

function DataService.Get(player: Player)
	return DataService.Profiles[player]
end

function DataService.Session(player: Player)
	return DataService.Sessions[player]
end

function DataService.IsLoaded(player: Player): boolean
	return DataService.Profiles[player] ~= nil
end

function DataService.MarkDirty(player: Player)
	DataService.Dirty[player] = true
end

-- Waits until a player's data is loaded (or they leave). Returns data or nil.
function DataService.WaitFor(player: Player)
	while player.Parent and not DataService.Profiles[player] do
		task.wait(0.1)
	end
	return DataService.Profiles[player]
end

local function key(player: Player): string
	return "Player_" .. player.UserId
end

local function load(player: Player)
	local data
	if store and canSave then
		local attempts = 0
		while true do
			attempts += 1
			local locked = false
			local ok, result = retry(function()
				return (store :: DataStore):UpdateAsync(key(player), function(old)
					old = old or {}
					local lock = old.SessionLock
					if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < SESSION_STALE and attempts < 4 then
						locked = true
						return nil -- cancel, someone else still has it
					end
					old.SessionLock = { JobId = game.JobId, Time = os.time() }
					return old
				end)
			end, 4)
			if not ok then
				warn("[Data] load failed for " .. player.Name .. ": " .. tostring(result))
				player:Kick("Could not load your data. Please rejoin in a moment.")
				return nil
			end
			if not locked then
				data = result
				break
			end
			task.wait(6) -- previous server is still saving, wait and retry
		end
	end
	data = data or {}
	Util.Reconcile(data, TEMPLATE)
	data.SessionLock = nil
	if data.FirstJoin == 0 then
		data.FirstJoin = os.time()
	end
	return data
end

local function serialize(data)
	local copy = Util.DeepCopy(data)
	copy.SessionLock = nil
	return copy
end

function DataService.Save(player: Player, release: boolean?)
	local data = DataService.Profiles[player]
	if not data or not store or not canSave then
		return false
	end
	data.LastOnline = os.time()
	local payload = serialize(data)
	local ok, err = retry(function()
		return (store :: DataStore):UpdateAsync(key(player), function(old)
			local lock = old and old.SessionLock
			if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < SESSION_STALE then
				return nil -- another server owns this save now; don't overwrite it
			end
			if not release then
				payload.SessionLock = { JobId = game.JobId, Time = os.time() }
			end
			return payload
		end)
	end, 3)
	if not ok then
		warn("[Data] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
		-- In Studio, check API access once so we don't spam errors.
		if RunService:IsStudio() then
			local accessOk = pcall(function()
				(store :: DataStore):GetAsync("__probe")
			end)
			if not accessOk then
				canSave = false
				warn("[Data] DataStore unavailable in Studio (enable 'Studio Access to API Services'). Progress won't save.")
			end
		end
	else
		canSave = false
		warn("[Data] DataStoreService unavailable: " .. tostring(result))
	end
end

function DataService.CanSave()
	return canSave and store ~= nil
end

function DataService.Start()
	local function onJoin(player: Player)
		DataService.Sessions[player] = newSession(player)
		local data = load(player)
		if not data or not player.Parent then
			return
		end
		DataService.Profiles[player] = data
		DataService.Loaded:Fire(player)
	end

	Players.PlayerAdded:Connect(onJoin)
	for _, p in ipairs(Players:GetPlayers()) do
		task.defer(onJoin, p) -- defer so every service has connected first
	end

	Players.PlayerRemoving:Connect(function(player)
		-- Other services clean up on PlayerRemoving too; give them a frame.
		task.defer(function()
			if DataService.Profiles[player] then
				DataService.Save(player, true)
			end
			DataService.Profiles[player] = nil
			DataService.Sessions[player] = nil
			DataService.Dirty[player] = nil
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in pairs(DataService.Profiles) do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in pairs(DataService.Profiles) do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
