-- RebirthWindow.lua
-- Rebirth progress, permanent bonuses, milestone rewards and title picker.

local Lib = require(script.Parent.Lib)
local State = require(script.Parent.Parent.Controllers.State)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local T = Lib.Theme
local new = Lib.new

local Rebirth = {}

local isOpen = false
local info: TextLabel
local setProgress
local rebirthButton: TextButton
local confirmUntil = 0
local rewardsList: Frame
local titlesList: Frame

local function refresh()
	if not isOpen or not State.Full then
		return
	end
	local full = State.Full
	local cost = full.RebirthCost
	local nextR = full.Rebirths + 1
	local bonus = math.floor(nextR * Config.Rebirth.IncomeBonusPerRebirth * 100)
	info.Text = ("You have rebirthed %d times.\nCurrent income multiplier: x%.2f\n\nRebirth %d gives: +%d%% total income, +%d walk speed and %s starting cash.\nYou keep: abilities, index, secrets, titles & exclusive treasures.\nYou lose: money, treasures and upgrades.")
		:format(full.Rebirths, full.Multiplier, nextR, bonus, Config.Rebirth.SpeedBonusPerRebirth, Util.Money(Config.StartingMoney + nextR * Config.Rebirth.StartingMoneyPerRebirth))
	setProgress(full.Money / cost, ("%s / %s"):format(Util.Money(full.Money), Util.Money(cost)))
	local req = full.RebirthReq
	if req then
		info.Text ..= ("\n\n📌 Also requires: %d × %s+ treasure%s"):format(req.Count, req.Rarity, req.Count > 1 and "s" or "")
	end
	local canAfford = full.Money >= cost
	if os.clock() < confirmUntil then
		rebirthButton.Text = "⚠️ TAP AGAIN TO CONFIRM"
		Lib.setButtonColor(rebirthButton, T.Orange)
	else
		rebirthButton.Text = canAfford and "🌀 REBIRTH NOW" or "🔒 NOT ENOUGH MONEY"
		Lib.setButtonColor(rebirthButton, canAfford and T.Pink or T.Panel2)
	end

	Lib.clear(rewardsList)
	local milestones = {}
	for n in pairs(Config.RebirthRewards) do
		table.insert(milestones, n)
	end
	table.sort(milestones)
	for i, n in ipairs(milestones) do
		local r = Config.RebirthRewards[n]
		local unlocked = full.Rebirths >= n
		local row = Lib.panel({ Size = UDim2.new(1, -6, 0, 44), BackgroundColor3 = unlocked and T.Green:Lerp(T.Panel, 0.5) or T.Panel2, LayoutOrder = i, Parent = rewardsList })
		local l = Lib.label({
			Size = UDim2.new(1, -16, 1, -8),
			Position = UDim2.fromOffset(8, 4),
			Text = ("%s Rebirth %d: %s + \"%s\" title + trail"):format(unlocked and "✅" or "🔒", n, r.Treasure, r.Title),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxText = 16,
			Parent = row,
		})
		Lib.textStroke(1).Parent = l
	end

	Lib.clear(titlesList)
	local options = { "" }
	for _, t in ipairs(full.Titles) do
		table.insert(options, t)
	end
	for i, title in ipairs(options) do
		local active = full.Title == title
		Lib.button({
			Text = title == "" and "No title" or title,
			Color = active and T.Accent or T.Panel2,
			Size = UDim2.fromOffset(120, 32),
			LayoutOrder = i,
			MaxText = 16,
			Parent = titlesList,
			OnClick = function()
				State.Request("SetTitle", title)
			end,
		})
	end
end

function Rebirth.Build(content: Frame)
	local left = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.55, -8, 1, 0), Parent = content })
	local big = Lib.label({ Size = UDim2.new(1, 0, 0, 44), Text = "🌀 REBIRTH", Font = T.Title, TextColor3 = T.Pink, MaxText = 40, Parent = left })
	Lib.textStroke(2.5).Parent = big
	info = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 170),
		Position = UDim2.fromOffset(0, 48),
		Font = T.Body,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.SubText,
		Parent = left,
	})
	local _, setter = Lib.bar({ Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, 224), Color = T.Pink, Parent = left })
	setProgress = setter
	rebirthButton = Lib.button({
		Text = "REBIRTH",
		Color = T.Pink,
		Size = UDim2.new(1, 0, 0, 58),
		Position = UDim2.fromOffset(0, 266),
		MaxText = 28,
		Parent = left,
		OnClick = function()
			if os.clock() < confirmUntil then
				confirmUntil = 0
				State.Request("Rebirth")
			elseif State.Full and State.Full.Money >= State.Full.RebirthCost then
				confirmUntil = os.clock() + 4
				refresh()
				task.delay(4.1, refresh)
			else
				State.Request("Rebirth")
			end
		end,
	})
	local right = Lib.panel({ Position = UDim2.new(0.55, 0, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), Parent = content })
	Lib.padding(8).Parent = right
	local h = Lib.label({ Size = UDim2.new(1, 0, 0, 26), Text = "🎁 Milestone Rewards", Font = T.Title, TextColor3 = T.Accent, MaxText = 20, Parent = right })
	Lib.textStroke(1.5).Parent = h
	rewardsList = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 200), Parent = right }, { Lib.list(Enum.FillDirection.Vertical, 6) })
	local h2 = Lib.label({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 236), Text = "🏷️ Your Titles", Font = T.Title, TextColor3 = T.Accent, MaxText = 20, Parent = right })
	Lib.textStroke(1.5).Parent = h2
	titlesList = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 266), Size = UDim2.new(1, 0, 1, -266), Parent = right }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(120, 32), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	State.FullChanged.Event:Connect(refresh)
	State.StatsChanged.Event:Connect(refresh)
end

function Rebirth.OnOpen()
	isOpen = true
	refresh()
end

function Rebirth.OnClose()
	isOpen = false
end

return Rebirth
