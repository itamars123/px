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
