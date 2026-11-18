-- ShopWindow.lua
-- Upgrades (speed, carry capacity, base expansion, protection, income) and
-- special abilities.

local Lib = require(script.Parent.Lib)
local State = require(script.Parent.Parent.Controllers.State)
local Shared = game:GetService("ReplicatedStorage").Shared
local UpgradeData = require(Shared.UpgradeData)
local Util = require(Shared.Util)

local T = Lib.Theme
local new = Lib.new

local Shop = {}

local rows = {}
local isOpen = false

local function makeRow(parent: Instance, order: number, icon: string, title: string, desc: string, color: Color3)
	local row = Lib.panel({ Size = UDim2.new(1, -8, 0, 84), BackgroundColor3 = T.Panel, LayoutOrder = order, Parent = parent })
	Lib.stroke(color, 2).Parent = row
	local iconBox = Lib.panel({ Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = color, Parent = row })
	Lib.gradient(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 160)).Parent = iconBox
	Lib.label({ Size = UDim2.fromScale(1, 1), Text = icon, MaxText = 38, Parent = iconBox })
	local t = Lib.label({ Size = UDim2.new(1, -250, 0, 28), Position = UDim2.fromOffset(86, 8), Text = title, Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, Parent = row })
	Lib.textStroke(1.5).Parent = t
	local d = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -250, 0, 40),
		Position = UDim2.fromOffset(86, 36),
		Font = T.Body,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.SubText,
		Text = desc,
		Parent = row,
	})
	local btn = Lib.button({ Text = "", Color = T.Green, Size = UDim2.fromOffset(150, 50), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = row })
	return { Row = row, Title = t, Desc = d, Button = btn }
end

local function refresh()
	if not isOpen or not State.Full then
		return
	end
	local full = State.Full
	for rowKey, r in pairs(rows) do
		local key = r.Key or rowKey
		if r.Kind == "Upgrade" then
			local up = UpgradeData.Upgrades[key]
			local level = full.Upgrades[key] or 0
			r.UI.Title.Text = ("%s  (Lv %d/%d)"):format(up.Name, level, up.MaxLevel)
			if level >= up.MaxLevel then
				r.UI.Button.Text = "MAXED"
				Lib.setButtonColor(r.UI.Button, T.Panel2)
			else
				local cost = up.Cost(level)
				r.UI.Button.Text = Util.Money(cost)
				Lib.setButtonColor(r.UI.Button, full.Money >= cost and T.Green or T.Red)
			end
		elseif r.Kind == "Gear" then
			local item = UpgradeData.Gear[key]
			local gear = full.Gear or {}
			if key == "Bat" then
				local lvl = gear.Bat or 0
				local cost = item.Costs[lvl + 1]
				r.UI.Title.Text = ("%s  (%s)"):format(item.Name, UpgradeData.BatStats(lvl).Name)
				if cost then
					r.UI.Button.Text = Util.Money(cost)
					Lib.setButtonColor(r.UI.Button, full.Money >= cost and T.Green or T.Red)
				else
					r.UI.Button.Text = "MAXED"
					Lib.setButtonColor(r.UI.Button, T.Panel2)
				end
			elseif gear[key] then
				r.UI.Button.Text = "OWNED"
				Lib.setButtonColor(r.UI.Button, T.Panel2)
			else
				r.UI.Button.Text = Util.Money(item.Cost)
				Lib.setButtonColor(r.UI.Button, full.Money >= item.Cost and T.Green or T.Red)
			end
		else
			local ab = UpgradeData.Abilities[key]
			if full.Abilities[key] then
				r.UI.Button.Text = ab.Key and ("OWNED [" .. ab.Key .. "]") or "OWNED"
				Lib.setButtonColor(r.UI.Button, T.Panel2)
			else
				r.UI.Button.Text = Util.Money(ab.Cost)
				Lib.setButtonColor(r.UI.Button, full.Money >= ab.Cost and T.Green or T.Red)
			end
		end
	end
end

function Shop.Build(content: Frame)
	local scroll = Lib.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	Lib.list(Enum.FillDirection.Vertical, 8).Parent = scroll
	Lib.padding(4).Parent = scroll
	local header1 = Lib.label({ Size = UDim2.new(1, 0, 0, 30), Text = "⬆️ UPGRADES", Font = T.Title, TextColor3 = T.Accent, LayoutOrder = 0, MaxText = 24, Parent = scroll })
	Lib.textStroke(2).Parent = header1
	local colors = { T.Blue, T.Orange, T.Green, T.Purple, T.Accent }
	for i, key in ipairs(UpgradeData.SortedKeys(UpgradeData.Upgrades)) do
		local up = UpgradeData.Upgrades[key]
		local ui = makeRow(scroll, i, up.Icon, up.Name, up.Description, colors[(i - 1) % #colors + 1])
		ui.Button.Activated:Connect(function()
			State.Request("BuyUpgrade", key)
		end)
		rows[key] = { Kind = "Upgrade", UI = ui }
	end
	local header2 = Lib.label({ Size = UDim2.new(1, 0, 0, 30), Text = "⚡ SPECIAL ABILITIES", Font = T.Title, TextColor3 = T.Pink, LayoutOrder = 50, MaxText = 24, Parent = scroll })
	Lib.textStroke(2).Parent = header2
	for i, key in ipairs(UpgradeData.SortedKeys(UpgradeData.Abilities)) do
		local ab = UpgradeData.Abilities[key]
		local desc = ab.Description .. (ab.Cooldown > 0 and ("  (cooldown %ds)"):format(ab.Cooldown) or "")
		local ui = makeRow(scroll, 50 + i, ab.Icon, ab.Name, desc, T.Pink)
		ui.Button.Activated:Connect(function()
			if not (State.Full and State.Full.Abilities[key]) then
				State.Request("BuyAbility", key)
			end
		end)
		rows[key] = { Kind = "Ability", UI = ui }
	end
	local header3 = Lib.label({ Size = UDim2.new(1, 0, 0, 30), Text = "🧰 GEAR", Font = T.Title, TextColor3 = T.Orange, LayoutOrder = 100, MaxText = 24, Parent = scroll })
	Lib.textStroke(2).Parent = header3
	for i, key in ipairs(UpgradeData.SortedKeys(UpgradeData.Gear)) do
		local item = UpgradeData.Gear[key]
		local ui = makeRow(scroll, 100 + i, item.Icon, item.Name, item.Description, T.Orange)
		ui.Button.Activated:Connect(function()
			State.Request("BuyGear", key)
		end)
		rows["Gear_" .. key] = { Kind = "Gear", Key = key, UI = ui }
	end
	State.FullChanged.Event:Connect(refresh)
	State.StatsChanged.Event:Connect(refresh)
end

function Shop.OnOpen()
	isOpen = true
	refresh()
end

function Shop.OnClose()
	isOpen = false
end

return Shop
