-- TreasureModels.lua
-- Procedurally builds a unique 3D model for every treasure from its shape,
-- colours, material and effect. Shared so the server (world objects) and the
-- client (viewport previews) build identical models without any asset uploads.
--
-- Every model has an invisible anchor part called "Root" at its base. All other
-- parts are welded to it, so moving Root moves the whole treasure. The client
-- animates Root locally (spin / bob) using the "Home" CFrame attribute.

local Rarities = require(script.Parent.Rarities)

local TreasureModels = {}

local TEX_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function mat(name: string): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return ok and m or Enum.Material.SmoothPlastic
end

-- Builder context ---------------------------------------------------------
local Builder = {}
Builder.__index = Builder

local function newBuilder(model: Model, root: BasePart, scale: number, def)
	return setmetatable({
		Model = model,
		Root = root,
		S = scale,
		Def = def,
		Primary = def.Primary,
		Secondary = def.Secondary,
		Material = mat(def.Material),
		Count = 0,
	}, Builder)
end

-- Adds a part. `cf` is relative to the root (in unscaled units).
function Builder:Part(shape: string, size: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?, mesh: Vector3?)
	local s = self.S
	local p = Instance.new("Part")
	self.Count += 1
	p.Name = "P" .. self.Count
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cyl" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "Wedge" then
		p:Destroy()
		p = Instance.new("WedgePart")
		p.Name = "P" .. self.Count
	end
	p.Size = size * s
	p.Color = color or self.Primary
	p.Material = material or self.Material
	if p.Material == Enum.Material.Glass then
		p.Transparency = 0.25
		p.Reflectance = 0.1
	elseif p.Material == Enum.Material.ForceField then
		p.Transparency = 0
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local pos = cf.Position * s
	p.CFrame = self.Root.CFrame * (CFrame.new(pos) * cf.Rotation)
	if mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Scale = mesh
		m.Parent = p
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = self.Root
	w.Part1 = p
	w.Parent = p
	p.Parent = self.Model
	return p
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder upright
local function at(x, y, z)
	return CFrame.new(x, y, z)
end

-- Shapes ------------------------------------------------------------------
local Shapes = {}

function Shapes.Gem(b)
	b:Part("Cyl", Vector3.new(0.4, 1.6, 1.6), at(0, 0.2, 0) * UP, b.Secondary, Enum.Material.Metal)
	b:Part("Block", Vector3.new(1.8, 1.8, 1.8), at(0, 1.9, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)))
	b:Part("Block", Vector3.new(1.0, 1.0, 1.0), at(0, 1.9, 0) * CFrame.Angles(0, math.rad(45), 0), b.Secondary, Enum.Material.Neon)
end

function Shapes.Crown(b)
	b:Part("Cyl", Vector3.new(1.0, 2.8, 2.8), at(0, 0.6, 0) * UP)
	b:Part("Cyl", Vector3.new(1.02, 2.3, 2.3), at(0, 0.62, 0) * UP, Color3.fromRGB(120, 0, 30), Enum.Material.Fabric)
	for i = 0, 4 do
		local a = math.rad(i * 72)
		local x, z = math.cos(a) * 1.2, math.sin(a) * 1.2
		b:Part("Wedge", Vector3.new(0.3, 1.1, 0.6), at(x, 1.6, z) * CFrame.Angles(0, -a + math.rad(90), 0))
		b:Part("Ball", Vector3.new(0.45, 0.45, 0.45), at(x, 2.25, z), b.Secondary, Enum.Material.Neon)
		b:Part("Ball", Vector3.new(0.35, 0.35, 0.35), at(math.cos(a + 0.6) * 1.42, 0.6, math.sin(a + 0.6) * 1.42), b.Secondary, Enum.Material.Glass)
	end
end

function Shapes.Chalice(b)
	b:Part("Cyl", Vector3.new(0.3, 1.8, 1.8), at(0, 0.15, 0) * UP)
	b:Part("Cyl", Vector3.new(1.4, 0.4, 0.4), at(0, 1.0, 0) * UP)
	b:Part("Ball", Vector3.new(0.6, 0.6, 0.6), at(0, 1.0, 0), b.Secondary)
	b:Part("Cyl", Vector3.new(1.3, 2.0, 2.0), at(0, 2.3, 0) * UP)
	b:Part("Cyl", Vector3.new(0.1, 1.7, 1.7), at(0, 2.95, 0) * UP, b.Secondary, Enum.Material.Neon)
end

function Shapes.CoinStack(b)
	for i = 0, 4 do
		b:Part("Cyl", Vector3.new(0.3, 1.6, 1.6), at(math.sin(i * 1.7) * 0.15, 0.15 + i * 0.3, math.cos(i * 1.3) * 0.15) * UP)
	end
	b:Part("Cyl", Vector3.new(0.3, 1.6, 1.6), at(1.2, 0.8, 0) * CFrame.Angles(0, 0, math.rad(20)))
	b:Part("Cyl", Vector3.new(0.32, 0.9, 0.9), at(1.21, 0.8, 0) * CFrame.Angles(0, 0, math.rad(20)), b.Secondary, Enum.Material.Neon)
	b:Part("Cyl", Vector3.new(0.3, 1.6, 1.6), at(-0.9, 0.15, 0.9) * UP, b.Secondary)
end

function Shapes.Orb(b)
	b:Part("Cyl", Vector3.new(0.4, 1.4, 1.4), at(0, 0.2, 0) * UP, b.Secondary, Enum.Material.Metal)
	for i = 0, 2 do
		local a = math.rad(i * 120)
		b:Part("Block", Vector3.new(0.2, 0.9, 0.2), at(math.cos(a) * 0.55, 0.7, math.sin(a) * 0.55) * CFrame.Angles(math.cos(a) * 0.4, 0, -math.sin(a) * 0.4), b.Secondary, Enum.Material.Metal)
	end
	b:Part("Ball", Vector3.new(2.2, 2.2, 2.2), at(0, 2.0, 0))
	b:Part("Ball", Vector3.new(1.0, 1.0, 1.0), at(0, 2.0, 0), b.Secondary, Enum.Material.Neon)
end

function Shapes.Sword(b)
	b:Part("Block", Vector3.new(1.2, 0.5, 1.2), at(0, 0.25, 0), Color3.fromRGB(110, 110, 115), Enum.Material.Slate)
	b:Part("Block", Vector3.new(0.5, 3.2, 0.12), at(0, 1.9, 0))
	b:Part("Wedge", Vector3.new(0.12, 0.5, 0.25), at(0, 0.35, 0.125) * CFrame.Angles(math.rad(180), 0, 0))
	b:Part("Block", Vector3.new(1.6, 0.25, 0.3), at(0, 3.55, 0), b.Secondary, Enum.Material.Metal)
	b:Part("Cyl", Vector3.new(0.9, 0.25, 0.25), at(0, 4.1, 0) * UP, Color3.fromRGB(80, 50, 30), Enum.Material.Fabric)
	b:Part("Ball", Vector3.new(0.4, 0.4, 0.4), at(0, 4.65, 0), b.Secondary, Enum.Material.Neon)
end

function Shapes.Chest(b)
	b:Part("Block", Vector3.new(2.8, 1.4, 1.8), at(0, 0.7, 0))
	b:Part("Block", Vector3.new(2.85, 0.25, 1.85), at(0, 1.3, 0), b.Secondary, Enum.Material.Metal)
	b:Part("Block", Vector3.new(2.85, 0.6, 1.85), at(0, 1.85, -0.35) * CFrame.Angles(math.rad(-25), 0, 0))
	b:Part("Ball", Vector3.new(1.6, 1.6, 1.6), at(0, 1.4, 0.15), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
	for _, x in ipairs({ -1.0, 1.0 }) do
		b:Part("Block", Vector3.new(0.25, 1.45, 1.85), at(x, 0.7, 0), b.Secondary, Enum.Material.Metal)
	end
	b:Part("Block", Vector3.new(0.4, 0.5, 0.15), at(0, 1.0, 0.95), b.Secondary, Enum.Material.Metal)
end

function Shapes.Egg(b)
	b:Part("Cyl", Vector3.new(0.3, 1.6, 1.6), at(0, 0.15, 0) * UP, Color3.fromRGB(240, 230, 200), Enum.Material.Sand)
	b:Part("Block", Vector3.new(1.9, 2.6, 1.9), at(0, 1.55, 0), nil, nil, Vector3.new(1, 1, 1))
	for i = 0, 5 do
		local a = math.rad(i * 60 + 15)
		local y = 1.2 + (i % 2) * 0.7
		b:Part("Ball", Vector3.new(0.35, 0.35, 0.35), at(math.cos(a) * 0.88, y, math.sin(a) * 0.88), b.Secondary, Enum.Material.Neon)
	end
end

function Shapes.Star(b)
	b:Part("Cyl", Vector3.new(0.3, 1.4, 1.4), at(0, 0.15, 0) * UP, b.Secondary, Enum.Material.Metal)
	b:Part("Cyl", Vector3.new(0.9, 0.2, 0.2), at(0, 0.7, 0) * UP, b.Secondary, Enum.Material.Metal)
	b:Part("Cyl", Vector3.new(0.5, 1.0, 1.0), at(0, 2.2, 0) * CFrame.Angles(0, math.rad(90), 0))
	for i = 0, 4 do
		local a = math.rad(i * 72 + 90)
		b:Part("Wedge", Vector3.new(0.4, 1.1, 0.7), at(math.cos(a) * 0.85, 2.2 + math.sin(a) * 0.85, 0) * CFrame.Angles(0, 0, a - math.rad(90)) * CFrame.Angles(0, math.rad(90), 0))
	end
	b:Part("Ball", Vector3.new(0.6, 0.6, 0.6), at(0, 2.2, 0), b.Secondary, Enum.Material.Neon)
end

function Shapes.Skull(b)
	b:Part("Block", Vector3.new(2.0, 2.0, 2.2), at(0, 1.6, 0), nil, nil, Vector3.new(1, 0.95, 1))
	b:Part("Block", Vector3.new(1.3, 0.6, 1.0), at(0, 0.5, 0.35))
	for _, x in ipairs({ -0.45, 0.45 }) do
		b:Part("Ball", Vector3.new(0.55, 0.55, 0.55), at(x, 1.55, 0.85), b.Secondary, Enum.Material.Neon)
	end
	b:Part("Wedge", Vector3.new(0.3, 0.35, 0.3), at(0, 1.05, 1.0), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	for i = -2, 2 do
		b:Part("Block", Vector3.new(0.16, 0.25, 0.1), at(i * 0.22, 0.72, 0.86), Color3.fromRGB(250, 250, 240), Enum.Material.SmoothPlastic)
	end
end

function Shapes.Trophy(b)
	b:Part("Block", Vector3.new(1.6, 0.6, 1.6), at(0, 0.3, 0), Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
	b:Part("Block", Vector3.new(1.62, 0.12, 1.62), at(0, 0.5, 0), b.Secondary, Enum.Material.Metal)
	b:Part("Cyl", Vector3.new(1.0, 0.35, 0.35), at(0, 1.1, 0) * UP)
	b:Part("Cyl", Vector3.new(1.5, 1.8, 1.8), at(0, 2.3, 0) * UP)
	b:Part("Cyl", Vector3.new(0.4, 1.2, 1.2), at(0, 1.55, 0) * UP)
	for _, x in ipairs({ -1.1, 1.1 }) do
		b:Part("Cyl", Vector3.new(0.18, 0.9, 0.9), at(x, 2.4, 0) * CFrame.Angles(0, math.rad(90), 0))
	end
	b:Part("Ball", Vector3.new(0.5, 0.5, 0.5), at(0, 2.3, 0.85), b.Secondary, Enum.Material.Neon)
end

local function torus(b, center: CFrame, radius: number, thick: number, segments: number, color, material)
	for i = 0, segments - 1 do
		local a = (i / segments) * math.pi * 2
		local len = 2 * math.pi * radius / segments + 0.05
		b:Part("Block", Vector3.new(len, thick, thick), center * CFrame.Angles(0, 0, a) * at(0, radius, 0), color, material)
	end
end

function Shapes.Ring(b)
	b:Part("Block", Vector3.new(1.4, 0.4, 1.0), at(0, 0.2, 0), Color3.fromRGB(40, 20, 60), Enum.Material.Fabric)
	torus(b, at(0, 1.55, 0), 1.05, 0.28, 14)
	b:Part("Block", Vector3.new(0.7, 0.7, 0.7), at(0, 2.85, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), b.Secondary, Enum.Material.Glass)
	b:Part("Ball", Vector3.new(0.4, 0.4, 0.4), at(0, 2.85, 0), b.Secondary, Enum.Material.Neon)
end

function Shapes.Crystal(b)
	b:Part("Cyl", Vector3.new(0.4, 2.2, 2.2), at(0, 0.2, 0) * UP, Color3.fromRGB(90, 90, 100), Enum.Material.Slate)
	local spikes = {
		{ 0, 2.0, 0, 3.4, 0, 0 },
		{ 0.6, 1.4, 0.3, 2.2, 20, -25 },
		{ -0.6, 1.3, 0.2, 2.0, -15, 30 },
		{ 0.1, 1.2, -0.6, 1.8, 30, 10 },
		{ -0.2, 1.0, 0.6, 1.4, -25, -10 },
	}
	for i, s in ipairs(spikes) do
		local cf = at(s[1], s[2], s[3]) * CFrame.Angles(math.rad(s[5]), math.rad(i * 33), math.rad(s[6]))
		b:Part("Block", Vector3.new(0.7, s[4], 0.7), cf * CFrame.Angles(0, math.rad(45), 0))
		b:Part("Block", Vector3.new(0.3, s[4] * 0.85, 0.3), cf, b.Secondary, Enum.Material.Neon)
	end
end

function Shapes.Idol(b)
	b:Part("Block", Vector3.new(1.6, 0.4, 1.4), at(0, 0.2, 0), b.Secondary)
	b:Part("Block", Vector3.new(1.2, 1.8, 1.0), at(0, 1.3, 0))
	b:Part("Block", Vector3.new(1.4, 1.2, 1.2), at(0, 2.8, 0))
	b:Part("Block", Vector3.new(1.6, 0.25, 1.4), at(0, 3.5, 0), b.Secondary)
	for _, x in ipairs({ -0.35, 0.35 }) do
		b:Part("Block", Vector3.new(0.3, 0.2, 0.1), at(x, 2.95, 0.61), b.Secondary, Enum.Material.Neon)
	end
	b:Part("Block", Vector3.new(0.6, 0.2, 0.1), at(0, 2.5, 0.61), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -0.8, 0.8 }) do
		b:Part("Block", Vector3.new(0.35, 1.2, 0.5), at(x, 1.5, 0.1) * CFrame.Angles(0, 0, math.rad(x > 0 and -15 or 15)))
	end
end

function Shapes.Key(b)
	b:Part("Block", Vector3.new(1.4, 0.3, 1.0), at(0, 0.15, 0), Color3.fromRGB(70, 30, 30), Enum.Material.Fabric)
	b:Part("Block", Vector3.new(0.28, 2.4, 0.28), at(0, 1.6, 0))
	for i = 0, 1 do
		b:Part("Block", Vector3.new(0.5, 0.22, 0.28), at(0.35, 0.65 + i * 0.4, 0))
	end
	torus(b, at(0, 3.45, 0), 0.6, 0.25, 12)
	b:Part("Ball", Vector3.new(0.45, 0.45, 0.45), at(0, 3.45, 0), b.Secondary, Enum.Material.Neon)
end

function Shapes.Lamp(b)
	b:Part("Cyl", Vector3.new(0.3, 1.2, 1.2), at(0, 0.15, 0) * UP)
	b:Part("Block", Vector3.new(2.2, 1.2, 1.5), at(0, 0.9, 0), nil, nil, Vector3.new(1, 1, 1))
	b:Part("Cyl", Vector3.new(1.4, 0.25, 0.25), at(1.4, 1.2, 0) * CFrame.Angles(0, 0, math.rad(30)))
	b:Part("Cyl", Vector3.new(0.18, 0.9, 0.9), at(-1.25, 1.1, 0) * CFrame.Angles(0, math.rad(90), 0))
	b:Part("Cyl", Vector3.new(0.4, 0.8, 0.8), at(0, 1.55, 0) * UP, b.Secondary)
	b:Part("Ball", Vector3.new(0.35, 0.35, 0.35), at(0, 1.85, 0), b.Secondary, Enum.Material.Neon)
	b:Part("Ball", Vector3.new(0.5, 0.5, 0.5), at(2.0, 1.6, 0), b.Secondary, Enum.Material.Neon)
end

function Shapes.Mask(b)
	b:Part("Block", Vector3.new(0.3, 1.2, 0.3), at(0, 0.6, -0.2), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	b:Part("Block", Vector3.new(1.2, 0.2, 0.9), at(0, 0.1, -0.2), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	b:Part("Block", Vector3.new(2.0, 2.4, 0.8), at(0, 2.2, 0), nil, nil, Vector3.new(1, 1, 0.5))
	for _, x in ipairs({ -0.45, 0.45 }) do
		b:Part("Block", Vector3.new(0.5, 0.3, 0.2), at(x, 2.5, 0.2), b.Secondary, Enum.Material.Neon)
	end
	b:Part("Block", Vector3.new(0.6, 0.15, 0.2), at(0, 1.6, 0.2), b.Secondary)
	for i = -1, 1 do
		b:Part("Wedge", Vector3.new(0.25, 0.7, 0.3), at(i * 0.55, 3.55, 0), b.Secondary)
	end
end

function Shapes.Potion(b)
	b:Part("Block", Vector3.new(1.9, 1.9, 1.9), at(0, 1.0, 0), nil, Enum.Material.Glass, Vector3.new(1, 1, 1))
	b:Part("Block", Vector3.new(1.5, 1.3, 1.5), at(0, 0.85, 0), b.Secondary, Enum.Material.Neon, Vector3.new(1, 1, 1))
	b:Part("Cyl", Vector3.new(0.8, 0.6, 0.6), at(0, 2.2, 0) * UP, nil, Enum.Material.Glass)
	b:Part("Cyl", Vector3.new(0.4, 0.5, 0.5), at(0, 2.7, 0) * UP, Color3.fromRGB(140, 95, 60), Enum.Material.Wood)
	b:Part("Cyl", Vector3.new(0.1, 0.75, 0.75), at(0, 2.0, 0) * UP, b.Secondary, Enum.Material.Metal)
end

function Shapes.Cube(b)
	b:Part("Block", Vector3.new(1.2, 0.3, 1.2), at(0, 0.15, 0), Color3.fromRGB(40, 40, 50), Enum.Material.Metal)
	local core = at(0, 1.8, 0) * CFrame.Angles(math.rad(35), math.rad(45), 0)
	b:Part("Block", Vector3.new(1.8, 1.8, 1.8), core)
	b:Part("Block", Vector3.new(1.0, 1.0, 1.0), core, b.Secondary, Enum.Material.Neon)
	for _, d in ipairs({ Vector3.new(1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, -1, 1) }) do
		b:Part("Ball", Vector3.new(0.35, 0.35, 0.35), core * at(d.X * 0.9, d.Y * 0.9, d.Z * 0.9), b.Secondary, Enum.Material.Neon)
	end
end

function Shapes.Pyramid(b)
	local y = 0
	for i = 0, 3 do
		local w = 2.8 - i * 0.65
		b:Part("Block", Vector3.new(w, 0.55, w), at(0, y + 0.275, 0), i % 2 == 0 and b.Primary or b.Secondary)
		y += 0.55
	end
	b:Part("Block", Vector3.new(0.6, 0.6, 0.6), at(0, y + 0.4, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), b.Secondary, Enum.Material.Neon)
end

function Shapes.Shield(b)
	b:Part("Block", Vector3.new(1.4, 0.3, 0.9), at(0, 0.15, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	b:Part("Cyl", Vector3.new(0.3, 2.8, 2.8), at(0, 1.8, 0) * CFrame.Angles(0, math.rad(90), 0))
	b:Part("Cyl", Vector3.new(0.32, 2.4, 2.4), at(0, 1.8, 0.01) * CFrame.Angles(0, math.rad(90), 0), b.Secondary)
	b:Part("Block", Vector3.new(0.35, 2.4, 0.35), at(0, 1.8, 0.05))
	b:Part("Block", Vector3.new(2.4, 0.35, 0.35), at(0, 1.8, 0.05))
	b:Part("Ball", Vector3.new(0.7, 0.7, 0.7), at(0, 1.8, 0.2), b.Secondary, Enum.Material.Neon)
end

function Shapes.Hourglass(b)
	b:Part("Cyl", Vector3.new(0.3, 1.8, 1.8), at(0, 0.15, 0) * UP)
	b:Part("Cyl", Vector3.new(0.3, 1.8, 1.8), at(0, 3.25, 0) * UP)
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		b:Part("Cyl", Vector3.new(3.0, 0.15, 0.15), at(math.cos(a) * 0.75, 1.7, math.sin(a) * 0.75) * UP, b.Secondary, Enum.Material.Metal)
	end
	b:Part("Ball", Vector3.new(1.2, 1.2, 1.2), at(0, 2.45, 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass)
	b:Part("Ball", Vector3.new(1.2, 1.2, 1.2), at(0, 0.95, 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass)
	b:Part("Ball", Vector3.new(0.8, 0.8, 0.8), at(0, 0.85, 0), b.Secondary, Enum.Material.Neon)
	b:Part("Cyl", Vector3.new(0.6, 0.12, 0.12), at(0, 1.7, 0) * UP, b.Secondary, Enum.Material.Neon)
end

function Shapes.Heart(b)
	b:Part("Cyl", Vector3.new(0.3, 1.4, 1.4), at(0, 0.15, 0) * UP, b.Secondary, Enum.Material.Metal)
	b:Part("Ball", Vector3.new(1.4, 1.4, 1.4), at(-0.5, 2.5, 0))
	b:Part("Ball", Vector3.new(1.4, 1.4, 1.4), at(0.5, 2.5, 0))
	b:Part("Block", Vector3.new(1.4, 1.4, 1.0), at(0, 1.75, 0) * CFrame.Angles(0, 0, math.rad(45)))
	b:Part("Ball", Vector3.new(0.6, 0.6, 0.6), at(0, 2.2, 0.4), b.Secondary, Enum.Material.Neon)
end

function Shapes.Book(b)
	b:Part("Block", Vector3.new(1.6, 0.3, 1.2), at(0, 0.15, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	local cf = at(0, 1.5, 0) * CFrame.Angles(math.rad(-15), 0, 0)
	b:Part("Block", Vector3.new(2.0, 2.6, 0.5), cf)
	b:Part("Block", Vector3.new(1.8, 2.45, 0.52), cf * at(0.08, 0, 0), Color3.fromRGB(250, 245, 225), Enum.Material.SmoothPlastic)
	b:Part("Block", Vector3.new(2.05, 2.65, 0.08), cf * at(0, 0, 0.27))
	b:Part("Block", Vector3.new(0.7, 0.7, 0.1), cf * at(0, 0.2, 0.32) * CFrame.Angles(0, 0, math.rad(45)), b.Secondary, Enum.Material.Neon)
end

function Shapes.Feather(b)
	b:Part("Cyl", Vector3.new(0.3, 1.2, 1.2), at(0, 0.15, 0) * UP, Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	local cf = at(0, 2.0, 0) * CFrame.Angles(0, 0, math.rad(12))
	b:Part("Cyl", Vector3.new(3.8, 0.12, 0.12), cf * UP, b.Secondary, Enum.Material.SmoothPlastic)
	b:Part("Block", Vector3.new(1.2, 3.4, 0.2), cf * at(0, 0.2, 0), nil, nil, Vector3.new(1, 1, 0.3))
	b:Part("Block", Vector3.new(0.6, 2.4, 0.22), cf * at(0, 0.3, 0), b.Secondary, Enum.Material.Neon, Vector3.new(1, 1, 0.3))
end

TreasureModels.Shapes = Shapes

-- Faces ---------------------------------------------------------------------
-- Where each shape's "face" sits (y, z-front, scale). Shapes that already have
-- eyes (Skull, Idol, Mask) get none. +Z is the front of every model.
local FACE = {
	Gem = { 1.9, 1.05, 0.8 },
	Crown = { 0.75, 1.45, 0.7 },
	Chalice = { 2.3, 1.02, 0.75 },
	CoinStack = { 1.0, 0.82, 0.55 },
	Orb = { 2.1, 1.1, 0.85 },
	Sword = { 3.55, 0.17, 0.4 },
	Chest = { 0.55, 0.92, 0.85 },
	Egg = { 1.6, 0.96, 0.85 },
	Star = { 2.25, 0.3, 0.6 },
	Trophy = { 2.6, 0.92, 0.7 },
	Ring = { 2.85, 0.4, 0.42 },
	Crystal = { 2.0, 0.42, 0.5 },
	Key = { 3.45, 0.25, 0.42 },
	Lamp = { 0.9, 0.76, 0.65 },
	Potion = { 1.05, 0.96, 0.8 },
	Cube = { 1.8, 1.1, 0.7 },
	Pyramid = { 0.85, 1.1, 0.6 },
	Shield = { 1.95, 0.25, 0.55 },
	Hourglass = { 2.45, 0.62, 0.5 },
	Heart = { 2.35, 0.75, 0.8 },
	Book = { 1.6, 0.42, 0.6 },
	Feather = { 2.6, 0.14, 0.4 },
}
TreasureModels.Face = FACE

local EYE_COLOR = Color3.fromRGB(25, 20, 35)
local function addFace(b)
	local f = FACE[b.Def.Shape]
	if not f then
		return
	end
	local y, z, k = f[1], f[2], f[3]
	local face = Instance.new("Folder")
	face.Name = "Face"
	face.Parent = b.Model
	local function facePart(name, shape, size, offset, color, mat, rot)
		local p = b:Part(shape, size, at(offset.X, offset.Y, offset.Z) * (rot or CFrame.identity), color, mat or Enum.Material.SmoothPlastic)
		p.Name = name
		p:SetAttribute("BaseSize", p.Size)
		p.Parent = face
		return p
	end
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "EyeL" or "EyeR"
		facePart(name, "Ball", Vector3.new(0.3, 0.3, 0.3) * k, Vector3.new(side * 0.3 * k, y + 0.12 * k, z), EYE_COLOR)
		facePart(name .. "Shine", "Ball", Vector3.new(0.1, 0.1, 0.1) * k, Vector3.new(side * 0.3 * k + 0.06 * k, y + 0.19 * k, z + 0.12 * k), Color3.new(1, 1, 1), Enum.Material.Neon)
		facePart("Cheek" .. name, "Ball", Vector3.new(0.16, 0.16, 0.16) * k, Vector3.new(side * 0.5 * k, y - 0.08 * k, z - 0.02), Color3.fromRGB(255, 130, 160), Enum.Material.SmoothPlastic)
	end
	-- smile made of three tilted segments
	facePart("Mouth1", "Block", Vector3.new(0.14, 0.06, 0.06) * k, Vector3.new(-0.12 * k, y - 0.12 * k, z), EYE_COLOR, nil, CFrame.Angles(0, 0, math.rad(-30)))
	facePart("Mouth2", "Block", Vector3.new(0.14, 0.06, 0.06) * k, Vector3.new(0, y - 0.16 * k, z), EYE_COLOR)
	facePart("Mouth3", "Block", Vector3.new(0.14, 0.06, 0.06) * k, Vector3.new(0.12 * k, y - 0.12 * k, z), EYE_COLOR, nil, CFrame.Angles(0, 0, math.rad(30)))
	local o = facePart("MouthO", "Ball", Vector3.new(0.16, 0.16, 0.16) * k, Vector3.new(0, y - 0.15 * k, z), EYE_COLOR)
	o.Transparency = 1
end

-- Effects -------------------------------------------------------------------
local FX = {
	Fire = { Tex = TEX_FIRE, C1 = Color3.fromRGB(255, 170, 40), C2 = Color3.fromRGB(255, 50, 0), Speed = 3, Rise = 4, Size = 0.9, Life = 0.9 },
	Frost = { Tex = TEX_SPARKLE, C1 = Color3.fromRGB(200, 245, 255), C2 = Color3.fromRGB(120, 200, 255), Speed = 1, Rise = -1, Size = 0.4, Life = 2 },
	Spark = { Tex = TEX_SPARKLE, C1 = Color3.fromRGB(255, 240, 120), C2 = Color3.fromRGB(255, 200, 60), Speed = 3, Rise = 1, Size = 0.35, Life = 1 },
	Void = { Tex = TEX_SMOKE, C1 = Color3.fromRGB(120, 30, 200), C2 = Color3.fromRGB(10, 0, 20), Speed = 0.6, Rise = 1, Size = 1.2, Life = 2.2 },
	Bubbles = { Tex = TEX_SPARKLE, C1 = Color3.fromRGB(150, 255, 250), C2 = Color3.fromRGB(80, 180, 255), Speed = 0.8, Rise = 3, Size = 0.5, Life = 2 },
	Leaves = { Tex = TEX_SPARKLE, C1 = Color3.fromRGB(140, 255, 120), C2 = Color3.fromRGB(40, 160, 60), Speed = 1.2, Rise = -0.5, Size = 0.45, Life = 2.4 },
	Stars = { Tex = TEX_SPARKLE, C1 = Color3.fromRGB(255, 255, 255), C2 = Color3.fromRGB(255, 230, 140), Speed = 2, Rise = 1.5, Size = 0.5, Life = 1.6 },
	Hearts = { Tex = TEX_SPARKLE, C1 = Color3.fromRGB(255, 140, 200), C2 = Color3.fromRGB(255, 60, 130), Speed = 1.5, Rise = 2.5, Size = 0.55, Life = 1.6 },
	Lightning = { Tex = TEX_SPARKLE, C1 = Color3.fromRGB(255, 255, 140), C2 = Color3.fromRGB(80, 160, 255), Speed = 8, Rise = 0, Size = 0.3, Life = 0.4 },
	Rainbow = { Tex = TEX_SPARKLE, Rainbow = true, Speed = 2.5, Rise = 2, Size = 0.6, Life = 1.8 },
}
TreasureModels.FX = FX

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 255, 100)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 220)),
})

local function addEmitter(parent: Instance, fx, rate: number, scale: number, name: string)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = fx.Tex
	e.Color = fx.Rainbow and RAINBOW or ColorSequence.new(fx.C1, fx.C2)
	e.LightEmission = 0.8
	e.LightInfluence = 0
	e.Rate = rate
	e.Lifetime = NumberRange.new(fx.Life * 0.7, fx.Life)
	e.Speed = NumberRange.new(fx.Speed * 0.5, fx.Speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, fx.Rise, 0)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, fx.Size * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parent
	return e
end

function TreasureModels.AddEffects(model: Model, def, root: BasePart, scale: number)
	local info = Rarities.Info[def.Rarity]
	local height = 2.2 * scale
	local att = Instance.new("Attachment")
	att.Name = "FxAttachment"
	att.Position = Vector3.new(0, height, 0)
	att.Parent = root

	local fx = FX[def.Fx]
	local rarityRate = info.Particles
	if fx then
		addEmitter(att, fx, math.max(3, rarityRate), scale, "FxEmitter")
	end
	if info.Sparkles and rarityRate > 0 then
		addEmitter(att, {
			Tex = TEX_SPARKLE,
			C1 = info.Glow,
			C2 = info.Color,
			Speed = 1.5,
			Rise = 1,
			Size = 0.35,
			Life = 1.2,
			Rainbow = info.Rainbow,
		}, rarityRate, scale, "RarityEmitter")
	end
	if info.Smoke then
		addEmitter(att, FX.Void, 4, scale * 1.4, "SmokeEmitter")
	end
	if info.Light > 0 then
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = def.Secondary
		light.Range = info.Light
		light.Brightness = 1.6
		light.Shadows = false
		light.Parent = att
	end
	if info.Beam then
		local a0 = Instance.new("Attachment")
		a0.Name = "BeamBottom"
		a0.Position = Vector3.new(0, 0.2, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "BeamTop"
		a1.Position = Vector3.new(0, 14 * scale, 0)
		a1.Parent = root
		local beam = Instance.new("Beam")
		beam.Name = "RarityBeam"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 2.6 * scale
		beam.Width1 = 0.2 * scale
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = info.Rainbow and RAINBOW or ColorSequence.new(info.Glow)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureSpeed = 0.6
		beam.TextureLength = 3
		beam.Parent = root
	end
	if info.Orbit then
		local moons = Instance.new("Model")
		moons.Name = "Orbit"
		for i = 1, 3 do
			local p = Instance.new("Part")
			p.Name = "Moon"
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(0.5, 0.5, 0.5) * scale
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromHSV(0.5 + i * 0.12, 0.5, 1)
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.CastShadow = false
			local a = i / 3 * math.pi * 2
			p.CFrame = root.CFrame * CFrame.new(math.cos(a) * 2.6 * scale, height, math.sin(a) * 2.6 * scale)
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
			p.Parent = moons
		end
		moons.Parent = model
	end
	if info.Halo then
		local halo = Instance.new("Model")
		halo.Name = "Halo"
		local segs = 10
		local r = 1.9 * scale
		for i = 0, segs - 1 do
			local a = (i / segs) * math.pi * 2
			local p = Instance.new("Part")
			p.Name = "HaloSeg"
			p.Size = Vector3.new(0.35, 0.15, 0.35) * scale
			p.Shape = Enum.PartType.Ball
			p.Material = Enum.Material.Neon
			p.Color = info.Glow
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.CastShadow = false
			p.CFrame = root.CFrame * CFrame.new(math.cos(a) * r, height + 0.4 * scale, math.sin(a) * r)
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
			p.Parent = halo
		end
		halo.Parent = model
	end
	model:SetAttribute("Rainbow", info.Rainbow)
	model:SetAttribute("Lightning", def.Fx == "Lightning")
end

-- Public API --------------------------------------------------------------
-- opts: { Scale = number?, Effects = boolean?, CFrame = CFrame?, Anchored = boolean? }
function TreasureModels.Build(def, opts)
	opts = opts or {}
	local scale = opts.Scale or 1
	local model = Instance.new("Model")
	model.Name = def.Name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CastShadow = false
	root.Anchored = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local builder = newBuilder(model, root, scale, def)
	local fn = Shapes[def.Shape] or Shapes.Gem
	fn(builder)
	if opts.Face ~= false then
		addFace(builder)
	end

	if opts.Effects ~= false then
		TreasureModels.AddEffects(model, def, root, scale)
	end

	model:SetAttribute("TreasureId", def.Id)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("Personality", def.Personality)

	local cf = opts.CFrame or CFrame.new()
	model:PivotTo(cf)
	model:SetAttribute("Home", cf)
	root.Anchored = opts.Anchored ~= false
	return model
end

-- Approximate height so labels can sit above the model.
function TreasureModels.Height(def, scale: number?): number
	local s = scale or 1
	local tall = { Sword = 4.9, Idol = 3.7, Key = 4.1, Feather = 4.0, Mask = 3.9, Crystal = 3.8, Hourglass = 3.4 }
	return (tall[def.Shape] or 3.1) * s
end

return TreasureModels
