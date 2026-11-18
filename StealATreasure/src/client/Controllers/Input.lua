-- Input.lua
-- Keyboard / gamepad bindings for abilities and menus. Touch players use the
-- on-screen HUD buttons, which call the same actions.

local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UpgradeData = require(Shared.UpgradeData)
local State = require(script.Parent.State)

local Input = {}

function Input.Init(windows)
	for key, ab in pairs(UpgradeData.Abilities) do
		if ab.Key then
			ContextActionService:BindAction("Ability_" .. key, function(_, inputState)
				if inputState == Enum.UserInputState.Begin then
					if State.Full and State.Full.Abilities[key] then
						State.Request("UseAbility", key)
					end
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.KeyCode[ab.Key])
		end
	end
	local menuKeys = {
		{ Enum.KeyCode.B, "Inventory" },
		{ Enum.KeyCode.N, "Index" },
		{ Enum.KeyCode.M, "Shop" },
		{ Enum.KeyCode.L, "LockBase" },
	}
	for _, mk in ipairs(menuKeys) do
		ContextActionService:BindAction("Menu_" .. mk[2], function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				if mk[2] == "LockBase" then
					State.Request("LockBase")
				else
					windows.Toggle(mk[2])
				end
			end
			return Enum.ContextActionResult.Pass
		end, false, mk[1])
	end
	ContextActionService:BindAction("CloseMenu", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and windows.Current then
			windows.Close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)
end

return Input
