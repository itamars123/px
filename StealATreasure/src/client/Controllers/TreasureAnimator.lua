-- TreasureAnimator.lua
-- Brings treasure "characters" to life, entirely on the client:
--   * personality idles: Hop, Dance, Float, Spin, Wiggle, Bounce
--   * roaming field treasures: walk / run / jump / dance on the shared
--     deterministic path (Motion), facing where they move
--   * faces: blinking, happy / surprised / sleepy / excited expressions
--   * special "power" animation for Legendary+ (spin-jump burst)
--   * spawn (pop-in) and disappear (shrink + spin) animations
--   * rainbow halos, lightning flicker, Celestial orbiting moons
-- The server never moves treasures, so this costs no network traffic.

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rarities = require(Shared.Rarities)
local Motion = require(Shared.Motion)
local State = require(script.Parent.State)

local TreasureAnimator = {}
TreasureAnimator.LowGfx = false
TreasureAnimator.Effects = true

local ANIM_DISTANCE = 150
local tracked: { [Model]: any } = {}
local carried: { [Model]: boolean } = {}

local function faceParts(model: Model)
	local face = model:FindFirstChild("Face")
	if not face then
		return nil
	end
	return {
		EyeL = face:FindFirstChild("EyeL"),
		EyeR = face:FindFirstChild("EyeR"),
		MouthO = face:FindFirstChild("MouthO"),
		Smile = { face:FindFirstChild("Mouth1"), face:FindFirstChild("Mouth2"), face:FindFirstChild("Mouth3") },
	}
end

-- Expressions: "Happy", "Surprised", "Sleepy", "Excited", "Blink"
local function setExpression(info, expr: string)
	local f = info.Face
	if not f or info.Expr == expr then
		return
	end
	info.Expr = expr
	local eyeScale = Vector3.new(1, 1, 1)
	if expr == "Surprised" or expr == "Excited" then
		eyeScale = Vector3.new(1.3, 1.3, 1.3)
	elseif expr == "Sleepy" then
		eyeScale = Vector3.new(1.1, 0.25, 1)
	elseif expr == "Blink" then
		eyeScale = Vector3.new(1.1, 0.12, 1)
	end
	for _, eye in ipairs({ f.EyeL, f.EyeR }) do
		if eye then
			local base = eye:GetAttribute("BaseSize")
			if base then
				eye.Size = base * eyeScale
			end
		end
	end
	local open = expr == "Surprised"
	if f.MouthO then
		f.MouthO.Transparency = open and 0 or 1
	end
	for _, m in ipairs(f.Smile) do
		if m then
			m.Transparency = open and 1 or 0
		end
	end
end

function TreasureAnimator.ApplyQuality(model: Instance)
	local showFx = TreasureAnimator.Effects and not TreasureAnimator.LowGfx
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("PointLight") then
			d.Enabled = showFx
		end
	end
end

function TreasureAnimator.Track(model: Model)
	if tracked[model] then
		return
	end
	if model:GetAttribute("Carried") then
		carried[model] = true
		local info = { Face = faceParts(model) }
		setExpression(info, "Surprised")
		return
	end
	local root = model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return
	end
	local rank = Rarities.Rank(model:GetAttribute("Rarity") or "Common")
	local info = {
		Root = root,
		Rank = rank,
		Personality = model:GetAttribute("Personality") or "Float",
		Phase = math.random() * 10,
		Seed = model:GetAttribute("WanderSeed"),
		Radius = model:GetAttribute("WanderRadius") or 7,
		Face = faceParts(model),
		NextBlink = os.clock() + math.random() * 4,
		NextPower = os.clock() + 4 + math.random() * 8,
		PowerStart = 0,
		Scale = 1,
		Halo = model:FindFirstChild("Halo"),
		Orbit = model:FindFirstChild("Orbit"),
		Rainbow = model:GetAttribute("Rainbow"),
		Lightning = model:GetAttribute("Lightning"),
	}
	-- spawn animation if it just appeared
	local spawnTime = model:GetAttribute("SpawnTime")
	if spawnTime and State.Now() - spawnTime < 1.5 then
		info.SpawnStart = os.clock()
		pcall(function()
			model:ScaleTo(0.05)
		end)
		info.Scale = 0.05
	end
	tracked[model] = info
	TreasureAnimator.ApplyQuality(model)
	model:GetAttributeChangedSignal("Despawning"):Connect(function()
		info.DespawnStart = os.clock()
	end)
end

local function setScale(model: Model, info, s: number)
	if math.abs(info.Scale - s) > 0.005 then
		info.Scale = s
		pcall(function()
			model:ScaleTo(math.max(0.02, s))
		end)
	end
end

local function backOut(t: number): number
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function isNight(): boolean
	local c = Lighting.ClockTime
	return c > 20.5 or c < 5.5
end

local function idleOffset(personality: string, t: number): (number, CFrame)
	if personality == "Hop" then
		return math.abs(math.sin(t * 3)) * 0.8, CFrame.identity
	elseif personality == "Dance" then
		return 0.2 + math.abs(math.sin(t * 4)) * 0.2, CFrame.Angles(0, math.sin(t * 2) * 0.8, math.sin(t * 4) * 0.25)
	elseif personality == "Spin" then
		return 0.4 + math.sin(t * 2) * 0.2, CFrame.Angles(0, t * 3, 0)
	elseif personality == "Wiggle" then
		return 0.3, CFrame.Angles(0, math.sin(t * 6) * 0.45, math.sin(t * 3) * 0.1)
	elseif personality == "Bounce" then
		return math.abs(math.sin(t * 4.5)) * 0.45, CFrame.Angles(math.sin(t * 9) * 0.06, 0, 0)
	end
	-- Float
	return 0.5 + math.sin(t * 1.5) * 0.45, CFrame.Angles(0, t * 0.7, 0)
end

local function animateOne(model: Model, info, t: number, now: number, camPos: Vector3, night: boolean)
	local home = model:GetAttribute("Home")
	if typeof(home) ~= "CFrame" or not info.Root.Anchored then
		return
	end
	local pos = home.Position
	local state = "Idle"
	local yaw = 0
	if info.Seed then
		local offset
		offset, state, yaw = Motion.Sample(info.Seed, now, info.Radius)
		pos += offset
	end
	if (pos - camPos).Magnitude > ANIM_DISTANCE and not info.Seed then
		return
	end
	local lowGfx = TreasureAnimator.LowGfx
	local cf
	if info.Seed then
		local facing = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
		if lowGfx then
			cf = facing
		elseif state == "Walk" then
			cf = facing * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.sin(t * 10 + info.Phase) * 0.18)
		elseif state == "Run" then
			cf = facing * CFrame.Angles(-0.25, 0, math.sin(t * 18 + info.Phase) * 0.22)
		elseif state == "Jump" then
			cf = facing * CFrame.Angles(0, t * 4, 0)
		elseif state == "Dance" then
			cf = facing * CFrame.new(0, math.abs(math.sin(t * 5)) * 0.3, 0) * CFrame.Angles(0, math.sin(t * 3) * 1.2, math.sin(t * 6) * 0.3)
		else
			local h, rot = idleOffset(info.Personality, t + info.Phase)
			cf = facing * CFrame.new(0, h, 0) * rot
		end
		setExpression(info, (state == "Run" or state == "Jump") and "Surprised" or (state == "Dance" and "Excited" or "Happy"))
	else
		if lowGfx then
			return
		end
		local h, rot = idleOffset(info.Personality, t + info.Phase)
		cf = CFrame.new(pos) * home.Rotation * CFrame.new(0, h, 0) * rot
		-- special power animation for Legendary+
		if info.Rank >= 5 then
			local clock = os.clock()
			if clock > info.NextPower then
				info.PowerStart = clock
				info.NextPower = clock + 7 + math.random() * 6
			end
			local p = clock - info.PowerStart
			if p < 1 then
				cf = cf * CFrame.new(0, math.sin(p * math.pi) * 2.2, 0) * CFrame.Angles(0, p * math.pi * 2, 0)
				setExpression(info, "Excited")
			elseif night and info.Rank < 7 then
				setExpression(info, "Sleepy")
			else
				setExpression(info, "Happy")
			end
		else
			setExpression(info, night and "Sleepy" or "Happy")
		end
	end
	info.Root.CFrame = cf

	-- blinking
	local clock = os.clock()
	if info.Face and info.Expr ~= "Sleepy" then
		if clock > info.NextBlink then
			info.BlinkEnd = clock + 0.12
			info.NextBlink = clock + 2.5 + math.random() * 3
			info.PrevExpr = info.Expr
			setExpression(info, "Blink")
		elseif info.BlinkEnd and clock > info.BlinkEnd then
			info.BlinkEnd = nil
			setExpression(info, info.PrevExpr or "Happy")
		end
	end
	-- spawn pop-in
	if info.SpawnStart then
		local k = math.clamp((clock - info.SpawnStart) / 0.55, 0, 1)
		setScale(model, info, math.max(0.05, backOut(k)))
		if k >= 1 then
			info.SpawnStart = nil
			setScale(model, info, 1)
		end
	end
	-- disappear
	if info.DespawnStart then
		local k = math.clamp((clock - info.DespawnStart) / 0.5, 0, 1)
		setScale(model, info, 1 - k * 0.95)
		info.Root.CFrame = cf * CFrame.new(0, k * 2, 0) * CFrame.Angles(0, k * 12, 0)
	end
	-- rainbow / lightning extras
	if info.Rainbow and info.Halo then
		local c = Color3.fromHSV((t * 0.25 + info.Phase) % 1, 0.7, 1)
		for _, seg in ipairs(info.Halo:GetChildren()) do
			(seg :: BasePart).Color = c
		end
	end
	if info.Lightning then
		local att = info.Root:FindFirstChild("FxAttachment")
		local glow = att and att:FindFirstChild("Glow")
		if glow then
			glow.Brightness = (math.random() < 0.08) and 6 or 1.6
		end
	end
end

function TreasureAnimator.Start()
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local camPos = cam.CFrame.Position
		local t = os.clock()
		local now = State.Now()
		local night = isNight()
		for model, info in pairs(tracked) do
			if not model.Parent then
				tracked[model] = nil
			else
				animateOne(model, info, t, now, camPos, night)
			end
		end
		for model in pairs(carried) do
			if not model.Parent then
				carried[model] = nil
			end
		end
	end)
end

function TreasureAnimator.SetQuality(lowGfx: boolean, effects: boolean)
	TreasureAnimator.LowGfx = lowGfx
	TreasureAnimator.Effects = effects
	for model in pairs(tracked) do
		TreasureAnimator.ApplyQuality(model)
	end
end

function TreasureAnimator.Untrack(model: Model)
	tracked[model] = nil
	carried[model] = nil
end

return TreasureAnimator
