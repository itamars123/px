-- Input.lua
-- Keyboard / gamepad bindings for abilities and menus. Touch players use the
-- on-screen HUD buttons, which call the same actions.

local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UpgradeData = require(Shared.UpgradeData)
local State = require(script.Parent.State)

local Input = {}

function Input.Init(windows, hud)
	-- Sprint: hold Shift (PC) or toggle with L3 (gamepad); mobile uses the HUD button
	ContextActionService:BindAction("Sprint", function(_, inputState, input)
		if input.KeyCode == Enum.KeyCode.ButtonL3 then
			if inputState == Enum.UserInputState.Begin then
				hud.SetSprint(not (game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:GetAttribute("Sprinting")))
			end
		elseif inputState == Enum.UserInputState.Begin then
			hud.SetSprint(true)
		elseif inputState == Enum.UserInputState.End then
			hud.SetSprint(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("Emotes", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			hud.ToggleEmotes()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.T, Enum.KeyCode.ButtonX)
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
		{ Enum.KeyCode.P, "Pets" },
		{ Enum.KeyCode.DPadUp, "Inventory" },
		{ Enum.KeyCode.DPadLeft, "Pets" },
		{ Enum.KeyCode.DPadRight, "Shop" },
		{ Enum.KeyCode.DPadDown, "Leaderboard" },
		{ Enum.KeyCode.ButtonSelect, "Settings" },
	}
	for i, mk in ipairs(menuKeys) do
		ContextActionService:BindAction("Menu_" .. i, function(_, inputState)
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
