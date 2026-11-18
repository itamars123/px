-- WorldService.lua
-- Living world systems:
--   * day/night cycle (server publishes the clock; clients render it smoothly)
--   * weather (Clear, Cloudy, Rain, Storm, Fog) + wind
--   * treasure chests that spawn around the map and open with an animation
--   * animated portals (server-validated teleports)
--   * golden coins used by events (touch to collect)

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local Scheduler = require(game:GetService("ServerScriptService").Modules.Scheduler)

local S

local WorldService = {}

local rng = Random.new()
local chests: { [Model]: { Spot: Vector3, Opened: boolean } } = {}
local chestFolder: Folder
local coinFolder: Folder

local function now()
	return workspace:GetServerTimeNow()
end

local function hrpOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Weather -----------------------------------------------------------------------
local WIND = {
	Clear = Vector3.new(6, 0, 3),
	Cloudy = Vector3.new(10, 0, 5),
	Rain = Vector3.new(16, 0, 8),
	Storm = Vector3.new(30, 0, 18),
	Fog = Vector3.new(3, 0, 1),
}

function WorldService.SetWeather(name: string)
	workspace:SetAttribute("Weather", name)
	workspace.GlobalWind = WIND[name] or WIND.Clear
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Cover = (name == "Clear" and 0.45) or (name == "Fog" and 0.75) or (name == "Cloudy" and 0.75) or 0.9
		clouds.Density = (name == "Storm" or name == "Rain") and 0.95 or 0.7
		clouds.Color = (name == "Storm" or name == "Rain") and Color3.fromRGB(150, 155, 170) or Color3.fromRGB(255, 255, 255)
	end
end

local function weatherLoop()
	WorldService.SetWeather("Clear")
	while true do
		task.wait(rng:NextNumber(Config.World.WeatherMin, Config.World.WeatherMax))
		local total = 0
		for _, w in pairs(Config.World.Weather) do
			total += w
		end
		local pick = rng:NextNumber() * total
		for name, w in pairs(Config.World.Weather) do
			pick -= w
			if pick <= 0 then
				WorldService.SetWeather(name)
				if name == "Storm" then
					Remotes.Announce:FireAllClients("⛈️ A storm is rolling in!", "Rare")
				elseif name == "Rain" then
					Remotes.Notify:FireAllClients("🌧️ It started raining.", "info")
				end
				break
			end
		end
	end
end

-- Chests -----------------------------------------------------------------------
local function buildChest(cf: CFrame): Model
	local P = S.MapBuilder.Part
	local m = Instance.new("Model")
	m.Name = "TreasureChest"
	local wood = Color3.fromRGB(140, 85, 40)
	local gold = Color3.fromRGB(255, 205, 60)
	local base = P(m, Vector3.new(4, 2.4, 2.8), cf * CFrame.new(0, 1.2, 0), wood, Enum.Material.Wood, { Name = "Base" })
	P(m, Vector3.new(4.1, 0.4, 2.9), cf * CFrame.new(0, 2.3, 0), gold, Enum.Material.Metal)
	for _, x in ipairs({ -1.5, 1.5 }) do
		P(m, Vector3.new(0.35, 2.45, 2.9), cf * CFrame.new(x, 1.2, 0), gold, Enum.Material.Metal)
	end
	P(m, Vector3.new(3.4, 0.3, 2.2), cf * CFrame.new(0, 2.45, 0), Color3.fromRGB(255, 220, 90), Enum.Material.Neon, { Name = "Treasure", CanCollide = false })
	-- lid (hinged at the back edge; the client rotates it open)
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	local hinge = P(lid, Vector3.new(4, 0.2, 0.2), cf * CFrame.new(0, 2.5, -1.4), gold, Enum.Material.Metal, { Name = "Hinge", CanCollide = false })
	P(lid, Vector3.new(4, 0.8, 2.8), cf * CFrame.new(0, 2.9, 0), wood, Enum.Material.Wood, { CanCollide = false })
	P(lid, Vector3.new(4.1, 0.3, 2.9), cf * CFrame.new(0, 3.2, 0), gold, Enum.Material.Metal, { CanCollide = false })
	P(lid, Vector3.new(0.6, 0.7, 0.2), cf * CFrame.new(0, 2.6, 1.45), gold, Enum.Material.Metal, { CanCollide = false })
	lid.PrimaryPart = hinge
	lid.Parent = m
	local glow = Instance.new("PointLight")
	glow.Color = gold
	glow.Range = 12
	glow.Brightness = 1.5
	glow.Parent = base
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(gold)
	sparkle.Rate = 6
	sparkle.LightEmission = 1
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.Parent = base
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "🧰 Treasure Chest"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	m.PrimaryPart = base
	return m
end

local function openChest(player: Player, chest: Model)
	local info = chests[chest]
	local hrp = hrpOf(player)
	local data = S.DataService.Get(player)
	if not info or info.Opened or not hrp or not data then
		return
	end
	if (chest:GetPivot().Position - hrp.Position).Magnitude > 16 then
		return
	end
	info.Opened = true
	chest:SetAttribute("Opened", true) -- clients play the lid animation
	data.Stats.ChestsOpened += 1
	local session = S.DataService.Session(player)
	local mps = session and session.MPS or 0
	local gems = rng:NextInteger(5, 20)
	local money = math.floor(math.max(500, mps * 45) * rng:NextNumber(0.8, 1.4))
	S.EconomyService.AddGems(player, gems)
	S.EconomyService.AddMoney(player, money)
	local text = ("🧰 Chest opened! +%s  +%d 💎"):format(Util.Money(money), gems)
	if rng:NextNumber() < 0.2 then
		local def = TreasureData.RollFromPool({ Rare = 50, Epic = 35, Legendary = 12, Mythical = 3 }, rng)
		S.TreasureService.Give(player, def.Id, { Source = "Chest" })
		text ..= (" and a %s %s!"):format(def.Rarity, def.Name)
	end
	S.NetService.Notify(player, text, "discovery")
	Remotes.Effect:FireClient(player, "ChestOpen", chest:GetPivot().Position)
	S.PlayerService.Emote(player, "Celebrate", 2.5)
	task.delay(3.5, function()
		chests[chest] = nil
		chest:SetAttribute("Despawning", true)
		task.wait(0.6)
		chest:Destroy()
	end)
end

local function spawnChest()
	local spots = S.MapBuilder.Map.ChestSpots
	if #spots == 0 then
		return
	end
	local count = 0
	local used = {}
	for _, info in pairs(chests) do
		count += 1
		used[info.Spot] = true
	end
	if count >= Config.World.MaxChests then
		return
	end
	for _ = 1, 10 do
		local spot = spots[rng:NextInteger(1, #spots)]
		if not used[spot] then
			local cf = CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local chest = buildChest(cf)
			chests[chest] = { Spot = spot, Opened = false }
			local prompt = chest.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
			prompt.Triggered:Connect(function(player)
				openChest(player, chest)
			end)
			chest.Parent = chestFolder
			return
		end
	end
end

-- Coins ---------------------------------------------------------------------------
function WorldService.SpawnCoin(position: Vector3)
	local coin = Instance.new("Part")
	coin.Name = "GoldCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2.2, 2.2)
	coin.Color = Color3.fromRGB(255, 205, 50)
	coin.Material = Enum.Material.Foil
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanTouch = true
	coin.CFrame = CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, 0)
	local l = Instance.new("PointLight")
	l.Color = coin.Color
	l.Range = 6
	l.Parent = coin
	CollectionService:AddTag(coin, "Spin")
	coin:SetAttribute("SpinSpeed", 3)
	CollectionService:AddTag(coin, "Bob")
	coin:SetAttribute("BobHeight", 0.5)
	local taken = false
	coin.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		local hrp = hrpOf(player)
		if not hrp or (hrp.Position - coin.Position).Magnitude > 10 then
			return
		end
		taken = true
		local session = S.DataService.Session(player)
		local value = math.floor(math.max(50, (session and session.MPS or 0) * Config.Events.CoinValueSeconds))
		S.EconomyService.AddMoney(player, value)
		Remotes.Effect:FireClient(player, "Coin", value)
		coin:Destroy()
	end)
	coin.Parent = coinFolder
	Debris:AddItem(coin, 60)
	return coin
end

-- Portals ------------------------------------------------------------------------
local function hookPortals()
	for _, disc in ipairs(CollectionService:GetTagged("Portal")) do
		local cooldown = {}
		disc.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local hrp = player and hrpOf(player)
			if not player or not hrp then
				return
			end
			if cooldown[player] and os.clock() - cooldown[player] < 3 then
				return
			end
			cooldown[player] = os.clock()
			local data = S.DataService.Get(player)
			local need = disc:GetAttribute("RequiresSecret")
			if need and data and not data.Secrets[need] then
				S.NetService.Notify(player, ("🔒 Discover %s on foot first to unlock this portal!"):format(need), "warn")
				return
			end
			if S.DataService.Session(player) and #S.DataService.Session(player).Carrying > 0 then
				S.NetService.Notify(player, "You can't use portals while carrying treasure!", "error")
				return
			end
			local target = disc:GetAttribute("PortalTo")
			if typeof(target) == "Vector3" then
				Remotes.Effect:FireClient(player, "Portal")
				S.PlayerService.Grace(player, 3)
				hrp.CFrame = CFrame.new(target)
			end
		end)
	end
end

function WorldService.Init(services)
	S = services
end

function WorldService.Start()
	chestFolder = Instance.new("Folder")
	chestFolder.Name = "Chests"
	chestFolder.Parent = workspace
	coinFolder = Instance.new("Folder")
	coinFolder.Name = "Coins"
	coinFolder.Parent = workspace

	-- day/night clock: clients compute ClockTime from these attributes
	workspace:SetAttribute("DayLength", Config.World.DayLength)
	workspace:SetAttribute("DayStart", now() - Config.World.DayLength * 0.3)

	task.spawn(weatherLoop)
	hookPortals()
	task.spawn(function()
		for _ = 1, 3 do
			spawnChest()
		end
		Scheduler.Every("Chests", Config.World.ChestInterval, spawnChest)
	end)
end

return WorldService
