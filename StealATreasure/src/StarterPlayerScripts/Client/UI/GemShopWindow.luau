-- GemShopWindow.lua
-- Gem shop (boosts, Auto Collector, pet slots), active boost timers and base
-- personalisation (12 colours).

local Lib = require(script.Parent.Lib)
local State = require(script.Parent.Parent.Controllers.State)
local Shared = game:GetService("ReplicatedStorage").Shared
local UpgradeData = require(Shared.UpgradeData)
local Util = require(Shared.Util)
local Config = require(Shared.Config)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local T = Lib.Theme
local new = Lib.new

local GemShop = {}

local isOpen = false
local rows = {}
local boostLabel: TextLabel
local gemsLabel: TextLabel
local swatches = {}
local passButtons = {}

local function refresh()
	if not isOpen or not State.Full then
		return
	end
	local full = State.Full
	gemsLabel.Text = ("💎 %s gems"):format(Util.Commas(full.Gems or 0))
	for key, b in pairs(rows) do
		local item = UpgradeData.GemShop[key]
		local cost = item.Cost
		if key == "PetSlot" then
			cost = item.Cost * ((full.ExtraPetSlots or 0) + 1)
		end
		if key == "AutoCollect" and full.AutoCollect then
			b.Text = "OWNED"
			Lib.setButtonColor(b, T.Panel2)
		elseif key == "PetSlot" and (full.PetSlots or 3) >= 6 then
			b.Text = "MAXED"
			Lib.setButtonColor(b, T.Panel2)
		else
			b.Text = "💎 " .. cost
			Lib.setButtonColor(b, (full.Gems or 0) >= cost and T.Blue or T.Red)
		end
	end
	local active = {}
	local nowT = (State.Stats and State.Stats.ServerTime) or os.time()
	for name, expiry in pairs(full.Boosts or {}) do
		if expiry > nowT then
			table.insert(active, ("%s %s"):format(name, Util.Time(expiry - nowT)))
		end
	end
	boostLabel.Text = #active > 0 and ("⏳ Active boosts: " .. table.concat(active, "   ")) or "No active boosts"
	for key, b in pairs(passButtons) do
		local owned = full.Passes and full.Passes[key]
		b.Text = owned and "OWNED" or ("R$ " .. Config.Monetization.GamePasses[key].Robux)
		Lib.setButtonColor(b, owned and T.Panel2 or T.Green)
	end
	for i, s in ipairs(swatches) do
		local stroke = s:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = (full.BaseColor == i) and T.Accent or Color3.new(0, 0, 0)
			stroke.Thickness = (full.BaseColor == i) and 4 or 2
		end
	end
end

function GemShop.Build(content: Frame)
	local scroll = Lib.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	Lib.list(Enum.FillDirection.Vertical, 8).Parent = scroll
	Lib.padding(4).Parent = scroll
	gemsLabel = Lib.label({ Size = UDim2.new(1, 0, 0, 32), Text = "", Font = T.Title, TextColor3 = T.Blue:Lerp(Color3.new(1, 1, 1), 0.3), LayoutOrder = 0, MaxText = 26, Parent = scroll })
	Lib.textStroke(2).Parent = gemsLabel
	boostLabel = Lib.label({ Size = UDim2.new(1, 0, 0, 22), Text = "", TextColor3 = T.Green, LayoutOrder = 1, MaxText = 15, Parent = scroll })
	for i, key in ipairs(UpgradeData.SortedKeys(UpgradeData.GemShop)) do
		local item = UpgradeData.GemShop[key]
		local row = Lib.panel({ Size = UDim2.new(1, -8, 0, 72), LayoutOrder = 10 + i, Parent = scroll })
		Lib.stroke(T.Blue, 2).Parent = row
		Lib.label({ Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(8, 8), Text = item.Icon, MaxText = 36, Parent = row })
		local t = Lib.label({ Size = UDim2.new(1, -240, 0, 26), Position = UDim2.fromOffset(72, 8), Text = item.Name, Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = row })
		Lib.textStroke(1.5).Parent = t
		Lib.label({ Size = UDim2.new(1, -240, 0, 30), Position = UDim2.fromOffset(72, 36), Text = item.Description, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14, Parent = row })
		rows[key] = Lib.button({ Text = "", Color = T.Blue, Size = UDim2.fromOffset(140, 48), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = row, OnClick = function()
			State.Request("BuyGemItem", key)
		end })
	end
	-- Robux shop: only items with a real ID in Config.Monetization are shown
	local robuxItems = {}
	for key, pass in pairs(Config.Monetization.GamePasses) do
		if pass.Id ~= 0 then
			table.insert(robuxItems, { Key = key, Item = pass, Pass = true })
		end
	end
	for key, product in pairs(Config.Monetization.Products) do
		if product.Id ~= 0 then
			table.insert(robuxItems, { Key = key, Item = product, Pass = false })
		end
	end
	if #robuxItems > 0 then
		local rh = Lib.label({ Size = UDim2.new(1, 0, 0, 30), Text = "🟢 ROBUX SHOP", Font = T.Title, TextColor3 = T.Green, LayoutOrder = 30, MaxText = 22, Parent = scroll })
		Lib.textStroke(2).Parent = rh
		table.sort(robuxItems, function(a, b)
			return a.Item.Robux < b.Item.Robux
		end)
		for i, e in ipairs(robuxItems) do
			local row = Lib.panel({ Size = UDim2.new(1, -8, 0, 64), LayoutOrder = 30 + i, Parent = scroll })
			Lib.stroke(T.Green, 2).Parent = row
			Lib.label({ Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(8, 6), Text = e.Item.Icon, MaxText = 32, Parent = row })
			local t = Lib.label({ Size = UDim2.new(1, -230, 0, 26), Position = UDim2.fromOffset(68, 6), Text = e.Item.Name, Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = row })
			Lib.textStroke(1.5).Parent = t
			Lib.label({ Size = UDim2.new(1, -230, 0, 24), Position = UDim2.fromOffset(68, 34), Text = e.Item.Description or (e.Pass and "Game Pass" or "Developer Product"), TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14, Parent = row })
			local b = Lib.button({ Text = "R$ " .. e.Item.Robux, Color = T.Green, Size = UDim2.fromOffset(130, 44), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = row, OnClick = function()
				if e.Pass then
					if not (State.Full and State.Full.Passes and State.Full.Passes[e.Key]) then
						MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, e.Item.Id)
					end
				else
					MarketplaceService:PromptProductPurchase(Players.LocalPlayer, e.Item.Id)
				end
			end })
			if e.Pass then
				passButtons[e.Key] = b
			end
		end
	end
	local h = Lib.label({ Size = UDim2.new(1, 0, 0, 30), Text = "🎨 PERSONALIZE YOUR BASE (free)", Font = T.Title, TextColor3 = T.Pink, LayoutOrder = 50, MaxText = 22, Parent = scroll })
	Lib.textStroke(2).Parent = h
	local palette = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 110), LayoutOrder = 51, Parent = scroll }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(48, 48), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	for i, color in ipairs(UpgradeData.BaseColors) do
		local sw = new("TextButton", { BackgroundColor3 = color, Text = "", LayoutOrder = i, Parent = palette }, { Lib.corner(24), Lib.stroke(Color3.new(0, 0, 0), 2) })
		sw.Activated:Connect(function()
			State.Request("SetBaseColor", i)
		end)
		swatches[i] = sw
	end
	Lib.label({ Size = UDim2.new(1, 0, 0, 20), Text = "Wall materials, cameras, traps and a second floor are in 🛒 Upgrades.", TextColor3 = T.SubText, LayoutOrder = 52, MaxText = 14, Parent = scroll })
	State.FullChanged.Event:Connect(refresh)
	State.StatsChanged.Event:Connect(refresh)
end

function GemShop.OnOpen()
	isOpen = true
	refresh()
end

function GemShop.OnClose()
	isOpen = false
end

return GemShop
