-- Emotes.lua
-- Procedural character animation layered on top of Roblox's default walk /
-- run / jump animations, for every player on every client:
--   carrying (arms overhead), stealing (crouch + reach), sprinting (lean),
--   celebrate, cheer, wave, dance, victory spin and flex.
-- The server only sets character attributes (Carrying, Stealing, Sprinting,
-- Emote + EmoteEnd); each client animates locally, so it's smooth everywhere.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local FrameLoop = require(script.Parent.FrameLoop)

local State = require(script.Parent.State)

local Emotes = {}

local originals = setmetatable({}, { __mode = "k" }) :: { [Motor6D]: CFrame }
local active = setmetatable({}, { __mode = "k" }) :: { [Model]: boolean }

local R15 = {
	RS = { "RightUpperArm", "RightShoulder" },
	LS = { "LeftUpperArm", "LeftShoulder" },
	RH = { "RightUpperLeg", "RightHip" },
	LH = { "LeftUpperLeg", "LeftHip" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	Root = { "LowerTorso", "Root" },
}
local R6 = {
	RS = { "Torso", "Right Shoulder" },
	LS = { "Torso", "Left Shoulder" },
	RH = { "Torso", "Right Hip" },
	LH = { "Torso", "Left Hip" },
	Neck = { "Torso", "Neck" },
	Root = { "HumanoidRootPart", "RootJoint" },
}

local function joints(char: Model)
	local map = char:FindFirstChild("UpperTorso") and R15 or R6
	local out = {}
	for key, path in pairs(map) do
		local holder = char:FindFirstChild(path[1])
		local j = holder and holder:FindFirstChild(path[2])
		if j and j:IsA("Motor6D") then
			if not originals[j] then
				originals[j] = j.C0
			end
			out[key] = j
		end
	end
	return out, map == R15
end

local rad = math.rad

-- Returns a table of joint -> rotation (and Root may include translation)
local function pose(char: Model, t: number, isR15: boolean)
	local p = {}
	local now = State.Now()
	local emote = char:GetAttribute("Emote")
	local emoteEnd = char:GetAttribute("EmoteEnd") or 0
	if emote and now > emoteEnd then
		emote = nil
	end
	local carrying = (char:GetAttribute("Carrying") or 0) > 0
	local stealing = char:GetAttribute("Stealing") == true
	local sprinting = char:GetAttribute("Sprinting") == true

	-- helpers: raise arm forward (X) or sideways (Z). R6 joints use Z for both.
	local function armForward(key, deg)
		if isR15 then
			p[key] = (p[key] or CFrame.identity) * CFrame.Angles(rad(deg), 0, 0)
		else
			local sign = key == "RS" and 1 or -1
			p[key] = (p[key] or CFrame.identity) * CFrame.Angles(0, 0, rad(deg) * sign)
		end
	end
	local function armSide(key, deg)
		if isR15 then
			local sign = key == "RS" and 1 or -1
			p[key] = (p[key] or CFrame.identity) * CFrame.Angles(0, 0, rad(deg) * sign)
		else
			armForward(key, deg)
		end
	end

	if emote == "Dance" then
		armSide("RS", 70 + 45 * math.sin(t * 8))
		armSide("LS", 70 + 45 * math.sin(t * 8 + math.pi))
		p.Root = CFrame.new(0, math.abs(math.sin(t * 8)) * 0.35, 0) * CFrame.Angles(0, math.sin(t * 4) * 0.5, math.sin(t * 8) * 0.08)
		p.RH = CFrame.Angles(math.sin(t * 8) * 0.4, 0, 0)
		p.LH = CFrame.Angles(-math.sin(t * 8) * 0.4, 0, 0)
		p.Neck = CFrame.Angles(0, 0, math.sin(t * 8) * 0.2)
	elseif emote == "Wave" then
		armSide("RS", 150 + 20 * math.sin(t * 10))
	elseif emote == "Cheer" or emote == "Celebrate" then
		armForward("RS", 165 + 15 * math.sin(t * 12))
		armForward("LS", 165 + 15 * math.sin(t * 12 + 1))
		p.Root = CFrame.new(0, math.abs(math.sin(t * 7)) * 0.9, 0)
		p.Neck = CFrame.Angles(rad(-15), 0, 0)
	elseif emote == "Victory" then
		armSide("RS", 150)
		armSide("LS", 150)
		p.Root = CFrame.new(0, math.abs(math.sin(t * 6)) * 0.6, 0) * CFrame.Angles(0, t * 7, 0)
	elseif emote == "Flex" then
		armSide("RS", 90 + 10 * math.sin(t * 6))
		armSide("LS", 90 + 10 * math.sin(t * 6))
		p.Root = CFrame.new(0, -0.3 + math.abs(math.sin(t * 3)) * 0.2, 0)
	end

	if stealing then
		p.RS, p.LS = nil, nil
		armForward("RS", 80 + 10 * math.sin(t * 14))
		armForward("LS", 80 + 10 * math.sin(t * 14 + 2))
		p.Waist = CFrame.Angles(rad(-25), 0, 0)
		p.Root = CFrame.new(0, -0.5, 0)
	end
	if carrying then
		-- arms locked overhead holding the loot (overrides emote arms)
		p.RS, p.LS = nil, nil
		armForward("RS", 165)
		armForward("LS", 165)
		if isR15 then
			p.RS = p.RS * CFrame.Angles(0, 0, rad(-12))
			p.LS = p.LS * CFrame.Angles(0, 0, rad(12))
		end
	end
	if sprinting and not emote and not stealing then
		p.Waist = (p.Waist or CFrame.identity) * CFrame.Angles(rad(-14), 0, 0)
		p.Neck = (p.Neck or CFrame.identity) * CFrame.Angles(rad(10), 0, 0)
	end
	return p, (emote ~= nil or carrying or stealing or sprinting)
end

local function animateCharacter(char: Model, t: number)
	local js, isR15 = joints(char)
	local p, any = pose(char, t, isR15)
	if not any and not active[char] then
		return
	end
	active[char] = any or nil
	for key, joint in pairs(js) do
		local base = originals[joint]
		local off = p[key]
		if off and not (key == "Root" and not isR15) then
			-- (R6 RootJoint uses a rotated frame, so whole-body moves are R15 only)
			joint.C0 = base * off
		else
			joint.C0 = base
		end
	end
end

function Emotes.Start()
	FrameLoop.Bind("Emotes", function()
		local t = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and (player == Players.LocalPlayer or (hrp.Position - camPos).Magnitude < 180) then
				animateCharacter(char, t)
			end
		end
	end)
end

return Emotes
