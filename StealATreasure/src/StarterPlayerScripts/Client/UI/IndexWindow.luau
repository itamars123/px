-- IndexWindow.lua
-- The Treasure Index: every treasure in the game, discovered or not,
-- filterable by rarity, with completion progress and 3D previews.

local Lib = require(script.Parent.Lib)
local Preview = require(script.Parent.Preview)
local Inventory = require(script.Parent.InventoryWindow)
local State = require(script.Parent.Parent.Controllers.State)
local Shared = game:GetService("ReplicatedStorage").Shared
local TreasureData = require(Shared.TreasureData)
local Rarities = require(Shared.Rarities)
local Util = require(Shared.Util)

local T = Lib.Theme
local new = Lib.new

local Index = {}

local filter = "All"
local grid: ScrollingFrame
local progressSet
local filterButtons = {}
local detailName: TextLabel
local detailInfo: TextLabel
local viewport: ViewportFrame
local cleanup = function() end
local isOpen = false

local function discovered(): { [string]: boolean }
	local set = {}
	if State.Full then
		for _, id in ipairs(State.Full.Index) do
			set[id] = true
		end
	end
	return set
end

local function selectDef(def, known: boolean)
	cleanup()
	if known then
		cleanup = Preview.Show(viewport, def)
		detailName.Text = def.Name
		detailName.TextColor3 = Rarities.Color(def.Rarity)
		detailInfo.Text = ("%s%s\n💰 %s/s\n💎 %s\n✨ %s effect"):format(
			def.Rarity,
			def.Exclusive and " • Rebirth Exclusive" or "",
			Util.Money(def.MPS),
			Util.Money(def.Value),
			def.Fx == "None" and "Classic" or def.Fx
		)
	else
		cleanup = function() end
		viewport:ClearAllChildren()
		detailName.Text = "???"
		detailName.TextColor3 = Rarities.Color(def.Rarity)
		detailInfo.Text = def.Rarity .. "\nNot discovered yet.\n" .. (def.Exclusive and "Unlocked through rebirth." or "Find, buy or steal it!")
	end
end

local function refresh()
	if not isOpen then
		return
	end
	Lib.clear(grid)
	local known = discovered()
	local found, total = 0, 0
	for _, def in ipairs(TreasureData.List) do
		if not def.Exclusive then
			total += 1
			if known[def.Id] then
				found += 1
			end
		end
	end
	progressSet(found / total, ("📖 %d / %d discovered"):format(found, total))
	for _, def in ipairs(TreasureData.List) do
		if filter == "All" or def.Rarity == filter then
			local isKnown = known[def.Id] == true
			local card = Inventory.Card(def, { Order = def.Order, Hidden = not isKnown, Sub = isKnown and (Util.Money(def.MPS) .. "/s") or def.Rarity })
			card.Activated:Connect(function()
				selectDef(def, isKnown)
			end)
			card.Parent = grid
		end
	end
	for name, b in pairs(filterButtons) do
		Lib.setButtonColor(b, name == filter and (name == "All" and T.Accent or Rarities.Color(name)) or T.Panel2)
	end
end

function Index.Build(content: Frame)
	local _, setter = Lib.bar({ Size = UDim2.new(1, 0, 0, 26), Color = T.Purple, Parent = content })
	progressSet = setter
	local filters = Lib.scroll({
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 40),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 3,
		Parent = content,
	})
	Lib.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = filters
	local names = { "All" }
	for _, r in ipairs(Rarities.Order) do
		table.insert(names, r)
	end
	for i, name in ipairs(names) do
		filterButtons[name] = Lib.button({
			Text = name,
			Color = T.Panel2,
			Size = UDim2.fromOffset(92, 32),
			LayoutOrder = i,
			MaxText = 16,
			Parent = filters,
			OnClick = function()
				filter = name
				refresh()
			end,
		})
	end
	grid = Lib.scroll({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(0.68, -8, 1, -78), Parent = content })
	Lib.grid(UDim2.fromOffset(96, 112), 8).Parent = grid
	Lib.padding(4).Parent = grid
	local panel = Lib.panel({ Position = UDim2.new(0.68, 0, 0, 78), Size = UDim2.new(0.32, 0, 1, -78), Parent = content })
	Lib.padding(10).Parent = panel
	viewport = new("ViewportFrame", { Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = T.Panel2, Parent = panel }, { Lib.corner(12) })
	detailName = Lib.label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.52, 0), Font = T.Title, Text = "Pick a treasure", MaxText = 22, Parent = panel })
	Lib.textStroke(1.5).Parent = detailName
	detailInfo = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0.48, -36),
		Position = UDim2.new(0, 0, 0.52, 34),
		Font = T.Body,
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.SubText,
		Text = "",
		Parent = panel,
	})
	State.FullChanged.Event:Connect(refresh)
end

function Index.OnOpen()
	isOpen = true
	refresh()
end

function Index.OnClose()
	isOpen = false
	cleanup()
	cleanup = function() end
end

return Index
