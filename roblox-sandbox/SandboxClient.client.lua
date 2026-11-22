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
local CAMERA_DISTANCE = 55

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

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = obj
end

local function label(parent, text, size, pos)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.Size = size
	l.Position = pos or UDim2.new()
	l.Text = text
	l.Parent = parent
	return l
end

-- message toast
local toast = label(gui, "", UDim2.new(0.6, 0, 0, 44), UDim2.new(0.2, 0, 0.12, 0))
toast.Font = Enum.Font.GothamBlack
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
hotbar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
hotbar.BackgroundTransparency = 0.3
hotbar.Parent = gui
corner(hotbar, 10)

local slots = {}
for i, item in ipairs(BlockData.Placeable) do
	local slot = Instance.new("TextButton")
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Size = UDim2.fromOffset(68, 68)
	slot.Position = UDim2.fromOffset(6 + (i - 1) * 74, 6)
	slot.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	slot.Parent = hotbar
	corner(slot, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = slot

	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(30, 30)
	swatch.Position = UDim2.fromOffset(19, 6)
	swatch.BackgroundColor3 = BlockData.Blocks[item].color
	swatch.Parent = slot
	corner(swatch, 4)

	local name = label(slot, i .. " " .. BlockData.Names[item], UDim2.new(1, -4, 0, 14), UDim2.fromOffset(2, 38))
	name.Font = Enum.Font.Gotham
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
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
panel.BackgroundTransparency = 0.3
panel.Parent = gui
corner(panel, 10)
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
corner(craftFrame, 12)
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
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	local _, amount = next(recipe.gives)
	button.Text = BlockData.Names[recipe.id] .. " ×" .. amount .. "   ←   " .. costText(recipe.cost)
	button.Parent = craftFrame
	corner(button, 8)
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
craftToggle.Font = Enum.Font.GothamBold
craftToggle.TextScaled = true
craftToggle.Text = "🔨 יצירה (C)"
craftToggle.Parent = gui
corner(craftToggle, 8)

function toggleCrafting()
	craftFrame.Visible = not craftFrame.Visible
end
craftToggle.MouseButton1Click:Connect(toggleCrafting)

function refreshHotbar()
	for i, slot in ipairs(slots) do
		slot.count.Text = tostring(itemCount(slot.item))
		slot.stroke.Color = i == selected and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(40, 40, 45)
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
		b.Font = Enum.Font.GothamBold
		b.Text = text
		b.Parent = gui
		corner(b, 40)
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
-- MAIN LOOP
---------------------------------------------------------------------
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 50

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

	-- lock to the 2D plane
	local pos = root.Position
	if math.abs(pos.Z - Z) > 0.05 then
		root.CFrame = root.CFrame + Vector3.new(0, 0, Z - pos.Z)
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
