--[[
	SandboxClient  (LocalScript → StarterPlayer > StarterPlayerScripts)
	Side-view camera, 2D movement, mining / building with the mouse,
	hotbar, inventory panel, crafting menu and mobile buttons.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlockData = require(ReplicatedStorage:WaitForChild("BlockData"))
local PixelArt = require(ReplicatedStorage:WaitForChild("PixelArt"))
local Lighting = game:GetService("Lighting")
local BlockAction = ReplicatedStorage:WaitForChild("BlockAction")
local CraftEvent = ReplicatedStorage:WaitForChild("Craft")
local AttackEvent = ReplicatedStorage:WaitForChild("Attack")
local MessageEvent = ReplicatedStorage:WaitForChild("SandboxMessage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local inventory = player:WaitForChild("Inventory")
local worldFolder = workspace:WaitForChild("World")
local enemyFolder = workspace:WaitForChild("Enemies")

local BS, Z = BlockData.BLOCK_SIZE, BlockData.PLANE_Z
-- long distance + narrow lens = almost flat, "2D" look
local CAMERA_DISTANCE = 150
local CAMERA_FOV = 20
local PIXEL_FONT = Enum.Font.Arcade

---------------------------------------------------------------------
-- Disable default 3D controls
---------------------------------------------------------------------
local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
playerModule:GetControls():Disable()

---------------------------------------------------------------------
-- Client copy of the block grid (for fast lookups)
---------------------------------------------------------------------
local cells = {}
local function track(part)
	if part:GetAttribute("BlockType") then cells[part.Name] = part end
end
for _, p in ipairs(worldFolder:GetChildren()) do track(p) end
worldFolder.ChildAdded:Connect(track)
worldFolder.ChildRemoved:Connect(function(part)
	if cells[part.Name] == part then cells[part.Name] = nil end
end)
local function getBlock(x, y) return cells[x .. "," .. y] end

---------------------------------------------------------------------
-- INPUT STATE
---------------------------------------------------------------------
local leftHeld, rightHeld, jumpHeld = false, false, false
local mineHeld, placeHeld = false, false
local touchPos, touchDown = nil, false
local mobileMode = "mine"
local selected = 1

local LEFT = { [Enum.KeyCode.A] = true, [Enum.KeyCode.Left] = true }
local RIGHT = { [Enum.KeyCode.D] = true, [Enum.KeyCode.Right] = true }
local JUMP = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.W] = true, [Enum.KeyCode.Up] = true }
local NUMBERS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
}

local refreshHotbar, toggleCrafting -- defined below

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local key = input.KeyCode
	if LEFT[key] then leftHeld = true end
	if RIGHT[key] then rightHeld = true end
	if JUMP[key] then jumpHeld = true end
	if NUMBERS[key] then selected = NUMBERS[key]; refreshHotbar() end
	if key == Enum.KeyCode.C then toggleCrafting() end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then mineHeld = true end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then placeHeld = true end
	if input.UserInputType == Enum.UserInputType.Touch then
		touchDown, touchPos = true, input.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch and touchDown then
		touchPos = input.Position
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		local n = #BlockData.Placeable
		selected = (selected - math.sign(input.Position.Z) - 1) % n + 1
		refreshHotbar()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local key = input.KeyCode
	if LEFT[key] then leftHeld = false end
	if RIGHT[key] then rightHeld = false end
	if JUMP[key] then jumpHeld = false end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then mineHeld = false end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then placeHeld = false end
	if input.UserInputType == Enum.UserInputType.Touch then touchDown = false end
end)

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SandboxHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- pixel-style box: no rounded corners, hard black border
local function corner(obj)
	obj.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(15, 10, 20)
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = obj
	return stroke
end

local function label(parent, text, size, pos)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.Font = PIXEL_FONT
	l.TextScaled = true
	l.Size = size
	l.Position = pos or UDim2.new()
	l.Text = text
	l.Parent = parent
	return l
end

-- message toast
local toast = label(gui, "", UDim2.new(0.6, 0, 0, 44), UDim2.new(0.2, 0, 0.12, 0))
toast.Font = PIXEL_FONT
local toastToken = 0
local function showMessage(text)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	task.delay(2.5, function()
		if token == toastToken then toast.Text = "" end
	end)
end
MessageEvent.OnClientEvent:Connect(showMessage)

local function itemCount(item)
	local v = inventory:FindFirstChild(item)
	return v and v.Value or 0
end

-- hotbar
local hotbar = Instance.new("Frame")
hotbar.Size = UDim2.fromOffset(#BlockData.Placeable * 74 + 6, 80)
hotbar.Position = UDim2.new(0.5, -(#BlockData.Placeable * 74 + 6) / 2, 1, -92)
hotbar.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
hotbar.BackgroundTransparency = 0.3
hotbar.Parent = gui
corner(hotbar)

local slots = {}
for i, item in ipairs(BlockData.Placeable) do
	local slot = Instance.new("TextButton")
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Size = UDim2.fromOffset(68, 68)
	slot.Position = UDim2.fromOffset(6 + (i - 1) * 74, 6)
	slot.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	slot.Parent = hotbar
	local stroke = corner(slot)

	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(32, 32)
	swatch.Position = UDim2.fromOffset(18, 4)
	swatch.BackgroundTransparency = 1
	swatch.Parent = slot
	PixelArt.MakeIcon(swatch, item)

	local name = label(slot, i .. " " .. BlockData.Names[item], UDim2.new(1, -4, 0, 14), UDim2.fromOffset(2, 38))
	name.Font = PIXEL_FONT
	local countLabel = label(slot, "0", UDim2.new(1, -4, 0, 14), UDim2.fromOffset(2, 52))
	countLabel.TextColor3 = Color3.fromRGB(255, 230, 120)

	slot.MouseButton1Click:Connect(function()
		selected = i
		refreshHotbar()
	end)
	slots[i] = { stroke = stroke, count = countLabel, item = item }
end

-- side panel: materials & tools
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(190, 260)
panel.Position = UDim2.new(1, -205, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
panel.BackgroundTransparency = 0.3
panel.Parent = gui
corner(panel)
label(panel, "🎒 תיק", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 4))

local panelLines = {}
local row = 0
for _, item in ipairs(BlockData.Materials) do
	row += 1
	panelLines[item] = label(panel, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 8 + row * 26))
	panelLines[item].TextXAlignment = Enum.TextXAlignment.Right
	panelLines[item].TextColor3 = BlockData.ItemColors[item]
end
for _, item in ipairs(BlockData.Tools) do
	row += 1
	panelLines[item] = label(panel, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 8 + row * 26))
	panelLines[item].TextXAlignment = Enum.TextXAlignment.Right
end

-- crafting menu
local craftFrame = Instance.new("Frame")
craftFrame.Visible = false
craftFrame.Size = UDim2.fromOffset(360, 60 + #BlockData.Recipes * 52)
craftFrame.Position = UDim2.new(0.5, -180, 0.5, -(60 + #BlockData.Recipes * 52) / 2)
craftFrame.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
craftFrame.BackgroundTransparency = 0.1
craftFrame.Parent = gui
corner(craftFrame)
label(craftFrame, "🔨 יצירה", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 8))

local function costText(cost)
	local parts = {}
	for item, amount in pairs(cost) do
		table.insert(parts, amount .. " " .. (BlockData.Names[item] or item))
	end
	return table.concat(parts, " + ")
end

local craftButtons = {}
for i, recipe in ipairs(BlockData.Recipes) do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -20, 0, 44)
	button.Position = UDim2.fromOffset(10, 50 + (i - 1) * 52)
	button.Font = PIXEL_FONT
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	local _, amount = next(recipe.gives)
	button.Text = BlockData.Names[recipe.id] .. " ×" .. amount .. "   ←   " .. costText(recipe.cost)
	button.Parent = craftFrame
	corner(button)
	button.MouseButton1Click:Connect(function()
		CraftEvent:FireServer(i)
	end)
	craftButtons[i] = { button = button, recipe = recipe }
end

local craftToggle = Instance.new("TextButton")
craftToggle.Size = UDim2.fromOffset(150, 40)
craftToggle.Position = UDim2.new(1, -205, 0, 330)
craftToggle.BackgroundColor3 = Color3.fromRGB(150, 100, 40)
craftToggle.TextColor3 = Color3.new(1, 1, 1)
craftToggle.Font = PIXEL_FONT
craftToggle.TextScaled = true
craftToggle.Text = "🔨 יצירה (C)"
craftToggle.Parent = gui
corner(craftToggle)

function toggleCrafting()
	craftFrame.Visible = not craftFrame.Visible
end
craftToggle.MouseButton1Click:Connect(toggleCrafting)

function refreshHotbar()
	for i, slot in ipairs(slots) do
		slot.count.Text = tostring(itemCount(slot.item))
		slot.stroke.Color = i == selected and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(15, 10, 20)
	end
	for _, item in ipairs(BlockData.Materials) do
		panelLines[item].Text = BlockData.Names[item] .. ": " .. itemCount(item)
	end
	for _, item in ipairs(BlockData.Tools) do
		local owned = itemCount(item) > 0
		panelLines[item].Text = (owned and "✅ " or "⬜ ") .. BlockData.Names[item]
		panelLines[item].TextColor3 = owned and Color3.fromRGB(140, 255, 140) or Color3.fromRGB(150, 150, 150)
	end
	for _, entry in ipairs(craftButtons) do
		local ok = true
		for item, amount in pairs(entry.recipe.cost) do
			if itemCount(item) < amount then ok = false end
		end
		entry.button.BackgroundColor3 = ok and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(80, 70, 65)
	end
end

local function watch(v)
	if v:IsA("IntValue") then v.Changed:Connect(refreshHotbar) end
	refreshHotbar()
end
for _, v in ipairs(inventory:GetChildren()) do watch(v) end
inventory.ChildAdded:Connect(watch)
refreshHotbar()

-- mobile controls
if UserInputService.TouchEnabled then
	local function makeButton(text, position, onChange, onTap)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(80, 80)
		b.Position = position
		b.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		b.BackgroundTransparency = 0.35
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true
		b.Font = PIXEL_FONT
		b.Text = text
		b.Parent = gui
		corner(b)
		if onChange then
			b.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then onChange(true) end end)
			b.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then onChange(false) end end)
		end
		if onTap then b.MouseButton1Click:Connect(function() onTap(b) end) end
		return b
	end
	makeButton("◀", UDim2.new(0, 20, 1, -110), function(v) leftHeld = v end)
	makeButton("▶", UDim2.new(0, 115, 1, -110), function(v) rightHeld = v end)
	makeButton("⬆", UDim2.new(1, -110, 1, -110), function(v) jumpHeld = v end)
	makeButton("⛏️", UDim2.new(1, -110, 1, -205), nil, function(b)
		mobileMode = mobileMode == "mine" and "place" or "mine"
		b.Text = mobileMode == "mine" and "⛏️" or "🧱"
		showMessage(mobileMode == "mine" and "מצב חציבה" or "מצב בנייה")
	end)
end

showMessage("לחיצה שמאלית = חציבה | ימנית = בנייה | 1-5 = בחירה | C = יצירה")

---------------------------------------------------------------------
-- SELECTION BOX
---------------------------------------------------------------------
local cursor = Instance.new("Part")
cursor.Name = "Cursor"
cursor.Anchored = true
cursor.CanCollide = false
cursor.CanQuery = false
cursor.CanTouch = false
cursor.Transparency = 1
cursor.Size = Vector3.new(BS, BS, BS)
cursor.Parent = workspace

local box = Instance.new("SelectionBox")
box.Adornee = cursor
box.LineThickness = 0.08
box.SurfaceTransparency = 1
box.SurfaceColor3 = Color3.new(0, 0, 0)
box.Parent = cursor

---------------------------------------------------------------------
-- PIXEL TEXTURES on blocks near the camera (far blocks stay plain = fast)
---------------------------------------------------------------------
local skinned = {}
local SKIN_RANGE_X, SKIN_RANGE_Y = 22, 13

local function updateSkins()
	local cx, cy = BlockData.WorldToCell(camera.CFrame.Position)
	local keep = {}
	for x = cx - SKIN_RANGE_X, cx + SKIN_RANGE_X do
		for y = cy - SKIN_RANGE_Y, cy + SKIN_RANGE_Y do
			local part = getBlock(x, y)
			if part then
				keep[part] = true
				if skinned[part] == nil then
					local mirror = (x * 7 + y * 13) % 2 == 1 -- variety, no tiling look
					skinned[part] = PixelArt.MakeSkin(part, part:GetAttribute("BlockType"), mirror) or false
				end
			end
		end
	end
	for part, skin in pairs(skinned) do
		if not keep[part] then
			if skin then skin:Destroy() end
			skinned[part] = nil
		end
	end
end

---------------------------------------------------------------------
-- PIXEL SKY (flat colour, square sun & moon, blocky clouds, stars)
---------------------------------------------------------------------
local sky = Instance.new("Part")
sky.Name = "PixelSky"
sky.Anchored = true
sky.CanCollide = false
sky.CanQuery = false
sky.CanTouch = false
sky.CastShadow = false
sky.Transparency = 1
sky.Size = Vector3.new(220, 120, 1)
sky.Parent = workspace

local skyGui = Instance.new("SurfaceGui")
skyGui.Face = Enum.NormalId.Back
skyGui.LightInfluence = 0
skyGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
skyGui.PixelsPerStud = 2   -- canvas = 440 x 240 "pixels"
skyGui.Parent = sky

local skyFill = Instance.new("Frame")
skyFill.Size = UDim2.fromScale(1, 1)
skyFill.BorderSizePixel = 0
skyFill.Parent = skyGui

local function block(parent, x, y, w, h, color)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.Parent = parent
	return f
end

local stars = {}
local starRng = Random.new(3)
for i = 1, 40 do
	stars[i] = block(skyFill, starRng:NextInteger(90, 350), starRng:NextInteger(50, 150), 2, 2, Color3.new(1, 1, 1))
end

local sun = block(skyFill, 0, 0, 14, 14, Color3.fromRGB(255, 220, 80))
block(sun, 3, 3, 8, 8, Color3.fromRGB(255, 245, 170))
local moon = block(skyFill, 0, 0, 12, 12, Color3.fromRGB(230, 230, 210))
block(moon, 2, 3, 3, 3, Color3.fromRGB(190, 190, 175))
block(moon, 7, 6, 2, 2, Color3.fromRGB(190, 190, 175))

local clouds = {}
for i = 1, 4 do
	local cloud = Instance.new("Frame")
	cloud.BackgroundTransparency = 1
	cloud.Size = UDim2.fromOffset(40, 14)
	cloud.Parent = skyFill
	block(cloud, 8, 0, 18, 6, Color3.new(1, 1, 1))
	block(cloud, 0, 5, 40, 7, Color3.new(1, 1, 1))
	block(cloud, 4, 12, 32, 2, Color3.fromRGB(210, 220, 235))
	clouds[i] = { frame = cloud, x = 80 + i * 75, y = 55 + (i % 2) * 22, speed = 2 + i }
end

local NIGHT = Color3.fromRGB(12, 16, 40)
local DUSK = Color3.fromRGB(240, 130, 90)
local DAY = Color3.fromRGB(105, 175, 255)

local function skyColor(t)
	if t >= 7 and t <= 17 then return DAY end
	if t > 5 and t < 7 then
		return t < 6 and NIGHT:Lerp(DUSK, t - 5) or DUSK:Lerp(DAY, t - 6)
	end
	if t > 17 and t < 19 then
		return t < 18 and DAY:Lerp(DUSK, t - 17) or DUSK:Lerp(NIGHT, t - 18)
	end
	return NIGHT
end

local function updateSky(dt)
	local camPos = camera.CFrame.Position
	sky.CFrame = CFrame.new(camPos.X, camPos.Y, Z - 45)

	local t = Lighting.ClockTime
	skyFill.BackgroundColor3 = skyColor(t)

	local night = t >= 19 or t < 5.5
	for _, star in ipairs(stars) do star.Visible = night end

	local function arc(progress, size)
		local x = 100 + progress * 240
		local y = 140 - math.sin(progress * math.pi) * 90
		return UDim2.fromOffset(math.floor(x) - size / 2, math.floor(y))
	end
	sun.Visible = t >= 6 and t <= 18
	if sun.Visible then sun.Position = arc((t - 6) / 12, 14) end
	moon.Visible = not sun.Visible
	if moon.Visible then moon.Position = arc(((t - 18) % 24) / 12, 12) end

	for _, c in ipairs(clouds) do
		c.x += c.speed * dt
		if c.x > 380 then c.x = 40 end
		c.frame.Position = UDim2.fromOffset(math.floor(c.x), c.y) -- whole pixels only
	end
end

---------------------------------------------------------------------
-- WALK ANIMATION for every pixel hero (swaps two leg frames)
---------------------------------------------------------------------
local function animateHeroes()
	local step = math.floor(os.clock() * 8) % 2 == 1
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local sprite = char and char:FindFirstChild("PixelSprite")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if sprite and root then
			local v = root.AssemblyLinearVelocity
			local walking = (math.abs(v.X) > 1 and step) or math.abs(v.Y) > 3
			if sprite:GetAttribute("Walking") ~= walking then
				sprite:SetAttribute("Walking", walking)
				for _, p in ipairs(sprite:GetChildren()) do
					local layer = p:GetAttribute("Layer")
					if layer == "LegA" then p.Transparency = walking and 1 or 0 end
					if layer == "LegB" then p.Transparency = walking and 0 or 1 end
				end
			end
		end
	end
end

local skinTimer = 0
RunService.Heartbeat:Connect(function(dt)
	skinTimer += dt
	if skinTimer > 0.2 then
		skinTimer = 0
		updateSkins()
	end
	updateSky(dt)
	animateHeroes()
end)

---------------------------------------------------------------------
-- MAIN LOOP
---------------------------------------------------------------------
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = CAMERA_FOV

local mining = nil          -- {x, y, progress, needed}
local lastPlaceTime = 0
local lastAttackTime = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { enemyFolder }

local function pointerRay()
	if touchDown and touchPos then
		return camera:ScreenPointToRay(touchPos.X, touchPos.Y)
	end
	local m = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(m.X, m.Y)
end

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then return end

	-- movement on X only
	local dir = (rightHeld and 1 or 0) - (leftHeld and 1 or 0)
	humanoid:Move(Vector3.new(dir, 0, 0), false)
	if jumpHeld then humanoid.Jump = true end

	-- lock to the 2D plane and face exactly left or right
	humanoid.AutoRotate = false
	local pos = root.Position
	local facing = root.CFrame.LookVector.X >= 0 and 1 or -1
	if dir ~= 0 then facing = dir end
	local look = root.CFrame.LookVector
	if math.abs(pos.Z - Z) > 0.05 or math.abs(look.X - facing) > 0.01 then
		root.CFrame = CFrame.lookAt(Vector3.new(pos.X, pos.Y, Z), Vector3.new(pos.X + facing, pos.Y, Z))
		pos = root.Position
	end
	local vel = root.AssemblyLinearVelocity
	if vel.Z ~= 0 then root.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y, 0) end

	-- camera
	camera.CameraType = Enum.CameraType.Scriptable
	local target = Vector3.new(pos.X, pos.Y + 3, Z)
	local desired = CFrame.lookAt(target + Vector3.new(0, 0, CAMERA_DISTANCE), target)
	camera.CFrame = camera.CFrame:Lerp(desired, math.clamp(dt * 10, 0, 1))

	-- where is the pointer on the 2D plane?
	local ray = pointerRay()
	if math.abs(ray.Direction.Z) < 1e-4 then return end
	local t = (Z - ray.Origin.Z) / ray.Direction.Z
	local point = ray.Origin + ray.Direction * t
	local cx, cy = BlockData.WorldToCell(point)
	local cellPos = BlockData.CellToWorld(cx, cy)
	local reachable = (cellPos - pos).Magnitude <= BlockData.REACH
	cursor.Position = cellPos
	box.Color3 = reachable and Color3.new(1, 1, 1) or Color3.fromRGB(255, 70, 70)

	local doMine = mineHeld or (touchDown and mobileMode == "mine")
	local doPlace = placeHeld or (touchDown and mobileMode == "place")

	-- attack a monster under the pointer
	if doMine then
		local hit = workspace:Raycast(ray.Origin, ray.Direction * (CAMERA_DISTANCE + 20), rayParams)
		if hit then
			local enemy = hit.Instance:FindFirstAncestorOfClass("Model")
			if enemy and os.clock() - lastAttackTime > 0.35 then
				lastAttackTime = os.clock()
				AttackEvent:FireServer(enemy)
			end
			mining = nil
			return
		end
	end

	-- mining
	local block = getBlock(cx, cy)
	if doMine and reachable and block then
		local info = BlockData.Blocks[block:GetAttribute("BlockType")]
		local tier, speed = BlockData.GetPickaxe(inventory)
		if info.hardness == math.huge then
			mining = nil
		elseif (info.tier or 1) > tier then
			if not mining or mining.x ~= cx or mining.y ~= cy then
				showMessage("⛏️ צריך מכוש ברזל כדי לחצוב זהב!")
				mining = { x = cx, y = cy, progress = 0, needed = math.huge }
			end
		else
			if not mining or mining.x ~= cx or mining.y ~= cy then
				mining = { x = cx, y = cy, progress = 0, needed = info.hardness / speed }
				BlockAction:FireServer("start", cx, cy)
			end
			mining.progress += dt
			box.Color3 = Color3.fromRGB(255, 220, 80):Lerp(Color3.fromRGB(255, 60, 30), mining.progress / mining.needed)
			if mining.progress >= mining.needed then
				BlockAction:FireServer("finish", cx, cy)
				mining = nil
			end
		end
	else
		mining = nil
	end

	-- placing
	if doPlace and reachable and not block and os.clock() - lastPlaceTime > 0.15 then
		local item = BlockData.Placeable[selected]
		if itemCount(item) > 0 then
			lastPlaceTime = os.clock()
			BlockAction:FireServer("place", cx, cy, item)
		end
	end
end)
