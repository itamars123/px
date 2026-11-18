-- GearService.lua
-- Gear tools bought with money: Speed Coil, Grapple Hook and Bear Traps (the
-- Bonk Bat tiers live in StealService). Every use is validated on the server.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage").Shared
local UpgradeData = require(Shared.UpgradeData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local S

local GearService = {}

local traps: { [Player]: { BasePart } } = {}
local grappleCd: { [Player]: number } = {}

local function handle(tool: Tool, color: Color3, size: Vector3, material: Enum.Material?)
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = size
	h.Color = color
	h.Material = material or Enum.Material.Neon
	h.CanCollide = false
	h.Massless = true
	h.Parent = tool
	return h
end

local function makeTool(name: string, tip: string): Tool
	local t = Instance.new("Tool")
	t.Name = name
	t.ToolTip = tip
	t.CanBeDropped = false
	return t
end

local function placeTrap(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local base = S.BaseService.Get(player)
	if not hrp or not base then
		return
	end
	if not S.BaseService.IsInside(base, hrp.Position) then
		S.NetService.Notify(player, "Place traps inside your own base!", "error")
		return
	end
	traps[player] = traps[player] or {}
	local list = traps[player]
	if #list >= 3 then
		local old = table.remove(list, 1)
		if old then
			old:Destroy()
		end
	end
	local trap = Instance.new("Part")
	trap.Name = "BearTrap"
	trap.Shape = Enum.PartType.Cylinder
	trap.Size = Vector3.new(0.4, 3.4, 3.4)
	trap.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trap.Color = Color3.fromRGB(110, 110, 120)
	trap.Material = Enum.Material.DiamondPlate
	trap.Anchored = true
	trap.CanCollide = false
	trap:SetAttribute("Owner", player.UserId)
	local teeth = Instance.new("Part")
	teeth.Shape = Enum.PartType.Cylinder
	teeth.Size = Vector3.new(0.5, 2, 2)
	teeth.CFrame = trap.CFrame
	teeth.Color = Color3.fromRGB(255, 70, 70)
	teeth.Material = Enum.Material.Neon
	teeth.Anchored = true
	teeth.CanCollide = false
	teeth.CanTouch = false
	teeth.Parent = trap
	local sprung = false
	trap.Touched:Connect(function(hit)
		if sprung then
			return
		end
		local victim = Players:GetPlayerFromCharacter(hit.Parent)
		if not victim or victim == player then
			return
		end
		sprung = true
		local dropped = S.CarryService.DropStolen(victim)
		S.PlayerService.Grace(victim, 3)
		Remotes.Effect:FireClient(victim, "Knockback", Vector3.new(0, 10, 0), 2.5)
		S.NetService.Notify(victim, "🪤 SNAP! You stepped in a bear trap!", "error")
		if player.Parent then
			S.NetService.Notify(player, ("🪤 %s got caught in your trap!%s"):format(victim.DisplayName, dropped > 0 and " Loot recovered!" or ""), "success")
		end
		teeth.Size = Vector3.new(0.5, 3.2, 3.2)
		Debris:AddItem(trap, 1)
	end)
	trap.Parent = workspace
	table.insert(list, trap)
	S.NetService.Notify(player, ("🪤 Trap placed (%d/3)"):format(#list), "success")
end

function GearService.GiveTools(player: Player)
	local data = S.DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not data or not backpack then
		return
	end
	local session = S.DataService.Session(player)
	if data.Gear.SpeedCoil and not backpack:FindFirstChild("Speed Coil") then
		local t = makeTool("Speed Coil", "Hold to run faster")
		handle(t, Color3.fromRGB(80, 200, 255), Vector3.new(1, 1, 1))
		t.Equipped:Connect(function()
			if session then
				session.CoilEquipped = true
				S.PlayerService.ApplyMovement(player)
			end
		end)
		t.Unequipped:Connect(function()
			if session then
				session.CoilEquipped = false
				S.PlayerService.ApplyMovement(player)
			end
		end)
		t.Parent = backpack
	end
	if data.Gear.Grapple and not backpack:FindFirstChild("Grapple Hook") then
		local t = makeTool("Grapple Hook", "Click to zip to a spot")
		handle(t, Color3.fromRGB(200, 200, 210), Vector3.new(0.6, 2, 0.6), Enum.Material.Metal)
		t:SetAttribute("Grapple", true) -- the client sends the aim point
		t.Parent = backpack
	end
	if data.Gear.Trap and not backpack:FindFirstChild("Bear Trap") then
		local t = makeTool("Bear Trap", "Click inside your base to place a trap")
		handle(t, Color3.fromRGB(110, 110, 120), Vector3.new(1.4, 0.4, 1.4), Enum.Material.DiamondPlate)
		local cd = 0
		t.Activated:Connect(function()
			if os.clock() - cd > 1 then
				cd = os.clock()
				placeTrap(player)
			end
		end)
		t.Parent = backpack
	end
end

function GearService.Buy(player: Player, key)
	local data = S.DataService.Get(player)
	if not data or typeof(key) ~= "string" then
		return false, "Bad request"
	end
	local item = UpgradeData.Gear[key]
	if not item then
		return false, "Unknown gear"
	end
	local cost
	if key == "Bat" then
		local lvl = data.Gear.Bat or 0
		cost = item.Costs[lvl + 1]
		if not cost then
			return false, "Your bat is maxed!"
		end
	else
		if data.Gear[key] then
			return false, "You already own this"
		end
		cost = item.Cost
	end
	if data.Money < cost then
		return false, ("Need %s more"):format(Util.Money(cost - data.Money))
	end
	data.Money -= cost
	if key == "Bat" then
		data.Gear.Bat = (data.Gear.Bat or 0) + 1
		S.StealService.RefreshHammer(player)
	else
		data.Gear[key] = true
		GearService.GiveTools(player)
	end
	Remotes.Effect:FireClient(player, "Purchase")
	S.StateService.MarkFull(player)
	return true, ("Got %s!"):format(key == "Bat" and UpgradeData.BatStats(data.Gear.Bat).Name or item.Name)
end

function GearService.Grapple(player: Player, target)
	local data = S.DataService.Get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not data or not data.Gear.Grapple or not hrp or typeof(target) ~= "Vector3" then
		return false
	end
	local tool = char:FindFirstChild("Grapple Hook")
	if not tool then
		return false
	end
	if grappleCd[player] and os.clock() - grappleCd[player] < 4 then
		return false
	end
	if (target - hrp.Position).Magnitude > 90 then
		return false, "Too far!"
	end
	grappleCd[player] = os.clock()
	S.PlayerService.Grace(player, 3)
	Remotes.Effect:FireClient(player, "Grapple", target)
	return true
end

function GearService.Init(services)
	S = services
end

function GearService.Start()
	S.NetService.Handle("BuyGear", { { Type = "string", MaxLen = 24 } }, GearService.Buy)
	S.NetService.Handle("Grapple", { "Vector3" }, GearService.Grapple)
	Players.PlayerRemoving:Connect(function(p)
		for _, t in ipairs(traps[p] or {}) do
			t:Destroy()
		end
		traps[p] = nil
		grappleCd[p] = nil
	end)
end

return GearService
