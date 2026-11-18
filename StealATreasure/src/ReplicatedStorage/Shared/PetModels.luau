-- PetModels.lua
-- Procedural pet builder. Every part is anchored and tagged with a Role so
-- the client follower can animate legs, wings, tails and ears each frame by
-- moving parts relative to the pet's root (BulkMoveTo, no physics).

local PetData = require(script.Parent.PetData)
local Rarities = require(script.Parent.Rarities)

local PetModels = {}

local function mat(name: string): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return ok and m or Enum.Material.SmoothPlastic
end

-- Builds a pet. Returns model, parts list { {Part, Offset: CFrame, Role} }
function PetModels.Build(def, scale: number?)
	local s = scale or 1
	local sp = PetData.Species[def.Species] or {}
	local model = Instance.new("Model")
	model.Name = def.Name
	local parts = {}
	local bodyMat = mat(def.Material)

	local function add(shape: string, size: Vector3, offset: CFrame, color: Color3, role: string?, material: Enum.Material?)
		local p = Instance.new("Part")
		if shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif shape == "Cyl" then
			p.Shape = Enum.PartType.Cylinder
		elseif shape == "Wedge" then
			p = Instance.new("WedgePart")
		end
		p.Size = size * s
		p.Color = color
		p.Material = material or bodyMat
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if p.Material == Enum.Material.Glass then
			p.Transparency = 0.3
		end
		if sp.Ghostly then
			p.Transparency = 0.25
		end
		local off = CFrame.new(offset.Position * s) * offset.Rotation
		p.CFrame = off
		p.Parent = model
		table.insert(parts, { Part = p, Offset = off, Role = role or "Body" })
		return p
	end

	local body, accent = def.Body, def.Accent
	local eye = Color3.fromRGB(20, 20, 30)

	-- Body + head
	if sp.Boxy then
		add("Block", Vector3.new(1.6, 1.4, 1.2), CFrame.new(0, 1.2, 0), body)
		add("Block", Vector3.new(1.3, 1.1, 1.1), CFrame.new(0, 2.45, 0.05), body, "Head")
		add("Block", Vector3.new(1.0, 0.5, 0.05), CFrame.new(0, 2.5, 0.6), accent, "Head", Enum.Material.Neon)
	elseif sp.Blob then
		local b = add("Block", Vector3.new(2, 1.7, 2), CFrame.new(0, 1, 0), body, "Squash")
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = b
	elseif sp.Tentacles then
		add("Ball", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, 1.8, 0), body, "Head")
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			add("Cyl", Vector3.new(1.4, 0.35, 0.35), CFrame.new(math.cos(a) * 0.55, 0.7, math.sin(a) * 0.55) * CFrame.Angles(0, 0, math.rad(90)), accent, "Tentacle")
		end
	else
		local bodyW = sp.Wide and 1.8 or 1.4
		local b = add("Block", Vector3.new(bodyW, 1.2, sp.Legs == 4 and 1.8 or 1.3), CFrame.new(0, 1.15, 0), body, "Body")
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = b
		add("Ball", Vector3.new(1.35, 1.35, 1.35), CFrame.new(0, 2.05, sp.Legs == 4 and 0.75 or 0.15), body, "Head")
	end

	local headZ = (sp.Legs == 4) and 0.75 or 0.15
	local headY = sp.Boxy and 2.45 or (sp.Blob and 1.1 or (sp.Tentacles and 1.8 or 2.05))
	local faceZ = headZ + (sp.Blob and 0.95 or (sp.Tentacles and 0.85 or 0.62))
	if sp.Boxy then
		faceZ = 0.62
	end

	-- Eyes
	local eyeY = sp.Eyes == "Top" and headY + 0.55 or headY + 0.12
	for _, x in ipairs({ -0.28, 0.28 }) do
		add("Ball", Vector3.new(0.3, 0.3, 0.3), CFrame.new(x, eyeY, faceZ), eye, "Head", Enum.Material.SmoothPlastic)
		add("Ball", Vector3.new(0.1, 0.1, 0.1), CFrame.new(x + 0.05, eyeY + 0.07, faceZ + 0.12), Color3.new(1, 1, 1), "Head", Enum.Material.Neon)
	end
	-- Snout / beak / nose
	if sp.Snout then
		add("Ball", Vector3.new(0.6, 0.5, 0.6), CFrame.new(0, headY - 0.2, faceZ + 0.05), accent, "Head")
		add("Ball", Vector3.new(0.2, 0.15, 0.15), CFrame.new(0, headY - 0.1, faceZ + 0.32), eye, "Head", Enum.Material.SmoothPlastic)
	elseif sp.Beak then
		add("Wedge", Vector3.new(0.3, 0.25, 0.4), CFrame.new(0, headY - 0.15, faceZ + 0.15) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(255, 170, 40), "Head", Enum.Material.SmoothPlastic)
	elseif not sp.Boxy then
		add("Block", Vector3.new(0.3, 0.06, 0.06), CFrame.new(0, headY - 0.2, faceZ), eye, "Head", Enum.Material.SmoothPlastic)
	end
	-- Ears
	if sp.Ears == "Pointy" or sp.Ears == "Tuft" then
		for _, x in ipairs({ -0.4, 0.4 }) do
			add("Wedge", Vector3.new(0.2, 0.55, 0.4), CFrame.new(x, headY + 0.7, headZ) * CFrame.Angles(0, 0, math.rad(x > 0 and -15 or 15)), accent, "Ear")
		end
	elseif sp.Ears == "Round" then
		for _, x in ipairs({ -0.5, 0.5 }) do
			add("Ball", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, headY + 0.55, headZ), accent, "Ear")
		end
	elseif sp.Ears == "Long" then
		for _, x in ipairs({ -0.25, 0.25 }) do
			add("Block", Vector3.new(0.25, 1.1, 0.15), CFrame.new(x, headY + 1.05, headZ - 0.05), body, "Ear")
			add("Block", Vector3.new(0.14, 0.8, 0.05), CFrame.new(x, headY + 1.05, headZ + 0.03), accent, "Ear")
		end
	elseif sp.Ears == "Floppy" then
		for _, x in ipairs({ -0.62, 0.62 }) do
			add("Block", Vector3.new(0.2, 0.8, 0.45), CFrame.new(x, headY, headZ) * CFrame.Angles(0, 0, math.rad(x > 0 and 15 or -15)), accent, "Ear")
		end
	end
	if sp.Horn then
		add("Wedge", Vector3.new(0.18, 0.8, 0.25), CFrame.new(0, headY + 0.9, headZ + 0.3), Color3.fromRGB(255, 230, 120), "Head", Enum.Material.Neon)
	end
	if sp.Antenna then
		for _, x in ipairs({ -0.25, 0.25 }) do
			add("Cyl", Vector3.new(0.6, 0.08, 0.08), CFrame.new(x, headY + 0.85, headZ) * CFrame.Angles(0, 0, math.rad(90)), eye, "Ear")
			add("Ball", Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, headY + 1.15, headZ), accent, "Ear", Enum.Material.Neon)
		end
	end
	-- Legs
	if sp.Legs == 4 then
		for _, lp in ipairs({ { -0.45, 0.6, "LegA" }, { 0.45, -0.6, "LegA" }, { 0.45, 0.6, "LegB" }, { -0.45, -0.6, "LegB" } }) do
			add("Cyl", Vector3.new(0.6, 0.35, 0.35), CFrame.new(lp[1], 0.35, lp[2]) * CFrame.Angles(0, 0, math.rad(90)), body, lp[3])
		end
	elseif sp.Legs == 2 then
		add("Cyl", Vector3.new(0.6, 0.3, 0.3), CFrame.new(-0.35, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), sp.Boxy and accent or Color3.fromRGB(255, 170, 40), "LegA")
		add("Cyl", Vector3.new(0.6, 0.3, 0.3), CFrame.new(0.35, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), sp.Boxy and accent or Color3.fromRGB(255, 170, 40), "LegB")
	end
	-- Wings
	if sp.Wings then
		local wingSize = sp.Wings == "Small" and Vector3.new(0.6, 0.15, 0.5)
			or (sp.Wings == "Flipper" and Vector3.new(0.5, 0.12, 0.3) or (sp.Wings == "Bug" and Vector3.new(1.0, 0.05, 0.6) or Vector3.new(1.6, 0.12, 0.9)))
		local wingMat = sp.Wings == "Bug" and Enum.Material.Glass or nil
		add("Block", wingSize, CFrame.new(-0.7 - wingSize.X / 2, 1.5, -0.1), accent, "WingL", wingMat)
		add("Block", wingSize, CFrame.new(0.7 + wingSize.X / 2, 1.5, -0.1), accent, "WingR", wingMat)
	end
	if sp.Fins then
		add("Block", Vector3.new(1.0, 0.12, 0.6), CFrame.new(-1.0, 1.0, 0.2), accent, "WingL")
		add("Block", Vector3.new(1.0, 0.12, 0.6), CFrame.new(1.0, 1.0, 0.2), accent, "WingR")
	end
	-- Tail
	if sp.Tail then
		local tailSize = (sp.Tail == "Long" or sp.Tail == "Thin") and Vector3.new(0.2, 0.2, 1.2)
			or (sp.Tail == "Fluffy" and Vector3.new(0.55, 0.55, 1.1) or (sp.Tail == "Feather" and Vector3.new(0.5, 0.1, 1.2) or (sp.Tail == "Fin" and Vector3.new(1.4, 0.15, 0.6) or Vector3.new(0.4, 0.4, 0.4))))
		local shape = (sp.Tail == "Puff" or sp.Tail == "Curl") and "Ball" or "Block"
		add(shape, tailSize, CFrame.new(0, 1.3, -1.0 - tailSize.Z / 3) * CFrame.Angles(math.rad(-25), 0, 0), sp.Tail == "Fluffy" and accent or body, "Tail")
	end
	if sp.Stripes then
		for i = -1, 1 do
			add("Block", Vector3.new(1.45, 0.18, 0.2), CFrame.new(0, 1.15, i * 0.35), accent, "Body", Enum.Material.SmoothPlastic)
		end
	end
	if sp.Shell then
		local sh = add("Block", Vector3.new(1.7, 0.9, 2), CFrame.new(0, 1.55, -0.1), accent, "Body")
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = sh
	end

	-- Rarity effects
	local info = Rarities.Info[def.Rarity]
	local rootPart = parts[1].Part
	rootPart.Name = "PetRoot"
	model.PrimaryPart = rootPart
	if info and info.Particles > 0 then
		local e = Instance.new("ParticleEmitter")
		e.Texture = sp.Fiery and "rbxasset://textures/particles/fire_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(info.Glow, def.Accent)
		e.LightEmission = 0.8
		e.Rate = math.max(2, info.Particles * 0.5)
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new(0.3 * s, 0)
		e.Parent = rootPart
	end
	if info and info.Light > 0 then
		local l = Instance.new("PointLight")
		l.Color = def.Accent
		l.Range = 6 + info.Rank
		l.Brightness = 1.2
		l.Parent = rootPart
	end
	model:SetAttribute("PetId", def.Id)
	return model, parts
end

return PetModels
