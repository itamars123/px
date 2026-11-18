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

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Rarities = require(Shared.Rarities)
local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local player = Players.LocalPlayer

local WorldFX = {}
WorldFX.LowGfx = false
WorldFX.Effects = true

local Windows, Notifications -- injected

local tracked: { [Model]: { Root: BasePart, Speed: number, Phase: number, Rank: number } } = {}
local ANIM_DISTANCE = 140

local SPIN = { 0.6, 0.7, 0.8, 0.9, 1.1, 1.3, 1.5, 1.8 }

local function track(model: Model)
	if tracked[model] or model:GetAttribute("Carried") then
		return
	end
	local root = model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return
	end
	local rank = Rarities.Rank(model:GetAttribute("Rarity") or "Common")
	tracked[model] = { Root = root, Speed = SPIN[rank] or 1, Phase = math.random() * 6, Rank = rank }
	WorldFX.ApplyQuality(model)
end

local function untrack(model: Model)
	tracked[model] = nil
end

function WorldFX.ApplyQuality(model: Instance)
	local showFx = WorldFX.Effects and not WorldFX.LowGfx
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") then
			d.Enabled = showFx
		elseif d:IsA("PointLight") then
			d.Enabled = showFx
		end
	end
end

local function applyAllQuality()
	for model in pairs(tracked) do
		WorldFX.ApplyQuality(model)
	end
	-- global quality
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

-- Treasure animation ------------------------------------------------------
local RAINBOW_SPEED = 0.25
local function animate()
	if WorldFX.LowGfx then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	for model, info in pairs(tracked) do
		if not model.Parent then
			tracked[model] = nil
		else
			local home = model:GetAttribute("Home")
			if typeof(home) == "CFrame" and info.Root.Anchored then
				if (home.Position - camPos).Magnitude < ANIM_DISTANCE then
					local bob = math.sin(t * 2 + info.Phase) * 0.25 + 0.3
					info.Root.CFrame = home * CFrame.new(0, bob, 0) * CFrame.Angles(0, (t * info.Speed + info.Phase) % (math.pi * 2), 0)
					if model:GetAttribute("Rainbow") then
						local c = Color3.fromHSV((t * RAINBOW_SPEED + info.Phase) % 1, 0.7, 1)
						local halo = model:FindFirstChild("Halo")
						if halo then
							for _, seg in ipairs(halo:GetChildren()) do
								(seg :: BasePart).Color = c
							end
						end
					end
					if model:GetAttribute("Lightning") then
						local glow = info.Root:FindFirstChild("FxAttachment") and info.Root.FxAttachment:FindFirstChild("Glow")
						if glow then
							glow.Brightness = (math.random() < 0.08) and 6 or 1.6
						end
					end
				end
			end
		end
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
		track(d)
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
		if d:IsA("Model") and tracked[d] then
			untrack(d)
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
		local ui = prompt:GetAttribute("OpenUI")
		if ui == "Sell" then
			Windows.Open("Inventory", "Sell")
		elseif ui then
			Windows.Open(ui)
		end
	end)

	RunService.RenderStepped:Connect(function()
		animate()
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
	player.CharacterAdded:Connect(function()
		guide.A0 = nil
		if guide.Beam then
			guide.Beam:Destroy()
			guide.Beam = nil
		end
	end)
end

return WorldFX
