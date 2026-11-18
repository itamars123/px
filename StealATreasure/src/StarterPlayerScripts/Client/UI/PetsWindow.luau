-- PetsWindow.lua
-- Pet inventory (equip / unequip / release / equip best, 3D preview) and the
-- egg shop with odds and an animated hatching sequence.

local TweenService = game:GetService("TweenService")

local Lib = require(script.Parent.Lib)
local Preview = require(script.Parent.Preview)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.Controllers.State)
local Sound = require(script.Parent.Parent.Controllers.Sound)
local Shared = game:GetService("ReplicatedStorage").Shared
local PetData = require(Shared.PetData)
local Rarities = require(Shared.Rarities)
local Util = require(Shared.Util)

local T = Lib.Theme
local new = Lib.new

local Pets = {}

local tab = "Pets"
local isOpen = false
local gui: ScreenGui
local petsPage: Frame
local eggsPage: Frame
local grid: ScrollingFrame
local tabButtons = {}
local slotsLabel: TextLabel
local bonusLabel: TextLabel
local selected: string? = nil
local detail = {}
local cleanup = function() end
local confirmDelete = 0
local hatching = false

function Pets.Card(def, opts)
	local color = Rarities.Color(def.Rarity)
	local card = new("TextButton", {
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = opts.Order or 0,
	}, {
		Lib.corner(12),
		Lib.gradient(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 130), 90),
		Lib.stroke(opts.Selected and T.Accent or color:Lerp(Color3.new(0, 0, 0), 0.4), opts.Selected and 4 or 2),
	})
	Lib.label({ Size = UDim2.new(1, 0, 0.48, 0), Position = UDim2.fromScale(0, 0.04), Text = PetData.Icons[def.Species] or "🐾", MaxText = 42, Parent = card })
	local n = Lib.label({ Size = UDim2.new(1, -8, 0.22, 0), Position = UDim2.new(0, 4, 0.52, 0), Text = def.Name, Font = T.Title, MaxText = 14, Parent = card })
	Lib.textStroke(1.5).Parent = n
	local b = Lib.label({ Size = UDim2.new(1, -8, 0.2, 0), Position = UDim2.new(0, 4, 0.76, 0), Text = opts.Sub or PetData.BonusText(def), TextColor3 = Color3.fromRGB(200, 255, 200), MaxText = 12, Parent = card })
	Lib.textStroke(1.5).Parent = b
	if opts.Badge then
		Lib.label({ Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(4, 4), Text = opts.Badge, MaxText = 18, Parent = card })
	end
	return card
end

local function findPet(uid)
	for _, p in ipairs(State.Full and State.Full.Pets or {}) do
		if p.Uid == uid then
			return p
		end
	end
	return nil
end

local function refreshDetail()
	cleanup()
	cleanup = function() end
	local pet = findPet(selected)
	if not pet then
		detail.Name.Text = "Select a pet"
		detail.Info.Text = "Hatch eggs at the 🐾 Pet Shop or in the Eggs tab!"
		detail.Equip.Visible = false
		detail.Delete.Visible = false
		detail.Viewport:ClearAllChildren()
		return
	end
	local def = PetData.Get(pet.Id)
	cleanup = Preview.ShowPet(detail.Viewport, def)
	detail.Name.Text = def.Name
	detail.Name.TextColor3 = Rarities.Color(def.Rarity)
	detail.Info.Text = ("%s %s\n%s\n%s"):format(def.Rarity, def.Flies and "• Flying" or "• Walking", PetData.BonusText(def), pet.InTrade and "🤝 In a trade" or (pet.Equipped and "✅ Equipped" or ""))
	detail.Equip.Visible = not pet.InTrade
	detail.Equip.Text = pet.Equipped and "Unequip" or "Equip"
	Lib.setButtonColor(detail.Equip, pet.Equipped and T.Orange or T.Green)
	detail.Delete.Visible = not pet.InTrade
	detail.Delete.Text = os.clock() < confirmDelete and "Confirm?" or "Release"
end

local function refreshPets()
	Lib.clear(grid)
	local full = State.Full
	if not full then
		return
	end
	local list = {}
	local equipped = 0
	for _, p in ipairs(full.Pets) do
		local def = PetData.Get(p.Id)
		if def then
			table.insert(list, { Pet = p, Def = def })
			if p.Equipped then
				equipped += 1
			end
		end
	end
	table.sort(list, function(a, b)
		if a.Pet.Equipped ~= b.Pet.Equipped then
			return a.Pet.Equipped
		end
		local ra, rb = Rarities.Rank(a.Def.Rarity), Rarities.Rank(b.Def.Rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.Pet.Uid < b.Pet.Uid
	end)
	slotsLabel.Text = ("🐾 %d pets • Equipped %d/%d"):format(#list, equipped, full.PetSlots)
	local pb = full.PetBonus or {}
	bonusLabel.Text = ("Bonus: +%d%% income • +%d%% luck • +%d speed • +%d%% gems"):format(
		math.floor((pb.Money or 0) * 100 + 0.5),
		math.floor((pb.Luck or 0) * 100 + 0.5),
		pb.Speed or 0,
		math.floor((pb.Gems or 0) * 100 + 0.5)
	)
	for i, e in ipairs(list) do
		local card = Pets.Card(e.Def, { Order = i, Selected = e.Pet.Uid == selected, Badge = e.Pet.Equipped and "✅" or (e.Pet.InTrade and "🤝" or nil) })
		card.Activated:Connect(function()
			selected = e.Pet.Uid
			confirmDelete = 0
			refreshPets()
		end)
		card.Parent = grid
	end
	refreshDetail()
end

local function refresh()
	if not isOpen then
		return
	end
	petsPage.Visible = tab == "Pets"
	eggsPage.Visible = tab == "Eggs"
	for name, b in pairs(tabButtons) do
		Lib.setButtonColor(b, name == tab and T.Orange or T.Panel2)
	end
	if tab == "Pets" then
		refreshPets()
	end
end

-- Hatching animation ------------------------------------------------------------
local function playHatch(eggKey: string, petId: string)
	local egg = PetData.Eggs[eggKey]
	local def = PetData.Get(petId)
	local overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 60, Parent = gui })
	local eggLabel = Lib.label({
		Size = UDim2.fromOffset(220, 220),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "🥚",
		TextColor3 = egg.Color,
		ZIndex = 61,
		Parent = overlay,
		MaxText = 200,
	})
	local tint = new("Frame", {
		Size = UDim2.fromOffset(170, 210),
		Position = UDim2.fromScale(0.5, 0.47),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = egg.Color,
		BackgroundTransparency = 0.55,
		ZIndex = 60,
		Parent = overlay,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	-- shake, faster and faster
	for i = 1, 14 do
		local amp = 4 + i * 1.5
		eggLabel.Rotation = (i % 2 == 0) and amp or -amp
		tint.Rotation = eggLabel.Rotation
		if i % 3 == 0 then
			Sound.Play("Hatch", 0.6, 0.8 + i * 0.05)
		end
		task.wait(0.14 - i * 0.006)
	end
	Notifications.Flash(Color3.new(1, 1, 1))
	Sound.Play(Rarities.Rank(def.Rarity) >= 5 and "Discovery" or "Purchase", 0.9)
	eggLabel:Destroy()
	tint:Destroy()
	local color = Rarities.Color(def.Rarity)
	local card = Lib.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(320, 380), BackgroundColor3 = T.Bg, ZIndex = 62, Radius = 20, Parent = overlay })
	Lib.stroke(color, 4).Parent = card
	local vp = new("ViewportFrame", { Size = UDim2.new(1, -30, 0, 220), Position = UDim2.fromOffset(15, 15), BackgroundColor3 = T.Panel, ZIndex = 63, Parent = card }, { Lib.corner(14) })
	local stop = Preview.ShowPet(vp, def)
	local n = Lib.label({ Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 240), Text = def.Name, Font = T.Title, ZIndex = 63, Parent = card, MaxText = 30 })
	Lib.textStroke(2).Parent = n
	local r = Lib.label({ Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 276), Text = def.Rarity:upper() .. " • " .. PetData.BonusText(def), Font = T.Title, TextColor3 = color, ZIndex = 63, Parent = card, MaxText = 20 })
	Lib.textStroke(2).Parent = r
	local scale = new("UIScale", { Scale = 0.2, Parent = card })
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Notifications.Confetti()
	local done = false
	Lib.button({ Text = "Awesome! 🎉", Color = T.Green, Size = UDim2.new(1, -40, 0, 46), Position = UDim2.new(0, 20, 1, -58), ZIndex = 64, Parent = card, OnClick = function()
		done = true
	end })
	local start = os.clock()
	while not done and os.clock() - start < 6 do
		task.wait(0.1)
	end
	stop()
	overlay:Destroy()
	hatching = false
end

local function buildEggs()
	local scroll = Lib.scroll({ Size = UDim2.fromScale(1, 1), Parent = eggsPage })
	Lib.grid(UDim2.fromOffset(200, 300), 12).Parent = scroll
	Lib.padding(6).Parent = scroll
	local keys = {}
	for k in pairs(PetData.Eggs) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return PetData.Eggs[a].Order < PetData.Eggs[b].Order
	end)
	for _, key in ipairs(keys) do
		local egg = PetData.Eggs[key]
		local card = Lib.panel({ BackgroundColor3 = T.Panel, LayoutOrder = egg.Order, Parent = scroll })
		Lib.stroke(egg.Color, 3).Parent = card
		local icon = Lib.label({ Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 6), Text = "🥚", TextColor3 = egg.Color, MaxText = 70, Parent = card })
		local bob = TweenService:Create(icon, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromOffset(0, 0), Rotation = 6 })
		bob:Play()
		local t = Lib.label({ Size = UDim2.new(1, -10, 0, 28), Position = UDim2.fromOffset(5, 88), Text = egg.Name, Font = T.Title, MaxText = 22, Parent = card })
		Lib.textStroke(1.5).Parent = t
		-- odds
		local total = 0
		for _, w in pairs(egg.Weights) do
			total += w
		end
		local lines = {}
		for _, r in ipairs(Rarities.Order) do
			local w = egg.Weights[r]
			if w then
				table.insert(lines, ("%s %.1f%%"):format(r, w / total * 100))
			end
		end
		new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 0, 110),
			Position = UDim2.fromOffset(8, 118),
			Font = T.Body,
			TextSize = 13,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = T.SubText,
			Text = table.concat(lines, "\n") .. "\n🍀 Luck boosts rare odds",
			Parent = card,
		})
		local price = egg.Currency == "Gems" and ("💎 " .. egg.Cost) or Util.Money(egg.Cost)
		Lib.button({
			Text = "Hatch " .. price,
			Color = egg.Currency == "Gems" and T.Blue or T.Green,
			Size = UDim2.new(1, -20, 0, 44),
			Position = UDim2.new(0, 10, 1, -52),
			Parent = card,
			OnClick = function()
				if hatching then
					return
				end
				hatching = true
				local ok, _, data = State.Request("HatchEgg", key) -- failures show a toast
				if ok and data then
					playHatch(key, data.PetId)
				else
					hatching = false
				end
			end,
		})
	end
end

function Pets.Build(content: Frame)
	gui = content:FindFirstAncestorOfClass("ScreenGui")
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = content }, {
		Lib.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	for i, info in ipairs({ { "Pets", "🐾 My Pets" }, { "Eggs", "🥚 Eggs" } }) do
		tabButtons[info[1]] = Lib.button({ Text = info[2], Color = T.Panel2, Size = UDim2.fromOffset(130, 34), LayoutOrder = i, Parent = top, OnClick = function()
			tab = info[1]
			refresh()
		end })
	end
	Lib.button({ Text = "⭐ Equip Best", Color = T.Accent, Size = UDim2.fromOffset(140, 34), LayoutOrder = 5, Parent = top, OnClick = function()
		State.Request("EquipBestPets")
	end })

	petsPage = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), Parent = content })
	eggsPage = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), Visible = false, Parent = content })
	slotsLabel = Lib.label({ Size = UDim2.new(0.64, 0, 0, 20), Text = "", TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15, Parent = petsPage })
	bonusLabel = Lib.label({ Size = UDim2.new(0.64, 0, 0, 18), Position = UDim2.fromOffset(0, 20), Text = "", TextColor3 = T.Green, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 13, Parent = petsPage })
	grid = Lib.scroll({ Position = UDim2.fromOffset(0, 42), Size = UDim2.new(0.64, -8, 1, -42), Parent = petsPage })
	Lib.grid(UDim2.fromOffset(100, 114), 8).Parent = grid
	Lib.padding(4).Parent = grid
	local panel = Lib.panel({ Position = UDim2.new(0.64, 0, 0, 0), Size = UDim2.new(0.36, 0, 1, 0), Parent = petsPage })
	Lib.padding(10).Parent = panel
	detail.Viewport = new("ViewportFrame", { Size = UDim2.new(1, 0, 0.45, 0), BackgroundColor3 = T.Panel2, Parent = panel }, { Lib.corner(12) })
	detail.Name = Lib.label({ Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0.47, 0), Font = T.Title, MaxText = 22, Parent = panel })
	Lib.textStroke(1.5).Parent = detail.Name
	detail.Info = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0.3, 0),
		Position = UDim2.new(0, 0, 0.47, 32),
		Font = T.Body,
		TextSize = 15,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.SubText,
		Text = "",
		Parent = panel,
	})
	local buttons = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40), Parent = panel }, {
		Lib.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center),
	})
	detail.Equip = Lib.button({ Text = "Equip", Color = T.Green, Size = UDim2.new(0.48, 0, 1, 0), Parent = buttons, OnClick = function()
		local pet = findPet(selected)
		if pet then
			State.Request(pet.Equipped and "UnequipPet" or "EquipPet", pet.Uid)
		end
	end })
	detail.Delete = Lib.button({ Text = "Release", Color = T.Red, Size = UDim2.new(0.48, 0, 1, 0), Parent = buttons, OnClick = function()
		local pet = findPet(selected)
		if not pet then
			return
		end
		if os.clock() < confirmDelete then
			confirmDelete = 0
			State.Request("DeletePet", pet.Uid)
			selected = nil
		else
			confirmDelete = os.clock() + 3
			refreshDetail()
		end
	end })
	buildEggs()
	State.FullChanged.Event:Connect(refresh)
end

function Pets.OnOpen(arg)
	isOpen = true
	if arg == "Eggs" then
		tab = "Eggs"
	end
	refresh()
end

function Pets.OnClose()
	isOpen = false
	cleanup()
	cleanup = function() end
end

return Pets
