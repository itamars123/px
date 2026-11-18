-- InventoryWindow.lua
-- Your treasures: placed on platforms or in storage. Place, store and sell,
-- with a rotating 3D preview of the selected treasure.

local Lib = require(script.Parent.Lib)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.Parent.Controllers.State)
local Shared = game:GetService("ReplicatedStorage").Shared
local TreasureData = require(Shared.TreasureData)
local Rarities = require(Shared.Rarities)
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Mutations = require(Shared.Mutations)

local T = Lib.Theme
local new = Lib.new

local Inventory = {}

local tab = "All"
local selectedUid: string? = nil
local grid: ScrollingFrame
local tabButtons = {}
local countLabel: TextLabel
local detail = {}
local cleanupPreview = function() end
local isOpen = false

function Inventory.Card(def, opts)
	local color = Rarities.Color(def.Rarity)
	local mut = opts.Mut and Mutations.Info[opts.Mut]
	local card = new("TextButton", {
		Name = def.Id,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = opts.Order or 0,
	}, {
		Lib.corner(12),
		Lib.gradient(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 130), 90),
		Lib.stroke(opts.Selected and T.Accent or (mut and mut.Color or color:Lerp(Color3.new(0, 0, 0), 0.4)), (opts.Selected or mut) and 4 or 2),
	})
	if mut then
		local tag = Lib.label({ Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -28, 0, 2), Text = mut.Icon, MaxText = 20, Parent = card })
		tag.ZIndex = 3
	end
	local icon = Lib.label({
		Size = UDim2.new(1, 0, 0.5, 0),
		Position = UDim2.fromScale(0, 0.04),
		Text = opts.Hidden and "❓" or def.Icon,
		Font = T.Title,
		MaxText = 44,
		Parent = card,
	})
	icon.TextTransparency = opts.Hidden and 0.3 or 0
	local name = Lib.label({
		Size = UDim2.new(1, -8, 0.22, 0),
		Position = UDim2.new(0, 4, 0.54, 0),
		Text = opts.Hidden and "???" or def.Name,
		Font = T.Title,
		MaxText = 15,
		Parent = card,
	})
	Lib.textStroke(1.5).Parent = name
	local sub = Lib.label({
		Size = UDim2.new(1, -8, 0.18, 0),
		Position = UDim2.new(0, 4, 0.78, 0),
		Text = opts.Sub or (Util.Money(def.MPS * Mutations.Multiplier(opts.Mut)) .. "/s"),
		TextColor3 = Color3.fromRGB(190, 255, 190),
		MaxText = 13,
		Parent = card,
	})
	Lib.textStroke(1.5).Parent = sub
	if opts.Badge then
		local badge = Lib.label({
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.fromOffset(4, 4),
			Text = opts.Badge,
			MaxText = 18,
			Parent = card,
		})
		badge.ZIndex = 3
	end
	return card
end

local function entries()
	local full = State.Full
	if not full then
		return {}
	end
	local list = {}
	for _, t in ipairs(full.Treasures) do
		local def = TreasureData.Get(t.Id)
		if def then
			local placed = t.Plot ~= nil
			if tab == "All" or (tab == "Placed" and placed) or (tab == "Storage" and not placed) then
				table.insert(list, { Entry = t, Def = def })
			end
		end
	end
	table.sort(list, function(a, b)
		if a.Def.MPS ~= b.Def.MPS then
			return a.Def.MPS > b.Def.MPS
		end
		return a.Entry.Uid < b.Entry.Uid
	end)
	return list
end

local function findEntry(uid: string?)
	if not uid or not State.Full then
		return nil
	end
	for _, t in ipairs(State.Full.Treasures) do
		if t.Uid == uid then
			return t
		end
	end
	return nil
end

local function refreshDetail()
	local t = findEntry(selectedUid)
	cleanupPreview()
	if not t then
		detail.Name.Text = "Select a treasure"
		detail.Rarity.Text = ""
		detail.Info.Text = "Tap a card to see it in 3D and manage it."
		detail.Place.Visible = false
		detail.Store.Visible = false
		detail.Sell.Visible = false
		cleanupPreview = function() end
		return
	end
	local def = TreasureData.Get(t.Id)
	cleanupPreview = Preview.Show(detail.Viewport, def)
	detail.Name.Text = def.Name
	detail.Rarity.Text = def.Rarity:upper() .. (def.Exclusive and " • EXCLUSIVE" or "") .. (t.Mut and ("  " .. Mutations.Label(t.Mut)) or "")
	detail.Rarity.TextColor3 = Rarities.Color(def.Rarity)
	local status = t.Stealing and "🚨 BEING STOLEN!" or (t.InTrade and "🤝 In trade" or (t.Plot and ("📍 Platform " .. t.Plot) or "📦 In storage"))
	local m = Mutations.Multiplier(t.Mut)
	detail.Info.Text = ("💰 %s/s\n💎 Value %s\n🏷️ Sells for %s\n%s"):format(
		Util.Money(def.MPS * m),
		Util.Money(def.Value * m),
		Util.Money(math.floor(def.Value * m * Config.SellMultiplier)),
		status
	)
	detail.Place.Visible = t.Plot == nil and not t.InTrade
	detail.Store.Visible = t.Plot ~= nil and not t.Stealing
	detail.Sell.Visible = not t.Stealing and not t.InTrade
end

local function refresh()
	if not isOpen then
		return
	end
	Lib.clear(grid)
	local full = State.Full
	if not full then
		return
	end
	local placed, stored = 0, 0
	for _, t in ipairs(full.Treasures) do
		if t.Plot then
			placed += 1
		else
			stored += 1
		end
	end
	countLabel.Text = ("📍 %d/%d platforms   📦 %d/%d storage"):format(placed, full.PlotCount, stored, full.MaxStorage)
	for i, e in ipairs(entries()) do
		local badge = e.Entry.Stealing and "🚨" or (e.Entry.Plot and "📍" or nil)
		local card = Inventory.Card(e.Def, { Order = i, Selected = e.Entry.Uid == selectedUid, Badge = badge, Mut = e.Entry.Mut })
		card.Activated:Connect(function()
			selectedUid = e.Entry.Uid
			refresh()
		end)
		card.Parent = grid
	end
	for name, b in pairs(tabButtons) do
		Lib.setButtonColor(b, name == tab and T.Accent or T.Panel2)
	end
	refreshDetail()
end

function Inventory.Build(content: Frame)
	-- top bar
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = content }, {
		Lib.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	for i, name in ipairs({ "All", "Placed", "Storage" }) do
		tabButtons[name] = Lib.button({
			Text = name,
			Color = T.Panel2,
			Size = UDim2.fromOffset(90, 34),
			LayoutOrder = i,
			Parent = top,
			OnClick = function()
				tab = name
				refresh()
			end,
		})
	end
	Lib.button({
		Text = "📍 Place All",
		Color = T.Green,
		Size = UDim2.fromOffset(120, 34),
		LayoutOrder = 10,
		Parent = top,
		OnClick = function()
			State.Request("PlaceAll")
		end,
	})
	Lib.button({
		Text = "💰 Sell Storage ≤ Rare",
		Color = T.Orange,
		Size = UDim2.fromOffset(170, 34),
		LayoutOrder = 11,
		Parent = top,
		OnClick = function()
			State.Request("SellStorage", 3)
		end,
	})
	countLabel = Lib.label({
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 44),
		Text = "",
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxText = 16,
		Parent = content,
	})

	grid = Lib.scroll({
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(0.64, -8, 1, -70),
		Parent = content,
	})
	Lib.grid(UDim2.fromOffset(104, 118), 8).Parent = grid
	Lib.padding(4).Parent = grid

	local panel = Lib.panel({
		Position = UDim2.new(0.64, 0, 0, 70),
		Size = UDim2.new(0.36, 0, 1, -70),
		BackgroundColor3 = T.Panel,
		Parent = content,
	})
	Lib.padding(10).Parent = panel
	detail.Viewport = new("ViewportFrame", {
		Size = UDim2.new(1, 0, 0.42, 0),
		BackgroundColor3 = T.Panel2,
		Parent = panel,
	}, { Lib.corner(12) })
	detail.Name = Lib.label({ Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0.43, 0), Font = T.Title, MaxText = 24, Parent = panel })
	detail.Rarity = Lib.label({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.43, 30), Font = T.Title, MaxText = 18, Parent = panel })
	Lib.textStroke(1.5).Parent = detail.Rarity
	detail.Info = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0.3, -50),
		Position = UDim2.new(0, 0, 0.43, 52),
		Font = T.Body,
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.SubText,
		Text = "",
		Parent = panel,
	})
	local buttons = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -40),
		Parent = panel,
	}, { Lib.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
	detail.Place = Lib.button({ Text = "Place", Color = T.Green, Size = UDim2.new(0.32, 0, 1, 0), Parent = buttons, OnClick = function()
		if selectedUid then
			State.Request("Place", selectedUid)
		end
	end })
	detail.Store = Lib.button({ Text = "Store", Color = T.Blue, Size = UDim2.new(0.32, 0, 1, 0), Parent = buttons, OnClick = function()
		if selectedUid then
			State.Request("Store", selectedUid)
		end
	end })
	detail.Sell = Lib.button({ Text = "Sell", Color = T.Red, Size = UDim2.new(0.32, 0, 1, 0), Parent = buttons, OnClick = function()
		if selectedUid then
			local ok = State.Request("Sell", selectedUid)
			if ok then
				selectedUid = nil
			end
		end
	end })

	State.FullChanged.Event:Connect(refresh)
end

function Inventory.OnOpen(arg)
	isOpen = true
	if arg == "Sell" then
		tab = "Storage"
	end
	refresh()
end

function Inventory.OnClose()
	isOpen = false
	cleanupPreview()
	cleanupPreview = function() end
end

return Inventory
