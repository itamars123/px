-- Ambience.lua
-- Client-side environment animation and atmosphere:
--   * smooth day/night cycle (server clock), night lamps, stars
--   * weather: clouds, rain, storms with lightning + thunder, fog
--   * event sky tints (Apocalypse red, Double Money gold, Lucky green ...)
--   * CollectionService animations: Spin, Bob, Pulse, Flag, Tree sway,
--     sliding base doors, sweeping security cameras, opening chests

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local FrameLoop = require(script.Parent.FrameLoop)

local State = require(script.Parent.State)
local Sound = require(script.Parent.Sound)

local Ambience = {}
Ambience.LowGfx = false
Ambience.WeatherEnabled = true

local anims: { [Instance]: any } = {}
local trees: { any } = {}
local pulses: { [BasePart]: any } = {}
local lamps: { BasePart } = {}
local cams: { any } = {}
local rainPart: Part?
local rainEmitter: ParticleEmitter?
local nextLightning = 0
local flashUntil = 0

-- Generic tag animation (Spin / Bob / Flag can stack on one object) ---------
local function register(inst: Instance)
	if anims[inst] then
		return
	end
	local base
	if inst:IsA("Model") then
		if not inst.PrimaryPart then
			return
		end
		base = inst:GetPivot()
	elseif inst:IsA("BasePart") then
		base = inst.CFrame
	else
		return
	end
	anims[inst] = { Base = base, Phase = math.random() * 10 }
end

local function unregister(inst)
	anims[inst] = nil
end

local function animateTagged(t: number, camPos: Vector3)
	for inst, a in pairs(anims) do
		if not inst.Parent then
			anims[inst] = nil
		elseif (a.Base.Position - camPos).Magnitude < 260 then
			local cf = a.Base
			if CollectionService:HasTag(inst, "Bob") then
				local h = inst:GetAttribute("BobHeight") or 0.5
				local sp = inst:GetAttribute("BobSpeed") or 1.2
				cf = cf + Vector3.new(0, math.sin(t * sp + a.Phase) * h, 0)
			end
			if CollectionService:HasTag(inst, "Spin") then
				local sp = inst:GetAttribute("SpinSpeed") or 1
				local axis = inst:GetAttribute("SpinAxis") or "Y"
				local ang = (t * sp) % (math.pi * 2)
				if axis == "Z" then
					cf = cf * CFrame.Angles(0, 0, ang)
				elseif axis == "X" then
					cf = cf * CFrame.Angles(ang, 0, 0)
				else
					cf = cf * CFrame.Angles(0, ang, 0)
				end
			end
			if CollectionService:HasTag(inst, "Flag") then
				local amt = inst:GetAttribute("SwayAmount") or 0.2
				local wind = workspace.GlobalWind.Magnitude / 10
				cf = cf * CFrame.Angles(0, math.sin(t * 3 + a.Phase) * amt * wind, math.sin(t * 2.3 + a.Phase) * amt * 0.3)
			end
			if inst:IsA("Model") then
				inst:PivotTo(cf)
			else
				(inst :: BasePart).CFrame = cf
			end
		end
	end
end

-- Trees sway in the wind --------------------------------------------------------
local function registerTree(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local trunk, leaves = nil, {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Material == Enum.Material.Wood and not trunk then
				trunk = p
			else
				table.insert(leaves, p)
			end
		end
	end
	if not trunk or #leaves == 0 then
		return
	end
	local pivot = CFrame.new(trunk.Position - Vector3.new(0, trunk.Size.X / 2, 0))
	local bases = {}
	for i, l in ipairs(leaves) do
		bases[i] = pivot:Inverse() * l.CFrame
	end
	table.insert(trees, { Pivot = pivot, Leaves = leaves, Bases = bases, Phase = math.random() * 10 })
end

local function swayTrees(t: number, camPos: Vector3)
	local wind = workspace.GlobalWind
	local strength = math.clamp(wind.Magnitude / 12, 0.3, 3)
	local parts, cfs = {}, {}
	for _, tr in ipairs(trees) do
		if (tr.Pivot.Position - camPos).Magnitude < 170 and tr.Leaves[1].Parent then
			local a = 0.025 * strength
			local rot = CFrame.Angles(math.sin(t * 1.3 + tr.Phase) * a, 0, math.cos(t * 1.1 + tr.Phase) * a)
			for i, leaf in ipairs(tr.Leaves) do
				table.insert(parts, leaf)
				table.insert(cfs, tr.Pivot * rot * tr.Bases[i])
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Pulse (glowing lights) ---------------------------------------------------------
local function registerPulse(p: Instance)
	if p:IsA("BasePart") then
		pulses[p] = { Base = p.Transparency, Phase = math.random() * 10 }
	end
end

-- Day / night ----------------------------------------------------------------------
local DAY_AMBIENT = Color3.fromRGB(90, 90, 110)
local NIGHT_AMBIENT = Color3.fromRGB(40, 45, 80)
local DAY_OUT = Color3.fromRGB(150, 150, 170)
local NIGHT_OUT = Color3.fromRGB(60, 70, 120)

local EVENT_TINT = {
	["Treasure Apocalypse"] = Color3.fromRGB(255, 140, 130),
	["Double Money"] = Color3.fromRGB(255, 235, 170),
	["Lucky Treasure"] = Color3.fromRGB(190, 255, 190),
	["Secret Treasure"] = Color3.fromRGB(210, 180, 255),
	["Golden Treasure Rain"] = Color3.fromRGB(255, 240, 190),
	["Meteor Shower"] = Color3.fromRGB(255, 210, 180),
	["Divine Descent"] = Color3.fromRGB(255, 255, 230),
}

local function updateSky(dt: number)
	local start = workspace:GetAttribute("DayStart")
	local length = workspace:GetAttribute("DayLength")
	local clock = Lighting.ClockTime
	if typeof(start) == "number" and typeof(length) == "number" and length > 0 then
		clock = (6 + ((State.Now() - start) / length) * 24) % 24
		Lighting.ClockTime = clock
	end
	-- daylight factor: 1 at noon, 0 at night
	local day = math.clamp(math.sin((clock - 6) / 12 * math.pi) * 1.6, 0, 1)
	local weather = Ambience.WeatherEnabled and (workspace:GetAttribute("Weather") or "Clear") or "Clear"
	local gloom = (weather == "Storm" and 0.5) or (weather == "Rain" and 0.3) or (weather == "Cloudy" and 0.15) or 0
	Lighting.Brightness = os.clock() < flashUntil and 8 or (0.6 + day * 2.2) * (1 - gloom * 0.6)
	Lighting.Ambient = NIGHT_AMBIENT:Lerp(DAY_AMBIENT, day)
	Lighting.OutdoorAmbient = NIGHT_OUT:Lerp(DAY_OUT, day)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		local targetDensity = (weather == "Fog" and 0.6) or (weather == "Storm" and 0.45) or (weather == "Rain" and 0.38) or 0.28
		atmo.Density += (targetDensity - atmo.Density) * math.min(1, dt * 0.5)
	end
	local cc = Lighting:FindFirstChild("GameColor")
	if cc and cc:IsA("ColorCorrectionEffect") then
		local tint = EVENT_TINT[workspace:GetAttribute("Event") or ""] or Color3.new(1, 1, 1)
		cc.TintColor = cc.TintColor:Lerp(tint, math.min(1, dt * 1.5))
	end
	-- night lamps
	local night = day < 0.3
	for _, lamp in ipairs(lamps) do
		if lamp.Parent then
			local light = lamp:FindFirstChildWhichIsA("Light")
			if light then
				light.Enabled = night or lamp.Name == "LighthouseLamp"
				if light:IsA("PointLight") then
					light.Brightness = night and 2.5 or 1
				end
			end
			lamp.Material = night and Enum.Material.Neon or Enum.Material.Glass
		end
	end
	-- rain
	if rainPart and rainEmitter then
		local cam = workspace.CurrentCamera
		if cam then
			rainPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 45, 0))
		end
		local rate = (weather == "Storm" and 900) or (weather == "Rain" and 450) or 0
		if Ambience.LowGfx then
			rate *= 0.3
		end
		rainEmitter.Rate = rate
		rainEmitter.Acceleration = Vector3.new(workspace.GlobalWind.X, 0, workspace.GlobalWind.Z)
	end
	-- lightning
	if weather == "Storm" and os.clock() > nextLightning then
		nextLightning = os.clock() + 4 + math.random() * 7
		flashUntil = os.clock() + 0.09
		task.delay(0.2, function()
			flashUntil = os.clock() + 0.06 -- double flash
		end)
		task.delay(0.6 + math.random(), function()
			Sound.Play("Thunder", 0.7, 0.5)
		end)
	end
end

-- Base doors, cameras, chests -------------------------------------------------------
local function hookDoor(door: Instance)
	if not door:IsA("BasePart") then
		return
	end
	local base = door.Parent
	local function apply()
		local closed = base and base:GetAttribute("Locked") == true
		local target = closed and door:GetAttribute("ClosedCF") or door:GetAttribute("OpenCF")
		if typeof(target) == "CFrame" then
			TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target }):Play()
		end
	end
	if base then
		base:GetAttributeChangedSignal("Locked"):Connect(apply)
	end
	apply()
end

local function hookCamera(cam: Instance)
	if cam:IsA("Model") and cam.PrimaryPart then
		table.insert(cams, { Model = cam, Base = cam:GetPivot(), Phase = math.random() * 6, Lens = cam:FindFirstChild("Lens") })
	end
end

local function hookChest(chest: Instance)
	if not chest:IsA("Model") then
		return
	end
	local function open()
		local lid = chest:FindFirstChild("Lid")
		if not lid or not lid.PrimaryPart then
			return
		end
		local start = lid:GetPivot()
		Sound.Play("ChestOpen", 0.8)
		local value = Instance.new("NumberValue")
		value.Changed:Connect(function(v)
			if lid.Parent then
				lid:PivotTo(start * CFrame.Angles(math.rad(-v), 0, 0))
			end
		end)
		TweenService:Create(value, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 115 }):Play()
		local base = chest.PrimaryPart
		local burst = base and base:FindFirstChildOfClass("ParticleEmitter")
		if burst then
			burst.Rate = 0
			burst:Emit(60)
		end
	end
	if chest:GetAttribute("Opened") then
		open()
	else
		chest:GetAttributeChangedSignal("Opened"):Connect(open)
	end
	chest:GetAttributeChangedSignal("Despawning"):Connect(function()
		local s = 1
		task.spawn(function()
			while s > 0.05 and chest.Parent do
				s -= 0.1
				pcall(function()
					chest:ScaleTo(math.max(0.05, s))
				end)
				task.wait(0.03)
			end
		end)
	end)
end

local function updateCams(t: number)
	local now = State.Now()
	for _, c in ipairs(cams) do
		if c.Model.Parent then
			c.Model:PivotTo(c.Base * CFrame.Angles(0, math.sin(t * 0.8 + c.Phase) * 0.7, 0))
			local base = c.Model.Parent
			local alert = base:GetAttribute("CameraAlert") or 0
			if c.Lens then
				c.Lens.Color = (now - alert < 5) and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(60, 255, 120)
			end
		end
	end
end

local function watchTag(tagName: string, fn)
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		task.spawn(fn, inst)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(fn)
end

function Ambience.SetSettings(settings)
	Ambience.LowGfx = settings.LowGfx == true
	Ambience.WeatherEnabled = settings.Weather ~= false
end

function Ambience.Start()
	for _, tagName in ipairs({ "Spin", "Bob", "Flag" }) do
		watchTag(tagName, register)
		CollectionService:GetInstanceRemovedSignal(tagName):Connect(unregister)
	end
	watchTag("Tree", registerTree)
	watchTag("Pulse", registerPulse)
	watchTag("Lamp", function(p)
		if p:IsA("BasePart") then
			table.insert(lamps, p)
		end
	end)
	watchTag("SlidingDoor", hookDoor)
	watchTag("SecurityCam", hookCamera)
	task.spawn(function()
		local chests = workspace:WaitForChild("Chests", 30)
		if chests then
			for _, c in ipairs(chests:GetChildren()) do
				hookChest(c)
			end
			chests.ChildAdded:Connect(hookChest)
		end
	end)

	-- rain emitter that follows the camera
	rainPart = Instance.new("Part")
	rainPart.Name = "RainEmitter"
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Transparency = 1
	rainPart.Size = Vector3.new(170, 1, 170)
	rainPart.Parent = workspace
	rainEmitter = Instance.new("ParticleEmitter")
	rainEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rainEmitter.Color = ColorSequence.new(Color3.fromRGB(190, 220, 255))
	rainEmitter.LightEmission = 0.3
	rainEmitter.Transparency = NumberSequence.new(0.35)
	rainEmitter.Size = NumberSequence.new(0.18)
	rainEmitter.Squash = NumberSequence.new(-3)
	rainEmitter.EmissionDirection = Enum.NormalId.Bottom
	rainEmitter.Speed = NumberRange.new(80, 95)
	rainEmitter.Lifetime = NumberRange.new(0.8, 1)
	rainEmitter.SpreadAngle = Vector2.new(4, 4)
	rainEmitter.Rate = 0
	rainEmitter.Parent = rainPart

	local pulseAcc = 0
	FrameLoop.Bind("Ambience", function(dt)
		local t = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		updateSky(dt)
		animateTagged(t, camPos)
		updateCams(t)
		if not Ambience.LowGfx then
			swayTrees(t, camPos)
		end
		pulseAcc += dt
		if pulseAcc > 0.05 then
			pulseAcc = 0
			for p, info in pairs(pulses) do
				if not p.Parent then
					pulses[p] = nil
				else
					local sp = p:GetAttribute("PulseSpeed") or 1
					p.Transparency = math.clamp(info.Base + (math.sin(t * sp * 2 + info.Phase) + 1) * 0.15, 0, 0.9)
				end
			end
		end
	end)
end

return Ambience
