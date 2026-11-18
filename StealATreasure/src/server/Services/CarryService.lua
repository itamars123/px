-- CarryService.lua
-- Carrying treasures above your head: attaching models, the carry pose (arms
-- raised), movement penalty, delivering to your own base and dropping/returning
-- on death, leave or getting bonked.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local TreasureModels = require(Shared.TreasureModels)
local UpgradeData = require(Shared.UpgradeData)

local S

local CarryService = {}

local CARRY_SCALE = 0.75

local function getCarrying(player: Player)
	local session = S.DataService.Session(player)
	return session and session.Carrying or {}
end

function CarryService.Count(player: Player): number
	return #getCarrying(player)
end

function CarryService.Capacity(player: Player): number
	local data = S.DataService.Get(player)
	return data and UpgradeData.CarryCapacity(data) or 1
end

function CarryService.CanCarry(player: Player): boolean
	return CarryService.Count(player) < CarryService.Capacity(player)
end

function CarryService.IsCarryingStolen(player: Player): boolean
	for _, item in ipairs(getCarrying(player)) do
		if item.Source == "Steal" then
			return true
		end
	end
	return false
end

-- Carry pose: the server only publishes how many treasures you hold; every
-- client animates the arms-overhead carry pose procedurally (Emotes controller).
local function setPose(character: Model?, count: number)
	if character then
		character:SetAttribute("Carrying", count)
	end
end

local function restack(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local list = getCarrying(player)
	if not hrp then
		return
	end
	for i, item in ipairs(list) do
		local model = item.Model
		if model and model.Parent then
			local root = model.PrimaryPart
			local weld = root:FindFirstChild("CarryWeld")
			if weld then
				weld:Destroy()
			end
			root.CFrame = hrp.CFrame * CFrame.new(0, 3.4 + (i - 1) * 2.8, 0)
			local w = Instance.new("WeldConstraint")
			w.Name = "CarryWeld"
			w.Part0 = hrp
			w.Part1 = root
			w.Parent = root
		end
	end
	setPose(char, #list)
	S.PlayerService.ApplyMovement(player)
end

function CarryService.Add(player: Player, item)
	local def = TreasureData.Get(item.Id)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not def or not hrp then
		return false
	end
	local model = TreasureModels.Build(def, { Scale = CARRY_SCALE, CFrame = hrp.CFrame, Anchored = false })
	model.Name = "Carried_" .. def.Id
	model:SetAttribute("Carried", true)
	model.Parent = char
	item.Model = model
	item.Start = os.clock()
	table.insert(getCarrying(player), item)
	restack(player)
	S.StateService.PushStats(player)
	return true
end

function CarryService.Remove(player: Player, item)
	local list = getCarrying(player)
	local idx = table.find(list, item)
	if idx then
		table.remove(list, idx)
	end
	if item.Model then
		item.Model:Destroy()
		item.Model = nil
	end
	if player.Parent then
		restack(player)
		S.StateService.PushStats(player)
	end
end

-- Returns stolen items to their owners. Used when bonked.
function CarryService.DropStolen(player: Player): number
	local dropped = 0
	local list = table.clone(getCarrying(player))
	for _, item in ipairs(list) do
		if item.Source == "Steal" then
			CarryService.Remove(player, item)
			S.StealService.Return(item, "bonked")
			dropped += 1
		end
	end
	return dropped
end

-- Death / leaving: stolen go home, world treasures drop on the ground,
-- purchased ones go to storage so nobody loses money.
function CarryService.DropAll(player: Player, position: Vector3?)
	local list = table.clone(getCarrying(player))
	for _, item in ipairs(list) do
		CarryService.Remove(player, item)
		if item.Source == "Steal" then
			S.StealService.Return(item, "dropped")
		elseif item.Source == "Market" then
			S.TreasureService.Give(player, item.Id, { Silent = true, NoAutoPlace = true })
		else
			if position then
				S.TreasureService.DropToWorld(item.Id, position, item.Source)
			end
		end
	end
end

local function deposit(player: Player)
	local list = table.clone(getCarrying(player))
	for _, item in ipairs(list) do
		CarryService.Remove(player, item)
		if item.Source == "Steal" then
			S.StealService.Complete(player, item)
		else
			S.TreasureService.Give(player, item.Id, { Source = item.Source })
		end
	end
end

function CarryService.Init(services)
	S = services
end

function CarryService.Start()
	-- Delivery + timeout loop
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, player in ipairs(Players:GetPlayers()) do
				local session = S.DataService.Session(player)
				if session and #session.Carrying > 0 then
					local char = player.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local base = S.BaseService.Get(player)
					if hrp and base and S.BaseService.IsInside(base, hrp.Position) then
						deposit(player)
					else
						-- stolen treasure that takes too long goes back home
						for _, item in ipairs(table.clone(session.Carrying)) do
							if item.Source == "Steal" and os.clock() - item.Start > Config.Steal.CarryTimeout then
								CarryService.Remove(player, item)
								S.StealService.Return(item, "timeout")
								S.NetService.Notify(player, "You took too long! The treasure teleported home.", "warn")
							end
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		CarryService.DropAll(player, hrp and hrp.Position or nil)
	end)
end

-- Called by PlayerService when a character dies.
function CarryService.OnDied(player: Player, position: Vector3?)
	CarryService.DropAll(player, position)
end

return CarryService
