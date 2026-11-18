-- TradeWindow.lua
-- Trading UI: pick a player, then build offers (treasures + money), mark
-- ready and watch the confirm countdown. Everything is validated server side.

local Players = game:GetService("Players")

local Lib = require(script.Parent.Lib)
local Inventory = require(script.Parent.InventoryWindow)
local State = require(script.Parent.Parent.Controllers.State)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local TreasureData = require(Shared.TreasureData)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local T = Lib.Theme
local new = Lib.new

local Trade = {}

local Windows -- set in Build
local trade = nil -- current trade view from server
local isOpen = false

local lobby: Frame
local session: Frame
local playerList: ScrollingFrame
local myOffer: ScrollingFrame
local theirOffer: ScrollingFrame
local picker: ScrollingFrame
local myMoney: TextBox
local theirMoney: TextLabel
local myStatus: TextLabel
local theirStatus: TextLabel
local readyButton: TextButton
local countdown: TextLabel
local partnerLabel: TextLabel

local function offerUids(): { string }
	local list = {}
	if trade then
		for _, item in ipairs(trade.Mine.Items) do
			table.insert(list, item.Uid)
		end
	end
	return list
end

local function sendOffer(uids)
	local money = tonumber(myMoney.Text) or 0
	State.Request("TradeOffer", uids, money)
end

local function refreshLobby()
	Lib.clear(playerList)
	local count = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Players.LocalPlayer then
			count += 1
			local row = Lib.panel({ Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = T.Panel2, LayoutOrder = count, Parent = playerList })
			new("ImageLabel", {
				Size = UDim2.fromOffset(44, 44),
				Position = UDim2.fromOffset(6, 5),
				BackgroundColor3 = T.Bg,
				Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(p.UserId),
				Parent = row,
			}, { Lib.corner(22) })
			local n = Lib.label({ Size = UDim2.new(1, -200, 1, -10), Position = UDim2.fromOffset(58, 5), Text = p.DisplayName, Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = row })
			Lib.textStroke(1.5).Parent = n
			Lib.button({
				Text = "🤝 Request",
				Color = T.Accent,
				Size = UDim2.fromOffset(130, 40),
				Position = UDim2.new(1, -8, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Parent = row,
				OnClick = function()
					State.Request("TradeRequest", p.UserId)
				end,
			})
		end
	end
	if count == 0 then
		Lib.label({ Size = UDim2.new(1, 0, 0, 40), Text = "No other players in this server yet.", TextColor3 = T.SubText, MaxText = 18, Parent = playerList })
	end
end

local function fillItems(container: ScrollingFrame, items, clickable: boolean)
	Lib.clear(container)
	for i, item in ipairs(items) do
		local def = TreasureData.Get(item.Id)
		if def then
			local card = Inventory.Card(def, { Order = i, Sub = clickable and "tap to remove" or nil })
			if clickable then
				card.Activated:Connect(function()
					local uids = offerUids()
					local idx = table.find(uids, item.Uid)
					if idx then
						table.remove(uids, idx)
					end
					sendOffer(uids)
				end)
			end
			card.Parent = container
		end
	end
end

local function refreshPicker()
	Lib.clear(picker)
	local full = State.Full
	if not full or not trade then
		return
	end
	local offered = {}
	for _, uid in ipairs(offerUids()) do
		offered[uid] = true
	end
	local list = {}
	for _, t in ipairs(full.Treasures) do
		if not offered[t.Uid] and not t.Stealing then
			local def = TreasureData.Get(t.Id)
			if def then
				table.insert(list, { t = t, def = def })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.def.MPS > b.def.MPS
	end)
	for i, e in ipairs(list) do
		local card = Inventory.Card(e.def, { Order = i, Badge = e.t.Plot and "📍" or nil })
		card.Activated:Connect(function()
			local uids = offerUids()
			if #uids >= Config.Trade.MaxItems then
				return
			end
			table.insert(uids, e.t.Uid)
			sendOffer(uids)
		end)
		card.Parent = picker
	end
end

local function refreshSession()
	if not trade then
		return
	end
	partnerLabel.Text = "Trading with " .. trade.Partner.Name
	fillItems(myOffer, trade.Mine.Items, true)
	fillItems(theirOffer, trade.Theirs.Items, false)
	theirMoney.Text = "💰 " .. Util.Money(trade.Theirs.Money)
	if not myMoney:IsFocused() then
		myMoney.Text = tostring(trade.Mine.Money)
	end
	myStatus.Text = trade.Mine.Ready and "✅ READY" or "⏳ Not ready"
	myStatus.TextColor3 = trade.Mine.Ready and T.Green or T.SubText
	theirStatus.Text = trade.Theirs.Ready and "✅ READY" or "⏳ Not ready"
	theirStatus.TextColor3 = trade.Theirs.Ready and T.Green or T.SubText
	readyButton.Text = trade.Mine.Ready and "UNREADY" or "✅ READY"
	Lib.setButtonColor(readyButton, trade.Mine.Ready and T.Orange or T.Green)
	refreshPicker()
end

local function refresh()
	lobby.Visible = trade == nil
	session.Visible = trade ~= nil
	if trade then
		refreshSession()
	else
		refreshLobby()
	end
end

local function itemGrid(parent, pos, size)
	local s = Lib.scroll({ Position = pos, Size = size, Parent = parent })
	Lib.grid(UDim2.fromOffset(84, 98), 6).Parent = s
	Lib.padding(4).Parent = s
	return s
end

function Trade.Build(content: Frame, windows)
	Windows = windows
	-- Lobby
	lobby = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = content })
	local h = Lib.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Choose a player to trade with", Font = T.Title, MaxText = 22, Parent = lobby })
	Lib.textStroke(1.5).Parent = h
	playerList = Lib.scroll({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), Parent = lobby })
	Lib.list(Enum.FillDirection.Vertical, 6).Parent = playerList
	Lib.padding(4).Parent = playerList

	-- Session
	session = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = content })
	partnerLabel = Lib.label({ Size = UDim2.new(0.6, 0, 0, 28), Text = "", Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22, Parent = session })
	Lib.textStroke(1.5).Parent = partnerLabel
	countdown = Lib.label({ Size = UDim2.new(0.4, 0, 0, 28), Position = UDim2.fromScale(0.6, 0), Text = "", Font = T.Title, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Right, MaxText = 22, Parent = session })
	Lib.textStroke(1.5).Parent = countdown

	local mine = Lib.panel({ Position = UDim2.fromOffset(0, 34), Size = UDim2.new(0.5, -4, 0.5, -34), Parent = session })
	Lib.padding(6).Parent = mine
	Lib.label({ Size = UDim2.new(0.5, 0, 0, 22), Text = "YOUR OFFER", Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, Parent = mine })
	myStatus = Lib.label({ Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromScale(0.5, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Right, MaxText = 16, Parent = mine })
	myOffer = itemGrid(mine, UDim2.fromOffset(0, 26), UDim2.new(1, 0, 1, -64))
	myMoney = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 1, -34),
		BackgroundColor3 = T.Bg,
		Font = T.Body,
		TextSize = 16,
		TextColor3 = T.Text,
		PlaceholderText = "💰 Add money (number)",
		Text = "0",
		ClearTextOnFocus = false,
		Parent = mine,
	}, { Lib.corner(8) })
	myMoney.FocusLost:Connect(function()
		sendOffer(offerUids())
	end)

	local theirs = Lib.panel({ Position = UDim2.new(0.5, 4, 0, 34), Size = UDim2.new(0.5, -4, 0.5, -34), Parent = session })
	Lib.padding(6).Parent = theirs
	Lib.label({ Size = UDim2.new(0.5, 0, 0, 22), Text = "THEIR OFFER", Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, Parent = theirs })
	theirStatus = Lib.label({ Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromScale(0.5, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Right, MaxText = 16, Parent = theirs })
	theirOffer = itemGrid(theirs, UDim2.fromOffset(0, 26), UDim2.new(1, 0, 1, -64))
	theirMoney = Lib.label({ Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 1, -34), Text = "", TextColor3 = T.Green, MaxText = 18, Parent = theirs })

	local pick = Lib.panel({ Position = UDim2.new(0, 0, 0.5, 6), Size = UDim2.new(1, 0, 0.5, -60), Parent = session })
	Lib.padding(6).Parent = pick
	Lib.label({ Size = UDim2.new(1, 0, 0, 20), Text = "Tap your treasures to add them (max " .. Config.Trade.MaxItems .. ")", TextColor3 = T.SubText, MaxText = 15, Parent = pick })
	picker = itemGrid(pick, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 1, -24))

	local buttons = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 46), Parent = session }, {
		Lib.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	readyButton = Lib.button({ Text = "READY", Color = T.Green, Size = UDim2.fromOffset(170, 44), Parent = buttons, OnClick = function()
		if trade then
			State.Request("TradeReady", not trade.Mine.Ready)
		end
	end })
	Lib.button({ Text = "✕ Cancel", Color = T.Red, Size = UDim2.fromOffset(150, 44), Parent = buttons, OnClick = function()
		State.Request("TradeCancel")
	end })

	Remotes.TradeUpdate.OnClientEvent:Connect(function(view, reason)
		local wasTrading = trade ~= nil
		trade = view or nil
		if view and not wasTrading then
			Windows.Open("Trade")
		end
		if not view and reason and Windows.IsOpen("Trade") then
			Windows.Close()
		end
		refresh()
	end)
	State.FullChanged.Event:Connect(function()
		if isOpen and trade then
			refreshPicker()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if isOpen and not trade then
			refreshLobby()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if isOpen and not trade then
				refreshLobby()
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			if trade and trade.Status == "Confirming" then
				local left = math.max(0, trade.CountdownEnd - State.Now())
				countdown.Text = ("Trading in %.1fs..."):format(left)
			elseif countdown then
				countdown.Text = ""
			end
		end
	end)
end

function Trade.OnOpen()
	isOpen = true
	refresh()
end

function Trade.OnClose()
	isOpen = false
	if trade then
		-- closing the window cancels the trade so nobody gets stuck
		State.Ask("TradeCancel")
	end
end

return Trade
