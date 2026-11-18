-- MapDetails.lua
-- Extra world detail built on top of MapBuilder: terrain lake with a dock and
-- lighthouse, rolling hills, pine forests, windmill farm, pet & gem shops,
-- animated portals, market flags, chest spawn spots and CollectionService
-- tags that the client animates (Spin, Bob, Pulse, Flag, Lamp, Tree).

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local PLAZA = Config.PlazaCenter

local MapDetails = {}

local function tag(inst: Instance, name: string, attrs: { [string]: any }?)
	CollectionService:AddTag(inst, name)
	if attrs then
		for k, v in pairs(attrs) do
			inst:SetAttribute(k, v)
		end
	end
	return inst
end
MapDetails.Tag = tag

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Lake -----------------------------------------------------------------------
local LAKE = Vector3.new(450, 0, 40)
local function buildLake(root, map, M)
	local terrain = workspace.Terrain
	local lake = folder("Lake", root)
	terrain:FillCylinder(CFrame.new(LAKE + Vector3.new(0, -4, 0)), 8, 64, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(LAKE + Vector3.new(0, -5.5, 0)), 10, 55, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(LAKE + Vector3.new(0, 1, 0)), 3, 55, Enum.Material.Air)
	-- small island with a palm
	terrain:FillBall(LAKE + Vector3.new(15, -4, 10), 9, Enum.Material.Sand)
	M.Tree(lake, LAKE + Vector3.new(15, 4, 10), 0.8, Color3.fromRGB(70, 190, 80))
	-- dock
	local wood = Color3.fromRGB(150, 105, 65)
	local dockStart = LAKE + Vector3.new(-62, 0.6, 0)
	M.Part(lake, Vector3.new(26, 0.6, 7), CFrame.new(dockStart + Vector3.new(13, 0, 0)), wood, Enum.Material.WoodPlanks)
	for i = 0, 3 do
		M.Part(lake, Vector3.new(0.8, 4, 0.8), CFrame.new(dockStart + Vector3.new(i * 8, -1.8, 3.2)), wood, Enum.Material.Wood)
		M.Part(lake, Vector3.new(0.8, 4, 0.8), CFrame.new(dockStart + Vector3.new(i * 8, -1.8, -3.2)), wood, Enum.Material.Wood)
	end
	-- lighthouse on the far shore
	local lh = LAKE + Vector3.new(58, 0, -24)
	for i = 0, 5 do
		M.Cylinder(lake, 5, 10 - i * 0.8, CFrame.new(lh + Vector3.new(0, 2.5 + i * 5, 0)), (i % 2 == 0) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(230, 60, 60), Enum.Material.SmoothPlastic)
	end
	M.Cylinder(lake, 4, 5.5, CFrame.new(lh + Vector3.new(0, 32, 0)), Color3.fromRGB(255, 240, 160), Enum.Material.Glass, { Transparency = 0.3 })
	local lamp = M.Part(lake, Vector3.new(1.5, 1.5, 6), CFrame.new(lh + Vector3.new(0, 32, 0)), Color3.fromRGB(255, 250, 200), Enum.Material.Neon, { CanCollide = false, Name = "LighthouseLamp" })
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 60
	spot.Angle = 35
	spot.Brightness = 6
	spot.Color = Color3.fromRGB(255, 245, 200)
	spot.Parent = lamp
	tag(lamp, "Spin", { SpinSpeed = 0.9 })
	tag(lamp, "Lamp")
	M.Cylinder(lake, 1, 7, CFrame.new(lh + Vector3.new(0, 34.5, 0)), Color3.fromRGB(230, 60, 60), Enum.Material.SmoothPlastic)
	table.insert(map.KeepClear, { Pos = LAKE, R = 80 })
	table.insert(map.ChestSpots, LAKE + Vector3.new(-70, 0.5, 18))
end

-- Hills ------------------------------------------------------------------------
local function buildHills(map, M)
	local terrain = workspace.Terrain
	local rng = M.Rng
	local placed = 0
	for _ = 1, 200 do
		if placed >= 14 then
			break
		end
		local r = rng:NextNumber(320, 560)
		local a = rng:NextNumber(0, math.pi * 2)
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if M.IsClear(pos, map) then
			local radius = rng:NextNumber(18, 34)
			terrain:FillBall(pos - Vector3.new(0, radius * 0.6, 0), radius, Enum.Material.Grass)
			table.insert(map.KeepClear, { Pos = pos, R = radius + 6 })
			placed += 1
		end
	end
end

-- Buildings ------------------------------------------------------------------------
local function shopBuilding(root, M, angleDeg: number, name: string, label: string, color: Color3, ui: string, action: string)
	local a = math.rad(angleDeg)
	local pos = PLAZA + Vector3.new(math.cos(a) * 64, 1.2, math.sin(a) * 64)
	local cf = CFrame.lookAt(pos, PLAZA + Vector3.new(0, 1.2, 0))
	local m = Instance.new("Model")
	m.Name = name
	local white = Color3.fromRGB(250, 248, 240)
	M.Part(m, Vector3.new(20, 1, 16), cf * CFrame.new(0, 0, 0), Color3.fromRGB(70, 70, 90), Enum.Material.Slate)
	M.Part(m, Vector3.new(18, 12, 1), cf * CFrame.new(0, 6.5, 7), white, Enum.Material.SmoothPlastic)
	M.Part(m, Vector3.new(1, 12, 14), cf * CFrame.new(-8.5, 6.5, 0), white, Enum.Material.SmoothPlastic)
	M.Part(m, Vector3.new(1, 12, 14), cf * CFrame.new(8.5, 6.5, 0), white, Enum.Material.SmoothPlastic)
	-- striped awning roof
	for i = 0, 5 do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(3, 3, 16)
		w.Color = (i % 2 == 0) and color or white
		w.Material = Enum.Material.Fabric
		w.CFrame = cf * CFrame.new(-7.5 + i * 3, 14, 0) * CFrame.Angles(0, math.rad(90), 0)
		w.Parent = m
	end
	M.Part(m, Vector3.new(19, 1, 16), cf * CFrame.new(0, 12.5, 0), color, Enum.Material.SmoothPlastic)
	local counter = M.Part(m, Vector3.new(14, 3.5, 3), cf * CFrame.new(0, 2.25, -4), color, Enum.Material.Wood, { Name = "Counter" })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = label
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenUI", ui)
	prompt.Parent = counter
	-- display eggs / gems on shelves (they bob)
	for i = -1, 1 do
		local item = M.Ball(m, 2.2, (cf * CFrame.new(i * 4.5, 6, 4)).Position, color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Neon, { CanCollide = false })
		tag(item, "Bob", { BobHeight = 0.6, BobSpeed = 1.5 + i * 0.3 })
		tag(item, "Spin", { SpinSpeed = 0.8 })
	end
	local signPart = M.Part(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, 18, 0), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	M.Billboard(signPart, label, color:Lerp(Color3.new(1, 1, 1), 0.3), UDim2.fromOffset(300, 70), 0)
	m.Parent = root
	return m
end

local function windmill(root, M, pos: Vector3, color: Color3)
	local m = Instance.new("Model")
	m.Name = "Windmill"
	for i = 0, 4 do
		M.Cylinder(m, 5, 9 - i, CFrame.new(pos + Vector3.new(0, 2.5 + i * 5, 0)), Color3.fromRGB(245, 240, 225), Enum.Material.Brick)
	end
	local roof = M.Part(m, Vector3.new(6, 4, 6), CFrame.new(pos + Vector3.new(0, 27, 0)) * CFrame.Angles(0, math.rad(45), 0), color, Enum.Material.Slate)
	roof.Name = "Roof"
	local toCenter = (-pos).Unit
	local hub = CFrame.lookAt(pos + Vector3.new(0, 24, 0) + toCenter * 3.5, pos + Vector3.new(0, 24, 0) + toCenter * 10)
	local blades = Instance.new("Model")
	blades.Name = "Blades"
	local hubPart = M.Part(blades, Vector3.new(1.6, 1.6, 1.6), hub, Color3.fromRGB(90, 70, 50), Enum.Material.Wood)
	for i = 0, 3 do
		local b = M.Part(blades, Vector3.new(1.8, 11, 0.3), hub * CFrame.Angles(0, 0, i * math.pi / 2) * CFrame.new(0, 6, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Fabric)
		b.CanCollide = false
	end
	blades.PrimaryPart = hubPart
	blades.Parent = m
	tag(blades, "Spin", { SpinSpeed = 1.2, SpinAxis = "Z" })
	m.Parent = root
	-- crop rows
	for r = 0, 4 do
		local rowPos = pos + toCenter * 14 + Vector3.new(-toCenter.Z, 0, toCenter.X) * (r - 2) * 4
		local crop = M.Part(root, Vector3.new(2, 1.2, 18), CFrame.lookAt(rowPos + Vector3.new(0, 0.6, 0), rowPos + toCenter * 10 + Vector3.new(0, 0.6, 0)), (r % 2 == 0) and Color3.fromRGB(240, 200, 60) or Color3.fromRGB(120, 200, 70), Enum.Material.Grass, { CanCollide = false })
		tag(crop, "Flag", { SwayAmount = 0.04 })
	end
end

-- Portals --------------------------------------------------------------------
local function portal(root, M, cf: CFrame, color: Color3, label: string, target: Vector3, requires: string?)
	local m = Instance.new("Model")
	m.Name = "Portal"
	M.Part(m, Vector3.new(16, 1, 6), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(60, 55, 80), Enum.Material.Slate)
	local ring = Instance.new("Model")
	ring.Name = "Ring"
	local center = cf * CFrame.new(0, 8, 0)
	local segs = 16
	local hub = M.Part(ring, Vector3.new(1, 1, 1), center, color, Enum.Material.Neon, { Transparency = 1, CanCollide = false })
	for i = 0, segs - 1 do
		local a = i / segs * math.pi * 2
		local seg = M.Part(ring, Vector3.new(2.4, 1.2, 1.2), center * CFrame.Angles(0, 0, a) * CFrame.new(0, 6.5, 0), (i % 2 == 0) and color or color:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Neon)
		seg.CanCollide = true
	end
	ring.PrimaryPart = hub
	ring.Parent = m
	tag(ring, "Spin", { SpinSpeed = 0.6, SpinAxis = "Z" })
	local disc = M.Part(m, Vector3.new(0.4, 12, 12), center * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.ForceField, {
		Name = "PortalDisc",
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		CanTouch = true,
		Transparency = 0.15,
	})
	disc:SetAttribute("PortalTo", target)
	if requires then
		disc:SetAttribute("RequiresSecret", requires)
	end
	tag(disc, "Pulse", { PulseSpeed = 2 })
	tag(disc, "Portal")
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	swirl.LightEmission = 1
	swirl.Rate = 25
	swirl.Lifetime = NumberRange.new(1, 1.6)
	swirl.Speed = NumberRange.new(1, 3)
	swirl.RotSpeed = NumberRange.new(-200, 200)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Size = NumberSequence.new(0.6, 0)
	swirl.Parent = disc
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 20
	light.Brightness = 2
	light.Parent = disc
	local signPart = M.Part(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, 17, 0), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	M.Billboard(signPart, label, color:Lerp(Color3.new(1, 1, 1), 0.4), UDim2.fromOffset(260, 50), 0)
	m.Parent = root
	return disc
end

local function buildPortals(root, map, M)
	local portals = folder("Portals", root)
	local function plazaCF(angleDeg)
		local a = math.rad(angleDeg)
		local pos = PLAZA + Vector3.new(math.cos(a) * 96, 0, math.sin(a) * 96)
		return CFrame.lookAt(pos, PLAZA), pos
	end
	local home = PLAZA + Vector3.new(0, 4, 30)
	local sky = Vector3.new(330, 156, 330)
	local crater = map.Crater.Center + (-map.Crater.Center).Unit * 50 + Vector3.new(0, 4, 0)
	local shrine = Vector3.new(380, 0, -320) + (-Vector3.new(380, 0, -320)).Unit * 42 + Vector3.new(0, 4, 0)
	local cf1, p1 = plazaCF(67.5)
	portal(portals, M, cf1, Color3.fromRGB(120, 220, 255), "🌀 Sky Island (discover it first!)", sky, "Sky Island")
	local cf2, p2 = plazaCF(157.5 + 22.5 / 2)
	portal(portals, M, cf2, Color3.fromRGB(255, 110, 50), "☄️ Meteor Crater", crater)
	local cf3, p3 = plazaCF(337.5 - 22.5 / 2)
	portal(portals, M, cf3, Color3.fromRGB(255, 230, 120), "🌟 Celestial Shrine", shrine)
	-- return portals
	local function back(pos: Vector3, color)
		local cf = CFrame.lookAt(pos, pos + (Vector3.new(0, pos.Y, 0) - pos))
		portal(portals, M, cf, color, "🏠 Back to Market", home)
	end
	back(Vector3.new(330, 151.5, 330) + Vector3.new(-22, 0, -22), Color3.fromRGB(120, 220, 255))
	back(map.Crater.Center + (-map.Crater.Center).Unit * 62, Color3.fromRGB(255, 110, 50))
	back(Vector3.new(380, 0, -320) + (-Vector3.new(380, 0, -320)).Unit * 55 + Vector3.new(12, 0, 12), Color3.fromRGB(255, 230, 120))
	for _, p in ipairs({ p1, p2, p3 }) do
		table.insert(map.KeepClear, { Pos = p, R = 14 })
	end
end

-- Pine forests ----------------------------------------------------------------
local function pine(parent, M, pos: Vector3, scale: number)
	local m = Instance.new("Model")
	m.Name = "Tree"
	M.Cylinder(m, 6 * scale, 1.6 * scale, CFrame.new(pos + Vector3.new(0, 3 * scale, 0)), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	local green = Color3.fromRGB(40, 130, 70):Lerp(Color3.fromRGB(70, 170, 90), M.Rng:NextNumber())
	for i = 0, 2 do
		local w = (9 - i * 2.5) * scale
		M.Cylinder(m, 3 * scale, w, CFrame.new(pos + Vector3.new(0, (6 + i * 3.2) * scale, 0)), green, Enum.Material.Grass)
	end
	M.Ball(m, 2 * scale, pos + Vector3.new(0, 15.2 * scale, 0), green, Enum.Material.Grass)
	m.Parent = parent
	tag(m, "Tree")
	return m
end

local FORESTS = {
	{ Name = "Whispering Woods", Center = Vector3.new(-520, 0, -200), R = 75 },
	{ Name = "Pinecrest Forest", Center = Vector3.new(100, 0, 480), R = 70 },
	{ Name = "Shadow Grove", Center = Vector3.new(-200, 0, -450), R = 65 },
}

local function buildForests(root, map, M)
	local f = folder("Forests", root)
	local rng = M.Rng
	for _, forest in ipairs(FORESTS) do
		local placed = 0
		for _ = 1, 260 do
			if placed >= 38 then
				break
			end
			local r = math.sqrt(rng:NextNumber()) * forest.R
			local a = rng:NextNumber(0, math.pi * 2)
			local pos = forest.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			if M.IsClear(pos, map) then
				if rng:NextNumber() < 0.65 then
					pine(f, M, pos, rng:NextNumber(0.9, 1.6))
				else
					tag(M.Tree(f, pos, rng:NextNumber(0.9, 1.4)), "Tree")
				end
				placed += 1
			end
		end
		-- glowing mushrooms
		for _ = 1, 10 do
			local r = rng:NextNumber(0, forest.R)
			local a = rng:NextNumber(0, math.pi * 2)
			local pos = forest.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			M.Cylinder(f, 1.2, 0.5, CFrame.new(pos + Vector3.new(0, 0.6, 0)), Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic, { CanCollide = false })
			local cap = M.Ball(f, 1.6, pos + Vector3.new(0, 1.3, 0), Color3.fromHSV(rng:NextNumber(), 0.6, 1), Enum.Material.Neon, { CanCollide = false })
			tag(cap, "Pulse", { PulseSpeed = rng:NextNumber(0.6, 1.4) })
		end
		local sign = M.Part(f, Vector3.new(0.6, 6, 0.6), CFrame.new(forest.Center + (-forest.Center).Unit * (forest.R + 4) + Vector3.new(0, 3, 0)), Color3.fromRGB(140, 100, 60), Enum.Material.Wood)
		M.Billboard(sign, "🌲 " .. forest.Name, Color3.fromRGB(200, 255, 200), UDim2.fromOffset(240, 50), 4)
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			table.insert(map.ChestSpots, forest.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(10, forest.R * 0.8) + Vector3.new(0, 0.5, 0))
		end
	end
end

-- Market flags & tagging existing objects -------------------------------------
local function decorate(root, map, M)
	local plaza = root:FindFirstChild("Marketplace")
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2 + 0.13
		local pos = PLAZA + Vector3.new(math.cos(a) * 74, 0, math.sin(a) * 74)
		M.Part(plaza, Vector3.new(0.5, 16, 0.5), CFrame.new(pos + Vector3.new(0, 8, 0)), Color3.fromRGB(240, 240, 240), Enum.Material.Metal)
		local flag = M.Part(plaza, Vector3.new(0.15, 3, 5), CFrame.new(pos + Vector3.new(0, 14.5, 2.6)), Color3.fromHSV(i / 12, 0.7, 1), Enum.Material.Fabric, { CanCollide = false })
		tag(flag, "Flag", { SwayAmount = 0.25 })
	end
	if map.FountainGem then
		tag(map.FountainGem, "Spin", { SpinSpeed = 1 })
		tag(map.FountainGem, "Bob", { BobHeight = 0.8, BobSpeed = 1 })
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "Glow" then
				tag(d, "Spin", { SpinSpeed = 1.5 })
			elseif d.Parent and d.Parent.Name == "Paths" and d.Material == Enum.Material.Neon then
				tag(d, "Lamp")
			elseif d.Parent and d.Parent.Name == "SecretCave" and d.Material == Enum.Material.Neon then
				tag(d, "Pulse", { PulseSpeed = 1 })
			elseif d.Name == "Waterfall" then
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, d.Size.Y / 2, 0)
				a0.Parent = d
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -d.Size.Y / 2, 0)
				a1.Parent = d
				local beam = Instance.new("Beam")
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.Width0 = d.Size.X
				beam.Width1 = d.Size.X
				beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
				beam.TextureSpeed = 2.5
				beam.TextureLength = 6
				beam.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
				beam.Transparency = NumberSequence.new(0.4)
				beam.LightEmission = 0.4
				beam.Parent = d
			end
		end
	end
	-- Clouds that drift with GlobalWind
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.7
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = workspace.Terrain
end

function MapDetails.BuildBefore(root, map, M)
	map.ChestSpots = map.ChestSpots or {}
	for _, f in ipairs(map.Fields) do
		table.insert(map.ChestSpots, f.Center + (f.Center.Unit * 24) + Vector3.new(0, 0.5, 0))
	end
	for _, secret in ipairs(map.Secrets) do
		table.insert(map.ChestSpots, secret.Spawns[1] + Vector3.new(3, 0, 3))
	end
	buildLake(root, map, M)
	buildHills(map, M)
	shopBuilding(root:FindFirstChild("Marketplace"), M, 67.5, "PetShop", "🐾 PET EGGS", Color3.fromRGB(255, 150, 80), "Pets", "Hatch Eggs")
	shopBuilding(root:FindFirstChild("Marketplace"), M, 247.5, "GemShop", "💎 GEM SHOP", Color3.fromRGB(80, 200, 255), "GemShop", "Open Gem Shop")
	windmill(root, M, Vector3.new(-430, 0, 160), Color3.fromRGB(200, 70, 60))
	windmill(root, M, Vector3.new(250, 0, -470), Color3.fromRGB(70, 110, 200))
	table.insert(map.KeepClear, { Pos = Vector3.new(-430, 0, 160), R = 34 })
	table.insert(map.KeepClear, { Pos = Vector3.new(250, 0, -470), R = 34 })
	buildPortals(root, map, M)
	for _, forest in ipairs(FORESTS) do
		-- reserve forest areas so random trees don't crowd them; forests add their own
		table.insert(map.KeepClear, { Pos = forest.Center, R = forest.R * 0.4 })
	end
end

function MapDetails.BuildAfter(root, map, M)
	-- forests ignore their own reservations
	local reserved = {}
	for i = #map.KeepClear, 1, -1 do
		for _, forest in ipairs(FORESTS) do
			if map.KeepClear[i].Pos == forest.Center then
				table.insert(reserved, table.remove(map.KeepClear, i))
				break
			end
		end
	end
	buildForests(root, map, M)
	decorate(root, map, M)
end

return MapDetails
