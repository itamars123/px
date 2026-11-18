-- DataService.luau
-- Player data on ProfileStore (skill SE-1): session-locked profiles, so two
-- servers can never overwrite each other; periodic auto-save; final save and
-- lock release when a player leaves; BindToClose handled by ProfileStore.
-- Also owns the per-player runtime Session (cooldowns, carrying, ...) and a
-- Trove per player for connection cleanup (skill SE-4).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local Trove = require(ServerScriptService.Modules.Trove)

local DataService = {}

local TEMPLATE = {
	Version = Config.DataVersion,
	Money = Config.StartingMoney,
	TotalEarned = 0,
	Rebirths = 0,
	XP = 0,
	Level = 1,
	Gems = Config.Gems.Start,
	Vault = 0, -- offline income waiting on your vault pad
	PlotCash = {}, -- [tostring(plot)] = cash waiting on that stand's collect plate
	Upgrades = { Speed = 0, Carry = 0, Base = 0, Protection = 0, Income = 0, Luck = 0, Security = 0, Walls = 0, Floors = 0 },
	Pets = {}, -- [uid] = { Id = string, Equipped = boolean }
	ExtraPetSlots = 0,
	Gear = { Bat = 0, SpeedCoil = false, Grapple = false, Trap = false },
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
	Trail = "",
	PurchaseIdCache = {}, -- Developer Product receipts already granted (ProfileStore pattern)
	LastOnline = 0,
	FirstJoin = 0,
}
DataService.Template = TEMPLATE

-- Schema migrations: each entry upgrades data from version N-1 to N.
local MIGRATIONS = {
	[4] = function(data)
		-- v4: treasures gained an optional mutation field; nothing to convert,
		-- but clamp any bad plot numbers left by older builds.
		for _, t in pairs(data.Treasures) do
			if typeof(t.Plot) ~= "number" then
				t.Plot = nil
			end
		end
	end,
}

local PlayerStore = nil
local LegacyStore: DataStore? = nil
local canSave = true

DataService.Profiles = {} :: { [Player]: any }
DataService.Sessions = {} :: { [Player]: any }
DataService.Troves = {} :: { [Player]: any }
DataService.Loaded = Instance.new("BindableEvent")

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
		Arriving = {}, -- [uid] = { From = Vector3, At = serverTime } treasures walking home
		PetBonus = { Money = 0, Luck = 0, Speed = 0, Gems = 0 },
		Aura = 0,
	}
end

function DataService.Get(player: Player)
	local profile = DataService.Profiles[player]
	return profile and profile.Data
end

function DataService.Session(player: Player)
	return DataService.Sessions[player]
end

function DataService.Trove(player: Player)
	return DataService.Troves[player]
end

function DataService.IsLoaded(player: Player): boolean
	return DataService.Profiles[player] ~= nil
end

function DataService.CanSave(): boolean
	return canSave
end

-- Asks ProfileStore to write now (used after trades/rebirths/purchases).
function DataService.Save(player: Player)
	local profile = DataService.Profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

local function migrate(data)
	local version = data.Version or 3
	for v = version + 1, Config.DataVersion do
		local fn = MIGRATIONS[v]
		if fn then
			fn(data)
		end
	end
	data.Version = Config.DataVersion
end

-- One-time import from the pre-ProfileStore save format.
local function importLegacy(player: Player, data)
	if not LegacyStore or data.FirstJoin ~= 0 then
		return
	end
	local ok, old = pcall(function()
		return (LegacyStore :: DataStore):GetAsync("Player_" .. player.UserId)
	end)
	if ok and typeof(old) == "table" then
		old.SessionLock = nil
		for k, v in pairs(old) do
			if TEMPLATE[k] ~= nil then
				data[k] = v
			end
		end
		print(("[Data] imported legacy save for %s"):format(player.Name))
	end
end

local function onJoin(player: Player)
	DataService.Sessions[player] = newSession(player)
	DataService.Troves[player] = Trove.new()
	local profile = PlayerStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Could not load your data. Please rejoin in a moment.")
		return
	end
	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile() -- fill new fields from TEMPLATE
	profile.OnSessionEnd:Connect(function()
		DataService.Profiles[player] = nil
		player:Kick("Your data was opened on another server. Please rejoin.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	importLegacy(player, profile.Data)
	Util.Reconcile(profile.Data, TEMPLATE)
	migrate(profile.Data)
	if profile.Data.FirstJoin == 0 then
		profile.Data.FirstJoin = os.time()
	end
	DataService.Profiles[player] = profile
	DataService.Loaded:Fire(player)
end

function DataService.Init()
	PlayerStore = ProfileStore.New(Config.ProfileStoreName, TEMPLATE)
	local ok, legacy = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		LegacyStore = legacy
	end
	if RunService:IsStudio() then
		local accessOk = pcall(function()
			DataStoreService:GetDataStore("__probe"):GetAsync("__probe")
		end)
		if not accessOk then
			canSave = false
			LegacyStore = nil
			warn("[Data] No DataStore access in Studio — ProfileStore runs in mock mode, progress won't persist.")
		end
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onJoin)
	for _, p in ipairs(Players:GetPlayers()) do
		task.defer(onJoin, p) -- defer so every service has connected first
	end
	Players.PlayerRemoving:Connect(function(player)
		-- other services clean up on PlayerRemoving first; give them a frame
		task.defer(function()
			local profile = DataService.Profiles[player]
			if profile then
				profile.Data.LastOnline = os.time()
				profile:EndSession() -- final save + release the session lock
			end
			local trove = DataService.Troves[player]
			if trove then
				trove:Clean()
			end
			DataService.Profiles[player] = nil
			DataService.Sessions[player] = nil
			DataService.Troves[player] = nil
		end)
	end)
end

return DataService
