--[[
	Game2DServer  (Script → ServerScriptService)
	Builds a side-view 2D platformer level, handles coins, spikes,
	checkpoints, falling, and the finish flag. All rewards are server-side.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local PLANE_Z = 0            -- everything lives on this Z plane
local DEPTH = 6              -- thickness of platforms (Z size)
local COIN_RESPAWN = 10      -- seconds until a collected coin comes back
local FINISH_REWARD = 50
local FALL_Y = -30           -- below this you die

local START = Vector3.new(5, 4, PLANE_Z)

-- Platforms: {leftX, topY, width, color}
local PLATFORMS = {
	{0,   0,  40, Color3.fromRGB(90, 200, 90)},
	{48,  0,  22, Color3.fromRGB(90, 200, 90)},
	{74,  4,  12, Color3.fromRGB(240, 180, 70)},
	{90,  8,  10, Color3.fromRGB(240, 180, 70)},
	{104, 4,  26, Color3.fromRGB(90, 200, 90)},
	{138, 0,  12, Color3.fromRGB(90, 200, 90)},
	-- elevator goes here (x 152..160)
	{164, 16, 26, Color3.fromRGB(120, 150, 255)},
	{194, 12, 10, Color3.fromRGB(240, 180, 70)},
	{208, 8,  10, Color3.fromRGB(240, 180, 70)},
	{222, 12, 10, Color3.fromRGB(240, 180, 70)},
	{236, 16, 10, Color3.fromRGB(240, 180, 70)},
	{250, 16, 40, Color3.fromRGB(120, 150, 255)},
}

-- Spikes: {centerX, topY of platform below}
local SPIKES = { {58, 0}, {118, 4}, {180, 16}, {265, 16} }

-- Coins: {x, y}
local COINS = {
	{15, 3}, {20, 3}, {25, 3},
	{52, 3}, {58, 6}, {65, 3},
	{80, 7}, {95, 11},
	{112, 7}, {124, 7},
	{144, 3}, {156, 20},
	{170, 19}, {185, 19},
	{199, 15}, {213, 11}, {227, 15}, {241, 19},
	{258, 19}, {272, 19},
}

-- Checkpoints: {x, topY}
local CHECKPOINTS = { {110, 4}, {170, 16}, {255, 16} }

local FINISH = {285, 16}

---------------------------------------------------------------------
-- SETUP
---------------------------------------------------------------------
local level = Instance.new("Folder")
level.Name = "Level2D"
level.Parent = workspace

local messageEvent = Instance.new("RemoteEvent")
messageEvent.Name = "Game2DMessage"
messageEvent.Parent = ReplicatedStorage

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = props.Parent or level
	return p
end

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return Players:GetPlayerFromCharacter(character), humanoid
end

---------------------------------------------------------------------
-- BACKGROUND (behind the level, camera looks at it)
---------------------------------------------------------------------
makePart({
	Name = "Background",
	Size = Vector3.new(500, 200, 1),
	Position = Vector3.new(140, 40, PLANE_Z - 12),
	Color = Color3.fromRGB(150, 210, 255),
	Material = Enum.Material.SmoothPlastic,
	CanCollide = false,
	CastShadow = false,
})

local rng = Random.new(7)
for i = 1, 14 do
	makePart({
		Name = "Cloud",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1) * rng:NextNumber(6, 12),
		Position = Vector3.new(i * 22 - 10, rng:NextNumber(30, 55), PLANE_Z - 10),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CastShadow = false,
	})
end

---------------------------------------------------------------------
-- PLATFORMS
---------------------------------------------------------------------
for _, data in ipairs(PLATFORMS) do
	local leftX, topY, width, color = data[1], data[2], data[3], data[4]
	makePart({
		Name = "Platform",
		Size = Vector3.new(width, 2, DEPTH),
		Position = Vector3.new(leftX + width / 2, topY - 1, PLANE_Z),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
end

-- Start spawn
local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Size = Vector3.new(6, 1, 4)
spawn.Position = Vector3.new(START.X, 0.5, PLANE_Z)
spawn.Color = Color3.fromRGB(255, 255, 255)
spawn.Parent = level

---------------------------------------------------------------------
-- ELEVATOR (moving platform)
---------------------------------------------------------------------
local elevator = makePart({
	Name = "Elevator",
	Size = Vector3.new(8, 1, DEPTH),
	Position = Vector3.new(156, -0.5, PLANE_Z),
	Color = Color3.fromRGB(200, 100, 255),
	Material = Enum.Material.Neon,
})
TweenService:Create(
	elevator,
	TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 1),
	{ Position = Vector3.new(156, 15.5, PLANE_Z) }
):Play()

---------------------------------------------------------------------
-- SPIKES
---------------------------------------------------------------------
for _, data in ipairs(SPIKES) do
	local spike = makePart({
		Name = "Spike",
		Size = Vector3.new(4, 1.5, DEPTH - 1),
		Position = Vector3.new(data[1], data[2] + 0.75, PLANE_Z),
		Color = Color3.fromRGB(255, 50, 50),
		Material = Enum.Material.Neon,
	})
	spike.Touched:Connect(function(hit)
		local _, humanoid = getPlayerFromHit(hit)
		if humanoid then
			humanoid.Health = 0
		end
	end)
end

---------------------------------------------------------------------
-- LEADERSTATS + CHECKPOINT RESPAWN
---------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = stats

	player:SetAttribute("Checkpoint", START)

	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart")
		task.wait() -- let default spawn finish
		local cp = player:GetAttribute("Checkpoint") or START
		character:PivotTo(CFrame.new(cp + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(-90), 0))
		root.AssemblyLinearVelocity = Vector3.zero
	end)
end)

---------------------------------------------------------------------
-- COINS
---------------------------------------------------------------------
for _, data in ipairs(COINS) do
	local coin = makePart({
		Name = "Coin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2, 2),
		CFrame = CFrame.new(data[1], data[2], PLANE_Z) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(255, 215, 0),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	coin:SetAttribute("Active", true)

	coin.Touched:Connect(function(hit)
		if not coin:GetAttribute("Active") then return end
		local player = getPlayerFromHit(hit)
		if not player then return end
		local stats = player:FindFirstChild("leaderstats")
		if not stats then return end

		coin:SetAttribute("Active", false)
		coin.Transparency = 1
		stats.Coins.Value += 1

		task.delay(COIN_RESPAWN, function()
			coin.Transparency = 0
			coin:SetAttribute("Active", true)
		end)
	end)
end

---------------------------------------------------------------------
-- CHECKPOINTS
---------------------------------------------------------------------
for index, data in ipairs(CHECKPOINTS) do
	local pos = Vector3.new(data[1], data[2], PLANE_Z)
	local flag = makePart({
		Name = "Checkpoint" .. index,
		Size = Vector3.new(1, 6, 1),
		Position = pos + Vector3.new(0, 3, 0),
		Color = Color3.fromRGB(180, 180, 180),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	flag.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if not player then return end
		local current = player:GetAttribute("Checkpoint")
		if current and current.X >= pos.X then return end
		player:SetAttribute("Checkpoint", pos)
		flag.Color = Color3.fromRGB(80, 255, 120)
		messageEvent:FireClient(player, "✅ נקודת שמירה " .. index .. "!")
	end)
end

---------------------------------------------------------------------
-- FINISH
---------------------------------------------------------------------
local finish = makePart({
	Name = "Finish",
	Size = Vector3.new(2, 10, DEPTH),
	Position = Vector3.new(FINISH[1], FINISH[2] + 5, PLANE_Z),
	Color = Color3.fromRGB(255, 255, 255),
	Material = Enum.Material.Neon,
	Transparency = 0.3,
	CanCollide = false,
})

local finishedRecently = {}
finish.Touched:Connect(function(hit)
	local player = getPlayerFromHit(hit)
	if not player or finishedRecently[player] then return end
	finishedRecently[player] = true

	player.leaderstats.Coins.Value += FINISH_REWARD
	player:SetAttribute("Checkpoint", START)
	messageEvent:FireClient(player, "🏆 סיימת את השלב! +" .. FINISH_REWARD .. " מטבעות")

	task.delay(3, function()
		finishedRecently[player] = nil
		if player.Parent then
			player:LoadCharacter()
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	finishedRecently[player] = nil
end)

---------------------------------------------------------------------
-- FALLING INTO A PIT
---------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and root.Position.Y < FALL_Y then
			humanoid.Health = 0
		end
	end
end)
