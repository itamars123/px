-- HUD.lua
-- Always-on interface: money counter, income, level bar, menu buttons,
-- carrying status, base lock button, cooldown chips, ability buttons (also
-- the mobile controls), world event timer and incoming trade requests.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lib = require(script.Parent.Lib)
local Windows = require(script.Parent.Windows)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.Controllers.State)
local Shared = game:GetService("ReplicatedStorage").Shared
local TreasureData = require(Shared.TreasureData)
local UpgradeData = require(Shared.UpgradeData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local T = Lib.Theme
local new = Lib.new

local HUD = {}

local gui: ScreenGui
local moneyLabel: TextLabel
local mpsLabel: TextLabel
local levelSet
local levelLabel: TextLabel
local rebirthLabel: TextLabel
local carryLabel: TextLabel
local lockButton: TextButton
local chips: Frame
local chipLabels = {}
local abilityButtons = {}
local eventFrame: Frame
local eventLabel: TextLabel
local gemsLabel: TextLabel
local vaultButton: TextButton
local staminaSet
local sprintButton: TextButton
local emotePanel: Frame
local sprinting = false
local displayedMoney = 0
local targetMoney = 0
local lastMoney = nil

function HUD.Gui()
	return gui
end

local function menuButton(parent, order, icon, text, color, window)
	local b = Lib.button({
		Text = "",
		Color = color,
		Size = UDim2.fromOffset(64, 64),
		LayoutOrder = order,
		Radius = 16,
		Parent = parent,
		OnClick = function()
			Windows.Toggle(window)
		end,
	})
	Lib.label({ Size = UDim2.new(1, 0, 0.68, 0), Text = icon, MaxText = 32, Parent = b })
	local l = Lib.label({ Size = UDim2.new(1, 4, 0.32, 0), Position = UDim2.new(0, -2, 0.66, 0), Text = text, Font = T.Title, MaxText = 13, Parent = b })
	Lib.textStroke(1.5).Parent = l
	return b
end

local function chip(name: string, color: Color3)
	local c = Lib.panel({ Size = UDim2.fromOffset(150, 30), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15, Visible = false, Parent = chips })
	Lib.stroke(color, 2).Parent = c
	local l = Lib.label({ Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Text = "", TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4), MaxText = 15, Parent = c })
	Lib.textStroke(1).Parent = l
	chipLabels[name] = { Frame = c, Label = l }
end

local function setChip(name: string, text: string?)
	local c = chipLabels[name]
	c.Frame.Visible = text ~= nil
	if text then
		c.Label.Text = text
	end
end

local function buildTop()
	local top = Lib.panel({
		Name = "MoneyPanel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 74),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.1,
		Radius = 16,
		Parent = gui,
	})
	Lib.stroke(T.Accent, 3).Parent = top
	moneyLabel = Lib.label({ Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 4), Text = "$0", Font = T.Title, TextColor3 = T.Accent, MaxText = 40, Parent = top })
	Lib.textStroke(2.5).Parent = moneyLabel
	mpsLabel = Lib.label({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 48), Text = "+$0/s", TextColor3 = T.Green, MaxText = 18, Parent = top })
	Lib.textStroke(1.5).Parent = mpsLabel

	-- gems + vault (collect) under the money panel
	local gems = Lib.panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.5, -158, 0, 8), Size = UDim2.fromOffset(120, 36), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, Radius = 12, Parent = gui })
	Lib.stroke(T.Blue, 2.5).Parent = gems
	gemsLabel = Lib.label({ Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Text = "💎 0", Font = T.Title, TextColor3 = T.Blue:Lerp(Color3.new(1, 1, 1), 0.4), MaxText = 22, Parent = gems })
	Lib.textStroke(1.5).Parent = gemsLabel
	vaultButton = Lib.button({
		Text = "💰 Vault $0",
		Color = T.Accent,
		Size = UDim2.fromOffset(150, 36),
		Position = UDim2.new(0.5, 158, 0, 8),
		AnchorPoint = Vector2.new(0, 0),
		MaxText = 18,
		Parent = gui,
		OnClick = function()
			State.Request("Collect")
		end,
	})

	local lvl = Lib.panel({ Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(230, 56), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, Radius = 14, Parent = gui })
	Lib.stroke(T.Blue, 2.5).Parent = lvl
	levelLabel = Lib.label({ Size = UDim2.new(0.6, 0, 0, 24), Position = UDim2.fromOffset(10, 3), Text = "⭐ Level 1", Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = lvl })
	Lib.textStroke(1.5).Parent = levelLabel
	rebirthLabel = Lib.label({ Size = UDim2.new(0.4, -10, 0, 24), Position = UDim2.new(0.6, 0, 0, 3), Text = "🌀 0", Font = T.Title, TextColor3 = T.Pink, TextXAlignment = Enum.TextXAlignment.Right, MaxText = 20, Parent = lvl })
	Lib.textStroke(1.5).Parent = rebirthLabel
	local _, setter = Lib.bar({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 30), Color = T.Blue, Parent = lvl })
	levelSet = setter

	eventFrame = Lib.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 88),
		Size = UDim2.fromOffset(320, 36),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	Lib.stroke(T.Pink, 2.5).Parent = eventFrame
	eventLabel = Lib.label({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Text = "", Font = T.Title, TextColor3 = T.Pink:Lerp(Color3.new(1, 1, 1), 0.4), MaxText = 18, Parent = eventFrame })
	Lib.textStroke(1.5).Parent = eventLabel
end

local function buildMenu()
	local menu = new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(140, 370),
		Parent = gui,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(64, 64),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirectionMaxCells = 2,
		}),
	})
	menuButton(menu, 1, "🎒", "Items", T.Blue, "Inventory")
	menuButton(menu, 2, "🐾", "Pets", T.Orange, "Pets")
	menuButton(menu, 3, "📖", "Index", T.Purple, "Index")
	menuButton(menu, 4, "🛒", "Upgrade", T.Green, "Shop")
	menuButton(menu, 5, "💎", "Gems", T.Blue, "GemShop")
	menuButton(menu, 6, "🌀", "Rebirth", T.Pink, "Rebirth")
	menuButton(menu, 7, "🏆", "Top", T.Accent, "Leaderboard")
	menuButton(menu, 8, "🤝", "Trade", T.Orange, "Trade")
	menuButton(menu, 9, "🎖️", "Awards", T.Accent, "Achievements")
	menuButton(menu, 10, "⚙️", "Settings", T.Panel2, "Settings")
end

local function buildBottom()
	local bottom = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(520, 120),
		Parent = gui,
	})
	carryLabel = Lib.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -54),
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
		Font = T.Title,
		TextColor3 = T.Accent,
		MaxText = 20,
		Parent = bottom,
	})
	Lib.textStroke(2).Parent = carryLabel
	lockButton = Lib.button({
		Text = "🔒 LOCK BASE",
		Color = T.Red,
		Size = UDim2.fromOffset(190, 46),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Parent = bottom,
		OnClick = function()
			State.Request("LockBase")
		end,
	})
	chips = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -86),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = bottom,
	}, { Lib.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	chip("Shield", T.Blue)
	chip("Steal", T.Orange)
	chip("Locked", T.Green)
	chip("Gold", T.Accent)
	chip("Boost", T.Green)
	chip("Luck", T.Green)
	-- stamina bar
	local _, setter = Lib.bar({ Size = UDim2.fromOffset(190, 12), Position = UDim2.new(0.5, 0, 1, -50), AnchorPoint = Vector2.new(0.5, 1), Color = T.Green, Parent = bottom })
	staminaSet = setter
end

function HUD.SetSprint(on: boolean)
	if sprinting == on then
		return
	end
	sprinting = on
	if sprintButton then
		Lib.setButtonColor(sprintButton, on and T.Green or T.Panel2)
	end
	State.Ask("Sprint", on)
end

local EMOTES = { { "Dance", "💃" }, { "Wave", "👋" }, { "Cheer", "🙌" }, { "Flex", "💪" }, { "Victory", "🏆" } }
function HUD.ToggleEmotes()
	emotePanel.Visible = not emotePanel.Visible
end

local function buildActions()
	-- sprint + emote buttons (bottom-left on PC, above the thumbstick on mobile)
	local touch = UserInputService.TouchEnabled
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = touch and Vector2.new(1, 0.5) or Vector2.new(0, 1),
		Position = touch and UDim2.new(1, -12, 0.38, 0) or UDim2.new(0, 12, 1, -12),
		Size = touch and UDim2.fromOffset(70, 136) or UDim2.fromOffset(150, 70),
		Parent = gui,
	}, { Lib.list(touch and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom) })
	sprintButton = Lib.button({ Text = touch and "🏃 Sprint" or "🏃 [Shift]", Color = T.Panel2, Size = UDim2.fromOffset(70, 60), Radius = 30, MaxText = 14, Parent = holder, OnClick = function()
		HUD.SetSprint(not sprinting)
	end })
	Lib.button({ Text = touch and "😀 Emote" or "😀 [T]", Color = T.Pink, Size = UDim2.fromOffset(70, 60), Radius = 30, MaxText = 14, Parent = holder, OnClick = HUD.ToggleEmotes })
	emotePanel = Lib.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(360, 70),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	Lib.stroke(T.Pink, 2.5).Parent = emotePanel
	Lib.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = emotePanel
	for i, e in ipairs(EMOTES) do
		Lib.button({ Text = e[2] .. " " .. e[1], Color = T.Panel2, Size = UDim2.fromOffset(64, 54), LayoutOrder = i, MaxText = 13, Parent = emotePanel, OnClick = function()
			State.Request("Emote", e[1])
			emotePanel.Visible = false
		end })
	end
end

local function buildAbilities()
	local holder = new("Frame", {
		Name = "Abilities",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, UserInputService.TouchEnabled and -190 or -24),
		Size = UDim2.fromOffset(76, 260),
		Parent = gui,
	}, { Lib.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom) })
	for i, key in ipairs(UpgradeData.SortedKeys(UpgradeData.Abilities)) do
		local ab = UpgradeData.Abilities[key]
		if ab.Key then
			local b = Lib.button({
				Text = "",
				Color = T.Purple,
				Size = UDim2.fromOffset(70, 70),
				LayoutOrder = i,
				Radius = 35,
				Visible = false,
				Parent = holder,
				OnClick = function()
					State.Request("UseAbility", key)
				end,
			})
			Lib.label({ Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.06), Text = ab.Icon, MaxText = 30, Parent = b })
			local keyLabel = Lib.label({ Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.64), Text = UserInputService.TouchEnabled and ab.Name or ("[" .. ab.Key .. "]"), Font = T.Title, MaxText = 13, Parent = b })
			Lib.textStroke(1.5).Parent = keyLabel
			local cd = new("TextLabel", {
				Name = "Cooldown",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45,
				Font = T.Title,
				TextScaled = true,
				TextColor3 = Color3.new(1, 1, 1),
				Text = "",
				Visible = false,
				ZIndex = 5,
				Parent = b,
			}, { Lib.corner(35) })
			abilityButtons[key] = { Button = b, Cooldown = cd }
		end
	end
end

local function tradePopup(fromUserId: number, fromName: string, timeout: number)
	local popup = Lib.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(340, 120),
		BackgroundColor3 = T.Bg,
		ZIndex = 20,
		Parent = gui,
	})
	Lib.stroke(T.Orange, 3).Parent = popup
	local l = Lib.label({ Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 8), Text = ("🤝 %s wants to trade!"):format(fromName), Font = T.Title, ZIndex = 21, MaxText = 22, Parent = popup })
	Lib.textStroke(1.5).Parent = l
	local function respond(accept)
		popup:Destroy()
		State.Request("TradeRespond", fromUserId, accept)
	end
	Lib.button({ Text = "Accept", Color = T.Green, Size = UDim2.fromOffset(140, 44), Position = UDim2.new(0.5, -6, 1, -12), AnchorPoint = Vector2.new(1, 1), ZIndex = 22, Parent = popup, OnClick = function()
		respond(true)
	end })
	Lib.button({ Text = "Decline", Color = T.Red, Size = UDim2.fromOffset(140, 44), Position = UDim2.new(0.5, 6, 1, -12), AnchorPoint = Vector2.new(0, 1), ZIndex = 22, Parent = popup, OnClick = function()
		respond(false)
	end })
	task.delay(timeout, function()
		if popup.Parent then
			popup:Destroy()
		end
	end)
end

local function onStats(stats)
	targetMoney = stats.Money
	if lastMoney and stats.Money - lastMoney > 0 and stats.Money - lastMoney > (stats.MPS or 0) * 1.5 then
		Notifications.MoneyPop("+" .. Util.Money(stats.Money - lastMoney))
		-- bounce the money panel on big gains
		local panel = gui:FindFirstChild("MoneyPanel")
		if panel then
			local sc = panel:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = panel })
			sc.Scale = 1.12
			TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
	lastMoney = stats.Money
	local mult = (stats.EventMultiplier or 1) > 1 and ("  🌟x" .. stats.EventMultiplier) or ""
	mpsLabel.Text = ("+%s/s%s"):format(Util.Money(stats.MPS or 0), mult)
	gemsLabel.Text = "💎 " .. Util.Abbreviate(stats.Gems or 0)
	local full = State.Full
	if full and full.AutoCollect then
		vaultButton.Text = "🤖 Auto Collect"
		Lib.setButtonColor(vaultButton, T.Panel2)
	else
		vaultButton.Text = "💰 Collect " .. Util.Money(math.floor(stats.Vault or 0))
		Lib.setButtonColor(vaultButton, (stats.Vault or 0) >= 1 and T.Accent or T.Panel2)
	end
	staminaSet((stats.Stamina or 0) / (stats.MaxStamina or 100), "⚡ Stamina")
	if sprinting and (stats.Stamina or 0) <= 0 then
		sprinting = false
		Lib.setButtonColor(sprintButton, T.Panel2)
	end
	levelLabel.Text = ("⭐ Level %d"):format(stats.Level)
	rebirthLabel.Text = ("🌀 %d"):format(stats.Rebirths or 0)
	levelSet(stats.XP / math.max(1, stats.XPNext), ("%s / %s XP"):format(Util.Abbreviate(stats.XP), Util.Abbreviate(stats.XPNext)))
	if #stats.Carrying > 0 then
		local names = {}
		local stolen = false
		for _, item in ipairs(stats.Carrying) do
			local def = TreasureData.Get(item.Id)
			table.insert(names, def and def.Name or "?")
			stolen = stolen or item.Source == "Steal"
		end
		carryLabel.Text = ("%s %s (%d/%d) — bring it to your base!"):format(stolen and "🏃‍♂️💨" or "📦", table.concat(names, ", "), #stats.Carrying, stats.CarryCap)
		carryLabel.TextColor3 = stolen and T.Red:Lerp(Color3.new(1, 1, 1), 0.3) or T.Accent
	else
		carryLabel.Text = ""
	end
end

local function tick()
	local stats = State.Stats
	local now = State.Now()
	if stats then
		local shield = stats.ShieldEnd - now
		setChip("Shield", shield > 0 and ("🛡️ New player shield %ds"):format(math.ceil(shield)) or nil)
		local steal = stats.StealCooldownEnd - now
		setChip("Steal", steal > 0 and ("🦹 Steal ready in %ds"):format(math.ceil(steal)) or nil)
		local lock = stats.LockEnd - now
		setChip("Locked", lock > 0 and ("🔒 Base locked %ds"):format(math.ceil(lock)) or nil)
		local gold = (stats.EventMultiplier or 1) > 1
		setChip("Gold", gold and "💸 DOUBLE MONEY" or nil)
		local active = {}
		local t0 = stats.ServerTime or os.time()
		for name, expiry in pairs(stats.Boosts or {}) do
			if expiry > t0 then
				table.insert(active, name)
			end
		end
		setChip("Boost", #active > 0 and ("⏳ Boost: " .. table.concat(active, ", ")) or nil)
		local luck = stats.Luck or 1
		setChip("Luck", luck > 1.001 and ("🍀 Luck x%.1f"):format(luck) or nil)
		local cooldown = stats.LockCooldownEnd - now
		if lock > 0 then
			lockButton.Text = ("🔒 LOCKED %ds"):format(math.ceil(lock))
			Lib.setButtonColor(lockButton, T.Green)
		elseif cooldown > 0 then
			lockButton.Text = ("⏳ LOCK IN %ds"):format(math.ceil(cooldown))
			Lib.setButtonColor(lockButton, T.Panel2)
		else
			lockButton.Text = "🔒 LOCK BASE"
			Lib.setButtonColor(lockButton, T.Red)
		end
		for key, ab in pairs(abilityButtons) do
			local cdEnd = stats.AbilityCooldowns and stats.AbilityCooldowns[key] or 0
			local left = cdEnd - now
			ab.Cooldown.Visible = left > 0
			ab.Cooldown.Text = left > 0 and tostring(math.ceil(left)) or ""
		end
	end
	local full = State.Full
	if full then
		for key, ab in pairs(abilityButtons) do
			ab.Button.Visible = full.Abilities[key] == true
		end
	end
	local eventName = workspace:GetAttribute("Event")
	if eventName and eventName ~= "" then
		local left = (workspace:GetAttribute("EventEnd") or 0) - now
		eventFrame.Visible = true
		eventLabel.Text = ("🎉 %s — %s"):format(eventName, Util.Time(left))
	else
		local nextEvent = (workspace:GetAttribute("NextEvent") or 0) - now
		eventFrame.Visible = nextEvent > 0 and nextEvent < 60
		eventLabel.Text = ("⏰ Next event in %ds"):format(math.ceil(nextEvent))
	end
end

function HUD.Init(parentGui: ScreenGui)
	gui = parentGui
	buildTop()
	buildMenu()
	buildBottom()
	buildAbilities()
	buildActions()
	State.StatsChanged.Event:Connect(onStats)
	State.FullChanged.Event:Connect(function(full)
		targetMoney = full.Money
	end)
	Remotes.TradeRequest.OnClientEvent:Connect(tradePopup)
	-- smooth money counter
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		if displayedMoney ~= targetMoney then
			local diff = targetMoney - displayedMoney
			if math.abs(diff) < 1 then
				displayedMoney = targetMoney
			else
				displayedMoney += diff * math.min(1, dt * 8)
			end
			moneyLabel.Text = Util.Money(math.floor(displayedMoney))
		end
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(0.25)
		end
	end)
end

return HUD
