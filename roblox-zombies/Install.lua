-- Zombie Waves installer: paste ALL of this into Roblox Studio > View > Command Bar, press Enter.
local function make(className, name, parent, source)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local s = Instance.new(className)
	s.Name = name
	s.Source = source
	s.Parent = parent
end
make("ModuleScript", "ZombieConfig", game:GetService('ReplicatedStorage'), [========[
-- ZombieConfig (ModuleScript) — put in ReplicatedStorage
-- Every number that controls the game lives here. Tweak freely.

local Config = {}

---------------------------------------------------------------- players
Config.StartingPoints = 500
Config.StartingWeapon = "Pistol"
Config.MaxWeapons = 2               -- buying a 3rd gun replaces the one in your hands
Config.PlayerMaxHealth = 100
Config.PlayerRegenDelay = 4         -- seconds without taking damage before health regenerates
Config.PlayerRegenRate = 25         -- health per second while regenerating
Config.WalkSpeed = 16
Config.SprintSpeed = 24

---------------------------------------------------------------- points
Config.PointsPerHit = 10
Config.PointsPerKill = 60
Config.PointsPerHeadshotKill = 100

---------------------------------------------------------------- rounds
Config.FirstRoundDelay = 8          -- countdown before round 1
Config.IntermissionTime = 10        -- break between rounds
Config.MaxZombiesAlive = 24         -- cap on zombies alive at once (performance)
Config.MinSpawnDistance = 25        -- prefer spawn points at least this far from players

-- How many zombies a round has (more players = more zombies)
function Config.ZombiesForRound(round, playerCount)
	return math.floor((6 + round * 3) * (1 + 0.5 * (math.max(playerCount, 1) - 1)))
end

-- Zombie health: grows linearly until round 9, then by 10% per round (like the classics)
function Config.ZombieHealth(round)
	if round <= 9 then
		return 100 + 80 * (round - 1)
	end
	return math.floor(740 * 1.1 ^ (round - 9))
end

-- Zombie walk speed (players walk at 16, sprint at 24)
function Config.ZombieSpeed(round)
	return math.min(7 + round * 0.9, 21)
end

-- Seconds between zombie spawns
function Config.SpawnInterval(round)
	return math.max(2 - round * 0.12, 0.35)
end

Config.ZombieDamage = 34            -- 3 hits kills a 100 hp player
Config.ZombieAttackRange = 4.5
Config.ZombieAttackCooldown = 1.1

---------------------------------------------------------------- weapons
-- FireRate = seconds between shots. Spread = degrees. Pellets > 1 = shotgun.
-- Cost = wall-buy price (ammo costs half). InBox = can come out of the Mystery Box.
Config.Weapons = {
	Pistol = {
		DisplayName = "M9 Pistol", Damage = 35, HeadshotMultiplier = 2.5,
		FireRate = 0.22, Automatic = false, MagSize = 8, ReserveAmmo = 80,
		ReloadTime = 1.4, Range = 300, Spread = 0.6, Pellets = 1, Recoil = 0.9,
		Cost = 500, InBox = false,
		Color = Color3.fromRGB(40, 40, 45), Length = 1.0, TracerColor = Color3.fromRGB(255, 220, 140),
	},
	SMG = {
		DisplayName = "Vector SMG", Damage = 28, HeadshotMultiplier = 2,
		FireRate = 0.075, Automatic = true, MagSize = 32, ReserveAmmo = 256,
		ReloadTime = 1.9, Range = 220, Spread = 2.2, Pellets = 1, Recoil = 0.45,
		Cost = 1200, InBox = true,
		Color = Color3.fromRGB(60, 60, 72), Length = 1.4, TracerColor = Color3.fromRGB(255, 220, 140),
	},
	Shotgun = {
		DisplayName = "Pump Shotgun", Damage = 40, HeadshotMultiplier = 1.5,
		FireRate = 0.85, Automatic = false, MagSize = 6, ReserveAmmo = 48,
		ReloadTime = 2.6, Range = 80, Spread = 6, Pellets = 8, Recoil = 2.2,
		Cost = 1500, InBox = true,
		Color = Color3.fromRGB(95, 62, 38), Length = 2.0, TracerColor = Color3.fromRGB(255, 200, 120),
	},
	Rifle = {
		DisplayName = "Assault Rifle", Damage = 55, HeadshotMultiplier = 2.5,
		FireRate = 0.11, Automatic = true, MagSize = 30, ReserveAmmo = 210,
		ReloadTime = 2.2, Range = 400, Spread = 1.3, Pellets = 1, Recoil = 0.7,
		Cost = 2500, InBox = true,
		Color = Color3.fromRGB(52, 58, 46), Length = 1.9, TracerColor = Color3.fromRGB(255, 220, 140),
	},
	LMG = {
		DisplayName = "Heavy LMG", Damage = 70, HeadshotMultiplier = 2,
		FireRate = 0.09, Automatic = true, MagSize = 100, ReserveAmmo = 400,
		ReloadTime = 4.5, Range = 400, Spread = 2.5, Pellets = 1, Recoil = 0.8,
		Cost = 3000, InBox = true,
		Color = Color3.fromRGB(38, 44, 38), Length = 2.2, TracerColor = Color3.fromRGB(255, 220, 140),
	},
	WonderGun = {
		DisplayName = "Ray Blaster", Damage = 1000, HeadshotMultiplier = 1.5,
		FireRate = 0.35, Automatic = false, MagSize = 20, ReserveAmmo = 160,
		ReloadTime = 2.5, Range = 500, Spread = 0.4, Pellets = 1, Recoil = 1.4,
		Cost = 5000, InBox = true, Neon = true,
		Color = Color3.fromRGB(40, 210, 90), Length = 1.4, TracerColor = Color3.fromRGB(80, 255, 120),
	},
}

-- Mystery Box price
Config.MysteryBoxCost = 950

---------------------------------------------------------------- perks
Config.Perks = {
	ToughBrew = { DisplayName = "Tough Brew", Cost = 2500, MaxHealth = 250, Color = Color3.fromRGB(200, 30, 30), Short = "TB" },
	QuickHands = { DisplayName = "Quick Hands", Cost = 3000, ReloadMultiplier = 0.5, Color = Color3.fromRGB(40, 190, 80), Short = "QH" },
}

---------------------------------------------------------------- sounds (optional)
-- Paste Roblox audio ids like "rbxassetid://1234567890". Empty = silent.
Config.Sounds = {
	Fire = "",
	Reload = "",
	Hitmarker = "",
	Hurt = "",
	RoundStart = "",
	Purchase = "",
}

return Config
]========])
make("ModuleScript", "ZombieMapBuilder", game:GetService('ServerScriptService'), [========[
-- ZombieMapBuilder (ModuleScript) — put in ServerScriptService
-- Builds a starter map (two rooms joined by a buyable door) when workspace has no "ZombieMap".
--
-- Want your own map? Make a Folder/Model called "ZombieMap" in Workspace and add parts with attributes:
--   Zombie spawn : Part named "ZombieSpawn", ~3 studs above the floor, attribute Area = "A" (string)
--   Wall-buy     : Interact = "WallBuy", Weapon = "SMG" (key from ZombieConfig.Weapons), optional Cost
--   Door         : Interact = "Door", Cost = 750, OpensArea = "B"  (spawns in area B wake up when opened)
--   Mystery box  : Interact = "MysteryBox"
--   Perk machine : Interact = "Perk", Perk = "ToughBrew" or "QuickHands"
-- Plus a SpawnLocation for players.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("ZombieConfig"))

local MapBuilder = {}

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function label(adornee, text, color, height)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(220, 56)
	bb.StudsOffset = Vector3.new(0, height or 3, 0)
	bb.MaxDistance = 45
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextStrokeTransparency = 0
	t.Parent = bb
	bb.Parent = adornee
	return bb
end

local function lamp(parent, pos)
	local p = part(parent, "Lamp", Vector3.new(2, 0.6, 2), CFrame.new(pos), Color3.fromRGB(255, 200, 130), Enum.Material.Neon, { CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 34
	light.Brightness = 2.2
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Shadows = true
	light.Parent = p
end

local function burningBarrel(parent, pos)
	local barrel = Instance.new("Part")
	barrel.Name = "BurningBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(3.4, 2.6, 2.6)
	barrel.CFrame = CFrame.new(pos + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	barrel.Anchored = true
	barrel.Color = Color3.fromRGB(60, 45, 35)
	barrel.Material = Enum.Material.CorrodedMetal
	barrel.Parent = parent

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(1.8, 0, 0) -- barrel is rotated: +X is up
	top.Parent = barrel
	local fire = Instance.new("Fire")
	fire.Size = 7
	fire.Heat = 12
	fire.Color = Color3.fromRGB(255, 120, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 40, 0)
	fire.Parent = top
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(40, 30, 30)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 6
	smoke.Size = 4
	smoke.Parent = top
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 60, 0))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.15, 0)
	embers.Lifetime = NumberRange.new(1.5, 3)
	embers.Rate = 25
	embers.Speed = NumberRange.new(4, 9)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0, 2, 0)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Parent = top
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 130, 40)
	light.Range = 28
	light.Brightness = 3
	light.Shadows = true
	light.Parent = top
	barrel:SetAttribute("Flicker", true)
end

local function bloodPool(parent, pos, size)
	local p = Instance.new("Part")
	p.Name = "BloodPool"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.05, size, size)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(math.random(0, 180)), math.rad(90))
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Color = Color3.fromRGB(80, 0, 0)
	p.Material = Enum.Material.Glass
	p.Reflectance = 0.1
	p.Parent = parent
end

local function zombieSpawn(parent, pos, area)
	local p = part(parent, "ZombieSpawn", Vector3.new(2, 1, 2), CFrame.new(pos), Color3.fromRGB(255, 0, 0), nil, {
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	p:SetAttribute("Area", area)
end

local function wallBuy(parent, weapon, pos, size)
	local w = Config.Weapons[weapon]
	local p = part(parent, "WallBuy_" .. weapon, size, CFrame.new(pos), Color3.fromRGB(150, 120, 60), Enum.Material.Wood)
	p:SetAttribute("Interact", "WallBuy")
	p:SetAttribute("Weapon", weapon)
	label(p, w.DisplayName .. "\n" .. w.Cost, Color3.fromRGB(255, 230, 140), 3)
	-- chalk outline glow
	local light = Instance.new("PointLight")
	light.Range = 8
	light.Brightness = 1
	light.Color = Color3.fromRGB(255, 230, 160)
	light.Parent = p
end

function MapBuilder.Build()
	local map = Instance.new("Folder")
	map.Name = "ZombieMap"

	local H = 16
	local wallColor = Color3.fromRGB(92, 82, 72)
	local brick = Enum.Material.Brick

	-- Floors (top surface at y = 0.1 so it never z-fights a default Baseplate)
	part(map, "FloorA", Vector3.new(80, 1, 80), CFrame.new(0, -0.4, 0), Color3.fromRGB(62, 60, 56), Enum.Material.Concrete)
	part(map, "FloorB", Vector3.new(60, 1, 60), CFrame.new(0, -0.4, -70), Color3.fromRGB(78, 58, 40), Enum.Material.WoodPlanks)

	-- Room A walls (x -40..40, z -40..40)
	part(map, "Wall", Vector3.new(84, H, 2), CFrame.new(0, H / 2, 41), wallColor, brick)
	part(map, "Wall", Vector3.new(2, H, 80), CFrame.new(41, H / 2, 0), wallColor, brick)
	part(map, "Wall", Vector3.new(2, H, 80), CFrame.new(-41, H / 2, 0), wallColor, brick)
	part(map, "Wall", Vector3.new(37, H, 2), CFrame.new(-23.5, H / 2, -41), wallColor, brick)
	part(map, "Wall", Vector3.new(37, H, 2), CFrame.new(23.5, H / 2, -41), wallColor, brick)
	part(map, "Wall", Vector3.new(10, H - 12, 2), CFrame.new(0, 12 + (H - 12) / 2, -41), wallColor, brick)

	-- Room B walls (x -30..30, z -100..-40)
	part(map, "Wall", Vector3.new(2, H, 60), CFrame.new(-31, H / 2, -70), wallColor, brick)
	part(map, "Wall", Vector3.new(2, H, 60), CFrame.new(31, H / 2, -70), wallColor, brick)
	part(map, "Wall", Vector3.new(64, H, 2), CFrame.new(0, H / 2, -101), wallColor, brick)

	-- Buyable door between A and B
	local door = part(map, "Door", Vector3.new(10, 12, 1.6), CFrame.new(0, 6, -41), Color3.fromRGB(105, 70, 40), Enum.Material.WoodPlanks)
	door:SetAttribute("Interact", "Door")
	door:SetAttribute("Cost", 750)
	door:SetAttribute("OpensArea", "B")
	label(door, "Door — 750", Color3.fromRGB(255, 255, 255), 7.5)

	-- Cover
	local crate = Color3.fromRGB(110, 85, 55)
	part(map, "Crate", Vector3.new(4, 4, 4), CFrame.new(15, 2.1, 10), crate, Enum.Material.WoodPlanks)
	part(map, "Crate", Vector3.new(6, 4, 3), CFrame.new(-12, 2.1, -15), crate, Enum.Material.WoodPlanks)
	part(map, "Crate", Vector3.new(4, 3, 4), CFrame.new(20, 1.6, -25), crate, Enum.Material.WoodPlanks)
	part(map, "Crate", Vector3.new(8, 4, 3), CFrame.new(-10, 2.1, -65), crate, Enum.Material.WoodPlanks)
	part(map, "Crate", Vector3.new(4, 4, 4), CFrame.new(12, 2.1, -78), crate, Enum.Material.WoodPlanks)

	-- Lights
	for _, pos in { Vector3.new(0, 14, 38), Vector3.new(38, 14, -18), Vector3.new(-38, 14, 18), Vector3.new(0, 14, -98), Vector3.new(28, 14, -60), Vector3.new(-28, 14, -85) } do
		lamp(map, pos)
	end

	-- Player spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.6, 25)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(50, 50, 55)
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Parent = map

	-- Zombie spawns
	zombieSpawn(map, Vector3.new(34, 3.1, 34), "A")
	zombieSpawn(map, Vector3.new(-34, 3.1, 34), "A")
	zombieSpawn(map, Vector3.new(34, 3.1, -34), "A")
	zombieSpawn(map, Vector3.new(-34, 3.1, 5), "A")
	zombieSpawn(map, Vector3.new(24, 3.1, -95), "B")
	zombieSpawn(map, Vector3.new(-24, 3.1, -50), "B")
	zombieSpawn(map, Vector3.new(24, 3.1, -55), "B")

	-- Wall-buys
	wallBuy(map, "SMG", Vector3.new(39.8, 6, 0), Vector3.new(0.4, 3, 5))
	wallBuy(map, "Shotgun", Vector3.new(-39.8, 6, 12), Vector3.new(0.4, 3, 5))
	wallBuy(map, "Rifle", Vector3.new(-29.8, 6, -70), Vector3.new(0.4, 3, 5))

	-- Mystery box
	local box = part(map, "MysteryBox", Vector3.new(6, 3, 3), CFrame.new(18, 1.6, -93), Color3.fromRGB(110, 70, 35), Enum.Material.Wood)
	box:SetAttribute("Interact", "MysteryBox")
	label(box, "? MYSTERY BOX ?\n" .. Config.MysteryBoxCost, Color3.fromRGB(120, 200, 255), 3.5)
	local boxLight = Instance.new("PointLight")
	boxLight.Range = 18
	boxLight.Brightness = 4
	boxLight.Color = Color3.fromRGB(90, 170, 255)
	boxLight.Parent = box
	-- light beam shooting into the sky so you can find the box from anywhere
	local beam = part(map, "BoxBeam", Vector3.new(60, 3, 3), CFrame.new(18, 33, -93) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 170, 255), Enum.Material.Neon, {
		Shape = Enum.PartType.Cylinder, Transparency = 0.75, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	})
	beam:SetAttribute("Pulse", true)

	-- atmosphere: fire barrels, blood, boards on the door
	burningBarrel(map, Vector3.new(-14, 0.1, 6))
	burningBarrel(map, Vector3.new(18, 0.1, -12))
	burningBarrel(map, Vector3.new(-20, 0.1, -80))
	for _ = 1, 14 do
		bloodPool(map, Vector3.new(math.random(-35, 35), 0.13, math.random(-35, 35)), math.random(15, 45) / 10)
	end
	for _ = 1, 6 do
		bloodPool(map, Vector3.new(math.random(-25, 25), 0.13, math.random(-95, -45)), math.random(15, 40) / 10)
	end
	local b1 = part(door, "Board", Vector3.new(11, 0.8, 0.3), door.CFrame * CFrame.new(-0.3, 2.5, 0.95) * CFrame.Angles(0, 0, 0.45), Color3.fromRGB(80, 55, 32), Enum.Material.WoodPlanks, { CanCollide = false })
	local b2 = part(door, "Board", Vector3.new(10, 0.8, 0.3), door.CFrame * CFrame.new(0.4, -2.5, 0.95) * CFrame.Angles(0, 0, -0.35), Color3.fromRGB(80, 55, 32), Enum.Material.WoodPlanks, { CanCollide = false })
	for _, b in { b1, b2 } do
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = door, b
		w.Parent = b
	end

	-- Perk machines
	local function perkMachine(perkId, pos)
		local perk = Config.Perks[perkId]
		local m = part(map, "Perk_" .. perkId, Vector3.new(4, 8, 3), CFrame.new(pos), perk.Color, Enum.Material.Neon)
		m:SetAttribute("Interact", "Perk")
		m:SetAttribute("Perk", perkId)
		label(m, perk.DisplayName .. "\n" .. perk.Cost, Color3.new(1, 1, 1), 5.5)
		local l = Instance.new("PointLight")
		l.Range = 12
		l.Brightness = 2
		l.Color = perk.Color
		l.Parent = m
	end
	perkMachine("ToughBrew", Vector3.new(-33, 4.1, -33))
	perkMachine("QuickHands", Vector3.new(-24, 4.1, -96))

	map.Parent = workspace
	return map
end

return MapBuilder
]========])
make("Script", "ZombieServer", game:GetService('ServerScriptService'), [========[
-- ZombieServer (Script) — put in ServerScriptService
-- Runs the whole game on the server: rounds/waves, zombie AI, shooting (server-validated),
-- points, wall-buys, doors, mystery box, perks, health regen and game over.
-- The client only sends "I pulled the trigger / reload / switch" — it never decides damage or points.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("ZombieConfig"))
local MapBuilder = require(script.Parent:WaitForChild("ZombieMapBuilder"))

local rng = Random.new()

---------------------------------------------------------------- remotes
local function getRemote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local ActionRemote = getRemote("ZombieAction") -- client -> server
local EventRemote = getRemote("ZombieEvent")   -- server -> client

---------------------------------------------------------------- world setup
Players.CharacterAutoLoads = false -- we spawn players ourselves (dead players return next round)
StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

do -- replace Roblox's default health regen with our own (delay + fast regen)
	local scripts = StarterPlayer:FindFirstChildOfClass("StarterCharacterScripts")
	if scripts and not scripts:FindFirstChild("Health") then
		local blank = Instance.new("Script")
		blank.Name = "Health"
		blank.Parent = scripts
	end
end

do -- spooky night lighting
	Lighting.ClockTime = 0.3
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(40, 38, 48)
	Lighting.OutdoorAmbient = Color3.fromRGB(60, 58, 75)
	Lighting.FogColor = Color3.fromRGB(18, 16, 22)
	Lighting.FogStart = 20
	Lighting.FogEnd = 170
	Lighting.FogColor = Color3.fromRGB(28, 6, 8)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.38
		atm.Color = Color3.fromRGB(110, 40, 40)
		atm.Decay = Color3.fromRGB(60, 10, 15)
		atm.Glare = 0.4
		atm.Haze = 1.5
		atm.Parent = Lighting
	end
	-- blood-moon colour grade + glow on neon, eyes, fire and muzzle flashes
	if not Lighting:FindFirstChild("ZombieGrade") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ZombieGrade"
		cc.TintColor = Color3.fromRGB(255, 225, 215)
		cc.Contrast = 0.18
		cc.Saturation = 0.1
		cc.Parent = Lighting
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.9
		bloom.Size = 30
		bloom.Threshold = 0.85
		bloom.Parent = Lighting
	end
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.MoonAngularSize = 40 -- giant moon
	sky.StarCount = 4000
	sky.Parent = Lighting
end

local map = workspace:FindFirstChild("ZombieMap") or MapBuilder.Build()
local mapTemplate = map:Clone()
mapTemplate.Parent = ServerStorage

-- disable spawn locations that aren't part of the zombie map (e.g. the Baseplate template's)
for _, d in workspace:GetDescendants() do
	if d:IsA("SpawnLocation") and not d:IsDescendantOf(map) then
		d.Enabled = false
	end
end

local zombiesFolder = workspace:FindFirstChild("Zombies") or Instance.new("Folder")
zombiesFolder.Name = "Zombies"
zombiesFolder.Parent = workspace

---------------------------------------------------------------- state
local round = 0
local gameActive = false
local gameOverFlag = false
local toSpawn = 0
local aliveZombieCount = 0
local zombies = {}        -- [model] = true
local lockedAreas = {}    -- [area] = true while its door is closed
local spawnPoints = {}
local playerState = {}    -- [player] = state table

local function fillAmmo(st, weapon)
	local c = Config.Weapons[weapon]
	st.ammo[weapon] = { mag = c.MagSize, reserve = c.ReserveAmmo }
end

local function newState()
	local st = {
		weapons = { Config.StartingWeapon },
		slot = 1,
		ammo = {},
		perks = {},
		reloading = false,
		reloadToken = 0,
		lastFire = 0,
		lastHurt = 0,
		lastPrompt = 0,
	}
	fillAmmo(st, Config.StartingWeapon)
	return st
end

local function currentWeapon(st)
	return st.weapons[st.slot]
end

local function sendState(player)
	local st = playerState[player]
	if not st then
		return
	end
	local a = st.ammo[currentWeapon(st)]
	EventRemote:FireClient(player, "State", {
		weapons = table.clone(st.weapons),
		slot = st.slot,
		mag = a and a.mag or 0,
		reserve = a and a.reserve or 0,
		reloading = st.reloading,
		perks = table.clone(st.perks),
	})
end

local function announce(text, duration, player)
	if player then
		EventRemote:FireClient(player, "Announce", text, duration or 3)
	else
		EventRemote:FireAllClients("Announce", text, duration or 3)
	end
end

local function getStat(player, name)
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild(name)
end

local function addPoints(player, n)
	local s = getStat(player, "Points")
	if s then
		s.Value += n
	end
end

local function spend(player, cost)
	local s = getStat(player, "Points")
	if s and s.Value >= cost then
		s.Value -= cost
		return true
	end
	announce("Not enough points (" .. cost .. ")", 1.5, player)
	return false
end

local function getAliveCharacter(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart") then
		return char, hum
	end
	return nil
end

local function anyoneAlive()
	for _, p in Players:GetPlayers() do
		if getAliveCharacter(p) then
			return true
		end
	end
	return false
end

local function checkGameOver()
	if gameActive and not anyoneAlive() then
		gameOverFlag = true
	end
end

local function updateZombiesLeft()
	ReplicatedStorage:SetAttribute("ZombiesLeft", toSpawn + aliveZombieCount)
end

local function setRound(n)
	round = n
	ReplicatedStorage:SetAttribute("Round", n)
end

---------------------------------------------------------------- players
local function onCharacterAdded(player, char)
	local hum = char:WaitForChild("Humanoid")
	local st = playerState[player]
	if not st then
		return
	end
	hum.MaxHealth = st.perks.ToughBrew and Config.Perks.ToughBrew.MaxHealth or Config.PlayerMaxHealth
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = Config.WalkSpeed
	hum.Died:Connect(function()
		-- going down costs you your guns and perks (you keep your points)
		playerState[player] = newState()
		sendState(player)
		announce("You went down! You'll respawn next round.", 4, player)
		checkGameOver()
	end)
	sendState(player)
end

local function spawnPlayer(player)
	if player.Parent ~= Players then
		return
	end
	playerState[player] = playerState[player] or newState()
	player:LoadCharacter()
end

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Value = Config.StartingPoints
	points.Parent = ls
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = ls
	ls.Parent = player

	player.CameraMode = Enum.CameraMode.LockFirstPerson
	playerState[player] = newState()
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	task.defer(spawnPlayer, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end
Players.PlayerRemoving:Connect(function(player)
	playerState[player] = nil
	task.defer(checkGameOver)
end)

-- health regeneration
task.spawn(function()
	while true do
		local dt = task.wait(0.25)
		local now = os.clock()
		for p, st in playerState do
			local _, hum = getAliveCharacter(p)
			if hum and hum.Health < hum.MaxHealth and now - st.lastHurt >= Config.PlayerRegenDelay then
				hum.Health = math.min(hum.MaxHealth, hum.Health + Config.PlayerRegenRate * dt)
			end
		end
	end
end)

---------------------------------------------------------------- weapons
local function giveWeapon(player, weapon)
	local st = playerState[player]
	local idx = table.find(st.weapons, weapon)
	if idx then
		st.slot = idx
	elseif #st.weapons < Config.MaxWeapons then
		table.insert(st.weapons, weapon)
		st.slot = #st.weapons
	else
		st.ammo[st.weapons[st.slot]] = nil
		st.weapons[st.slot] = weapon
	end
	fillAmmo(st, weapon)
	st.reloading = false
	st.reloadToken += 1
	sendState(player)
end

local function startReload(player)
	local st = playerState[player]
	local weapon = currentWeapon(st)
	local c = Config.Weapons[weapon]
	local a = st.ammo[weapon]
	if st.reloading or not a or a.mag >= c.MagSize or a.reserve <= 0 then
		return
	end
	st.reloading = true
	st.reloadToken += 1
	local token = st.reloadToken
	sendState(player)
	local t = c.ReloadTime * (st.perks.QuickHands and Config.Perks.QuickHands.ReloadMultiplier or 1)
	task.delay(t, function()
		if playerState[player] ~= st or st.reloadToken ~= token then
			return -- switched weapon, died or left
		end
		local take = math.min(c.MagSize - a.mag, a.reserve)
		a.mag += take
		a.reserve -= take
		st.reloading = false
		sendState(player)
	end)
end

local function spreadDirection(dir, degrees)
	if degrees <= 0 then
		return dir
	end
	local cf = CFrame.lookAt(Vector3.zero, dir)
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local roll = rng:NextNumber() * math.pi * 2
	return (cf * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function zombieFromPart(inst)
	local model = inst:FindFirstAncestorOfClass("Model")
	if model and zombies[model] then
		return model, model:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

local function damageZombie(player, model, hum, damage, isHead)
	if hum.Health <= 0 then
		return false
	end
	hum:TakeDamage(damage)
	if hum.Health <= 0 then
		if not model:GetAttribute("Killed") then
			model:SetAttribute("Killed", true)
			if isHead then
				-- pop the head off
				local headPart = model:FindFirstChild("Head")
				if headPart then
					EventRemote:FireAllClients("Gore", headPart.Position)
					for _, name in { "Head", "LeftEye", "RightEye", "Mouth" } do
						local p = model:FindFirstChild(name)
						if p then
							p.Transparency = 1
						end
					end
				end
			end
			addPoints(player, isHead and Config.PointsPerHeadshotKill or Config.PointsPerKill)
			local kills = getStat(player, "Kills")
			if kills then
				kills.Value += 1
			end
		end
		return true
	end
	addPoints(player, Config.PointsPerHit)
	return false
end

local function onFire(player, st, origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	local mag = direction.Magnitude
	if not (mag > 0.01 and mag < 1e6) then
		return -- also rejects NaN
	end
	direction = direction / mag

	local char = getAliveCharacter(player)
	if not char or st.reloading then
		return
	end
	local weapon = currentWeapon(st)
	local c = Config.Weapons[weapon]
	local a = st.ammo[weapon]
	local now = os.clock()
	if not c or not a or a.mag <= 0 or now - st.lastFire < c.FireRate * 0.75 then
		return -- empty, or firing faster than the gun allows
	end
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	if not ((origin - head.Position).Magnitude <= 8) then
		origin = head.Position -- don't let clients shoot from somewhere else
	end

	st.lastFire = now
	a.mag -= 1

	local exclude = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	local hit, kill, headshot = false, false, false
	local endPoints, bloodPoints = {}, {}
	for _ = 1, c.Pellets or 1 do
		local dir = spreadDirection(direction, c.Spread)
		local result = workspace:Raycast(origin, dir * c.Range, params)
		table.insert(endPoints, result and result.Position or origin + dir * c.Range)
		if result then
			local model, hum = zombieFromPart(result.Instance)
			if model and hum and hum.Health > 0 then
				local isHead = result.Instance.Name == "Head"
				local dmg = c.Damage * (isHead and c.HeadshotMultiplier or 1)
				hit = true
				headshot = headshot or isHead
				table.insert(bloodPoints, result.Position)
				if damageZombie(player, model, hum, dmg, isHead) then
					kill = true
				end
			end
		end
	end

	if hit then
		EventRemote:FireClient(player, "Hit", kill, headshot)
	end
	EventRemote:FireAllClients("Shot", player, origin, endPoints, weapon, bloodPoints)
	sendState(player)
end

ActionRemote.OnServerEvent:Connect(function(player, action, arg1, arg2)
	local st = playerState[player]
	if not st then
		return
	end
	if action == "Fire" then
		onFire(player, st, arg1, arg2)
	elseif action == "Reload" then
		if getAliveCharacter(player) then
			startReload(player)
		end
	elseif action == "Switch" then
		if typeof(arg1) == "number" and st.weapons[arg1] and arg1 ~= st.slot then
			st.slot = arg1
			st.reloading = false
			st.reloadToken += 1
			sendState(player)
		end
	end
end)

---------------------------------------------------------------- interactables
local function makePrompt(part, action, object)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = part
	return p
end

local function canUse(player)
	local st = playerState[player]
	if not st or not getAliveCharacter(player) then
		return nil
	end
	local now = os.clock()
	if now - st.lastPrompt < 0.3 then
		return nil
	end
	st.lastPrompt = now
	return st
end

local function setupWallBuy(part)
	local weapon = part:GetAttribute("Weapon")
	local c = Config.Weapons[weapon]
	if not c then
		warn("WallBuy has unknown Weapon attribute:", weapon)
		return
	end
	local cost = part:GetAttribute("Cost") or c.Cost
	local ammoCost = math.floor(cost / 2)
	local prompt = makePrompt(part, "Buy " .. c.DisplayName, cost .. " pts  (ammo " .. ammoCost .. ")")
	prompt.Triggered:Connect(function(player)
		local st = canUse(player)
		if not st then
			return
		end
		if table.find(st.weapons, weapon) then
			if spend(player, ammoCost) then
				fillAmmo(st, weapon)
				sendState(player)
				EventRemote:FireClient(player, "Purchase")
			end
		elseif spend(player, cost) then
			giveWeapon(player, weapon)
			EventRemote:FireClient(player, "Purchase")
		end
	end)
end

local function setupDoor(part)
	local cost = part:GetAttribute("Cost") or 750
	local area = part:GetAttribute("OpensArea")
	if area then
		lockedAreas[area] = true
	end
	local prompt = makePrompt(part, "Open Door", cost .. " pts")
	prompt.Triggered:Connect(function(player)
		if not canUse(player) or not spend(player, cost) then
			return
		end
		prompt:Destroy()
		if area then
			lockedAreas[area] = nil
		end
		announce(player.DisplayName .. " opened a door!", 2)
		EventRemote:FireClient(player, "Purchase")
		part.CanCollide = false
		for _, d in part:GetDescendants() do
			if d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
		TweenService:Create(part, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		Debris:AddItem(part, 0.7)
	end)
end

local function setupMysteryBox(part)
	local busy = false
	local prompt = makePrompt(part, "Mystery Box", Config.MysteryBoxCost .. " pts")
	prompt.Triggered:Connect(function(player)
		local st = canUse(player)
		if busy or not st or not spend(player, Config.MysteryBoxCost) then
			return
		end
		busy = true
		prompt.Enabled = false
		EventRemote:FireClient(player, "Purchase")
		local pool, fallback = {}, {}
		for name, c in Config.Weapons do
			if c.InBox then
				table.insert(fallback, name)
				if not table.find(st.weapons, name) then
					table.insert(pool, name)
				end
			end
		end
		if #pool == 0 then
			pool = fallback
		end
		local weapon = pool[rng:NextInteger(1, #pool)]
		announce("Mystery Box...", 1.5, player)
		task.wait(1.5)
		if playerState[player] and getAliveCharacter(player) then
			giveWeapon(player, weapon)
			announce("You got the " .. Config.Weapons[weapon].DisplayName .. "!", 2.5, player)
		end
		busy = false
		if prompt.Parent then
			prompt.Enabled = true
		end
	end)
end

local function setupPerk(part)
	local perkId = part:GetAttribute("Perk")
	local perk = Config.Perks[perkId]
	if not perk then
		warn("Perk machine has unknown Perk attribute:", perkId)
		return
	end
	local prompt = makePrompt(part, "Drink " .. perk.DisplayName, perk.Cost .. " pts")
	prompt.Triggered:Connect(function(player)
		local st = canUse(player)
		if not st then
			return
		end
		if st.perks[perkId] then
			announce("You already have " .. perk.DisplayName, 1.5, player)
			return
		end
		if not spend(player, perk.Cost) then
			return
		end
		st.perks[perkId] = true
		if perk.MaxHealth then
			local _, hum = getAliveCharacter(player)
			if hum then
				hum.MaxHealth = perk.MaxHealth
				hum.Health = perk.MaxHealth
			end
		end
		sendState(player)
		EventRemote:FireClient(player, "Purchase")
		announce(perk.DisplayName .. " acquired!", 2, player)
	end)
end

local function setupMap(m)
	lockedAreas = {}
	spawnPoints = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "ZombieSpawn" then
				table.insert(spawnPoints, d)
			end
			local kind = d:GetAttribute("Interact")
			if kind == "WallBuy" then
				setupWallBuy(d)
			elseif kind == "Door" then
				setupDoor(d)
			elseif kind == "MysteryBox" then
				setupMysteryBox(d)
			elseif kind == "Perk" then
				setupPerk(d)
			end
		end
	end
	if #spawnPoints == 0 then
		warn("ZombieMap has no parts named ZombieSpawn — zombies cannot spawn!")
	end
end

---------------------------------------------------------------- zombies
local SKIN = { Color3.fromRGB(110, 140, 90), Color3.fromRGB(125, 150, 105), Color3.fromRGB(95, 120, 85) }
local SHIRTS = { Color3.fromRGB(80, 40, 35), Color3.fromRGB(45, 55, 70), Color3.fromRGB(70, 65, 50), Color3.fromRGB(40, 40, 40) }
local PANTS = { Color3.fromRGB(35, 40, 60), Color3.fromRGB(55, 45, 35), Color3.fromRGB(30, 30, 30) }

local function buildZombie()
	local model = Instance.new("Model")
	model.Name = "Zombie"
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local shirt = SHIRTS[rng:NextInteger(1, #SHIRTS)]
	local pants = PANTS[rng:NextInteger(1, #PANTS)]

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	model.PrimaryPart = root

	-- welded part (no animation): attached rigidly to `base`
	local function welded(base, name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.Massless = true
		p.CFrame = base.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end

	-- jointed limb: a Motor6D the clients animate (walk cycle) through Motor6D.Transform.
	-- c0 = joint position on the root, c1 = joint position on the limb.
	local function jointed(name, size, c0, c1, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.Massless = true
		p.CFrame = root.CFrame * c0 * c1:Inverse()
		local m = Instance.new("Motor6D")
		m.Name = name .. "Joint"
		m.Part0 = root
		m.Part1 = p
		m.C0 = c0
		m.C1 = c1
		m.Parent = root
		p.Parent = model
		return p
	end

	local torso = welded(root, "Torso", Vector3.new(2, 2, 1), CFrame.new(), shirt, Enum.Material.Fabric)
	welded(torso, "Blood", Vector3.new(rng:NextNumber(0.5, 1), rng:NextNumber(0.5, 1), 0.05), CFrame.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4), -0.52), Color3.fromRGB(100, 0, 0), Enum.Material.Glass)

	local tilt = CFrame.Angles(math.rad(rng:NextNumber(-18, 8)), math.rad(rng:NextNumber(-15, 15)), math.rad(rng:NextNumber(-15, 15)))
	local head = jointed("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1, 0) * tilt, CFrame.new(0, -0.6, 0), skin)
	welded(head, "LeftEye", Vector3.new(0.25, 0.15, 0.1), CFrame.new(-0.25, 0.15, -0.6), Color3.fromRGB(255, 40, 20), Enum.Material.Neon)
	welded(head, "RightEye", Vector3.new(0.25, 0.15, 0.1), CFrame.new(0.25, 0.15, -0.6), Color3.fromRGB(255, 40, 20), Enum.Material.Neon)
	welded(head, "Mouth", Vector3.new(0.6, 0.18, 0.08), CFrame.new(0, -0.3, -0.6), Color3.fromRGB(35, 0, 0))
	-- arms reaching forward (shoulder joint at the back end of the arm)
	jointed("LeftArm", Vector3.new(0.9, 0.9, 2.2), CFrame.new(-1.45, 0.6, 0.2), CFrame.new(0, 0, 1.1), skin)
	jointed("RightArm", Vector3.new(0.9, 0.9, 2.2), CFrame.new(1.45, 0.45, 0.25), CFrame.new(0, 0, 1.1), skin)
	-- legs (hip joint at the top of the leg)
	jointed("LeftLeg", Vector3.new(0.95, 2, 1), CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0), pants, Enum.Material.Fabric)
	jointed("RightLeg", Vector3.new(0.95, 2, 1), CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0), pants, Enum.Material.Fabric)

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 2
	hum.AutomaticScalingEnabled = false
	hum.RequiresNeck = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	hum.Parent = model

	return model, root, hum
end

local function nearestTarget(pos)
	local best, bestDist, bestHum, bestChar = nil, math.huge, nil, nil
	for _, p in Players:GetPlayers() do
		local char, hum = getAliveCharacter(p)
		if char then
			local root = char.HumanoidRootPart
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist, bestHum, bestChar = root, d, hum, char
			end
		end
	end
	return best, bestDist, bestHum, bestChar
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(fromPos, toPos, targetChar)
	losParams.FilterDescendantsInstances = { zombiesFolder, targetChar }
	return workspace:Raycast(fromPos, toPos - fromPos, losParams) == nil
end

local function runZombie(model, root, hum)
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
	local waypoints, wpIndex, lastPath, lastAttack = nil, 0, 0, 0
	while hum.Health > 0 and model.Parent do
		local targetRoot, dist, targetHum, targetChar = nearestTarget(root.Position)
		if not targetRoot then
			hum:MoveTo(root.Position)
			task.wait(0.5)
			continue
		end
		local now = os.clock()
		if dist <= Config.ZombieAttackRange then
			hum:MoveTo(targetRoot.Position)
			waypoints = nil
			if now - lastAttack >= Config.ZombieAttackCooldown then
				lastAttack = now
				targetHum:TakeDamage(Config.ZombieDamage)
				local p = Players:GetPlayerFromCharacter(targetChar)
				if p and playerState[p] then
					playerState[p].lastHurt = now
					EventRemote:FireClient(p, "Hurt")
				end
			end
		elseif hasLineOfSight(root.Position, targetRoot.Position, targetChar) then
			hum:MoveTo(targetRoot.Position)
			waypoints = nil
		else
			if not waypoints or now - lastPath > 1 then
				lastPath = now
				local ok = pcall(function()
					path:ComputeAsync(root.Position, targetRoot.Position)
				end)
				if ok and path.Status == Enum.PathStatus.Success then
					waypoints = path:GetWaypoints()
					wpIndex = 2
				else
					waypoints = nil
				end
			end
			local wp = waypoints and waypoints[wpIndex]
			if wp then
				local flat = Vector3.new(wp.Position.X, root.Position.Y, wp.Position.Z)
				if (flat - root.Position).Magnitude < 3 then
					wpIndex += 1
					wp = waypoints[wpIndex]
				end
			end
			hum:MoveTo(wp and wp.Position or targetRoot.Position)
		end
		task.wait(0.15)
	end
end

local function chooseSpawn()
	local open, far = {}, {}
	for _, sp in spawnPoints do
		if sp.Parent and not lockedAreas[sp:GetAttribute("Area") or "A"] then
			table.insert(open, sp)
			local _, d = nearestTarget(sp.Position)
			if d >= Config.MinSpawnDistance then
				table.insert(far, sp)
			end
		end
	end
	local list = #far > 0 and far or open
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

local function spawnZombie()
	local sp = chooseSpawn()
	if not sp then
		return false
	end
	local model, root, hum = buildZombie()
	hum.MaxHealth = Config.ZombieHealth(round)
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = Config.ZombieSpeed(round) * rng:NextNumber(0.85, 1.15)
	local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
	model:PivotTo(CFrame.new(sp.Position + offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = zombiesFolder
	root:SetNetworkOwner(nil)

	zombies[model] = true
	aliveZombieCount += 1
	hum.Died:Connect(function()
		if zombies[model] then
			zombies[model] = nil
			aliveZombieCount -= 1
			updateZombiesLeft()
		end
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") then
				d.CanQuery = false -- corpses don't soak up bullets
				if d ~= root then
					d.CanCollide = true
					d.Massless = false
				end
			end
		end
		Debris:AddItem(model, 4)
	end)
	task.spawn(runZombie, model, root, hum)
	return true
end

local function clearZombies()
	for model in zombies do
		model:Destroy()
	end
	zombies = {}
	aliveZombieCount = 0
	toSpawn = 0
	zombiesFolder:ClearAllChildren()
	updateZombiesLeft()
end

---------------------------------------------------------------- game loop
local function resetGame()
	clearZombies()
	map:Destroy()
	map = mapTemplate:Clone()
	map.Parent = workspace
	setupMap(map)
	setRound(0)
	for _, p in Players:GetPlayers() do
		local points, kills = getStat(p, "Points"), getStat(p, "Kills")
		if points then
			points.Value = Config.StartingPoints
		end
		if kills then
			kills.Value = 0
		end
		playerState[p] = newState()
		spawnPlayer(p)
	end
end

setupMap(map)
setRound(0)

while true do
	while #Players:GetPlayers() == 0 do
		task.wait(1)
	end

	resetGame()
	gameActive = true
	gameOverFlag = false

	for i = Config.FirstRoundDelay, 1, -1 do
		announce("Zombies incoming in " .. i, 1.1)
		task.wait(1)
	end

	while not gameOverFlag do
		setRound(round + 1)
		for _, p in Players:GetPlayers() do
			if not getAliveCharacter(p) then
				spawnPlayer(p)
			end
		end
		announce("ROUND " .. round, 3)
		EventRemote:FireAllClients("RoundStart", round)

		toSpawn = Config.ZombiesForRound(round, #Players:GetPlayers())
		updateZombiesLeft()
		local lastSpawn = 0
		while (toSpawn > 0 or aliveZombieCount > 0) and not gameOverFlag do
			if toSpawn > 0 and aliveZombieCount < Config.MaxZombiesAlive and os.clock() - lastSpawn >= Config.SpawnInterval(round) then
				if spawnZombie() then
					toSpawn -= 1
					lastSpawn = os.clock()
					updateZombiesLeft()
				end
			end
			if not anyoneAlive() then
				gameOverFlag = true
			end
			task.wait(0.1)
		end

		if gameOverFlag then
			break
		end
		announce("Round " .. round .. " survived!", 3)
		task.wait(Config.IntermissionTime)
	end

	gameActive = false
	local survived = math.max(round - 1, 0)
	announce(("GAME OVER\nYou survived %d round%s"):format(survived, survived == 1 and "" or "s"), 7)
	task.wait(8)
end
]========])
make("LocalScript", "ZombieClient", game:GetService('StarterPlayer'):WaitForChild('StarterPlayerScripts'), [========[
-- ZombieClient (LocalScript) — put in StarterPlayer > StarterPlayerScripts
-- First-person gun viewmodel, shooting input, tracers, HUD (round, points, ammo, health), hitmarkers.
-- Controls: Mouse1 shoot · R reload · 1/2 or mouse wheel switch gun · Shift sprint · E buy

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Config = require(ReplicatedStorage:WaitForChild("ZombieConfig"))
local ActionRemote = ReplicatedStorage:WaitForChild("ZombieAction")
local EventRemote = ReplicatedStorage:WaitForChild("ZombieEvent")

local rng = Random.new()
local state = { weapons = {}, slot = 1, mag = 0, reserve = 0, reloading = false, perks = {} }
local firing, wantShot, sprinting = false, false, false
local lastShot = 0
local recoil, reloadBlend, bobBlend = 0, 0, 0
local currentVM = nil -- weapon name the viewmodel was built for
local shake = 0 -- camera shake amount
local function addShake(amount)
	shake = math.min(shake + amount, 1.2)
end

---------------------------------------------------------------- sounds
local function playSound(id, volume)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.Parent = camera
	s:Play()
	Debris:AddItem(s, 5)
end

---------------------------------------------------------------- HUD
local okFont, horrorFont = pcall(function()
	return Enum.Font.Creepster
end)
if not okFont then
	horrorFont = Enum.Font.GothamBlack
end

local gui = Instance.new("ScreenGui")
gui.Name = "ZombieHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function newLabel(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextStrokeTransparency = 0.3
	for k, v in props do
		l[k] = v
	end
	l.Parent = props.Parent or gui
	return l
end

local function newFrame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	f.Parent = props.Parent or gui
	return f
end

local damageOverlay = newFrame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 0, 0), BackgroundTransparency = 1, ZIndex = 0 })

local roundLabel = newLabel({ Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(160, 90), Text = "", TextColor3 = Color3.fromRGB(175, 10, 10), Font = horrorFont, TextXAlignment = Enum.TextXAlignment.Left })
local zombiesLabel = newLabel({ Position = UDim2.fromOffset(26, 104), Size = UDim2.fromOffset(220, 22), Text = "", TextColor3 = Color3.fromRGB(220, 200, 200), TextXAlignment = Enum.TextXAlignment.Left })

local pointsLabel = newLabel({ Position = UDim2.new(0, 24, 1, -118), Size = UDim2.fromOffset(260, 40), Text = "0", TextColor3 = Color3.fromRGB(255, 230, 140), TextXAlignment = Enum.TextXAlignment.Left })
local perksLabel = newLabel({ Position = UDim2.new(0, 24, 1, -150), Size = UDim2.fromOffset(260, 26), Text = "", RichText = true, TextXAlignment = Enum.TextXAlignment.Left })
local healthBack = newFrame({ Position = UDim2.new(0, 24, 1, -66), Size = UDim2.fromOffset(260, 14), BackgroundColor3 = Color3.fromRGB(25, 20, 20), BackgroundTransparency = 0.2 })
local healthFill = newFrame({ Parent = healthBack, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 200, 80) })

local ammoLabel = newLabel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 1, -122), Size = UDim2.fromOffset(280, 52), Text = "", TextXAlignment = Enum.TextXAlignment.Right })
local weaponLabel = newLabel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 1, -68), Size = UDim2.fromOffset(360, 24), Text = "", RichText = true, TextXAlignment = Enum.TextXAlignment.Right })

local reloadLabel = newLabel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 40), Size = UDim2.fromOffset(300, 26), Text = "", TextColor3 = Color3.fromRGB(255, 220, 120) })
local announceLabel = newLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.28), Size = UDim2.fromOffset(820, 90), Text = "", TextTransparency = 1, TextStrokeTransparency = 1 })

-- crosshair: 4 bars around the screen center
local crossBars = {}
for i = 1, 4 do
	crossBars[i] = newFrame({ AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.15 })
end
local function layoutCrosshair(gap)
	crossBars[1].Size, crossBars[1].Position = UDim2.fromOffset(2, 10), UDim2.new(0.5, 0, 0.5, -gap - 5)
	crossBars[2].Size, crossBars[2].Position = UDim2.fromOffset(2, 10), UDim2.new(0.5, 0, 0.5, gap + 5)
	crossBars[3].Size, crossBars[3].Position = UDim2.fromOffset(10, 2), UDim2.new(0.5, -gap - 5, 0.5, 0)
	crossBars[4].Size, crossBars[4].Position = UDim2.fromOffset(10, 2), UDim2.new(0.5, gap + 5, 0.5, 0)
end

-- hitmarker: an X
local hitmarker = newFrame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Visible = false })
local hitBars = {}
for i, rot in { 45, -45 } do
	hitBars[i] = newFrame({ Parent = hitmarker, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 26), Rotation = rot, BackgroundColor3 = Color3.new(1, 1, 1) })
end

local announceToken = 0
local function announce(text, duration)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = text
	announceLabel.TextTransparency = 0
	announceLabel.TextStrokeTransparency = 0.2
	task.delay(duration or 3, function()
		if token == announceToken then
			TweenService:Create(announceLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function pointsPopup(diff)
	local l = newLabel({
		Position = UDim2.new(0, 150, 1, -118), Size = UDim2.fromOffset(120, 30),
		Text = (diff > 0 and "+" or "") .. diff,
		TextColor3 = diff > 0 and Color3.fromRGB(255, 230, 140) or Color3.fromRGB(255, 90, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	TweenService:Create(l, TweenInfo.new(0.8), {
		Position = UDim2.new(0, 150 + rng:NextInteger(0, 40), 1, -170),
		TextTransparency = 1, TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(l, 0.9)
end

local function updateHUD()
	local name = state.weapons[state.slot]
	local c = name and Config.Weapons[name]
	if c then
		ammoLabel.Text = state.mag .. "  /  " .. state.reserve
		ammoLabel.TextColor3 = state.mag == 0 and Color3.fromRGB(255, 80, 80) or Color3.new(1, 1, 1)
		local parts = {}
		for i, w in state.weapons do
			local wc = Config.Weapons[w]
			local text = "[" .. i .. "] " .. (wc and wc.DisplayName or w)
			if i == state.slot then
				text = '<font color="#FFE68C">' .. text .. "</font>"
			else
				text = '<font color="#9A9A9A">' .. text .. "</font>"
			end
			table.insert(parts, text)
		end
		weaponLabel.Text = table.concat(parts, "   ")
	else
		ammoLabel.Text = ""
		weaponLabel.Text = ""
	end

	if state.reloading then
		reloadLabel.Text = "RELOADING..."
	elseif c and state.mag == 0 then
		reloadLabel.Text = state.reserve > 0 and "PRESS R TO RELOAD" or "NO AMMO — BUY MORE"
	elseif c and state.mag <= math.ceil(c.MagSize * 0.25) and state.reserve > 0 then
		reloadLabel.Text = "LOW AMMO"
	else
		reloadLabel.Text = ""
	end

	local perkText = {}
	for id in state.perks do
		local p = Config.Perks[id]
		if p then
			table.insert(perkText, ('<font color="#%s">■ %s</font>'):format(p.Color:ToHex(), p.DisplayName))
		end
	end
	perksLabel.Text = table.concat(perkText, "  ")
end

---------------------------------------------------------------- leaderstats / round
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local points = ls:WaitForChild("Points")
	local last = points.Value
	pointsLabel.Text = tostring(points.Value)
	points.Changed:Connect(function(v)
		pointsLabel.Text = tostring(v)
		if v ~= last then
			pointsPopup(v - last)
		end
		last = v
	end)
end)

local function updateRound()
	local r = ReplicatedStorage:GetAttribute("Round") or 0
	roundLabel.Text = r > 0 and tostring(r) or ""
	local left = ReplicatedStorage:GetAttribute("ZombiesLeft") or 0
	zombiesLabel.Text = r > 0 and ("Zombies: " .. left) or ""
end
ReplicatedStorage:GetAttributeChangedSignal("Round"):Connect(updateRound)
ReplicatedStorage:GetAttributeChangedSignal("ZombiesLeft"):Connect(updateRound)
updateRound()

---------------------------------------------------------------- health
local function getHumanoid()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return hum
	end
	return nil
end

local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	local lastHealth = hum.Health
	local function refresh()
		local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		healthFill.Size = UDim2.fromScale(frac, 1)
		healthFill.BackgroundColor3 = Color3.fromRGB(220, 50, 40):Lerp(Color3.fromRGB(70, 200, 80), frac)
		damageOverlay.BackgroundTransparency = 1 - (1 - frac) * 0.45
		if hum.Health < lastHealth then
			damageOverlay.BackgroundTransparency = 0.45
			TweenService:Create(damageOverlay, TweenInfo.new(0.5), { BackgroundTransparency = 1 - (1 - frac) * 0.45 }):Play()
		end
		lastHealth = hum.Health
	end
	hum.HealthChanged:Connect(refresh)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(refresh)
	refresh()
	UserInputService.MouseIconEnabled = false
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

---------------------------------------------------------------- viewmodel
local VM_OFFSET = CFrame.new(0.75, -0.7, -1.5)
local vmFolder = Instance.new("Folder")
vmFolder.Name = "Viewmodel"
vmFolder.Parent = camera
local vmParts = {} -- { part, offset }
local muzzle, muzzleLight

local function clearViewmodel()
	vmFolder:ClearAllChildren()
	vmParts = {}
	muzzle, muzzleLight = nil, nil
end

local function vmPart(name, size, offset, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = vmFolder
	table.insert(vmParts, { p, offset })
	return p
end

local function buildViewmodel(weaponName)
	clearViewmodel()
	currentVM = weaponName
	local c = weaponName and Config.Weapons[weaponName]
	if not c then
		return
	end
	local L = c.Length or 1.4
	local bodyMat = c.Neon and Enum.Material.Neon or Enum.Material.Metal
	local dark = c.Color:Lerp(Color3.new(0, 0, 0), 0.45)
	vmPart("Body", Vector3.new(0.35, 0.4, L), CFrame.new(), c.Color, bodyMat)
	vmPart("Barrel", Vector3.new(0.15, 0.15, L * 0.5), CFrame.new(0, 0.08, -L * 0.62), dark)
	vmPart("Sight", Vector3.new(0.1, 0.12, 0.2), CFrame.new(0, 0.25, -L * 0.3), dark)
	vmPart("Grip", Vector3.new(0.25, 0.55, 0.3), CFrame.new(0, -0.38, L * 0.28) * CFrame.Angles(math.rad(-15), 0, 0), dark)
	vmPart("Mag", Vector3.new(0.22, 0.5, 0.3), CFrame.new(0, -0.38, -L * 0.08), dark)
	local skin = Color3.fromRGB(205, 160, 125)
	local char = player.Character
	local bodyColors = char and char:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		skin = bodyColors.RightArmColor3
	end
	vmPart("Hand", Vector3.new(0.32, 0.32, 1.1), CFrame.new(0.05, -0.45, L * 0.28 + 0.55), skin, Enum.Material.SmoothPlastic)
	vmPart("Sleeve", Vector3.new(0.4, 0.4, 1.4), CFrame.new(0.05, -0.5, L * 0.28 + 1.6), Color3.fromRGB(45, 50, 40), Enum.Material.Fabric)
	muzzle = vmPart("Muzzle", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 0.08, -L * 0.9), Color3.fromRGB(255, 210, 110), Enum.Material.Neon, 1)
	muzzleLight = Instance.new("PointLight")
	muzzleLight.Range = 14
	muzzleLight.Brightness = 4
	muzzleLight.Color = Color3.fromRGB(255, 190, 110)
	muzzleLight.Enabled = false
	muzzleLight.Parent = muzzle
end

local function flashMuzzle()
	if not muzzle then
		return
	end
	muzzle.Transparency = 0.1
	muzzleLight.Enabled = true
	task.delay(0.045, function()
		if muzzle then
			muzzle.Transparency = 1
			muzzleLight.Enabled = false
		end
	end)
end

---------------------------------------------------------------- tracers
local function tracer(from, to, color)
	local dist = (to - from).Magnitude
	if dist < 0.5 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color or Color3.fromRGB(255, 220, 140)
	p.Transparency = 0.35
	p.Size = Vector3.new(0.07, 0.07, dist)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.09), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.1)
end

local function spreadDirection(dir, degrees)
	if degrees <= 0 then
		return dir
	end
	local cf = CFrame.lookAt(Vector3.zero, dir)
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	return (cf * CFrame.Angles(0, 0, rng:NextNumber() * math.pi * 2) * CFrame.Angles(angle, 0, 0)).LookVector
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

---------------------------------------------------------------- actions
local lastReloadRequest = 0
local function requestReload()
	local c = Config.Weapons[state.weapons[state.slot] or ""]
	if os.clock() - lastReloadRequest < 0.5 then
		return
	end
	if c and not state.reloading and state.mag < c.MagSize and state.reserve > 0 then
		lastReloadRequest = os.clock()
		ActionRemote:FireServer("Reload")
		playSound(Config.Sounds.Reload, 0.5)
	end
end

local function switchTo(slot)
	if state.weapons[slot] and slot ~= state.slot then
		ActionRemote:FireServer("Switch", slot)
	end
end

-- returns true when the queued shot is "used up" (fired, or impossible)
local function tryFire()
	local name = state.weapons[state.slot]
	local c = name and Config.Weapons[name]
	if not c or not getHumanoid() then
		return true
	end
	if state.reloading then
		return false
	end
	if state.mag <= 0 then
		requestReload()
		return true
	end
	local now = os.clock()
	if now - lastShot < c.FireRate then
		return false
	end
	lastShot = now
	state.mag -= 1
	updateHUD()

	local origin = camera.CFrame.Position
	local dir = camera.CFrame.LookVector
	ActionRemote:FireServer("Fire", origin, dir)

	recoil = math.min(recoil + (c.Recoil or 1), 3)
	addShake(0.18 * (c.Recoil or 1))
	flashMuzzle()
	playSound(Config.Sounds.Fire, 0.5)

	rayParams.FilterDescendantsInstances = { player.Character, camera }
	local from = muzzle and muzzle.Position or origin
	for _ = 1, c.Pellets or 1 do
		local d = spreadDirection(dir, c.Spread)
		local result = workspace:Raycast(origin, d * c.Range, rayParams)
		tracer(from, result and result.Position or origin + d * c.Range, c.TracerColor)
	end
	return true
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = true
		wantShot = true
	elseif input.KeyCode == Enum.KeyCode.R then
		requestReload()
	elseif input.KeyCode == Enum.KeyCode.One then
		switchTo(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		switchTo(2)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
	end
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel or #state.weapons < 2 then
		return
	end
	local n = #state.weapons
	local nextSlot = ((state.slot - 1 + (input.Position.Z > 0 and 1 or -1)) % n) + 1
	switchTo(nextSlot)
end)

---------------------------------------------------------------- juice: blood, gore, shake, popups
local activeBits = 0
local function burst(pos, count, colors, speed, size)
	if activeBits > 220 then
		return
	end
	for _ = 1, count do
		local s = size * rng:NextNumber(0.5, 1.3)
		local p = Instance.new("Part")
		p.Size = Vector3.new(s, s, s)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		p.Color = colors[rng:NextInteger(1, #colors)]
		p.Material = Enum.Material.SmoothPlastic
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Parent = workspace
		p.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1.4), rng:NextNumber(-1, 1)).Unit * speed * rng:NextNumber(0.4, 1)
		p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
		activeBits += 1
		task.delay(1.6, function()
			TweenService:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end)
		task.delay(2.1, function()
			activeBits -= 1
			p:Destroy()
		end)
	end
end

local BLOOD = { Color3.fromRGB(150, 0, 0), Color3.fromRGB(110, 0, 0), Color3.fromRGB(190, 15, 10) }
local GORE = { Color3.fromRGB(150, 0, 0), Color3.fromRGB(100, 0, 0), Color3.fromRGB(92, 132, 69), Color3.fromRGB(190, 15, 10) }
local DIRT = { Color3.fromRGB(60, 45, 35), Color3.fromRGB(80, 20, 20), Color3.fromRGB(45, 40, 38) }

local function goreBurst(pos)
	burst(pos, 26, GORE, 28, 0.32)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 40, 20)
	l.Range = 12
	l.Brightness = 4
	l.Parent = a
	Debris:AddItem(a, 0.12)
end

-- camera shake (removed again before the camera scripts run, so it never drifts your aim)
local lastShake = CFrame.identity
RunService:BindToRenderStep("ZombieShakeUndo", Enum.RenderPriority.Camera.Value - 1, function()
	camera.CFrame = camera.CFrame * lastShake:Inverse()
	lastShake = CFrame.identity
end)

local headshotLabel = newLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 150, 0.5, -70), Size = UDim2.fromOffset(330, 70), Text = "HEADSHOT!", TextColor3 = Color3.fromRGB(255, 40, 40), Font = horrorFont, Rotation = -8, TextTransparency = 1, TextStrokeTransparency = 1 })
local headshotScale = Instance.new("UIScale")
headshotScale.Parent = headshotLabel
local function headshotPopup()
	headshotLabel.TextTransparency = 0
	headshotLabel.TextStrokeTransparency = 0.2
	headshotScale.Scale = 1.7
	TweenService:Create(headshotScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(0.7, function()
		TweenService:Create(headshotLabel, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local roundScale = Instance.new("UIScale")
roundScale.Parent = roundLabel
local function roundBanner()
	roundScale.Scale = 2.2
	TweenService:Create(roundScale, TweenInfo.new(0.9, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
	damageOverlay.BackgroundTransparency = 0.55
	TweenService:Create(damageOverlay, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	addShake(0.6)
end

---------------------------------------------------------------- zombie walk animation (client-side, via Motor6D.Transform)
local zombieAnim = {}
local zombiesFolder = workspace:WaitForChild("Zombies")
local function trackZombie(model)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	local joints = {}
	for _, n in { "LeftLeg", "RightLeg", "LeftArm", "RightArm", "Head" } do
		joints[n] = root:WaitForChild(n .. "Joint", 3)
	end
	zombieAnim[model] = { root = root, j = joints, phase = rng:NextNumber(0, 6), seed = rng:NextNumber(0, 10) }
	burst(root.Position - Vector3.new(0, 2.5, 0), 10, DIRT, 14, 0.35) -- spawn dust
end
zombiesFolder.ChildAdded:Connect(trackZombie)
zombiesFolder.ChildRemoved:Connect(function(m)
	zombieAnim[m] = nil
end)
for _, m in zombiesFolder:GetChildren() do
	task.spawn(trackZombie, m)
end

local function setJoint(joint, cf)
	if joint and joint.Parent then
		joint.Transform = cf
	end
end

local function animateZombies(dt)
	local camPos = camera.CFrame.Position
	local t = os.clock()
	for model, a in zombieAnim do
		local root = a.root
		if not model.Parent or not root.Parent then
			zombieAnim[model] = nil
			continue
		end
		local dist = (root.Position - camPos).Magnitude
		if dist > 160 then
			continue
		end
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local amt = math.clamp(speed / 10, 0, 1)
		a.phase += dt * (2 + speed * 0.55)
		local s = math.sin(a.phase)
		setJoint(a.j.LeftLeg, CFrame.Angles(s * 0.75 * amt, 0, 0))
		setJoint(a.j.RightLeg, CFrame.Angles(-s * 0.75 * amt, 0, 0))
		local reach = dist < 8 and (math.sin(t * 9 + a.seed) * 0.35 - 0.25) or 0 -- swipe when close
		setJoint(a.j.LeftArm, CFrame.Angles(math.sin(t * 2 + a.seed) * 0.12 + s * 0.12 * amt + reach, 0, 0))
		setJoint(a.j.RightArm, CFrame.Angles(math.sin(t * 2.3 + a.seed) * 0.12 - s * 0.12 * amt - reach, 0, 0))
		setJoint(a.j.Head, CFrame.Angles(math.sin(t * 1.3 + a.seed) * 0.12, math.sin(t * 0.9 + a.seed) * 0.25, math.sin(t * 1.7 + a.seed) * 0.15))
	end
end

---------------------------------------------------------------- flickering fire / pulsing box beam
local flickerLights, pulseParts = {}, {}
task.spawn(function()
	while true do
		flickerLights, pulseParts = {}, {}
		local map = workspace:FindFirstChild("ZombieMap")
		if map then
			for _, d in map:GetDescendants() do
				if d:IsA("BasePart") then
					if d:GetAttribute("Flicker") then
						for _, l in d:GetDescendants() do
							if l:IsA("PointLight") then
								table.insert(flickerLights, l)
							end
						end
					elseif d:GetAttribute("Pulse") then
						table.insert(pulseParts, d)
					end
				end
			end
		end
		task.wait(3)
	end
end)

---------------------------------------------------------------- server events
EventRemote.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if kind == "State" then
		state = a
		if state.weapons[state.slot] ~= currentVM then
			buildViewmodel(state.weapons[state.slot])
		end
		updateHUD()
	elseif kind == "Announce" then
		announce(a, b)
	elseif kind == "Hit" then
		local color = a and Color3.fromRGB(255, 60, 60) or Color3.new(1, 1, 1)
		for _, bar in hitBars do
			bar.BackgroundColor3 = color
		end
		hitmarker.Size = UDim2.fromOffset(b and 34 or 26, b and 34 or 26)
		hitmarker.Visible = true
		task.delay(0.12, function()
			hitmarker.Visible = false
		end)
		if a and b then
			headshotPopup()
		end
		playSound(Config.Sounds.Hitmarker, 0.4)
	elseif kind == "Hurt" then
		addShake(0.9)
		playSound(Config.Sounds.Hurt, 0.6)
	elseif kind == "Gore" then
		if typeof(a) == "Vector3" then
			goreBurst(a)
		end
	elseif kind == "Purchase" then
		playSound(Config.Sounds.Purchase, 0.6)
	elseif kind == "RoundStart" then
		roundBanner()
		playSound(Config.Sounds.RoundStart, 0.8)
	elseif kind == "Shot" then
		-- a = shooter, b = origin, c = end points, d = weapon, e = blood points
		if a ~= player and typeof(b) == "Vector3" and type(c) == "table" then
			local wc = Config.Weapons[d]
			for _, endPos in c do
				tracer(b, endPos, wc and wc.TracerColor)
			end
		end
		if type(e) == "table" then
			for _, pos in e do
				if typeof(pos) == "Vector3" then
					burst(pos, 5, BLOOD, 16, 0.22)
				end
			end
		end
	end
end)

---------------------------------------------------------------- per-frame
RunService:BindToRenderStep("ZombieViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local hum = getHumanoid()
	local name = state.weapons[state.slot]
	local c = name and Config.Weapons[name]

	-- shooting
	if c and (wantShot or (firing and c.Automatic)) then
		if tryFire() then
			wantShot = false
		end
	end

	-- sprint
	if hum then
		hum.WalkSpeed = (sprinting and not firing) and Config.SprintSpeed or Config.WalkSpeed
	end

	-- camera shake (undone next frame by ZombieShakeUndo)
	shake = math.max(shake - dt * 3.5, 0)
	if shake > 0 then
		local tt = os.clock() * 40
		local s = shake * shake * 0.035
		lastShake = CFrame.Angles(math.noise(tt, 1) * s, math.noise(tt, 2) * s, math.noise(tt, 3) * s * 0.6)
		camera.CFrame = camera.CFrame * lastShake
	end

	animateZombies(dt)

	-- fire flicker + beam pulse
	local tf = os.clock()
	for i, l in flickerLights do
		l.Brightness = 2.6 + math.noise(tf * 6, i * 1.7) * 2.2
	end
	for _, p in pulseParts do
		p.Transparency = 0.72 + math.sin(tf * 3) * 0.08
	end

	-- viewmodel motion
	local t = os.clock()
	recoil += (0 - recoil) * math.min(dt * 14, 1)
	reloadBlend += ((state.reloading and 1 or 0) - reloadBlend) * math.min(dt * 10, 1)
	local moving = hum and hum.MoveDirection.Magnitude > 0.1
	bobBlend += ((moving and (sprinting and 1.8 or 1) or 0) - bobBlend) * math.min(dt * 8, 1)
	local speed = sprinting and 12 or 8
	local bob = CFrame.new(math.sin(t * speed) * 0.05 * bobBlend, -math.abs(math.cos(t * speed)) * 0.05 * bobBlend, 0)
	local recoilCF = CFrame.new(0, 0, recoil * 0.22) * CFrame.Angles(recoil * 0.1, 0, 0)
	local reloadCF = CFrame.new(0, -0.45 * reloadBlend, 0) * CFrame.Angles(-0.7 * reloadBlend, 0, 0.45 * reloadBlend)
	local base = camera.CFrame * VM_OFFSET * bob * recoilCF * reloadCF

	vmFolder.Parent = hum and camera or nil
	for _, entry in vmParts do
		entry[1].CFrame = base * entry[2]
	end

	-- crosshair
	local gap = 6 + (c and c.Spread or 1) * 3 + recoil * 6 + (moving and 6 or 0)
	layoutCrosshair(gap)
	for _, bar in crossBars do
		bar.Visible = hum ~= nil and reloadBlend < 0.5
	end
end)
]========])
print("Zombie Waves installed! Press Play (F5) to test.")
