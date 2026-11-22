-- ZombieServer (Script) — put in ServerScriptService
-- Runs the whole game on the server: rounds/waves, zombie AI, shooting (server-validated),
-- points, wall-buys, doors, mystery box, perks, health regen and game over.
-- The client only sends "I pulled the trigger / reload / switch" — it never decides damage or points.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("ZombieConfig"))
local MapBuilder = require(script.Parent:WaitForChild("ZombieMapBuilder"))

local rng = Random.new()

---------------------------------------------------------------- remotes
local function getRemote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local ActionRemote = getRemote("ZombieAction") -- client -> server
local EventRemote = getRemote("ZombieEvent")   -- server -> client

---------------------------------------------------------------- world setup
Players.CharacterAutoLoads = false -- we spawn players ourselves (dead players return next round)
StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

do -- replace Roblox's default health regen with our own (delay + fast regen)
	local scripts = StarterPlayer:FindFirstChildOfClass("StarterCharacterScripts")
	if scripts and not scripts:FindFirstChild("Health") then
		local blank = Instance.new("Script")
		blank.Name = "Health"
		blank.Parent = scripts
	end
end

do -- spooky night lighting
	Lighting.ClockTime = 0.3
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(40, 38, 48)
	Lighting.OutdoorAmbient = Color3.fromRGB(60, 58, 75)
	Lighting.FogColor = Color3.fromRGB(18, 16, 22)
	Lighting.FogStart = 20
	Lighting.FogEnd = 170
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.35
		atm.Color = Color3.fromRGB(80, 70, 90)
		atm.Decay = Color3.fromRGB(40, 30, 40)
		atm.Parent = Lighting
	end
end

local map = workspace:FindFirstChild("ZombieMap") or MapBuilder.Build()
local mapTemplate = map:Clone()
mapTemplate.Parent = ServerStorage

-- disable spawn locations that aren't part of the zombie map (e.g. the Baseplate template's)
for _, d in workspace:GetDescendants() do
	if d:IsA("SpawnLocation") and not d:IsDescendantOf(map) then
		d.Enabled = false
	end
end

local zombiesFolder = workspace:FindFirstChild("Zombies") or Instance.new("Folder")
zombiesFolder.Name = "Zombies"
zombiesFolder.Parent = workspace

---------------------------------------------------------------- state
local round = 0
local gameActive = false
local gameOverFlag = false
local toSpawn = 0
local aliveZombieCount = 0
local zombies = {}        -- [model] = true
local lockedAreas = {}    -- [area] = true while its door is closed
local spawnPoints = {}
local playerState = {}    -- [player] = state table

local function fillAmmo(st, weapon)
	local c = Config.Weapons[weapon]
	st.ammo[weapon] = { mag = c.MagSize, reserve = c.ReserveAmmo }
end

local function newState()
	local st = {
		weapons = { Config.StartingWeapon },
		slot = 1,
		ammo = {},
		perks = {},
		reloading = false,
		reloadToken = 0,
		lastFire = 0,
		lastHurt = 0,
		lastPrompt = 0,
	}
	fillAmmo(st, Config.StartingWeapon)
	return st
end

local function currentWeapon(st)
	return st.weapons[st.slot]
end

local function sendState(player)
	local st = playerState[player]
	if not st then
		return
	end
	local a = st.ammo[currentWeapon(st)]
	EventRemote:FireClient(player, "State", {
		weapons = table.clone(st.weapons),
		slot = st.slot,
		mag = a and a.mag or 0,
		reserve = a and a.reserve or 0,
		reloading = st.reloading,
		perks = table.clone(st.perks),
	})
end

local function announce(text, duration, player)
	if player then
		EventRemote:FireClient(player, "Announce", text, duration or 3)
	else
		EventRemote:FireAllClients("Announce", text, duration or 3)
	end
end

local function getStat(player, name)
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild(name)
end

local function addPoints(player, n)
	local s = getStat(player, "Points")
	if s then
		s.Value += n
	end
end

local function spend(player, cost)
	local s = getStat(player, "Points")
	if s and s.Value >= cost then
		s.Value -= cost
		return true
	end
	announce("Not enough points (" .. cost .. ")", 1.5, player)
	return false
end

local function getAliveCharacter(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart") then
		return char, hum
	end
	return nil
end

local function anyoneAlive()
	for _, p in Players:GetPlayers() do
		if getAliveCharacter(p) then
			return true
		end
	end
	return false
end

local function checkGameOver()
	if gameActive and not anyoneAlive() then
		gameOverFlag = true
	end
end

local function updateZombiesLeft()
	ReplicatedStorage:SetAttribute("ZombiesLeft", toSpawn + aliveZombieCount)
end

local function setRound(n)
	round = n
	ReplicatedStorage:SetAttribute("Round", n)
end

---------------------------------------------------------------- players
local function onCharacterAdded(player, char)
	local hum = char:WaitForChild("Humanoid")
	local st = playerState[player]
	if not st then
		return
	end
	hum.MaxHealth = st.perks.ToughBrew and Config.Perks.ToughBrew.MaxHealth or Config.PlayerMaxHealth
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = Config.WalkSpeed
	hum.Died:Connect(function()
		-- going down costs you your guns and perks (you keep your points)
		playerState[player] = newState()
		sendState(player)
		announce("You went down! You'll respawn next round.", 4, player)
		checkGameOver()
	end)
	sendState(player)
end

local function spawnPlayer(player)
	if player.Parent ~= Players then
		return
	end
	playerState[player] = playerState[player] or newState()
	player:LoadCharacter()
end

local function onPlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Value = Config.StartingPoints
	points.Parent = ls
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = ls
	ls.Parent = player

	player.CameraMode = Enum.CameraMode.LockFirstPerson
	playerState[player] = newState()
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	task.defer(spawnPlayer, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	onPlayerAdded(p)
end
Players.PlayerRemoving:Connect(function(player)
	playerState[player] = nil
	task.defer(checkGameOver)
end)

-- health regeneration
task.spawn(function()
	while true do
		local dt = task.wait(0.25)
		local now = os.clock()
		for p, st in playerState do
			local _, hum = getAliveCharacter(p)
			if hum and hum.Health < hum.MaxHealth and now - st.lastHurt >= Config.PlayerRegenDelay then
				hum.Health = math.min(hum.MaxHealth, hum.Health + Config.PlayerRegenRate * dt)
			end
		end
	end
end)

---------------------------------------------------------------- weapons
local function giveWeapon(player, weapon)
	local st = playerState[player]
	local idx = table.find(st.weapons, weapon)
	if idx then
		st.slot = idx
	elseif #st.weapons < Config.MaxWeapons then
		table.insert(st.weapons, weapon)
		st.slot = #st.weapons
	else
		st.ammo[st.weapons[st.slot]] = nil
		st.weapons[st.slot] = weapon
	end
	fillAmmo(st, weapon)
	st.reloading = false
	st.reloadToken += 1
	sendState(player)
end

local function startReload(player)
	local st = playerState[player]
	local weapon = currentWeapon(st)
	local c = Config.Weapons[weapon]
	local a = st.ammo[weapon]
	if st.reloading or not a or a.mag >= c.MagSize or a.reserve <= 0 then
		return
	end
	st.reloading = true
	st.reloadToken += 1
	local token = st.reloadToken
	sendState(player)
	local t = c.ReloadTime * (st.perks.QuickHands and Config.Perks.QuickHands.ReloadMultiplier or 1)
	task.delay(t, function()
		if playerState[player] ~= st or st.reloadToken ~= token then
			return -- switched weapon, died or left
		end
		local take = math.min(c.MagSize - a.mag, a.reserve)
		a.mag += take
		a.reserve -= take
		st.reloading = false
		sendState(player)
	end)
end

local function spreadDirection(dir, degrees)
	if degrees <= 0 then
		return dir
	end
	local cf = CFrame.lookAt(Vector3.zero, dir)
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local roll = rng:NextNumber() * math.pi * 2
	return (cf * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function zombieFromPart(inst)
	local model = inst:FindFirstAncestorOfClass("Model")
	if model and zombies[model] then
		return model, model:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

local function damageZombie(player, model, hum, damage, isHead)
	if hum.Health <= 0 then
		return false
	end
	hum:TakeDamage(damage)
	if hum.Health <= 0 then
		if not model:GetAttribute("Killed") then
			model:SetAttribute("Killed", true)
			addPoints(player, isHead and Config.PointsPerHeadshotKill or Config.PointsPerKill)
			local kills = getStat(player, "Kills")
			if kills then
				kills.Value += 1
			end
		end
		return true
	end
	addPoints(player, Config.PointsPerHit)
	return false
end

local function onFire(player, st, origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	local mag = direction.Magnitude
	if not (mag > 0.01 and mag < 1e6) then
		return -- also rejects NaN
	end
	direction = direction / mag

	local char = getAliveCharacter(player)
	if not char or st.reloading then
		return
	end
	local weapon = currentWeapon(st)
	local c = Config.Weapons[weapon]
	local a = st.ammo[weapon]
	local now = os.clock()
	if not c or not a or a.mag <= 0 or now - st.lastFire < c.FireRate * 0.75 then
		return -- empty, or firing faster than the gun allows
	end
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	if not ((origin - head.Position).Magnitude <= 8) then
		origin = head.Position -- don't let clients shoot from somewhere else
	end

	st.lastFire = now
	a.mag -= 1

	local exclude = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	local hit, kill, headshot = false, false, false
	local endPoints = {}
	for _ = 1, c.Pellets or 1 do
		local dir = spreadDirection(direction, c.Spread)
		local result = workspace:Raycast(origin, dir * c.Range, params)
		table.insert(endPoints, result and result.Position or origin + dir * c.Range)
		if result then
			local model, hum = zombieFromPart(result.Instance)
			if model and hum and hum.Health > 0 then
				local isHead = result.Instance.Name == "Head"
				local dmg = c.Damage * (isHead and c.HeadshotMultiplier or 1)
				hit = true
				headshot = headshot or isHead
				if damageZombie(player, model, hum, dmg, isHead) then
					kill = true
				end
			end
		end
	end

	if hit then
		EventRemote:FireClient(player, "Hit", kill, headshot)
	end
	EventRemote:FireAllClients("Shot", player, origin, endPoints, weapon)
	sendState(player)
end

ActionRemote.OnServerEvent:Connect(function(player, action, arg1, arg2)
	local st = playerState[player]
	if not st then
		return
	end
	if action == "Fire" then
		onFire(player, st, arg1, arg2)
	elseif action == "Reload" then
		if getAliveCharacter(player) then
			startReload(player)
		end
	elseif action == "Switch" then
		if typeof(arg1) == "number" and st.weapons[arg1] and arg1 ~= st.slot then
			st.slot = arg1
			st.reloading = false
			st.reloadToken += 1
			sendState(player)
		end
	end
end)

---------------------------------------------------------------- interactables
local function makePrompt(part, action, object)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = part
	return p
end

local function canUse(player)
	local st = playerState[player]
	if not st or not getAliveCharacter(player) then
		return nil
	end
	local now = os.clock()
	if now - st.lastPrompt < 0.3 then
		return nil
	end
	st.lastPrompt = now
	return st
end

local function setupWallBuy(part)
	local weapon = part:GetAttribute("Weapon")
	local c = Config.Weapons[weapon]
	if not c then
		warn("WallBuy has unknown Weapon attribute:", weapon)
		return
	end
	local cost = part:GetAttribute("Cost") or c.Cost
	local ammoCost = math.floor(cost / 2)
	local prompt = makePrompt(part, "Buy " .. c.DisplayName, cost .. " pts  (ammo " .. ammoCost .. ")")
	prompt.Triggered:Connect(function(player)
		local st = canUse(player)
		if not st then
			return
		end
		if table.find(st.weapons, weapon) then
			if spend(player, ammoCost) then
				fillAmmo(st, weapon)
				sendState(player)
				EventRemote:FireClient(player, "Purchase")
			end
		elseif spend(player, cost) then
			giveWeapon(player, weapon)
			EventRemote:FireClient(player, "Purchase")
		end
	end)
end

local function setupDoor(part)
	local cost = part:GetAttribute("Cost") or 750
	local area = part:GetAttribute("OpensArea")
	if area then
		lockedAreas[area] = true
	end
	local prompt = makePrompt(part, "Open Door", cost .. " pts")
	prompt.Triggered:Connect(function(player)
		if not canUse(player) or not spend(player, cost) then
			return
		end
		prompt:Destroy()
		if area then
			lockedAreas[area] = nil
		end
		announce(player.DisplayName .. " opened a door!", 2)
		EventRemote:FireClient(player, "Purchase")
		part.CanCollide = false
		for _, d in part:GetDescendants() do
			if d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
		TweenService:Create(part, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		Debris:AddItem(part, 0.7)
	end)
end

local function setupMysteryBox(part)
	local busy = false
	local prompt = makePrompt(part, "Mystery Box", Config.MysteryBoxCost .. " pts")
	prompt.Triggered:Connect(function(player)
		local st = canUse(player)
		if busy or not st or not spend(player, Config.MysteryBoxCost) then
			return
		end
		busy = true
		prompt.Enabled = false
		EventRemote:FireClient(player, "Purchase")
		local pool, fallback = {}, {}
		for name, c in Config.Weapons do
			if c.InBox then
				table.insert(fallback, name)
				if not table.find(st.weapons, name) then
					table.insert(pool, name)
				end
			end
		end
		if #pool == 0 then
			pool = fallback
		end
		local weapon = pool[rng:NextInteger(1, #pool)]
		announce("Mystery Box...", 1.5, player)
		task.wait(1.5)
		if playerState[player] and getAliveCharacter(player) then
			giveWeapon(player, weapon)
			announce("You got the " .. Config.Weapons[weapon].DisplayName .. "!", 2.5, player)
		end
		busy = false
		if prompt.Parent then
			prompt.Enabled = true
		end
	end)
end

local function setupPerk(part)
	local perkId = part:GetAttribute("Perk")
	local perk = Config.Perks[perkId]
	if not perk then
		warn("Perk machine has unknown Perk attribute:", perkId)
		return
	end
	local prompt = makePrompt(part, "Drink " .. perk.DisplayName, perk.Cost .. " pts")
	prompt.Triggered:Connect(function(player)
		local st = canUse(player)
		if not st then
			return
		end
		if st.perks[perkId] then
			announce("You already have " .. perk.DisplayName, 1.5, player)
			return
		end
		if not spend(player, perk.Cost) then
			return
		end
		st.perks[perkId] = true
		if perk.MaxHealth then
			local _, hum = getAliveCharacter(player)
			if hum then
				hum.MaxHealth = perk.MaxHealth
				hum.Health = perk.MaxHealth
			end
		end
		sendState(player)
		EventRemote:FireClient(player, "Purchase")
		announce(perk.DisplayName .. " acquired!", 2, player)
	end)
end

local function setupMap(m)
	lockedAreas = {}
	spawnPoints = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "ZombieSpawn" then
				table.insert(spawnPoints, d)
			end
			local kind = d:GetAttribute("Interact")
			if kind == "WallBuy" then
				setupWallBuy(d)
			elseif kind == "Door" then
				setupDoor(d)
			elseif kind == "MysteryBox" then
				setupMysteryBox(d)
			elseif kind == "Perk" then
				setupPerk(d)
			end
		end
	end
	if #spawnPoints == 0 then
		warn("ZombieMap has no parts named ZombieSpawn — zombies cannot spawn!")
	end
end

---------------------------------------------------------------- zombies
local SKIN = { Color3.fromRGB(110, 140, 90), Color3.fromRGB(125, 150, 105), Color3.fromRGB(95, 120, 85) }
local SHIRTS = { Color3.fromRGB(80, 40, 35), Color3.fromRGB(45, 55, 70), Color3.fromRGB(70, 65, 50), Color3.fromRGB(40, 40, 40) }
local PANTS = { Color3.fromRGB(35, 40, 60), Color3.fromRGB(55, 45, 35), Color3.fromRGB(30, 30, 30) }

local function buildZombie()
	local model = Instance.new("Model")
	model.Name = "Zombie"
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local shirt = SHIRTS[rng:NextInteger(1, #SHIRTS)]
	local pants = PANTS[rng:NextInteger(1, #PANTS)]

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	model.PrimaryPart = root

	local function limb(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.Massless = true
		p.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end

	limb("Torso", Vector3.new(2, 2, 1), CFrame.new(), shirt, Enum.Material.Fabric)
	limb("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.6, 0) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-10, 10))), skin)
	limb("LeftEye", Vector3.new(0.25, 0.15, 0.1), CFrame.new(-0.25, 1.75, -0.6), Color3.fromRGB(255, 40, 20), Enum.Material.Neon)
	limb("RightEye", Vector3.new(0.25, 0.15, 0.1), CFrame.new(0.25, 1.75, -0.6), Color3.fromRGB(255, 40, 20), Enum.Material.Neon)
	-- arms reaching forward
	limb("LeftArm", Vector3.new(0.9, 0.9, 2.2), CFrame.new(-1.45, 0.6, -0.9), skin)
	limb("RightArm", Vector3.new(0.9, 0.9, 2.2), CFrame.new(1.45, 0.45, -0.85), skin)
	limb("LeftLeg", Vector3.new(0.95, 2, 1), CFrame.new(-0.5, -2, 0), pants, Enum.Material.Fabric)
	limb("RightLeg", Vector3.new(0.95, 2, 1), CFrame.new(0.5, -2, 0), pants, Enum.Material.Fabric)

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 2
	hum.AutomaticScalingEnabled = false
	hum.RequiresNeck = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	hum.Parent = model

	return model, root, hum
end

local function nearestTarget(pos)
	local best, bestDist, bestHum, bestChar = nil, math.huge, nil, nil
	for _, p in Players:GetPlayers() do
		local char, hum = getAliveCharacter(p)
		if char then
			local root = char.HumanoidRootPart
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist, bestHum, bestChar = root, d, hum, char
			end
		end
	end
	return best, bestDist, bestHum, bestChar
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(fromPos, toPos, targetChar)
	losParams.FilterDescendantsInstances = { zombiesFolder, targetChar }
	return workspace:Raycast(fromPos, toPos - fromPos, losParams) == nil
end

local function runZombie(model, root, hum)
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
	local waypoints, wpIndex, lastPath, lastAttack = nil, 0, 0, 0
	while hum.Health > 0 and model.Parent do
		local targetRoot, dist, targetHum, targetChar = nearestTarget(root.Position)
		if not targetRoot then
			hum:MoveTo(root.Position)
			task.wait(0.5)
			continue
		end
		local now = os.clock()
		if dist <= Config.ZombieAttackRange then
			hum:MoveTo(targetRoot.Position)
			waypoints = nil
			if now - lastAttack >= Config.ZombieAttackCooldown then
				lastAttack = now
				targetHum:TakeDamage(Config.ZombieDamage)
				local p = Players:GetPlayerFromCharacter(targetChar)
				if p and playerState[p] then
					playerState[p].lastHurt = now
					EventRemote:FireClient(p, "Hurt")
				end
			end
		elseif hasLineOfSight(root.Position, targetRoot.Position, targetChar) then
			hum:MoveTo(targetRoot.Position)
			waypoints = nil
		else
			if not waypoints or now - lastPath > 1 then
				lastPath = now
				local ok = pcall(function()
					path:ComputeAsync(root.Position, targetRoot.Position)
				end)
				if ok and path.Status == Enum.PathStatus.Success then
					waypoints = path:GetWaypoints()
					wpIndex = 2
				else
					waypoints = nil
				end
			end
			local wp = waypoints and waypoints[wpIndex]
			if wp then
				local flat = Vector3.new(wp.Position.X, root.Position.Y, wp.Position.Z)
				if (flat - root.Position).Magnitude < 3 then
					wpIndex += 1
					wp = waypoints[wpIndex]
				end
			end
			hum:MoveTo(wp and wp.Position or targetRoot.Position)
		end
		task.wait(0.15)
	end
end

local function chooseSpawn()
	local open, far = {}, {}
	for _, sp in spawnPoints do
		if sp.Parent and not lockedAreas[sp:GetAttribute("Area") or "A"] then
			table.insert(open, sp)
			local _, d = nearestTarget(sp.Position)
			if d >= Config.MinSpawnDistance then
				table.insert(far, sp)
			end
		end
	end
	local list = #far > 0 and far or open
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

local function spawnZombie()
	local sp = chooseSpawn()
	if not sp then
		return false
	end
	local model, root, hum = buildZombie()
	hum.MaxHealth = Config.ZombieHealth(round)
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = Config.ZombieSpeed(round) * rng:NextNumber(0.85, 1.15)
	local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
	model:PivotTo(CFrame.new(sp.Position + offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = zombiesFolder
	root:SetNetworkOwner(nil)

	zombies[model] = true
	aliveZombieCount += 1
	hum.Died:Connect(function()
		if zombies[model] then
			zombies[model] = nil
			aliveZombieCount -= 1
			updateZombiesLeft()
		end
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") and d ~= root then
				d.CanCollide = true
				d.Massless = false
			end
		end
		Debris:AddItem(model, 4)
	end)
	task.spawn(runZombie, model, root, hum)
	return true
end

local function clearZombies()
	for model in zombies do
		model:Destroy()
	end
	zombies = {}
	aliveZombieCount = 0
	toSpawn = 0
	zombiesFolder:ClearAllChildren()
	updateZombiesLeft()
end

---------------------------------------------------------------- game loop
local function resetGame()
	clearZombies()
	map:Destroy()
	map = mapTemplate:Clone()
	map.Parent = workspace
	setupMap(map)
	setRound(0)
	for _, p in Players:GetPlayers() do
		local points, kills = getStat(p, "Points"), getStat(p, "Kills")
		if points then
			points.Value = Config.StartingPoints
		end
		if kills then
			kills.Value = 0
		end
		playerState[p] = newState()
		spawnPlayer(p)
	end
end

setupMap(map)
setRound(0)

while true do
	while #Players:GetPlayers() == 0 do
		task.wait(1)
	end

	resetGame()
	gameActive = true
	gameOverFlag = false

	for i = Config.FirstRoundDelay, 1, -1 do
		announce("Zombies incoming in " .. i, 1.1)
		task.wait(1)
	end

	while not gameOverFlag do
		setRound(round + 1)
		for _, p in Players:GetPlayers() do
			if not getAliveCharacter(p) then
				spawnPlayer(p)
			end
		end
		announce("ROUND " .. round, 3)
		EventRemote:FireAllClients("RoundStart", round)

		toSpawn = Config.ZombiesForRound(round, #Players:GetPlayers())
		updateZombiesLeft()
		local lastSpawn = 0
		while (toSpawn > 0 or aliveZombieCount > 0) and not gameOverFlag do
			if toSpawn > 0 and aliveZombieCount < Config.MaxZombiesAlive and os.clock() - lastSpawn >= Config.SpawnInterval(round) then
				if spawnZombie() then
					toSpawn -= 1
					lastSpawn = os.clock()
					updateZombiesLeft()
				end
			end
			if not anyoneAlive() then
				gameOverFlag = true
			end
			task.wait(0.1)
		end

		if gameOverFlag then
			break
		end
		announce("Round " .. round .. " survived!", 3)
		task.wait(Config.IntermissionTime)
	end

	gameActive = false
	local survived = math.max(round - 1, 0)
	announce(("GAME OVER\nYou survived %d round%s"):format(survived, survived == 1 and "" or "s"), 7)
	task.wait(8)
end
