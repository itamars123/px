--[[
	SandboxServer  (Script → ServerScriptService)
	"Block Diggers" – 2D sandbox: world generation, mining, building,
	crafting, day/night cycle and night monsters.
	The server owns the world and every inventory; the client only asks.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local BlockData = require(ReplicatedStorage:WaitForChild("BlockData"))
local PixelArt = require(ReplicatedStorage:WaitForChild("PixelArt"))
local BS, W, H, Z = BlockData.BLOCK_SIZE, BlockData.WIDTH, BlockData.HEIGHT, BlockData.PLANE_Z
local Blocks = BlockData.Blocks

local DAY_LENGTH = 360           -- seconds for a full day
local MAX_ENEMIES = 6
local ENEMY_HEALTH = 60
local ENEMY_DAMAGE = 15
local START_TORCHES = 5

---------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = ReplicatedStorage
	return r
end
local BlockAction = remote("BlockAction")   -- ("start"|"finish"|"place", x, y, item)
local CraftEvent = remote("Craft")          -- (recipeIndex)
local AttackEvent = remote("Attack")        -- (enemyModel)
local MessageEvent = remote("SandboxMessage")

---------------------------------------------------------------------
-- WORLD
---------------------------------------------------------------------
local worldFolder = Instance.new("Folder")
worldFolder.Name = "World"
worldFolder.Parent = workspace

local enemyFolder = Instance.new("Folder")
enemyFolder.Name = "Enemies"
enemyFolder.Parent = workspace

local grid = {}
for x = 0, W - 1 do grid[x] = {} end

local function inBounds(x, y)
	return x >= 0 and x < W and y >= 0 and y < H
end

local function createBlock(x, y, blockType)
	local info = Blocks[blockType]
	local part = Instance.new("Part")
	part.Name = x .. "," .. y
	part.Anchored = true
	if info.back then
		-- decorations sit behind the player so you can walk "through" them
		part.Size = Vector3.new(BS, BS, 0.5)
		part.Position = BlockData.CellToWorld(x, y) + Vector3.new(0, 0, -1.2)
	else
		part.Size = Vector3.new(BS, BS, BS)
		part.Position = BlockData.CellToWorld(x, y)
	end
	part.Color = info.color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = info.solid ~= false
	part.Transparency = info.transparency or 0
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("BlockType", blockType)
	if info.light then
		local light = Instance.new("PointLight")
		light.Range = 20
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 190, 120)
		light.Parent = part
	end
	part.Parent = worldFolder
	grid[x][y] = part
	return part
end

local function removeBlock(x, y)
	local part = grid[x][y]
	if part then
		part:Destroy()
		grid[x][y] = nil
	end
end

local function highestSolid(x)
	for y = H - 1, 0, -1 do
		local p = grid[x][y]
		if p and p.CanCollide then return y end
	end
	return 0
end

local seed = math.random(1, 100000) / 100
local rng = Random.new()
local surface = {}
local SPAWN_X = math.floor(W / 2)

for x = 0, W - 1 do
	local h = 32 + math.noise(x / 28, seed) * 9 + math.noise(x / 9, seed + 17) * 3
	h = math.clamp(math.floor(h), 20, H - 12)
	surface[x] = h

	for y = 0, h do
		local blockType
		if y == 0 then
			blockType = "Bedrock"
		elseif y == h then
			blockType = "Grass"
		elseif y > h - 4 then
			blockType = "Dirt"
		else
			local cave = math.noise(x / 11, y / 8, seed + 40)
			if y > 2 and y < h - 5 and cave > 0.22 then
				blockType = nil -- cave air
			else
				local roll = rng:NextNumber()
				if y < 14 and roll < 0.025 then
					blockType = "GoldOre"
				elseif y < 26 and roll < 0.06 then
					blockType = "IronOre"
				elseif roll < 0.11 then
					blockType = "CoalOre"
				else
					blockType = "Stone"
				end
			end
		end
		if blockType then
			createBlock(x, y, blockType)
		end
	end

	-- dark dirt wall behind the underground (looks nicer when you dig)
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.CastShadow = false
	wall.Size = Vector3.new(BS, h * BS, 1)
	wall.Position = Vector3.new(x * BS, h * BS / 2 - BS / 2, Z - BS / 2 - 0.5)
	wall.Color = Color3.fromRGB(52, 36, 26)
	wall.Material = Enum.Material.SmoothPlastic
	wall.Parent = worldFolder
end

-- trees
local lastTree = -10
for x = 2, W - 3 do
	if math.abs(x - SPAWN_X) > 3 and x - lastTree > 4 and rng:NextNumber() < 0.18 then
		lastTree = x
		local base = surface[x] + 1
		local height = rng:NextInteger(4, 6)
		for y = base, math.min(base + height - 1, H - 1) do
			createBlock(x, y, "Trunk")
		end
		local top = base + height
		for dx = -2, 2 do
			for dy = -1, 1 do
				local lx, ly = x + dx, top + dy
				if inBounds(lx, ly) and not grid[lx][ly] and not (math.abs(dx) == 2 and dy == 1) then
					createBlock(lx, ly, "Leaves")
				end
			end
		end
	end
end

-- spawn point above the middle of the map
local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.CanCollide = false
spawn.Transparency = 1
spawn.Size = Vector3.new(4, 1, 2)
spawn.Position = BlockData.CellToWorld(SPAWN_X, surface[SPAWN_X] + 3)
spawn.Parent = workspace

---------------------------------------------------------------------
-- PLAYERS & INVENTORY
---------------------------------------------------------------------
local function getInventory(player)
	return player:FindFirstChild("Inventory")
end

local function count(player, item)
	local inv = getInventory(player)
	local v = inv and inv:FindFirstChild(item)
	return v and v.Value or 0
end

local function add(player, item, amount)
	local inv = getInventory(player)
	if not inv then return end
	local v = inv:FindFirstChild(item)
	if not v then
		v = Instance.new("IntValue")
		v.Name = item
		v.Parent = inv
	end
	v.Value = math.max(0, v.Value + amount)
end

local function message(player, text)
	MessageEvent:FireClient(player, text)
end

local miningState = {}   -- [player] = {x, y, t}
local lastPlace = {}
local lastAttack = {}
local lastHurt = {}

---------------------------------------------------------------------
-- PIXEL HERO: hide the 3D avatar and weld a pixel sprite to it
---------------------------------------------------------------------
local HERO_PS = 0.34   -- stud size of one sprite pixel

local function hide(obj, sprite)
	if obj:IsDescendantOf(sprite) then return end
	if obj:IsA("Accessory") or obj:IsA("Clothing") or obj:IsA("ShirtGraphic") then
		task.defer(function() obj:Destroy() end)
	elseif obj:IsA("BasePart") then
		obj.Transparency = 1
	elseif obj:IsA("Decal") then
		obj.Transparency = 1
	end
end

local function makeHero(character)
	local root = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")
	-- height of the root above the floor (feet of the sprite touch the ground)
	local rootHeight = humanoid.HipHeight + root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R6 then rootHeight = 3 end

	local sprite = Instance.new("Model")
	sprite.Name = "PixelSprite"
	local hero = PixelArt.Hero
	local rows = #hero.body + #hero.legsA
	local top = -rootHeight + rows * HERO_PS
	local base = { ps = HERO_PS, top = top, width = #hero.body[1], facing = true }

	PixelArt.BuildLayer(sprite, root, hero.body, hero.palette, base)
	local legOpts = table.clone(base)
	legOpts.rowOffset = #hero.body
	legOpts.tag = "LegA"
	PixelArt.BuildLayer(sprite, root, hero.legsA, hero.palette, legOpts)
	legOpts.tag = "LegB"
	for _, p in ipairs(PixelArt.BuildLayer(sprite, root, hero.legsB, hero.palette, legOpts)) do
		p.Transparency = 1
	end
	sprite.Parent = character

	for _, obj in ipairs(character:GetDescendants()) do hide(obj, sprite) end
	character.DescendantAdded:Connect(function(obj) hide(obj, sprite) end)
end

Players.PlayerAdded:Connect(function(player)
	local inv = Instance.new("Folder")
	inv.Name = "Inventory"
	inv.Parent = player
	add(player, "Torch", START_TORCHES)

	player.CharacterAdded:Connect(makeHero)
	if player.Character then task.spawn(makeHero, player.Character) end
end)

Players.PlayerRemoving:Connect(function(player)
	miningState[player] = nil
	lastPlace[player] = nil
	lastAttack[player] = nil
	lastHurt[player] = nil
end)

local function getRoot(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then return root end
	return nil
end

local function inReach(player, x, y)
	local root = getRoot(player)
	if not root then return false end
	return (root.Position - BlockData.CellToWorld(x, y)).Magnitude <= BlockData.REACH + 2
end

local function isCell(x, y)
	return typeof(x) == "number" and typeof(y) == "number"
		and x % 1 == 0 and y % 1 == 0 and inBounds(x, y)
end

local function cellBlocked(x, y)
	-- don't let blocks be placed inside players or monsters
	local center = BlockData.CellToWorld(x, y)
	local function overlaps(pos)
		return math.abs(pos.X - center.X) < BS / 2 + 1 and math.abs(pos.Y - center.Y) < BS / 2 + 2.6
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local root = getRoot(p)
		if root and overlaps(root.Position) then return true end
	end
	for _, enemy in ipairs(enemyFolder:GetChildren()) do
		if enemy.PrimaryPart and overlaps(enemy.PrimaryPart.Position) then return true end
	end
	return false
end

local function hasNeighbour(x, y)
	for _, d in ipairs({ {1, 0}, {-1, 0}, {0, 1}, {0, -1} }) do
		local nx, ny = x + d[1], y + d[2]
		if inBounds(nx, ny) and grid[nx][ny] then return true end
	end
	return false
end

---------------------------------------------------------------------
-- MINING & PLACING
---------------------------------------------------------------------
BlockAction.OnServerEvent:Connect(function(player, action, x, y, item)
	if not isCell(x, y) or not inReach(player, x, y) then return end
	local inv = getInventory(player)

	if action == "start" then
		local part = grid[x][y]
		if not part then return end
		local info = Blocks[part:GetAttribute("BlockType")]
		if info.hardness == math.huge then return end
		local tier = BlockData.GetPickaxe(inv)
		if (info.tier or 1) > tier then
			message(player, "⛏️ צריך מכוש ברזל כדי לחצוב זהב!")
			return
		end
		miningState[player] = { x = x, y = y, t = os.clock() }

	elseif action == "finish" then
		local state = miningState[player]
		local part = grid[x][y]
		if not state or state.x ~= x or state.y ~= y or not part then return end
		miningState[player] = nil

		local blockType = part:GetAttribute("BlockType")
		local info = Blocks[blockType]
		local tier, speed = BlockData.GetPickaxe(inv)
		if (info.tier or 1) > tier then return end
		local needed = info.hardness / speed
		if os.clock() - state.t < needed - 0.15 then return end -- too fast = cheating

		removeBlock(x, y)
		if info.drop then
			add(player, info.drop, 1)
		end

	elseif action == "place" then
		if typeof(item) ~= "string" or not table.find(BlockData.Placeable, item) then return end
		local now = os.clock()
		if lastPlace[player] and now - lastPlace[player] < 0.12 then return end
		if grid[x][y] or count(player, item) <= 0 then return end
		if not hasNeighbour(x, y) then return end
		if Blocks[item].solid ~= false and cellBlocked(x, y) then return end

		lastPlace[player] = now
		add(player, item, -1)
		createBlock(x, y, item)
	end
end)

---------------------------------------------------------------------
-- CRAFTING
---------------------------------------------------------------------
CraftEvent.OnServerEvent:Connect(function(player, index)
	if typeof(index) ~= "number" then return end
	local recipe = BlockData.Recipes[index]
	if not recipe then return end

	if recipe.tool then
		for item in pairs(recipe.gives) do
			if count(player, item) > 0 then
				message(player, "כבר יש לך " .. BlockData.Names[item])
				return
			end
		end
	end
	for item, amount in pairs(recipe.cost) do
		if count(player, item) < amount then
			message(player, "❌ אין מספיק " .. (BlockData.Names[item] or item))
			return
		end
	end
	for item, amount in pairs(recipe.cost) do add(player, item, -amount) end
	for item, amount in pairs(recipe.gives) do add(player, item, amount) end
	local _, first = next(recipe.gives)
	message(player, "🔨 יצרת " .. BlockData.Names[recipe.id] .. " ×" .. first)
end)

---------------------------------------------------------------------
-- DAY / NIGHT  (flat, shadow-less lighting = cleaner pixel look)
---------------------------------------------------------------------
Lighting.GlobalShadows = false
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(70, 70, 90)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
for _, effect in ipairs(Lighting:GetChildren()) do
	if effect:IsA("Atmosphere") or effect:IsA("BloomEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") then
		effect:Destroy()
	end
end
Lighting.ClockTime = 8
local function isNight()
	local t = Lighting.ClockTime
	return t >= 19 or t < 6
end
local wasNight = false

---------------------------------------------------------------------
-- MONSTERS (come out at night)
---------------------------------------------------------------------
local function spawnEnemy(nearPlayer)
	local root = getRoot(nearPlayer)
	if not root then return end
	local px = BlockData.WorldToCell(root.Position)
	local side = rng:NextNumber() < 0.5 and -1 or 1
	local ex = math.clamp(px + side * rng:NextInteger(12, 18), 1, W - 2)
	local ey = highestSolid(ex) + 2

	local model = Instance.new("Model")
	model.Name = "NightBlob"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.6, 2.6, 2.6)
	body.Transparency = 1 -- invisible hitbox, the pixel sprite is what you see
	body.Position = BlockData.CellToWorld(ex, ey)
	body.Parent = model

	local monster = PixelArt.Monster
	PixelArt.BuildLayer(model, body, monster.rows, monster.palette, {
		ps = 2.6 / #monster.rows,
		top = 1.3,
		width = #monster.rows[1],
	})

	model.PrimaryPart = body
	model:SetAttribute("Health", ENEMY_HEALTH)
	model.Parent = enemyFolder
	body:SetNetworkOwner(nil)

	body.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not player or not hum or hum.Health <= 0 then return end
		local now = os.clock()
		if lastHurt[player] and now - lastHurt[player] < 1 then return end
		lastHurt[player] = now
		hum:TakeDamage(ENEMY_DAMAGE)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			local dir = math.sign(root.Position.X - body.Position.X)
			root.AssemblyLinearVelocity = Vector3.new(dir * 40, 30, 0)
		end
	end)
end

AttackEvent.OnServerEvent:Connect(function(player, enemy)
	if typeof(enemy) ~= "Instance" or enemy.Parent ~= enemyFolder or not enemy.PrimaryPart then return end
	local root = getRoot(player)
	if not root then return end
	if (root.Position - enemy.PrimaryPart.Position).Magnitude > 14 then return end
	local now = os.clock()
	if lastAttack[player] and now - lastAttack[player] < 0.35 then return end
	lastAttack[player] = now

	local health = enemy:GetAttribute("Health") - BlockData.GetDamage(getInventory(player))
	enemy:SetAttribute("Health", health)
	local body = enemy.PrimaryPart
	local dir = math.sign(body.Position.X - root.Position.X)
	body.AssemblyLinearVelocity = Vector3.new(dir * 30, 20, 0)
	if health <= 0 then
		enemy:Destroy()
		add(player, "Coins", 3)
		message(player, "💥 ניצחת מפלצת! +3 מטבעות")
	end
end)

local spawnTimer = 0
local targetTimer = 0
local targets = {}   -- [enemy] = targetX or nil

RunService.Heartbeat:Connect(function(dt)
	-- clock
	Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / DAY_LENGTH) % 24
	-- fade the world light: dark nights make torches matter
	local t = Lighting.ClockTime
	local daylight = math.clamp(math.min(t - 5, 19 - t) / 2, 0, 1)
	Lighting.OutdoorAmbient = Color3.fromRGB(35, 35, 65):Lerp(Color3.fromRGB(150, 150, 160), daylight)
	Lighting.Brightness = 0.2 + 1.8 * daylight
	local night = isNight()
	if night ~= wasNight then
		wasNight = night
		for _, p in ipairs(Players:GetPlayers()) do
			message(p, night and "🌙 הלילה ירד... מפלצות יוצאות!" or "☀️ בוקר טוב! המפלצות נעלמו")
		end
		if not night then
			for _, e in ipairs(enemyFolder:GetChildren()) do e:Destroy() end
		end
	end

	-- spawning
	spawnTimer += dt
	if night and spawnTimer > 7 then
		spawnTimer = 0
		local list = Players:GetPlayers()
		if #list > 0 and #enemyFolder:GetChildren() < MAX_ENEMIES then
			spawnEnemy(list[rng:NextInteger(1, #list)])
		end
	end

	-- choose targets twice per second
	targetTimer += dt
	local retarget = targetTimer > 0.5
	if retarget then targetTimer = 0 end

	for _, enemy in ipairs(enemyFolder:GetChildren()) do
		local body = enemy.PrimaryPart
		if not body then continue end
		local pos = body.Position

		if pos.Y < -20 then
			enemy:Destroy()
			continue
		end

		if retarget then
			local best, bestDist = nil, 70
			for _, p in ipairs(Players:GetPlayers()) do
				local root = getRoot(p)
				if root then
					local d = (root.Position - pos).Magnitude
					if d < bestDist then best, bestDist = root.Position.X, d end
				end
			end
			targets[enemy] = best
		end

		local vel = body.AssemblyLinearVelocity
		local targetX = targets[enemy]
		local vx = 0
		if targetX and math.abs(targetX - pos.X) > 1 then
			vx = math.sign(targetX - pos.X) * 9
			-- jump if a wall is in the way and we are on the ground
			local cx, cy = BlockData.WorldToCell(pos + Vector3.new(math.sign(vx) * BS * 0.8, 0, 0))
			local front = inBounds(cx, cy) and grid[cx][cy]
			if front and front.CanCollide and math.abs(vel.Y) < 1 then
				vel = Vector3.new(vel.X, 38, 0)
			end
		end
		-- keep it on the 2D plane and upright
		body.CFrame = CFrame.new(pos.X, pos.Y, Z)
		body.AssemblyAngularVelocity = Vector3.zero
		body.AssemblyLinearVelocity = Vector3.new(
			math.abs(vel.X) > 15 and vel.X or vx, -- keep knockback
			vel.Y, 0)
	end

	for enemy in pairs(targets) do
		if enemy.Parent == nil then targets[enemy] = nil end
	end
end)
