-- MapBuilder.lua
-- Builds the whole world procedurally at server start:
--   central treasure marketplace (stalls, fountain, shop, rebirth altar, sell
--   station, global leaderboard), 8 base slots, treasure fields, decorations,
--   border mountains, 3 secret areas and 2 special event locations.
-- Everything is generated from code so the place file needs no assets.

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local MapBuilder = {}
MapBuilder.Map = nil

local rng = Random.new(1337)

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end
MapBuilder.Part = part

local function cyl(parent, height, diameter, cf, color, material, props)
	local p = part(parent, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
MapBuilder.Cylinder = cyl

local function ball(parent, d, pos, color, material, props)
	local p = part(parent, Vector3.new(d, d, d), CFrame.new(pos), color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end

local function folder(name: string, parent: Instance)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function billboardText(adornee: BasePart, text: string, color: Color3, size: UDim2?, offset: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = size or UDim2.fromOffset(260, 60)
	bb.StudsOffset = Vector3.new(0, offset or 4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 220
	bb.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 20, 40)
	stroke.Parent = label
	label.Parent = bb
	bb.Parent = adornee
	return bb, label
end
MapBuilder.Billboard = billboardText

local function addPrompt(p: BasePart, action: string, object: string, uiName: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt:SetAttribute("OpenUI", uiName)
	prompt.Parent = p
	return prompt
end

-- Lighting ------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(90, 90, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 170)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 2200
	Lighting.FogColor = Color3.fromRGB(190, 220, 255)

	local function ensure(className: string, name: string)
		local inst = Lighting:FindFirstChild(name)
		if not inst then
			inst = Instance.new(className)
			inst.Name = name
			inst.Parent = Lighting
		end
		return inst
	end
	local atmo = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmo.Density = 0.28
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(200, 225, 255)
	atmo.Decay = Color3.fromRGB(120, 150, 220)
	atmo.Glare = 0.2
	atmo.Haze = 1.2
	local cc = ensure("ColorCorrectionEffect", "GameColor") :: ColorCorrectionEffect
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	local bloom = ensure("BloomEffect", "GameBloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	local rays = ensure("SunRaysEffect", "GameSunRays") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.8
	ensure("Sky", "GameSky")
end

-- Pieces ----------------------------------------------------------------------
local TREE_LEAF_COLORS = {
	Color3.fromRGB(80, 200, 90),
	Color3.fromRGB(60, 170, 80),
	Color3.fromRGB(255, 140, 190),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(150, 220, 70),
	Color3.fromRGB(170, 120, 255),
}

local function tree(parent: Instance, pos: Vector3, scale: number, leafColor: Color3?)
	local m = Instance.new("Model")
	m.Name = "Tree"
	local h = 10 * scale
	cyl(m, h, 2.2 * scale, CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color3.fromRGB(120, 80, 50), Enum.Material.Wood, { CastShadow = true })
	local c = leafColor or TREE_LEAF_COLORS[rng:NextInteger(1, #TREE_LEAF_COLORS)]
	ball(m, 9 * scale, pos + Vector3.new(0, h + 2 * scale, 0), c, Enum.Material.Grass)
	ball(m, 6 * scale, pos + Vector3.new(2.5 * scale, h + 4.5 * scale, 1 * scale), c:Lerp(Color3.new(1, 1, 1), 0.12), Enum.Material.Grass)
	m.Parent = parent
	return m
end

MapBuilder.Tree = tree
MapBuilder.Ball = ball
MapBuilder.Rng = rng

local function rock(parent, pos: Vector3, size: Vector3, color: Color3?)
	return part(parent, size, CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)), color or Color3.fromRGB(130, 130, 140), Enum.Material.Slate)
end

local function zonePart(parent, name: string, size: Vector3, cf: CFrame)
	local z = part(parent, size, cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Name = name,
	})
	return z
end

-- Plaza / marketplace ---------------------------------------------------------
local function buildPlaza(root: Instance, map)
	local plaza = folder("Marketplace", root)
	cyl(plaza, 1, 150, CFrame.new(0, 0.5, 0), Color3.fromRGB(240, 232, 215), Enum.Material.Marble)
	cyl(plaza, 1.1, 100, CFrame.new(0, 0.55, 0), Color3.fromRGB(255, 210, 120), Enum.Material.Sandstone)
	cyl(plaza, 1.2, 70, CFrame.new(0, 0.6, 0), Color3.fromRGB(240, 232, 215), Enum.Material.Marble)

	-- Fountain
	local f = folder("Fountain", plaza)
	cyl(f, 3, 26, CFrame.new(0, 2, 0), Color3.fromRGB(220, 220, 230), Enum.Material.Marble)
	local water = cyl(f, 0.6, 23, CFrame.new(0, 3.4, 0), Color3.fromRGB(80, 190, 255), Enum.Material.Glass, { Transparency = 0.25, Name = "Water" })
	cyl(f, 8, 3, CFrame.new(0, 7, 0), Color3.fromRGB(220, 220, 230), Enum.Material.Marble)
	cyl(f, 1.5, 10, CFrame.new(0, 11, 0), Color3.fromRGB(220, 220, 230), Enum.Material.Marble)
	local top = ball(f, 4, Vector3.new(0, 13.5, 0), Color3.fromRGB(255, 215, 80), Enum.Material.Neon, { Name = "FountainGem" })
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 235, 255))
	spray.Rate = 30
	spray.Speed = NumberRange.new(10, 14)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -25, 0)
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Size = NumberSequence.new(0.5, 0.1)
	spray.LightEmission = 0.5
	spray.Parent = top
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Parent = top
	map.FountainWater = water
	map.FountainGem = top

	-- Title sign
	local sign = part(plaza, Vector3.new(1, 1, 1), CFrame.new(0, 26, 0), Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	billboardText(sign, "💎 TREASURE MARKET 💎", Color3.fromRGB(255, 220, 80), UDim2.fromOffset(520, 90), 0).MaxDistance = 600

	-- Market stalls
	local stalls = folder("Stalls", plaza)
	map.Stalls = {}
	local stallColors = {
		Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 230, 80),
		Color3.fromRGB(110, 220, 110), Color3.fromRGB(80, 200, 255), Color3.fromRGB(150, 120, 255),
		Color3.fromRGB(255, 120, 210), Color3.fromRGB(80, 230, 200), Color3.fromRGB(255, 140, 100),
		Color3.fromRGB(180, 230, 90),
	}
	for i = 1, Config.Market.Stalls do
		local a = (i - 1) / Config.Market.Stalls * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 44, 1.2, math.sin(a) * 44)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 1.2, 0))
		local m = Instance.new("Model")
		m.Name = "Stall" .. i
		local color = stallColors[(i - 1) % #stallColors + 1]
		part(m, Vector3.new(8, 3, 8), cf * CFrame.new(0, 1.5, 0), Color3.fromRGB(250, 245, 235), Enum.Material.Wood)
		part(m, Vector3.new(8.4, 0.4, 8.4), cf * CFrame.new(0, 3.1, 0), color, Enum.Material.SmoothPlastic)
		for _, o in ipairs({ Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4) }) do
			part(m, Vector3.new(0.6, 12, 0.6), cf * CFrame.new(o.X, 6, o.Z), Color3.fromRGB(255, 255, 255), Enum.Material.Wood)
		end
		local roof = Instance.new("WedgePart")
		roof.Anchored = true
		roof.Size = Vector3.new(10, 2.5, 5)
		roof.Color = color
		roof.Material = Enum.Material.Fabric
		roof.CFrame = cf * CFrame.new(0, 13.25, 2.5)
		roof.Parent = m
		local roof2 = roof:Clone()
		roof2.CFrame = cf * CFrame.new(0, 13.25, -2.5) * CFrame.Angles(0, math.pi, 0)
		roof2.Parent = m
		m.Parent = stalls
		table.insert(map.Stalls, { Index = i, CFrame = cf * CFrame.new(0, 3.3, 0) })
	end

	-- Buildings: shop, rebirth altar, sell station, leaderboard
	local function station(name: string, angleDeg: number, color: Color3, label: string, action: string, ui: string)
		local a = math.rad(angleDeg)
		local pos = Vector3.new(math.cos(a) * 64, 1.2, math.sin(a) * 64)
		local cf = CFrame.lookAt(pos, Vector3.new(0, 1.2, 0))
		local m = Instance.new("Model")
		m.Name = name
		part(m, Vector3.new(18, 1, 12), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(60, 60, 80), Enum.Material.Slate)
		local counter = part(m, Vector3.new(14, 4, 3), cf * CFrame.new(0, 3, -2), color, Enum.Material.SmoothPlastic, { Name = "Counter" })
		part(m, Vector3.new(14.2, 0.4, 3.2), cf * CFrame.new(0, 5.1, -2), Color3.fromRGB(255, 255, 255), Enum.Material.Marble)
		part(m, Vector3.new(18, 1, 12), cf * CFrame.new(0, 16, 0), color, Enum.Material.SmoothPlastic)
		for _, x in ipairs({ -8, 8 }) do
			part(m, Vector3.new(1.2, 15, 1.2), cf * CFrame.new(x, 8.5, 5), Color3.fromRGB(255, 255, 255), Enum.Material.Marble)
			part(m, Vector3.new(1.2, 15, 1.2), cf * CFrame.new(x, 8.5, -5), Color3.fromRGB(255, 255, 255), Enum.Material.Marble)
		end
		local glow = part(m, Vector3.new(3, 3, 3), cf * CFrame.new(0, 7, -2) * CFrame.Angles(math.rad(45), 0, math.rad(45)), color, Enum.Material.Neon, { Name = "Glow", CanCollide = false })
		local pl = Instance.new("PointLight")
		pl.Color = color
		pl.Range = 18
		pl.Brightness = 2
		pl.Parent = glow
		addPrompt(counter, action, label, ui)
		local signPart = part(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, 19, 0), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
		billboardText(signPart, label, color:Lerp(Color3.new(1, 1, 1), 0.3), UDim2.fromOffset(300, 70), 0)
		m.Parent = plaza
		return m, cf
	end
	map.Shop = station("Shop", 22.5, Color3.fromRGB(60, 170, 255), "🛒 UPGRADE SHOP", "Open Shop", "Shop")
	map.RebirthAltar = station("RebirthAltar", 112.5, Color3.fromRGB(255, 80, 170), "🌀 REBIRTH ALTAR", "Rebirth", "Rebirth")
	map.SellStation = station("SellStation", 202.5, Color3.fromRGB(90, 220, 110), "💰 SELL TREASURES", "Sell", "Sell")

	-- Leaderboard board
	local a = math.rad(292.5)
	local pos = Vector3.new(math.cos(a) * 64, 0, math.sin(a) * 64)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	local lb = Instance.new("Model")
	lb.Name = "GlobalLeaderboard"
	part(lb, Vector3.new(1.5, 26, 1.5), cf * CFrame.new(-11, 13, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Metal)
	part(lb, Vector3.new(1.5, 26, 1.5), cf * CFrame.new(11, 13, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Metal)
	local board = part(lb, Vector3.new(21, 22, 1), cf * CFrame.new(0, 14, 0), Color3.fromRGB(25, 25, 45), Enum.Material.SmoothPlastic, { Name = "Board" })
	addPrompt(board, "View", "🏆 Leaderboard", "Leaderboard")
	lb.Parent = plaza
	map.LeaderboardBoard = board

	-- Trade booth (opens trade menu)
	map.TradeBooth = station("TradeBooth", 157.5, Color3.fromRGB(255, 200, 60), "🤝 TRADING POST", "Trade", "Trade")
	map.IndexBooth = station("IndexBooth", 337.5, Color3.fromRGB(170, 110, 255), "📖 TREASURE INDEX", "View Index", "Index")

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 1.2, 24)
	spawn.Color = Color3.fromRGB(255, 220, 90)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = plaza

	-- the plaza is built around the origin, then moved to the parade's start
	local offset = CFrame.new(Config.PlazaCenter)
	for _, d in ipairs(plaza:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = offset * d.CFrame
		end
	end
	for _, st in ipairs(map.Stalls) do
		st.CFrame = offset * st.CFrame
	end
end

-- Fields ---------------------------------------------------------------------
local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(140, 120, 255),
	Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 60), Color3.fromRGB(90, 220, 255),
}

local function buildFields(root: Instance, map)
	local fields = folder("TreasureFields", root)
	map.Fields = {}
	local names = { "Sunny Meadow", "Golden Grove", "Crystal Clearing", "Rainbow Patch", "Mushroom Hollow", "Starlight Glade", "Coral Garden", "Lucky Lawn" }
	for i = 0, 7 do
		local col = Config.BaseColumnsX[i % 4 + 1]
		local side = i < 4 and 1 or -1
		local center = Vector3.new(col, 0, side * 190)
		local m = Instance.new("Model")
		m.Name = names[i + 1]
		local color = FLOWER_COLORS[i % #FLOWER_COLORS + 1]
		cyl(m, 0.4, 48, CFrame.new(center + Vector3.new(0, 0.2, 0)), Color3.fromRGB(120, 220, 100), Enum.Material.Grass)
		cyl(m, 0.5, 44, CFrame.new(center + Vector3.new(0, 0.25, 0)), color:Lerp(Color3.fromRGB(120, 220, 100), 0.75), Enum.Material.Grass)
		for _ = 1, 16 do
			local r = rng:NextNumber(4, 21)
			local t = rng:NextNumber(0, math.pi * 2)
			local p = center + Vector3.new(math.cos(t) * r, 0.9, math.sin(t) * r)
			ball(m, rng:NextNumber(0.8, 1.4), p, FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
		end
		local signPost = part(m, Vector3.new(0.6, 6, 0.6), CFrame.new(center + Vector3.new(0, 3, 0) - (center.Unit * 24)), Color3.fromRGB(140, 100, 60), Enum.Material.Wood)
		billboardText(signPost, "✨ " .. names[i + 1], Color3.fromRGB(255, 255, 255), UDim2.fromOffset(240, 50), 4)
		m.Parent = fields
		table.insert(map.Fields, { Name = names[i + 1], Center = center, Radius = 19 })
	end
end

-- Paths ------------------------------------------------------------------------
local function buildPaths(root: Instance)
	local paths = folder("Paths", root)
	local P = Config.Parade
	-- wide stone promenades on both sides of the parade
	for _, side in ipairs({ -1, 1 }) do
		part(paths, Vector3.new(P.EndX - P.StartX + 40, 0.3, 26), CFrame.new(0, 0.15, side * 22), Color3.fromRGB(205, 190, 165), Enum.Material.Cobblestone)
		-- short paths from the promenade to every base door
		for _, x in ipairs(Config.BaseColumnsX) do
			local z0, z1 = side * 34, side * (Config.BaseRowZ - Config.BaseSize / 2)
			part(paths, Vector3.new(14, 0.3, math.abs(z1 - z0) + 2), CFrame.new(x, 0.16, (z0 + z1) / 2), Color3.fromRGB(230, 200, 150), Enum.Material.Sand)
		end
		-- lamp posts
		for x = P.StartX + 20, P.EndX - 20, 40 do
			local p = Vector3.new(x, 0, side * 12)
			part(paths, Vector3.new(0.6, 10, 0.6), CFrame.new(p + Vector3.new(0, 5, 0)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
			local bulb = ball(paths, 1.8, p + Vector3.new(0, 10.5, 0), Color3.fromRGB(255, 230, 160), Enum.Material.Neon)
			local l = Instance.new("PointLight")
			l.Range = 18
			l.Brightness = 1.2
			l.Color = Color3.fromRGB(255, 220, 150)
			l.Parent = bulb
		end
	end
	-- road from the plaza to the parade start
	local plaza = Config.PlazaCenter
	part(paths, Vector3.new(math.abs(P.StartX - plaza.X) - 60, 0.3, 30), CFrame.new((P.StartX + plaza.X + 60) / 2, 0.15, 0), Color3.fromRGB(230, 200, 150), Enum.Material.Sand)
end

-- Treasure Parade: the red carpet that treasures walk along (buy them as they pass!)
local function buildParade(root: Instance, map)
	local CollectionService = game:GetService("CollectionService")
	local f = folder("TreasureParade", root)
	local P = Config.Parade
	local length = P.EndX - P.StartX
	local mid = (P.StartX + P.EndX) / 2
	part(f, Vector3.new(length + 8, 0.6, P.Width + 4), CFrame.new(mid, 0.3, P.Z), Color3.fromRGB(255, 200, 60), Enum.Material.Foil, { Name = "CarpetTrim" })
	local carpet = part(f, Vector3.new(length + 8, 0.7, P.Width), CFrame.new(mid, 0.35, P.Z), Color3.fromRGB(200, 30, 50), Enum.Material.Fabric, { Name = "Carpet" })
	-- flowing light along the carpet (animated Beam texture)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-length / 2, 0.4, 0)
	a0.Parent = carpet
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(length / 2, 0.4, 0)
	a1.Parent = carpet
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = P.Width - 2
	beam.Width1 = P.Width - 2
	beam.FaceCamera = false
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = 10
	beam.TextureSpeed = P.Speed / 10
	beam.LightEmission = 0.6
	beam.Transparency = NumberSequence.new(0.55)
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	beam.Parent = carpet
	-- velvet rope posts along both edges
	for x = P.StartX, P.EndX, 12 do
		for _, side in ipairs({ -1, 1 }) do
			local pos = Vector3.new(x, 0, P.Z + side * (P.Width / 2 + 2.5))
			cyl(f, 3.4, 0.5, CFrame.new(pos + Vector3.new(0, 1.7, 0)), Color3.fromRGB(255, 205, 70), Enum.Material.Foil)
			ball(f, 0.8, pos + Vector3.new(0, 3.6, 0), Color3.fromRGB(255, 220, 90), Enum.Material.Foil)
		end
	end
	-- spawn + exit arches (glowing portals)
	for _, info in ipairs({ { P.StartX - 6, Color3.fromRGB(120, 220, 255), "✨ TREASURE PARADE ✨" }, { P.EndX + 6, Color3.fromRGB(255, 120, 200), "👋 BYE BYE!" } }) do
		local x, color = info[1], info[2]
		part(f, Vector3.new(3, 22, 3), CFrame.new(x, 11, P.Z - P.Width / 2 - 3), Color3.fromRGB(250, 245, 235), Enum.Material.Marble)
		part(f, Vector3.new(3, 22, 3), CFrame.new(x, 11, P.Z + P.Width / 2 + 3), Color3.fromRGB(250, 245, 235), Enum.Material.Marble)
		part(f, Vector3.new(4, 3, P.Width + 10), CFrame.new(x, 23, P.Z), color, Enum.Material.SmoothPlastic)
		local disc = part(f, Vector3.new(0.6, 19, P.Width + 2), CFrame.new(x, 10.5, P.Z), color, Enum.Material.ForceField, { CanCollide = false, Transparency = 0.2 })
		CollectionService:AddTag(disc, "Pulse")
		local sp = Instance.new("ParticleEmitter")
		sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sp.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		sp.LightEmission = 1
		sp.Rate = 30
		sp.Speed = NumberRange.new(2, 5)
		sp.SpreadAngle = Vector2.new(180, 180)
		sp.Size = NumberSequence.new(0.8, 0)
		sp.Parent = disc
		local sign = part(f, Vector3.new(1, 1, 1), CFrame.new(x, 28, P.Z), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
		billboardText(sign, info[3], color:Lerp(Color3.new(1, 1, 1), 0.3), UDim2.fromOffset(360, 70), 0).MaxDistance = 600
	end
	map.Parade = {
		Start = Vector3.new(P.StartX, 0.7, P.Z),
		End = Vector3.new(P.EndX, 0.7, P.Z),
	}
end

-- Decorations & border ---------------------------------------------------------------
local function isClear(pos: Vector3, map): boolean
	local flat = Vector3.new(pos.X, 0, pos.Z)
	-- plaza
	if (flat - Config.PlazaCenter).Magnitude < 100 then
		return false
	end
	-- the whole base district: parade, promenades and both base rows
	local reach = Config.BaseRowZ + Config.BaseSize / 2 + 18
	if math.abs(flat.X) < 290 and math.abs(flat.Z) < reach then
		return false
	end
	-- road from the plaza
	if flat.X < -240 and flat.X > Config.PlazaCenter.X and math.abs(flat.Z) < 25 then
		return false
	end
	for _, f in ipairs(map.Fields) do
		if (flat - f.Center).Magnitude < 30 then
			return false
		end
	end
	for _, c in ipairs(map.KeepClear or {}) do
		if (flat - c.Pos).Magnitude < c.R then
			return false
		end
	end
	return true
end

MapBuilder.IsClear = isClear

local function buildNature(root: Instance, map)
	local nature = folder("Nature", root)
	local placed = 0
	local tries = 0
	while placed < 110 and tries < 2000 do
		tries += 1
		local r = rng:NextNumber(90, 560)
		local t = rng:NextNumber(0, math.pi * 2)
		local pos = Vector3.new(math.cos(t) * r, 0, math.sin(t) * r)
		if isClear(pos, map) then
			local t = tree(nature, pos, rng:NextNumber(0.8, 1.5))
			game:GetService("CollectionService"):AddTag(t, "Tree")
			placed += 1
		end
	end
	for _ = 1, 50 do
		local r = rng:NextNumber(100, 560)
		local t = rng:NextNumber(0, math.pi * 2)
		local pos = Vector3.new(math.cos(t) * r, 0.5, math.sin(t) * r)
		if isClear(pos, map) then
			rock(nature, pos, Vector3.new(rng:NextNumber(3, 7), rng:NextNumber(2, 5), rng:NextNumber(3, 7)))
		end
	end

	-- Border mountains + invisible wall
	local border = folder("Border", root)
	for i = 0, 47 do
		local a = i / 48 * math.pi * 2
		local r = rng:NextNumber(620, 660)
		local h = rng:NextNumber(70, 150)
		local w = rng:NextNumber(90, 130)
		local p = part(border, Vector3.new(w, h, w), CFrame.new(math.cos(a) * r, h / 2 - 10, math.sin(a) * r) * CFrame.Angles(0, a, math.rad(rng:NextNumber(-8, 8))), Color3.fromRGB(110, 150, 95):Lerp(Color3.fromRGB(150, 140, 130), rng:NextNumber()), Enum.Material.Rock)
		p.CastShadow = false
		part(border, Vector3.new(w * 0.6, 8, w * 0.6), p.CFrame * CFrame.new(0, h / 2, 0), Color3.fromRGB(245, 250, 255), Enum.Material.Snow, { CastShadow = false })
	end
	for i = 0, 3 do
		local a = i * math.pi / 2
		part(border, Vector3.new(1400, 400, 4), CFrame.new(math.cos(a) * 690, 200, math.sin(a) * 690) * CFrame.Angles(0, -a + math.pi / 2, 0), Color3.new(), nil, { Transparency = 1, CastShadow = false })
	end
end

-- Secret areas ------------------------------------------------------------------
local function buildSecretCave(root: Instance, map)
	local cave = folder("SecretCave", root)
	local rockColor = Color3.fromRGB(100, 95, 110)
	local z0 = -500 -- front face
	-- hollow cliff: interior x -15..15, y 0..18, z -535..-500
	part(cave, Vector3.new(45, 60, 40), CFrame.new(-37.5, 30, z0 - 20), rockColor, Enum.Material.Rock)
	part(cave, Vector3.new(45, 60, 40), CFrame.new(37.5, 30, z0 - 20), rockColor, Enum.Material.Rock)
	part(cave, Vector3.new(30, 42, 40), CFrame.new(0, 39, z0 - 20), rockColor, Enum.Material.Rock)
	part(cave, Vector3.new(30, 18, 5), CFrame.new(0, 9, z0 - 37.5), rockColor, Enum.Material.Rock)
	part(cave, Vector3.new(30, 1, 35), CFrame.new(0, 0.5, z0 - 17.5), Color3.fromRGB(60, 50, 80), Enum.Material.Slate)
	-- waterfall curtain (walk through it!)
	local fall = part(cave, Vector3.new(32, 34, 1), CFrame.new(0, 17, z0 + 1), Color3.fromRGB(120, 200, 255), Enum.Material.Glass, {
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		Name = "Waterfall",
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	mist.Rate = 15
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Speed = NumberRange.new(2, 5)
	mist.Size = NumberSequence.new(3, 6)
	mist.Transparency = NumberSequence.new(0.6, 1)
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Parent = fall
	cyl(cave, 0.6, 40, CFrame.new(0, 0.3, z0 + 10), Color3.fromRGB(80, 180, 255), Enum.Material.Glass, { Transparency = 0.3, CanCollide = false })
	-- crystals inside
	local crystalColors = { Color3.fromRGB(120, 255, 240), Color3.fromRGB(200, 120, 255), Color3.fromRGB(255, 120, 200) }
	for i = 1, 14 do
		local x = rng:NextNumber(-13, 13)
		local z = rng:NextNumber(z0 - 33, z0 - 4)
		local side = (i % 2 == 0)
		local pos = side and Vector3.new(x > 0 and 14 or -14, rng:NextNumber(2, 14), z) or Vector3.new(x, 1.5, z)
		if math.abs(x) < 6 and not side then
			pos = Vector3.new(x > 0 and 10 or -10, 1.5, z)
		end
		local c = part(cave, Vector3.new(1.2, rng:NextNumber(2.5, 5), 1.2), CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5)), crystalColors[i % 3 + 1], Enum.Material.Neon, { CanCollide = false })
		if i % 4 == 0 then
			local l = Instance.new("PointLight")
			l.Color = c.Color
			l.Range = 14
			l.Parent = c
		end
	end
	local zone = zonePart(cave, "CaveZone", Vector3.new(30, 18, 35), CFrame.new(0, 9, z0 - 17.5))
	table.insert(map.Secrets, {
		Name = "Crystal Cave",
		Zone = zone,
		Spawns = { Vector3.new(-6, 1, z0 - 28), Vector3.new(6, 1, z0 - 20), Vector3.new(0, 1, z0 - 12) },
	})
	table.insert(map.KeepClear, { Pos = Vector3.new(0, 0, z0 - 10), R = 60 })
end

local function buildSkyIsland(root: Instance, map)
	local sky = folder("SkyIsland", root)
	local center = Vector3.new(330, 0, 330)
	local islandY = 150
	-- parkour spiral
	local steps = 34
	for i = 1, steps do
		local t = i / steps
		local a = t * math.pi * 4
		local y = 4 + t * (islandY - 8)
		local r = 46
		local pos = center + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		local hue = (i / steps)
		part(sky, Vector3.new(7, 1.2, 7), CFrame.new(pos), Color3.fromHSV(hue, 0.55, 1), Enum.Material.SmoothPlastic)
	end
	-- island
	cyl(sky, 8, 80, CFrame.new(center + Vector3.new(0, islandY - 4, 0)), Color3.fromRGB(150, 120, 90), Enum.Material.Ground)
	cyl(sky, 1.5, 80, CFrame.new(center + Vector3.new(0, islandY + 0.75, 0)), Color3.fromRGB(110, 230, 110), Enum.Material.Grass)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		tree(sky, center + Vector3.new(math.cos(a) * 28, islandY + 1.5, math.sin(a) * 28), 0.9, Color3.fromRGB(255, 180, 230))
	end
	-- rock spikes underneath
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part(sky, Vector3.new(14, 26, 14), CFrame.new(center + Vector3.new(math.cos(a) * 18, islandY - 18, math.sin(a) * 18)) * CFrame.Angles(0, a, math.rad(180)), Color3.fromRGB(140, 110, 80), Enum.Material.Rock)
	end
	local shrine = part(sky, Vector3.new(6, 6, 6), CFrame.new(center + Vector3.new(0, islandY + 6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color3.fromRGB(255, 240, 150), Enum.Material.Neon, { CanCollide = false })
	local l = Instance.new("PointLight")
	l.Range = 30
	l.Brightness = 3
	l.Color = Color3.fromRGB(255, 240, 150)
	l.Parent = shrine
	local zone = zonePart(sky, "SkyZone", Vector3.new(80, 30, 80), CFrame.new(center + Vector3.new(0, islandY + 15, 0)))
	table.insert(map.Secrets, {
		Name = "Sky Island",
		Zone = zone,
		Spawns = {
			center + Vector3.new(12, islandY + 2, 0),
			center + Vector3.new(-12, islandY + 2, 6),
			center + Vector3.new(0, islandY + 2, -14),
		},
	})
	table.insert(map.KeepClear, { Pos = center, R = 60 })
end

local function buildVault(root: Instance, map)
	local vault = folder("HiddenVault", root)
	-- The entrance: a hollow tree with a glowing pad inside
	local treePos = Vector3.new(-330, 0, 330)
	local trunkColor = Color3.fromRGB(110, 75, 45)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		if i ~= 0 then -- one side open = doorway
			part(vault, Vector3.new(4, 16, 2), CFrame.new(treePos + Vector3.new(math.cos(a) * 4.5, 8, math.sin(a) * 4.5)) * CFrame.Angles(0, -a + math.pi / 2, 0), trunkColor, Enum.Material.Wood)
		end
	end
	ball(vault, 22, treePos + Vector3.new(0, 22, 0), Color3.fromRGB(70, 150, 70), Enum.Material.Grass)
	ball(vault, 14, treePos + Vector3.new(6, 28, 3), Color3.fromRGB(90, 170, 80), Enum.Material.Grass)
	local roomCenter = Vector3.new(-330, -80, 330)
	local pad = part(vault, Vector3.new(5, 0.4, 5), CFrame.new(treePos + Vector3.new(0, 0.3, 0)), Color3.fromRGB(120, 255, 160), Enum.Material.Neon, { Name = "VaultEntrance", CanCollide = false, CanTouch = true })
	pad:SetAttribute("TeleportTo", roomCenter + Vector3.new(0, 4, 10))
	-- Vault room
	local gold = Color3.fromRGB(255, 200, 60)
	part(vault, Vector3.new(50, 1, 50), CFrame.new(roomCenter), Color3.fromRGB(60, 45, 30), Enum.Material.Wood)
	part(vault, Vector3.new(50, 1, 50), CFrame.new(roomCenter + Vector3.new(0, 20, 0)), Color3.fromRGB(70, 60, 50), Enum.Material.Brick)
	for _, d in ipairs({ Vector3.new(25, 0, 0), Vector3.new(-25, 0, 0), Vector3.new(0, 0, 25), Vector3.new(0, 0, -25) }) do
		local size = (d.X ~= 0) and Vector3.new(1, 20, 50) or Vector3.new(50, 20, 1)
		part(vault, size, CFrame.new(roomCenter + d + Vector3.new(0, 10, 0)), Color3.fromRGB(80, 65, 50), Enum.Material.Brick)
	end
	for i = 1, 10 do
		local p = roomCenter + Vector3.new(rng:NextNumber(-20, 20), 1.5, rng:NextNumber(-20, -8))
		ball(vault, rng:NextNumber(2, 4), p, gold, Enum.Material.Foil, { CanCollide = false })
	end
	local torchColor = Color3.fromRGB(255, 160, 60)
	for _, x in ipairs({ -20, 20 }) do
		local t = part(vault, Vector3.new(1, 1, 1), CFrame.new(roomCenter + Vector3.new(x, 12, -24)), torchColor, Enum.Material.Neon)
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Parent = t
		local l = Instance.new("PointLight")
		l.Range = 30
		l.Color = torchColor
		l.Brightness = 2
		l.Parent = t
	end
	local exitPad = part(vault, Vector3.new(5, 0.4, 5), CFrame.new(roomCenter + Vector3.new(0, 0.7, 20)), Color3.fromRGB(120, 200, 255), Enum.Material.Neon, { Name = "VaultExit", CanCollide = false, CanTouch = true })
	exitPad:SetAttribute("TeleportTo", treePos + Vector3.new(10, 4, 0))
	billboardText(exitPad, "⬆ EXIT", Color3.fromRGB(150, 220, 255), UDim2.fromOffset(160, 40), 3)
	local zone = zonePart(vault, "VaultZone", Vector3.new(48, 18, 48), CFrame.new(roomCenter + Vector3.new(0, 9, 0)))
	table.insert(map.Secrets, {
		Name = "Hidden Vault",
		Zone = zone,
		Spawns = { roomCenter + Vector3.new(-10, 1.5, -12), roomCenter + Vector3.new(10, 1.5, -12), roomCenter + Vector3.new(0, 1.5, -4) },
	})
	map.TeleportPads = { pad, exitPad }
	table.insert(map.KeepClear, { Pos = treePos, R = 25 })
end

-- Event locations ------------------------------------------------------------
local function buildCrater(root: Instance, map)
	local crater = folder("MeteorCrater", root)
	local center = Vector3.new(-380, 0, -300)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		part(crater, Vector3.new(12, rng:NextNumber(5, 9), 8), CFrame.new(center + Vector3.new(math.cos(a) * 40, 2, math.sin(a) * 40)) * CFrame.Angles(0, -a, math.rad(-20)), Color3.fromRGB(70, 60, 60), Enum.Material.Basalt)
	end
	cyl(crater, 0.6, 76, CFrame.new(center + Vector3.new(0, 0.3, 0)), Color3.fromRGB(60, 50, 50), Enum.Material.Basalt)
	cyl(crater, 0.7, 16, CFrame.new(center + Vector3.new(0, 0.35, 0)), Color3.fromRGB(255, 90, 20), Enum.Material.CrackedLava, { Name = "LavaCore" })
	local sign = part(crater, Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 18, 0)), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	billboardText(sign, "☄️ METEOR CRATER", Color3.fromRGB(255, 140, 60), UDim2.fromOffset(320, 70), 0).MaxDistance = 500
	map.Crater = { Center = center, Radius = 30 }
	table.insert(map.KeepClear, { Pos = center, R = 60 })
end

local function buildShrine(root: Instance, map)
	local shrine = folder("CelestialShrine", root)
	local center = Vector3.new(380, 0, -320)
	local y = 0
	for i = 0, 5 do
		local w = 60 - i * 9
		part(shrine, Vector3.new(w, 5, w), CFrame.new(center + Vector3.new(0, y + 2.5, 0)), (i % 2 == 0) and Color3.fromRGB(240, 235, 220) or Color3.fromRGB(255, 215, 120), Enum.Material.Marble)
		y += 5
	end
	-- stairs on the front (facing map centre)
	local toCenter = (-center).Unit
	for i = 0, 29 do
		local p = center + toCenter * (32 - i * 0.9) + Vector3.new(0, i + 0.5, 0)
		part(shrine, Vector3.new(10, 1, 1.6), CFrame.lookAt(p, p + toCenter), Color3.fromRGB(250, 245, 235), Enum.Material.Marble)
	end
	local altar = part(shrine, Vector3.new(8, 2, 8), CFrame.new(center + Vector3.new(0, y + 1, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.Marble)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local pillar = part(shrine, Vector3.new(1.5, 12, 1.5), CFrame.new(center + Vector3.new(math.cos(a) * 7, y + 6, math.sin(a) * 7)), Color3.fromRGB(255, 230, 150), Enum.Material.Marble)
		ball(shrine, 2, pillar.Position + Vector3.new(0, 7, 0), Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
	end
	local sign = part(shrine, Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, y + 20, 0)), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	billboardText(sign, "🌟 CELESTIAL SHRINE", Color3.fromRGB(255, 240, 160), UDim2.fromOffset(340, 70), 0).MaxDistance = 500
	map.ShrineAltar = altar.CFrame * CFrame.new(0, 1, 0)
	table.insert(map.KeepClear, { Pos = center, R = 60 })
end

function MapBuilder.Build()
	local root = workspace:FindFirstChild("Map")
	if root then
		root:Destroy()
	end
	root = folder("Map", workspace)
	setupLighting()

	local map = {
		Root = root,
		Secrets = {},
		KeepClear = {},
	}

	-- Ground: real smooth terrain grass (animated grass blades with GlobalWind)
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(1400, 8, 1400), Enum.Material.Grass)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(105, 200, 90))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 220, 160))
	pcall(function()
		terrain.Decoration = true
	end)
	terrain.WaterColor = Color3.fromRGB(40, 170, 220)
	terrain.WaterWaveSize = 0.3
	terrain.WaterWaveSpeed = 12
	terrain.WaterReflectance = 0.6
	terrain.WaterTransparency = 0.5
	workspace.GlobalWind = Vector3.new(8, 0, 4)
	-- Kill floor far below for anyone who glitches out
	part(root, Vector3.new(2000, 2, 2000), CFrame.new(0, -200, 0), Color3.new(), nil, { Name = "KillFloor", Transparency = 1, CanCollide = false, CanTouch = true })

	buildPlaza(root, map)
	buildFields(root, map)
	buildPaths(root)
	buildParade(root, map)
	buildSecretCave(root, map)
	buildSkyIsland(root, map)
	buildVault(root, map)
	buildCrater(root, map)
	buildShrine(root, map)
	local Details = require(script.Parent.MapDetails)
	Details.BuildBefore(root, map, MapBuilder)
	buildNature(root, map)
	Details.BuildAfter(root, map, MapBuilder)

	-- Base slot transforms (BaseService builds the bases themselves)
	map.BaseSlots = {}
	for i = 1, Config.MaxBases do
		local col = Config.BaseColumnsX[(i - 1) % 4 + 1]
		local side = i <= 4 and 1 or -1
		local pos = Vector3.new(col, 0, side * Config.BaseRowZ)
		-- each base's door faces the parade
		map.BaseSlots[i] = CFrame.lookAt(pos, Vector3.new(col, 0, 0))
	end

	MapBuilder.Map = map
	return map
end

function MapBuilder.Init()
	MapBuilder.Build()
end

function MapBuilder.Start()
	local map = MapBuilder.Map
	-- Teleport pads (hidden vault)
	for _, pad in ipairs(map.TeleportPads) do
		local debounce = {}
		pad.Touched:Connect(function(hit)
			local char = hit.Parent
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hum or not hrp then
				return
			end
			if debounce[char] and os.clock() - debounce[char] < 2 then
				return
			end
			debounce[char] = os.clock()
			local target = pad:GetAttribute("TeleportTo")
			if typeof(target) == "Vector3" then
				(hrp :: BasePart).CFrame = CFrame.new(target)
			end
		end)
	end
	-- Kill floor
	local kill = map.Root:FindFirstChild("KillFloor")
	if kill then
		kill.Touched:Connect(function(hit)
			local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = 0
			end
		end)
	end
end

return MapBuilder
