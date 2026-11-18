-- WorldFX.lua
-- Client-side world logic and polish:
--   * treasure idle animation (spin + bob), rainbow / lightning flicker
--   * performance mode (turns off particles, beams and lights locally)
--   * shows only the relevant prompts (Steal on others, Pick Up on yours)
--   * lets the owner walk through their own locked barrier
--   * guide beam to your base while carrying
--   * dash, knockback, camera shake, FOV punch effects
--   * opening menus from world prompts (shop, rebirth altar, ...)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)
local Rarities = require(Shared.Rarities)
local State = require(script.Parent.State)
local Util = require(Shared.Util)
local Sound = require(script.Parent.Sound)

local player = Players.LocalPlayer

local WorldFX = {}
WorldFX.LowGfx = false
WorldFX.Effects = true

local Windows, Notifications -- injected

local TreasureAnimator = require(script.Parent.TreasureAnimator)

local function applyAllQuality()
	TreasureAnimator.SetQuality(WorldFX.LowGfx, WorldFX.Effects)
	Lighting.GlobalShadows = not WorldFX.LowGfx
	local bloom = Lighting:FindFirstChild("GameBloom")
	if bloom then
		bloom.Enabled = not WorldFX.LowGfx
	end
	local rays = Lighting:FindFirstChild("GameSunRays")
	if rays then
		rays.Enabled = not WorldFX.LowGfx
	end
end

function WorldFX.SetSettings(settings)
	local low = settings.LowGfx == true
	local fx = settings.Effects ~= false
	if low ~= WorldFX.LowGfx or fx ~= WorldFX.Effects then
		WorldFX.LowGfx = low
		WorldFX.Effects = fx
		applyAllQuality()
	end
end

-- Prompts ---------------------------------------------------------------------
local function myBaseIndex(): number?
	return player:GetAttribute("BaseIndex")
end

local function updatePrompt(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("Kind")
	if kind == "Steal" or kind == "Store" then
		local model = prompt:FindFirstAncestorWhichIsA("Model")
		local owner = model and model:GetAttribute("OwnerId")
		local mine = owner == player.UserId
		prompt.Enabled = (kind == "Store") == mine
	elseif prompt:GetAttribute("OwnerOnly") then
		local base = prompt:FindFirstAncestor("Bases") and prompt.Parent and prompt.Parent.Parent
		local owner = base and base:GetAttribute("OwnerId")
		prompt.Enabled = owner == player.UserId
	end
end

local function watchDescendant(d: Instance)
	if d:IsA("ProximityPrompt") then
		updatePrompt(d)
	elseif d:IsA("Model") and d:GetAttribute("TreasureId") then
		TreasureAnimator.Track(d)
	end
end

-- Barrier: the owner may always pass through their own laser wall.
local function hookBarrier(base: Instance)
	local barrier = base:FindFirstChild("Barrier")
	if not barrier then
		return
	end
	local function apply()
		if base:GetAttribute("OwnerId") == player.UserId then
			barrier.CanCollide = false
		end
	end
	barrier:GetPropertyChangedSignal("CanCollide"):Connect(apply)
	base:GetAttributeChangedSignal("OwnerId"):Connect(function()
		apply()
		local lockPrompt = base:FindFirstChild("LockButton") and base.LockButton:FindFirstChild("LockPrompt")
		if lockPrompt then
			updatePrompt(lockPrompt)
		end
	end)
	apply()
end

-- Guide beam while carrying -----------------------------------------------------
local guide = {}
local function updateGuide(stats)
	local carrying = stats and #stats.Carrying > 0
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local bases = workspace:FindFirstChild("Bases")
	local base = bases and myBaseIndex() and bases:FindFirstChild("Base" .. myBaseIndex())
	if not carrying or not hrp or not base then
		if guide.Beam then
			guide.Beam.Enabled = false
		end
		return
	end
	if not guide.Target or not guide.Target.Parent then
		local floor = base:FindFirstChild("Floor")
		if not floor then
			return
		end
		local p = Instance.new("Part")
		p.Name = "GuideTarget"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = floor.CFrame * CFrame.new(0, 4, 0)
		p.Parent = workspace
		guide.Target = p
		guide.A1 = Instance.new("Attachment")
		guide.A1.Parent = p
	end
	if not guide.A0 or guide.A0.Parent ~= hrp then
		guide.A0 = Instance.new("Attachment")
		guide.A0.Position = Vector3.new(0, -2.5, 0)
		guide.A0.Parent = hrp
		if guide.Beam then
			guide.Beam:Destroy()
		end
		local beam = Instance.new("Beam")
		beam.Attachment0 = guide.A0
		beam.Attachment1 = guide.A1
		beam.Width0 = 1.4
		beam.Width1 = 1.4
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80))
		beam.Transparency = NumberSequence.new(0.3)
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureMode = Enum.TextureMode.Static
		beam.TextureLength = 4
		beam.TextureSpeed = 2
		beam.Parent = hrp
		guide.Beam = beam
	end
	local floor = base:FindFirstChild("Floor")
	if floor then
		guide.Target.CFrame = floor.CFrame * CFrame.new(0, 4, 0)
	end
	local stolen = false
	for _, item in ipairs(stats.Carrying) do
		stolen = stolen or item.Source == "Steal"
	end
	guide.Beam.Color = ColorSequence.new(stolen and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 220, 80))
	guide.Beam.Enabled = true
end

-- Effects -------------------------------------------------------------------------
local function fovPunch(amount: number, duration: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local base = 70
	cam.FieldOfView = base + amount
	TweenService:Create(cam, TweenInfo.new(duration, Enum.EasingStyle.Quad), { FieldOfView = base }):Play()
end

local shakeUntil, shakeAmount = 0, 0
local function shake(amount: number, duration: number)
	shakeAmount = amount
	shakeUntil = os.clock() + duration
end

local function onEffect(kind: string, a, b)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if kind == "Dash" and hrp then
		local look = hrp.CFrame.LookVector
		hrp.AssemblyLinearVelocity = Vector3.new(look.X * 110, 18, look.Z * 110)
		fovPunch(18, 0.5)
		Sound.Play("Dash", 0.6)
	elseif kind == "SuperJump" then
		Sound.Play("Jump", 0.6)
		Notifications.Toast("🦘 Super Jump active!", "info")
	elseif kind == "Cloak" then
		Notifications.Toast("👻 You are cloaked!", "info")
	elseif kind == "Knockback" and hrp and hum then
		hrp.AssemblyLinearVelocity = a
		hum.PlatformStand = true
		shake(0.6, 0.4)
		Sound.Play("Bonk", 0.8)
		task.delay(b or 1, function()
			if hum.Parent then
				hum.PlatformStand = false
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	elseif kind == "BonkHit" then
		shake(0.25, 0.2)
	elseif kind == "Shake" and hrp and typeof(a) == "Vector3" then
		local d = (hrp.Position - a).Magnitude
		if d < 160 then
			shake((b or 0.5) * (1 - d / 160), 0.6)
		end
	elseif kind == "Pickup" then
		Sound.Play("Pickup", 0.6)
		if Rarities.Rank(a or "Common") >= 5 then
			Sound.Play("Legendary", 0.8)
			fovPunch(8, 0.6)
		end
	elseif kind == "Deposit" then
		Sound.Play("Deposit", 0.7)
		if Rarities.Rank(a or "Common") >= 5 then
			Notifications.Confetti()
		end
	elseif kind == "Sell" or kind == "Purchase" then
		Sound.Play("Purchase", 0.6)
	elseif kind == "LevelUp" then
		Sound.Play("LevelUp", 0.7)
		Notifications.Splash(("LEVEL %d!"):format(a or 0), "Keep collecting treasures!", Color3.fromRGB(255, 220, 80))
	elseif kind == "Rebirth" then
		Sound.Play("Rebirth", 0.8)
		Notifications.Splash(("REBIRTH %d"):format(a or 0), "Permanent income bonus unlocked!", Color3.fromRGB(255, 110, 200))
		fovPunch(25, 1.2)
	elseif kind == "Confetti" then
		Notifications.Confetti()
		Sound.Play("Legendary", 0.6)
	elseif kind == "Grapple" and hrp and typeof(a) == "Vector3" then
		local dir = a - hrp.Position
		hrp.AssemblyLinearVelocity = dir.Unit * math.clamp(dir.Magnitude * 2.2, 60, 160) + Vector3.new(0, 18, 0)
		local rope = Instance.new("Part")
		rope.Anchored = true
		rope.CanCollide = false
		rope.CanQuery = false
		rope.Material = Enum.Material.Neon
		rope.Color = Color3.fromRGB(230, 230, 240)
		rope.Size = Vector3.new(0.2, 0.2, dir.Magnitude)
		rope.CFrame = CFrame.lookAt(hrp.Position + dir / 2, a)
		rope.Parent = workspace
		TweenService:Create(rope, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		game:GetService("Debris"):AddItem(rope, 0.6)
		Sound.Play("Dash", 0.7, 1.3)
		fovPunch(15, 0.6)
	elseif kind == "GlobalShake" then
		shake(a or 0.4, 1.2)
	elseif kind == "ChestOpen" then
		Notifications.Confetti()
	elseif kind == "Coin" then
		Sound.Play("Collect", 0.5, 1.4)
		Notifications.MoneyPop("+" .. Util.Money(a or 0), Color3.fromRGB(255, 220, 80))
	elseif kind == "Collect" then
		Sound.Play("Collect", 0.8)
		Notifications.MoneyPop("💰 +" .. Util.Money(a or 0), Color3.fromRGB(120, 255, 120))
		fovPunch(6, 0.4)
	elseif kind == "Discovery" then
		Sound.Play("Discovery", 0.8)
		Notifications.DiscoveryCard(a)
	elseif kind == "Achievement" then
		Sound.Play("LevelUp", 0.7)
		Notifications.Confetti()
	elseif kind == "Portal" then
		Sound.Play("Portal", 0.8)
		fovPunch(30, 0.8)
		Notifications.Flash(Color3.fromRGB(180, 140, 255))
	elseif kind == "Zap" and typeof(a) == "Vector3" and typeof(b) == "Vector3" then
		local p0 = Instance.new("Part")
		p0.Anchored = true
		p0.CanCollide = false
		p0.CanQuery = false
		p0.Material = Enum.Material.Neon
		p0.Color = Color3.fromRGB(255, 60, 60)
		local len = (b - a).Magnitude
		p0.Size = Vector3.new(0.4, 0.4, len)
		p0.CFrame = CFrame.lookAt((a + b) / 2, b)
		p0.Parent = workspace
		Sound.Play("Bonk", 0.8, 1.5)
		TweenService:Create(p0, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(0.05, 0.05, len) }):Play()
		game:GetService("Debris"):AddItem(p0, 0.5)
	end
end

function WorldFX.Init(windows, notifications)
	Windows = windows
	Notifications = notifications
end

function WorldFX.Start()
	-- track everything that exists and appears later
	for _, d in ipairs(workspace:GetDescendants()) do
		watchDescendant(d)
	end
	workspace.DescendantAdded:Connect(watchDescendant)
	workspace.DescendantRemoving:Connect(function(d)
		if d:IsA("Model") and d:GetAttribute("TreasureId") then
			TreasureAnimator.Untrack(d)
		end
	end)
	TreasureAnimator.Start()
	-- stealing pose: tell the server while we hold a Steal prompt
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt:GetAttribute("Kind") == "Steal" then
			State.Ask("SetStealing", true)
			Sound.Play("Steal", 0.5)
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt:GetAttribute("Kind") == "Steal" then
			State.Ask("SetStealing", false)
		end
	end)

	local function hookBases()
		local bases = workspace:WaitForChild("Bases", 30)
		if not bases then
			return
		end
		for _, b in ipairs(bases:GetChildren()) do
			hookBarrier(b)
		end
		bases.ChildAdded:Connect(hookBarrier)
	end
	task.spawn(hookBases)

	player:GetAttributeChangedSignal("BaseIndex"):Connect(function()
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				updatePrompt(d)
			end
		end
	end)

	-- world prompts that open menus
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		if prompt:GetAttribute("Kind") == "Steal" then
			State.Ask("SetStealing", false)
		end
		local ui = prompt:GetAttribute("OpenUI")
		if ui == "Sell" then
			Windows.Open("Inventory", "Sell")
		elseif ui == "Pets" then
			Windows.Open("Pets", "Eggs")
		elseif ui then
			Windows.Open(ui)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if os.clock() < shakeUntil then
			local cam = workspace.CurrentCamera
			local s = shakeAmount
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * s * 4), math.rad((math.random() - 0.5) * s * 4), 0)
		end
	end)

	Remotes.Effect.OnClientEvent:Connect(onEffect)
	Remotes.Alarm.OnClientEvent:Connect(function(thief, treasure)
		Notifications.Alarm(thief, treasure)
		shake(0.3, 0.5)
	end)
	Remotes.Announce.OnClientEvent:Connect(function(text, rarity)
		Notifications.Banner(text, rarity)
	end)
	Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		Notifications.Toast(text, kind)
	end)
	State.StatsChanged.Event:Connect(updateGuide)
	-- Grapple Hook: the tool asks the server to zip us to where we clicked
	local function hookTool(tool: Instance)
		if tool:IsA("Tool") and tool:GetAttribute("Grapple") and not tool:GetAttribute("Hooked") then
			tool:SetAttribute("Hooked", true)
			tool.Activated:Connect(function()
				local mouse = player:GetMouse()
				local target = mouse.Hit and mouse.Hit.Position
				if target then
					State.Request("Grapple", target)
				end
			end)
		end
	end
	local function watchContainer(c: Instance?)
		if not c then
			return
		end
		for _, t in ipairs(c:GetChildren()) do
			hookTool(t)
		end
		c.ChildAdded:Connect(hookTool)
	end
	watchContainer(player:FindFirstChildOfClass("Backpack"))
	player.ChildAdded:Connect(function(c)
		if c:IsA("Backpack") then
			watchContainer(c)
		end
	end)
	player.CharacterAdded:Connect(function()
		guide.A0 = nil
		if guide.Beam then
			guide.Beam:Destroy()
			guide.Beam = nil
		end
	end)
end

return WorldFX
