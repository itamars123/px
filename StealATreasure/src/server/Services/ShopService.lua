-- ShopService.lua
-- Upgrade shop + special abilities (purchase and server-validated use).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UpgradeData = require(Shared.UpgradeData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local S

local ShopService = {}

local function now()
	return workspace:GetServerTimeNow()
end

function ShopService.BuyUpgrade(player: Player, key: string)
	local data = S.DataService.Get(player)
	if not data or typeof(key) ~= "string" then
		return false, "Bad request"
	end
	local up = UpgradeData.Upgrades[key]
	if not up then
		return false, "Unknown upgrade"
	end
	local level = data.Upgrades[key] or 0
	if level >= up.MaxLevel then
		return false, "Already maxed!"
	end
	local cost = up.Cost(level)
	if data.Money < cost then
		return false, ("Need %s more"):format(Util.Money(cost - data.Money))
	end
	data.Money -= cost
	data.Upgrades[key] = level + 1

	if key == "Speed" then
		S.PlayerService.ApplyMovement(player)
	elseif key == "Base" then
		S.BaseService.Refresh(player)
	elseif key == "Protection" then
		S.BaseService.RefreshPrompts(player)
	end
	Remotes.Effect:FireClient(player, "Purchase")
	S.StateService.MarkFull(player)
	return true, ("%s upgraded to level %d!"):format(up.Name, level + 1)
end

function ShopService.BuyAbility(player: Player, key: string)
	local data = S.DataService.Get(player)
	if not data or typeof(key) ~= "string" then
		return false, "Bad request"
	end
	local ab = UpgradeData.Abilities[key]
	if not ab then
		return false, "Unknown ability"
	end
	if data.Abilities[key] then
		return false, "You already own this"
	end
	if data.Money < ab.Cost then
		return false, ("Need %s more"):format(Util.Money(ab.Cost - data.Money))
	end
	data.Money -= ab.Cost
	data.Abilities[key] = true
	Remotes.Effect:FireClient(player, "Purchase")
	S.StateService.MarkFull(player)
	local hint = ab.Key and (" Press " .. ab.Key .. " or tap its button to use it.") or ""
	return true, ("Unlocked %s!%s"):format(ab.Name, hint)
end

local function setCloak(player: Player, on: boolean)
	local session = S.DataService.Session(player)
	local char = player.Character
	if not session or not char then
		return
	end
	session.Cloaked = on
	for _, d in ipairs(char:GetDescendants()) do
		local owner = d:FindFirstAncestorWhichIsA("Model")
		local isCarried = owner ~= nil and owner:GetAttribute("Carried") == true
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not isCarried then
			if on then
				if d:GetAttribute("CloakOrig") == nil then
					d:SetAttribute("CloakOrig", d.Transparency)
				end
				d.Transparency = 0.92
			else
				local orig = d:GetAttribute("CloakOrig")
				if orig ~= nil then
					d.Transparency = orig
					d:SetAttribute("CloakOrig", nil)
				end
			end
		elseif d:IsA("Decal") and d.Name == "face" then
			d.Transparency = on and 1 or 0
		end
	end
	S.PlayerService.UpdateOverhead(player)
end

function ShopService.UseAbility(player: Player, key: string)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session or typeof(key) ~= "string" then
		return false, "Bad request"
	end
	local ab = UpgradeData.Abilities[key]
	if not ab or not ab.Key then
		return false, "Not usable"
	end
	if not data.Abilities[key] then
		return false, ("Buy %s in the shop first!"):format(ab.Name)
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false, "You're not alive"
	end
	local t = now()
	local cd = session.AbilityCooldowns[key] or 0
	if cd > t then
		return false, ("%s ready in %ds"):format(ab.Name, math.ceil(cd - t))
	end
	session.AbilityCooldowns[key] = t + ab.Cooldown

	if key == "Dash" then
		Remotes.Effect:FireClient(player, "Dash")
	elseif key == "SuperJump" then
		session.SuperJump = true
		S.PlayerService.ApplyMovement(player)
		Remotes.Effect:FireClient(player, "SuperJump", ab.Duration)
		task.delay(ab.Duration, function()
			if session.SuperJump then
				session.SuperJump = false
				S.PlayerService.ApplyMovement(player)
			end
		end)
	elseif key == "Cloak" then
		setCloak(player, true)
		Remotes.Effect:FireClient(player, "Cloak", ab.Duration)
		task.delay(ab.Duration, function()
			if player.Parent and player.Character == char then
				setCloak(player, false)
			end
		end)
	end
	S.StateService.PushStats(player)
	return true
end

function ShopService.Init(services)
	S = services
end

function ShopService.Start()
	S.NetService.Handle("BuyUpgrade", ShopService.BuyUpgrade)
	S.NetService.Handle("BuyAbility", ShopService.BuyAbility)
	S.NetService.Handle("UseAbility", ShopService.UseAbility)
end

return ShopService
