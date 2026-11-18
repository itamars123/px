-- PetFollower.lua
-- Renders and animates every player's equipped pets locally.
-- Walkers trot with swinging legs and hop when their owner jumps; flyers bob
-- in the air flapping their wings; idle pets breathe, wag tails and look at
-- their owner. Parts are moved with workspace:BulkMoveTo (no physics).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage").Shared
local PetData = require(Shared.PetData)
local PetModels = require(Shared.PetModels)

local PetFollower = {}
PetFollower.LowGfx = false

local folder: Folder
local owners: { [Player]: { any } } = {}

local SLOTS = {
	Vector3.new(-4, 0, 4),
	Vector3.new(4, 0, 4),
	Vector3.new(0, 0, 7),
	Vector3.new(-7, 0, 7.5),
	Vector3.new(7, 0, 7.5),
	Vector3.new(0, 0, 10.5),
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function clear(player: Player)
	for _, pet in ipairs(owners[player] or {}) do
		pet.Model:Destroy()
	end
	owners[player] = nil
end

local function build(player: Player)
	clear(player)
	local raw = player:GetAttribute("Pets")
	if typeof(raw) ~= "string" or raw == "" then
		return
	end
	local ok, ids = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or typeof(ids) ~= "table" then
		return
	end
	local list = {}
	for i, id in ipairs(ids) do
		local def = PetData.Get(id)
		if def and i <= #SLOTS then
			local model, parts = PetModels.Build(def, 0.8)
			model.Parent = folder
			local partList, offsets = {}, {}
			for _, e in ipairs(parts) do
				table.insert(partList, e.Part)
				table.insert(offsets, e)
			end
			table.insert(list, {
				Def = def,
				Model = model,
				Parts = partList,
				Entries = offsets,
				Slot = SLOTS[i],
				Pos = nil,
				Yaw = 0,
				GroundY = 0,
				NextRay = 0,
				Phase = math.random() * 10,
				JumpStart = -10,
			})
		end
	end
	owners[player] = list
end

local function hook(player: Player)
	player:GetAttributeChangedSignal("Pets"):Connect(function()
		build(player)
	end)
	build(player)
end

local function animatePet(pet, hrp: BasePart, dt: number, t: number, ownerJumping: boolean)
	local sp = PetData.Species[pet.Def.Species] or {}
	local target = (hrp.CFrame * CFrame.new(pet.Slot)).Position
	if not pet.Pos or (pet.Pos - target).Magnitude > 70 then
		pet.Pos = target
	end
	local clock = os.clock()
	if clock > pet.NextRay then
		pet.NextRay = clock + 0.2
		local result = workspace:Raycast(target + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), rayParams)
		pet.GroundY = result and result.Position.Y or (hrp.Position.Y - 3)
	end
	local flat = Vector3.new(target.X, 0, target.Z)
	local cur = Vector3.new(pet.Pos.X, 0, pet.Pos.Z)
	local newFlat = cur:Lerp(flat, 1 - math.exp(-dt * 6))
	local vel = (newFlat - cur) / math.max(dt, 1e-3)
	local speed = vel.Magnitude
	local moving = speed > 1.5
	if moving then
		local dir = vel.Unit
		pet.Yaw = math.atan2(-dir.X, -dir.Z)
	else
		local look = hrp.CFrame.LookVector
		local desired = math.atan2(-look.X, -look.Z)
		pet.Yaw = pet.Yaw + (desired - pet.Yaw) * math.min(1, dt * 3)
	end
	local y
	if pet.Def.Flies then
		y = hrp.Position.Y + 1.5 + math.sin(t * 2.5 + pet.Phase) * 0.6
	else
		y = pet.GroundY
		if ownerJumping and clock - pet.JumpStart > 0.6 then
			pet.JumpStart = clock
		end
		local j = clock - pet.JumpStart
		if j < 0.5 then
			y += math.sin(j / 0.5 * math.pi) * 3
		elseif moving then
			local hop = sp.Hops and 1.2 or 0.45
			y += math.abs(math.sin(t * (sp.Hops and 9 or 14) + pet.Phase)) * hop * math.min(1, speed / 12)
		else
			y += math.sin(t * 2 + pet.Phase) * 0.05
		end
	end
	pet.Pos = Vector3.new(newFlat.X, y, newFlat.Z)
	local rootCF = CFrame.new(pet.Pos) * CFrame.Angles(0, pet.Yaw + math.pi, 0)
	if moving and not pet.Def.Flies then
		rootCF *= CFrame.Angles(0, 0, math.sin(t * 14 + pet.Phase) * 0.08)
	end
	if PetFollower.LowGfx then
		pet.Model:PivotTo(rootCF)
		return
	end
	local cframes = table.create(#pet.Entries)
	local swing = moving and math.sin(t * 14 + pet.Phase) * 0.7 or 0
	local flap = math.sin(t * (pet.Def.Flies and 16 or 6) + pet.Phase) * (pet.Def.Flies and 0.7 or 0.15)
	local wag = math.sin(t * (moving and 10 or 5) + pet.Phase) * 0.5
	for i, e in ipairs(pet.Entries) do
		local role = e.Role
		local off = e.Offset
		if role == "LegA" then
			off = off * CFrame.Angles(swing, 0, 0)
		elseif role == "LegB" then
			off = off * CFrame.Angles(-swing, 0, 0)
		elseif role == "WingL" then
			off = CFrame.new(-0.7, 1.5, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.7, 1.5, 0):Inverse() * off
		elseif role == "WingR" then
			off = CFrame.new(0.7, 1.5, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.7, 1.5, 0):Inverse() * off
		elseif role == "Tail" then
			off = off * CFrame.Angles(0, wag, 0)
		elseif role == "Ear" then
			off = off * CFrame.Angles(0, 0, math.sin(t * 3 + pet.Phase) * 0.08)
		elseif role == "Head" then
			off = CFrame.Angles(math.sin(t * 2 + pet.Phase) * 0.05, 0, 0) * off
		elseif role == "Tentacle" then
			off = off * CFrame.Angles(math.sin(t * 6 + i) * 0.3, 0, 0)
		end
		cframes[i] = rootCF * off
	end
	workspace:BulkMoveTo(pet.Parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function PetFollower.Start()
	folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = workspace
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local exclude = { folder }
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				table.insert(exclude, p.Character)
			end
		end
		rayParams.FilterDescendantsInstances = exclude
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		for player, list in pairs(owners) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum then
				local near = (hrp.Position - camPos).Magnitude < 220
				local jumping = hum.FloorMaterial == Enum.Material.Air and hrp.AssemblyLinearVelocity.Y > 4
				for _, pet in ipairs(list) do
					pet.Model.Parent = near and folder or nil
					if near then
						animatePet(pet, hrp, dt, t, jumping)
					end
				end
			end
		end
	end)
end

return PetFollower
