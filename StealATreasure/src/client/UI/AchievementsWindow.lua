-- AchievementsWindow.lua
-- Achievement list with progress bars and gem rewards.

local Lib = require(script.Parent.Lib)
local State = require(script.Parent.Parent.Controllers.State)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AchievementData = require(Shared.AchievementData)
local Util = require(Shared.Util)

local T = Lib.Theme

local Achievements = {}

local list: ScrollingFrame
local header: TextLabel
local isOpen = false

local function refresh()
	if not isOpen or not State.Full then
		return
	end
	Lib.clear(list)
	local done = {}
	for _, id in ipairs(State.Full.Achievements or {}) do
		done[id] = true
	end
	local progress = State.Full.AchievementProgress or {}
	local count = 0
	for _, a in ipairs(AchievementData.List) do
		local unlocked = done[a.Id] == true
		if unlocked then
			count += 1
		end
		local row = Lib.panel({ Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = unlocked and T.Green:Lerp(T.Panel, 0.6) or T.Panel, LayoutOrder = (unlocked and 1000 or 0) + a.Order, Parent = list })
		Lib.label({ Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(6, 4), Text = a.Icon, MaxText = 34, Parent = row })
		local n = Lib.label({ Size = UDim2.new(0.55, -70, 0, 26), Position = UDim2.fromOffset(66, 4), Text = a.Name, Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = row })
		Lib.textStroke(1.5).Parent = n
		local value = progress[a.Stat] or 0
		local goalText = a.Goal >= 1000 and Util.Abbreviate(a.Goal) or tostring(a.Goal)
		local valueText = value >= 1000 and Util.Abbreviate(value) or tostring(math.floor(value))
		local _, set = Lib.bar({ Size = UDim2.new(0.55, -70, 0, 20), Position = UDim2.fromOffset(66, 34), Color = unlocked and T.Green or T.Blue, Parent = row })
		set(math.min(1, value / a.Goal), unlocked and "COMPLETE ✅" or (valueText .. " / " .. goalText))
		local r = Lib.label({ Size = UDim2.new(0.45, -16, 1, -12), Position = UDim2.new(0.55, 0, 0, 6), Text = ("+%d 💎"):format(a.Gems), Font = T.Title, TextColor3 = T.Blue:Lerp(Color3.new(1, 1, 1), 0.3), TextXAlignment = Enum.TextXAlignment.Right, MaxText = 22, Parent = row })
		Lib.textStroke(1.5).Parent = r
	end
	header.Text = ("🏆 %d / %d achievements unlocked"):format(count, #AchievementData.List)
end

function Achievements.Build(content: Frame)
	header = Lib.label({ Size = UDim2.new(1, 0, 0, 30), Text = "", Font = T.Title, TextColor3 = T.Accent, MaxText = 22, Parent = content })
	Lib.textStroke(1.5).Parent = header
	list = Lib.scroll({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), Parent = content })
	Lib.list(Enum.FillDirection.Vertical, 6).Parent = list
	Lib.padding(4).Parent = list
	State.FullChanged.Event:Connect(refresh)
end

function Achievements.OnOpen()
	isOpen = true
	refresh()
end

function Achievements.OnClose()
	isOpen = false
end

return Achievements
