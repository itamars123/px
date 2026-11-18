-- TradeService.lua
-- Player-to-player trading, fully server validated:
--   request -> accept -> both sides set offers (treasures + money) -> both
--   ready -> 3 second confirm countdown (any change cancels ready) -> atomic
--   swap with re-validation, then both saves are written immediately.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local S

local TradeService = {}

local pending: { [Player]: { [Player]: number } } = {} -- pending[target][from] = expiry
local nextId = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function view(trade, player: Player)
	local other = trade.A == player and trade.B or trade.A
	local function side(p)
		local items = {}
		local data = S.DataService.Get(p)
		for _, uid in ipairs(trade.Offers[p].Uids) do
			local t = data and data.Treasures[uid]
			if t then
				table.insert(items, { Uid = uid, Id = t.Id, Mut = t.Mut })
			end
		end
		local pets = {}
		for _, uid in ipairs(trade.Offers[p].Pets) do
			local pet = data and data.Pets[uid]
			if pet then
				table.insert(pets, { Uid = uid, Id = pet.Id })
			end
		end
		return { Items = items, Pets = pets, Money = trade.Offers[p].Money, Ready = trade.Ready[p] }
	end
	return {
		Id = trade.Id,
		Partner = { Name = other.DisplayName, UserId = other.UserId },
		Mine = side(player),
		Theirs = side(other),
		Status = trade.Status,
		CountdownEnd = trade.CountdownEnd,
	}
end

local function broadcast(trade)
	for _, p in ipairs({ trade.A, trade.B }) do
		if p.Parent then
			Remotes.TradeUpdate:FireClient(p, view(trade, p))
		end
	end
end

local function close(trade, reason: string?)
	if trade.Status == "Closed" then
		return
	end
	trade.Status = "Closed"
	for _, p in ipairs({ trade.A, trade.B }) do
		local ses = S.DataService.Session(p)
		if ses and ses.Trade and ses.Trade.Ref == trade then
			ses.Trade = nil
		end
		if p.Parent then
			Remotes.TradeUpdate:FireClient(p, false, reason)
			S.StateService.MarkFull(p)
		end
	end
end

local function tradeOf(player: Player)
	local ses = S.DataService.Session(player)
	return ses and ses.Trade and ses.Trade.Ref
end

local function unready(trade)
	trade.Ready[trade.A] = false
	trade.Ready[trade.B] = false
	trade.Status = "Open"
	trade.CountdownEnd = 0
end

-- Validates that `player` can give their current offer and receive the other.
local function validateSide(trade, giver: Player, receiver: Player)
	local gData, rData = S.DataService.Get(giver), S.DataService.Get(receiver)
	local gSes = S.DataService.Session(giver)
	if not gData or not rData or not gSes then
		return false, "A player left"
	end
	local offer = trade.Offers[giver]
	for _, uid in ipairs(offer.Uids) do
		local entry = gData.Treasures[uid]
		if not entry then
			return false, "An offered treasure no longer exists"
		end
		if gSes.Stealing[uid] then
			return false, "An offered treasure is being stolen!"
		end
	end
	for _, uid in ipairs(offer.Pets) do
		if not gData.Pets[uid] then
			return false, "An offered pet no longer exists"
		end
	end
	local petCount = 0
	for _ in pairs(rData.Pets) do
		petCount += 1
	end
	if petCount - #trade.Offers[receiver].Pets + #offer.Pets > Config.Pets.MaxOwned then
		return false, receiver.DisplayName .. " has too many pets"
	end
	if gData.Money < offer.Money then
		return false, giver.DisplayName .. " doesn't have enough money"
	end
	local recvOffer = trade.Offers[receiver]
	local newCount = S.TreasureService.Count(rData) - #recvOffer.Uids + #offer.Uids
	if newCount > S.TreasureService.Capacity(rData) then
		return false, receiver.DisplayName .. " doesn't have enough room"
	end
	return true
end

local function execute(trade)
	local ok, err = validateSide(trade, trade.A, trade.B)
	if ok then
		ok, err = validateSide(trade, trade.B, trade.A)
	end
	if not ok then
		unready(trade)
		broadcast(trade)
		for _, p in ipairs({ trade.A, trade.B }) do
			S.NetService.Notify(p, "Trade failed: " .. tostring(err), "error")
		end
		return
	end
	local aData, bData = S.DataService.Get(trade.A), S.DataService.Get(trade.B)
	-- remove from both first, then add (so capacity checks above hold)
	local moving = { [trade.A] = {}, [trade.B] = {} }
	local movingPets = { [trade.A] = {}, [trade.B] = {} }
	for _, pair in ipairs({ { trade.A, aData }, { trade.B, bData } }) do
		local p, data = pair[1], pair[2]
		for _, uid in ipairs(trade.Offers[p].Uids) do
			table.insert(moving[p], { Id = data.Treasures[uid].Id, Mut = data.Treasures[uid].Mut })
			data.Treasures[uid] = nil
		end
		for _, uid in ipairs(trade.Offers[p].Pets) do
			table.insert(movingPets[p], data.Pets[uid].Id)
			data.Pets[uid] = nil
		end
		data.Money -= trade.Offers[p].Money
	end
	local function receive(p: Player, data, ids, money, petIds)
		for _, id in ipairs(petIds) do
			local uid = Util.NewUid()
			while data.Pets[uid] do
				uid = Util.NewUid()
			end
			data.Pets[uid] = { Id = id, Equipped = false }
		end
		for _, item in ipairs(ids) do
			local uid = Util.NewUid()
			while data.Treasures[uid] do
				uid = Util.NewUid()
			end
			data.Treasures[uid] = { Id = item.Id, Plot = nil, Mut = item.Mut }
			data.Index[item.Id] = true
		end
		data.Money += money
		data.Stats.Trades += 1
	end
	receive(trade.A, aData, moving[trade.B], trade.Offers[trade.B].Money, movingPets[trade.B])
	receive(trade.B, bData, moving[trade.A], trade.Offers[trade.A].Money, movingPets[trade.A])

	for _, p in ipairs({ trade.A, trade.B }) do
		S.BaseService.Refresh(p)
		S.PetService.Refresh(p)
		task.spawn(S.DataService.Save, p, false)
		S.NetService.Notify(p, "🤝 Trade complete! New treasures are in your storage.", "success")
		Remotes.Effect:FireClient(p, "Confetti")
	end
	close(trade, "Trade complete!")
end

local function start(a: Player, b: Player)
	nextId += 1
	local trade = {
		Id = nextId,
		A = a,
		B = b,
		Offers = { [a] = { Uids = {}, Money = 0, Pets = {} }, [b] = { Uids = {}, Money = 0, Pets = {} } },
		Ready = { [a] = false, [b] = false },
		Status = "Open",
		CountdownEnd = 0,
	}
	S.DataService.Session(a).Trade = { Ref = trade, MyOffer = trade.Offers[a].Uids, MyPets = trade.Offers[a].Pets }
	S.DataService.Session(b).Trade = { Ref = trade, MyOffer = trade.Offers[b].Uids, MyPets = trade.Offers[b].Pets }
	broadcast(trade)
end

-- Handlers ----------------------------------------------------------------------
local function busy(p: Player): string?
	local ses = S.DataService.Session(p)
	if not ses then
		return "not loaded"
	end
	if ses.Trade then
		return "already trading"
	end
	if #ses.Carrying > 0 then
		return "carrying treasure"
	end
	return nil
end

local function onRequest(player: Player, targetUserId)
	if typeof(targetUserId) ~= "number" then
		return false, "Bad request"
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return false, "Player not found"
	end
	local b1 = busy(player)
	if b1 then
		return false, "You are " .. b1
	end
	local b2 = busy(target)
	if b2 then
		return false, target.DisplayName .. " is " .. b2
	end
	-- if they already asked us, just start
	if pending[player] and pending[player][target] and pending[player][target] > now() then
		pending[player][target] = nil
		start(target, player)
		return true, "Trade started!"
	end
	pending[target] = pending[target] or {}
	if pending[target][player] and pending[target][player] > now() then
		return false, "Request already sent"
	end
	pending[target][player] = now() + Config.Trade.RequestTimeout
	Remotes.TradeRequest:FireClient(target, player.UserId, player.DisplayName, Config.Trade.RequestTimeout)
	return true, "Trade request sent to " .. target.DisplayName
end

local function onRespond(player: Player, fromUserId, accept)
	if typeof(fromUserId) ~= "number" then
		return false, "Bad request"
	end
	local from = Players:GetPlayerByUserId(fromUserId)
	local list = pending[player]
	if not from or not list or not list[from] or list[from] < now() then
		return false, "That request expired"
	end
	list[from] = nil
	if not accept then
		S.NetService.Notify(from, player.DisplayName .. " declined your trade.", "warn")
		return true
	end
	local b1, b2 = busy(player), busy(from)
	if b1 or b2 then
		return false, "Someone is busy right now"
	end
	start(from, player)
	return true
end

local function onOffer(player: Player, uids, money, petUids)
	local trade = tradeOf(player)
	if not trade or trade.Status == "Closed" then
		return false, "No active trade"
	end
	if typeof(uids) ~= "table" then
		return false, "Bad request"
	end
	local data = S.DataService.Get(player)
	local ses = S.DataService.Session(player)
	local clean = {}
	local seen = {}
	for _, uid in ipairs(uids) do
		if typeof(uid) == "string" and not seen[uid] and data.Treasures[uid] and not ses.Stealing[uid] then
			seen[uid] = true
			table.insert(clean, uid)
			if #clean >= Config.Trade.MaxItems then
				break
			end
		end
	end
	local cleanPets = {}
	local petsChanged = false
	if typeof(petUids) == "table" then
		for _, uid in ipairs(petUids) do
			if typeof(uid) == "string" and not seen[uid] and data.Pets[uid] then
				seen[uid] = true
				table.insert(cleanPets, uid)
				if data.Pets[uid].Equipped then
					data.Pets[uid].Equipped = false -- offered pets stop following
					petsChanged = true
				end
				if #cleanPets >= Config.Trade.MaxItems then
					break
				end
			end
		end
	end
	trade.Offers[player].Pets = cleanPets
	ses.Trade.MyPets = cleanPets
	if petsChanged then
		S.PetService.Refresh(player)
	end
	local m = (typeof(money) == "number" and money == money) and math.floor(math.clamp(money, 0, data.Money)) or 0
	trade.Offers[player].Uids = clean
	trade.Offers[player].Money = m
	ses.Trade.MyOffer = clean
	-- offered treasures leave their platforms so they can't earn/be stolen mid-trade
	for _, uid in ipairs(clean) do
		data.Treasures[uid].Plot = nil
	end
	S.BaseService.Refresh(player)
	unready(trade)
	broadcast(trade)
	S.StateService.MarkFull(player)
	return true
end

local function onReady(player: Player, ready)
	local trade = tradeOf(player)
	if not trade or trade.Status == "Closed" then
		return false, "No active trade"
	end
	trade.Ready[player] = ready == true
	if trade.Ready[trade.A] and trade.Ready[trade.B] then
		trade.Status = "Confirming"
		trade.CountdownEnd = now() + Config.Trade.ConfirmCountdown
		local myToken = {}
		trade.Token = myToken
		task.delay(Config.Trade.ConfirmCountdown, function()
			if trade.Token == myToken and trade.Status == "Confirming" and trade.Ready[trade.A] and trade.Ready[trade.B] then
				execute(trade)
			end
		end)
	else
		trade.Status = "Open"
		trade.CountdownEnd = 0
	end
	broadcast(trade)
	return true
end

local function onCancel(player: Player)
	local trade = tradeOf(player)
	if not trade then
		return false, "No active trade"
	end
	close(trade, player.DisplayName .. " cancelled the trade.")
	return true
end

function TradeService.Init(services)
	S = services
end

function TradeService.Start()
	S.NetService.Handle("TradeRequest", onRequest)
	S.NetService.Handle("TradeRespond", onRespond)
	S.NetService.Handle("TradeOffer", onOffer)
	S.NetService.Handle("TradeReady", onReady)
	S.NetService.Handle("TradeCancel", onCancel)
	Players.PlayerRemoving:Connect(function(player)
		local trade = tradeOf(player)
		if trade then
			close(trade, player.DisplayName .. " left the game.")
		end
		pending[player] = nil
		for _, list in pairs(pending) do
			list[player] = nil
		end
	end)
end

return TradeService
