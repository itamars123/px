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
