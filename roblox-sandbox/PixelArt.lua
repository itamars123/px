--[[
	PixelArt  (ModuleScript → ReplicatedStorage)
	All pixel art for "Block Diggers": 8x8 block textures, the hero sprite,
	the monster sprite, and helpers to draw them.
	Each pattern is a list of strings. "." = base colour / empty,
	any other character = a colour from the palette.
]]

local PixelArt = {}

local rgb = Color3.fromRGB

---------------------------------------------------------------------
-- BLOCK TEXTURES (8x8)
---------------------------------------------------------------------
local ORE = {
	"........",
	".oO..d..",
	".ooo....",
	"....oO..",
	"..d.ooo.",
	".oO.....",
	".ooo..O.",
	"......oo",
}

PixelArt.Blocks = {
	Dirt = {
		base = rgb(134, 96, 67),
		palette = { d = rgb(105, 72, 50), l = rgb(160, 118, 84) },
		rows = {
			"..d.....",
			"......l.",
			".l...d..",
			"....d...",
			"d......l",
			"...l....",
			".d....d.",
			"....l...",
		},
	},
	Grass = {
		base = rgb(134, 96, 67),
		palette = { g = rgb(98, 180, 60), G = rgb(140, 215, 85), d = rgb(105, 72, 50), l = rgb(160, 118, 84) },
		rows = {
			"GGgGGGgG",
			"gggggggg",
			"g.gg.ggg",
			"..g...g.",
			"....d...",
			".l....d.",
			"d...l...",
			"...d...l",
		},
	},
	Stone = {
		base = rgb(128, 128, 132),
		palette = { d = rgb(100, 100, 106), l = rgb(155, 155, 160) },
		rows = {
			"..dd....",
			".d..l...",
			"........",
			"l...dd..",
			"...d..l.",
			".l......",
			"....d..d",
			"dd....l.",
		},
	},
	CoalOre = {
		base = rgb(128, 128, 132),
		palette = { o = rgb(35, 35, 40), O = rgb(65, 65, 72), d = rgb(100, 100, 106) },
		rows = ORE,
	},
	IronOre = {
		base = rgb(128, 128, 132),
		palette = { o = rgb(210, 150, 110), O = rgb(245, 205, 170), d = rgb(100, 100, 106) },
		rows = ORE,
	},
	GoldOre = {
		base = rgb(128, 128, 132),
		palette = { o = rgb(250, 190, 30), O = rgb(255, 245, 150), d = rgb(100, 100, 106) },
		rows = ORE,
	},
	Trunk = {
		base = rgb(120, 82, 48),
		palette = { d = rgb(90, 60, 35), l = rgb(150, 105, 65) },
		rows = {
			".d...d..",
			".d..l...",
			".d...d..",
			"..l..d..",
			".d...d..",
			".d..l.d.",
			".d...d..",
			"..l..d..",
		},
	},
	Leaves = {
		base = rgb(60, 150, 55),
		palette = { L = rgb(95, 190, 75), d = rgb(40, 110, 40) },
		rows = {
			"..L...d.",
			".d..L...",
			"L...d..L",
			"..L.....",
			"d....L.d",
			"..d.....",
			".L...d.L",
			"...L....",
		},
	},
	Planks = {
		base = rgb(190, 140, 85),
		palette = { d = rgb(140, 95, 55), l = rgb(215, 170, 110) },
		rows = {
			"llllllll",
			"........",
			"...d....",
			"dddddddd",
			"llllllll",
			"........",
			"......d.",
			"dddddddd",
		},
	},
	StoneBrick = {
		base = rgb(150, 150, 160),
		palette = { d = rgb(100, 100, 110), l = rgb(185, 185, 195) },
		rows = {
			"lllldlll",
			"....d...",
			"....d...",
			"dddddddd",
			"dlllllll",
			"d.......",
			"d.......",
			"dddddddd",
		},
	},
	Bedrock = {
		base = rgb(40, 40, 48),
		palette = { d = rgb(20, 20, 25), x = rgb(70, 70, 80) },
		rows = {
			"d..x..d.",
			".x...x..",
			"...d....",
			"x.....x.",
			"..x.d...",
			"d.....x.",
			".x.d....",
			"....x..d",
		},
	},
	Torch = {
		base = nil, -- transparent background
		palette = { y = rgb(255, 150, 40), Y = rgb(255, 240, 120), w = rgb(130, 85, 45) },
		rows = {
			"........",
			"...yy...",
			"..yYYy..",
			"...yy...",
			"...ww...",
			"...ww...",
			"...ww...",
			"...ww...",
		},
	},
}

---------------------------------------------------------------------
-- HERO SPRITE (10 x 16, facing right)
---------------------------------------------------------------------
PixelArt.Hero = {
	palette = {
		h = rgb(90, 55, 30), s = rgb(245, 200, 160), e = rgb(30, 30, 40),
		c = rgb(60, 120, 220), C = rgb(40, 85, 170), p = rgb(45, 45, 90), b = rgb(70, 45, 25),
	},
	body = {
		"...hhhh...",
		"..hhhhhhh.",
		"..hhsssss.",
		"..hsssses.",
		"..hssssss.",
		"...ssss...",
		"..cccccc..",
		".cCccccCc.",
		".cCccccCc.",
		".s.cccc.s.",
		"...pppp...",
		"...pppp...",
	},
	legsA = { -- standing
		"...p..p...",
		"...p..p...",
		"...p..p...",
		"..bb..bb..",
	},
	legsB = { -- walking step
		"...pp.p...",
		"..pp...p..",
		".pp....p..",
		".bb....bb.",
	},
}

---------------------------------------------------------------------
-- MONSTER SPRITE (8 x 8)
---------------------------------------------------------------------
PixelArt.Monster = {
	palette = { m = rgb(130, 50, 170), M = rgb(170, 90, 210), Y = rgb(255, 240, 60), k = rgb(20, 10, 30), d = rgb(70, 20, 90) },
	rows = {
		"..mmmm..",
		".mMMmmm.",
		"mMmmmmmm",
		"mYkmmYkm",
		"mmmmmmmm",
		"mmmddmmm",
		"mmmmmmmm",
		".m.mm.m.",
	},
}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

-- Calls fn(char, col, row, length) for each horizontal run of same colour
function PixelArt.Runs(rows, fn)
	for r, line in ipairs(rows) do
		local c = 1
		while c <= #line do
			local ch = line:sub(c, c)
			if ch ~= "." then
				local len = 1
				while c + len <= #line and line:sub(c + len, c + len) == ch do
					len += 1
				end
				fn(ch, c - 1, r - 1, len)
				c += len
			else
				c += 1
			end
		end
	end
end

-- Draws a pattern into a GUI object using scale coordinates
local function drawPattern(parent, art, mirror)
	local n = #art.rows
	PixelArt.Runs(art.rows, function(ch, col, row, len)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = art.palette[ch]
		local x = mirror and (n - col - len) or col
		f.Position = UDim2.fromScale(x / n, row / n)
		f.Size = UDim2.fromScale(len / n, 1 / n)
		f.Parent = parent
	end)
end

-- Puts a pixel texture on the camera-facing side of a block part (client only)
function PixelArt.MakeSkin(part, blockType, mirror)
	local art = PixelArt.Blocks[blockType]
	if not art then return nil end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PixelSkin"
	gui.Face = Enum.NormalId.Back -- the +Z side, where the camera is
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 16
	drawPattern(gui, art, mirror)
	gui.Parent = part
	return gui
end

-- Draws a block icon inside a UI frame (for the hotbar)
function PixelArt.MakeIcon(parent, blockType)
	local art = PixelArt.Blocks[blockType]
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BorderSizePixel = 0
	holder.BackgroundColor3 = art.base or Color3.new()
	holder.BackgroundTransparency = art.base and 0 or 1
	holder.Parent = parent
	drawPattern(holder, art, false)
	return holder
end

--[[
	Builds a sprite out of flat parts welded to `root`.
	opts.ps        pixel size in studs
	opts.top       Y offset (from root) of the sprite's top edge
	opts.width     number of columns
	opts.rowOffset first row index of this layer
	opts.facing    true = attach to a character (sprite flips with facing)
	opts.tag       optional attribute value for "Layer"
]]
function PixelArt.BuildLayer(model, root, rows, palette, opts)
	local ps = opts.ps
	local parts = {}
	PixelArt.Runs(rows, function(ch, col, row, len)
		local p = Instance.new("Part")
		p.Name = "Pixel"
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = palette[ch]

		local dx = (col + len / 2 - opts.width / 2) * ps
		local dy = opts.top - ps * ((opts.rowOffset or 0) + row + 0.5)

		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = p
		if opts.facing then
			-- character root looks along its -Z, so "forward" = -Z, sideways = X
			p.Size = Vector3.new(0.2, ps, ps * len)
			weld.C0 = CFrame.new(0, dy, -dx)
		else
			p.Size = Vector3.new(ps * len, ps, 0.2)
			weld.C0 = CFrame.new(dx, dy, 0)
		end
		weld.Parent = p
		if opts.tag then p:SetAttribute("Layer", opts.tag) end
		p.Parent = model
		table.insert(parts, p)
	end)
	return parts
end

return PixelArt
