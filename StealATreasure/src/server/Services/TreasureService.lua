-- TreasureService.lua
-- Treasure ownership + the world economy:
--   * free treasures spawning in fields / secret areas / events
--   * the central marketplace stalls (buy with money, carry home)
--   * giving, placing, storing and selling owned treasures
--   * secret-area discovery rewards and the Treasure Magnet ability

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local TreasureModels = require(Shared.TreasureModels)
local UpgradeData = require(Shared.UpgradeData)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local S

local TreasureService = {}
TreasureService.World = {} :: { [string]: any }

local rng = Random.new()
local worldFolder: Folder
local marketSign: TextLabel?
local nextRestock = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function hrpOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Ownership ---------------------------------------------------------------------
function TreasureService.Count(data): number
	local n = 0
	for _ in pairs(data.Treasures) do
		n += 1
	end
	return n
end

function TreasureService.Capacity(data): number
	return UpgradeData.PlotCount(data) + Config.MaxStorage
end

function TreasureService.IsFull(player: Player, extra: number?): boolean
	local data = S.DataService.Get(player)
	if not data then
		return true
	end
	return TreasureService.Count(data) + (extra or 0) > TreasureService.Capacity(data)
end

-- Adds a treasure to a player. opts: { Source, Silent, NoAutoPlace }
function TreasureService.Give(player: Player, id: string, opts)
	opts = opts or {}
	local data = S.DataService.Get(player)
	local def = TreasureData.Get(id)
	if not data or not def then
		return nil
	end
	if TreasureService.Count(data) >= TreasureService.Capacity(data) then
		local value = math.floor(def.Value * Config.SellMultiplier)
		S.EconomyService.AddMoney(player, value)
		S.NetService.Notify(player, ("No room! %s was auto-sold for %s"):format(def.Name, Util.Money(value)), "warn")
		return nil
	end
	local uid = Util.NewUid()
	while data.Treasures[uid] do
		uid = Util.NewUid()
	end
	local plot = (not opts.NoAutoPlace) and S.BaseService.FreePlot(player) or nil
	data.Treasures[uid] = { Id = id, Plot = plot }
	data.Stats.Collected += 1

	-- discovery bonus
	if not data.Index[id] then
		data.Index[id] = true
		local bonus = math.floor(def.MPS * 10 * Config.DiscoveryBonusMultiplier)
		S.EconomyService.AddMoney(player, bonus)
		if not opts.Silent then
			S.NetService.Notify(player, ("📖 NEW DISCOVERY: %s! +%s"):format(def.Name, Util.Money(bonus)), "discovery")
		end
	elseif not opts.Silent then
		S.NetService.Notify(player, ("+ %s (%s)%s"):format(def.Name, def.Rarity, plot and "" or " → storage"), "success")
	end
	local xp = opts.Source == "Market" and Config.XP.Buy or Config.XP.Collect
	if opts.Source ~= "Steal" and opts.Source ~= "Trade" and opts.Source ~= "Rebirth" then
		S.EconomyService.AddXP(player, xp)
	end
	Remotes.Effect:FireClient(player, "Deposit", def.Rarity)
	S.BaseService.Refresh(player)
	S.StateService.MarkFull(player)
	return uid
end

function TreasureService.Store(player: Player, uid: string)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session then
		return false, "Not ready"
	end
	local entry = data.Treasures[uid]
	if typeof(uid) ~= "string" or not entry then
		return false, "Unknown treasure"
	end
	if not entry.Plot then
		return false, "Already in storage"
	end
	if session.Stealing[uid] then
		return false, "It's being stolen!"
	end
	if S.BaseService.CountStored(data) >= Config.MaxStorage then
		return false, "Storage is full"
	end
	entry.Plot = nil
	S.BaseService.Refresh(player)
	S.StateService.MarkFull(player)
	return true, "Moved to storage"
end

function TreasureService.Place(player: Player, uid: string, plot: number?)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session then
		return false, "Not ready"
	end
	if typeof(uid) ~= "string" then
		return false, "Bad request"
	end
	local entry = data.Treasures[uid]
	if not entry then
		return false, "Unknown treasure"
	end
	if session.Trade and table.find(session.Trade.MyOffer or {}, uid) then
		return false, "That treasure is in a trade"
	end
	local target = nil
	if typeof(plot) == "number" then
		plot = math.floor(plot)
		if plot < 1 or plot > UpgradeData.PlotCount(data) then
			return false, "That platform is locked"
		end
		for _, t in pairs(data.Treasures) do
			if t.Plot == plot then
				return false, "That platform is taken"
			end
		end
		target = plot
	else
		target = S.BaseService.FreePlot(player)
	end
	if not target then
		return false, "No free platforms! Expand your base."
	end
	if entry.Plot then
		return false, "Already placed"
	end
	entry.Plot = target
	S.BaseService.Refresh(player)
	S.StateService.MarkFull(player)
	return true, "Placed on platform " .. target
end

local function sellOne(player: Player, data, session, uid: string): number?
	local entry = data.Treasures[uid]
	if not entry or session.Stealing[uid] then
		return nil
	end
	if session.Trade and table.find(session.Trade.MyOffer or {}, uid) then
		return nil
	end
	local def = TreasureData.Get(entry.Id)
	local value = def and math.floor(def.Value * Config.SellMultiplier) or 0
	data.Treasures[uid] = nil
	return value
end

function TreasureService.Sell(player: Player, uid: string)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session or typeof(uid) ~= "string" then
		return false, "Bad request"
	end
	local value = sellOne(player, data, session, uid)
	if not value then
		return false, "Can't sell that right now"
	end
	S.EconomyService.AddMoney(player, value)
	S.EconomyService.AddXP(player, Config.XP.Sell)
	S.BaseService.Refresh(player)
	S.StateService.MarkFull(player)
	Remotes.Effect:FireClient(player, "Sell", value)
	return true, "Sold for " .. Util.Money(value)
end

-- Sells everything in storage (optionally only up to a rarity rank).
function TreasureService.SellStorage(player: Player, maxRank: number?)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session then
		return false, "Not ready"
	end
	local cap = typeof(maxRank) == "number" and maxRank or 99
	local total, count = 0, 0
	for uid, entry in pairs(table.clone(data.Treasures)) do
		local def = TreasureData.Get(entry.Id)
		if not entry.Plot and def and Rarities.Rank(def.Rarity) <= cap and not def.Exclusive then
			local v = sellOne(player, data, session, uid)
			if v then
				total += v
				count += 1
			end
		end
	end
	if count == 0 then
		return false, "Nothing to sell in storage"
	end
	S.EconomyService.AddMoney(player, total)
	S.StateService.MarkFull(player)
	Remotes.Effect:FireClient(player, "Sell", total)
	return true, ("Sold %d treasures for %s"):format(count, Util.Money(total))
end

-- World treasures --------------------------------------------------------------
local KIND_TEXT = {
	Field = { "Grab", 0.4 },
	Secret = { "Grab", 0.6 },
	Event = { "Grab", 0.8 },
	Market = { "Buy", 0.3 },
}

local function groundAt(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { worldFolder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return result and result.Position or pos
end

function TreasureService.RemoveWorld(uid: string)
	local w = TreasureService.World[uid]
	if w then
		TreasureService.World[uid] = nil
		if w.Model then
			w.Model:Destroy()
		end
	end
end

local tryPickup -- forward

function TreasureService.SpawnWorld(def, cf: CFrame, kind: string, extra)
	local uid = Util.NewUid()
	local scale = kind == "Market" and 1.1 or 1
	local model = TreasureModels.Build(def, { CFrame = cf, Scale = scale })
	model:SetAttribute("WorldUid", uid)
	model:SetAttribute("Kind", kind)
	local root = model.PrimaryPart :: BasePart
	local label = S.BaseService.MakeLabel(root, def, TreasureModels.Height(def, scale))
	label.MaxDistance = 90
	local price = extra and extra.Price
	if price then
		model:SetAttribute("Price", price)
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Name = "Price"
		priceLabel.BackgroundColor3 = Color3.fromRGB(30, 160, 60)
		priceLabel.Position = UDim2.new(0.15, 0, -0.45, 0)
		priceLabel.Size = UDim2.fromScale(0.7, 0.4)
		priceLabel.Font = Enum.Font.FredokaOne
		priceLabel.TextScaled = true
		priceLabel.TextColor3 = Color3.new(1, 1, 1)
		priceLabel.Text = Util.Money(price)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = priceLabel
		priceLabel.Parent = label
		label.Size = UDim2.fromOffset(180, 54)
		label.StudsOffset += Vector3.new(0, 1.2, 0)
	end
	local text = KIND_TEXT[kind] or KIND_TEXT.Field
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = price and ("Buy " .. Util.Money(price)) or text[1]
	prompt.ObjectText = def.Name .. " (" .. def.Rarity .. ")"
	prompt.HoldDuration = text[2]
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", kind)
	prompt.Parent = root
	local record = {
		Uid = uid,
		Id = def.Id,
		Kind = kind,
		Model = model,
		Spawned = os.clock(),
		Price = price,
		Region = extra and extra.Region,
		Lifetime = extra and extra.Lifetime or Config.Spawns.Lifetime,
	}
	TreasureService.World[uid] = record
	prompt.Triggered:Connect(function(player)
		tryPickup(player, uid)
	end)
	model.Parent = worldFolder
	if Rarities.Info[def.Rarity].Announce and kind ~= "Event" then
		local where = kind == "Market" and "the Treasure Market" or (extra and extra.Region) or "the world"
		Remotes.Announce:FireAllClients(("✨ A %s %s appeared in %s!"):format(def.Rarity, def.Name, tostring(where)), def.Rarity)
	end
	return record
end

function TreasureService.DropToWorld(id: string, position: Vector3, kind: string?)
	local def = TreasureData.Get(id)
	if not def then
		return
	end
	local ground = groundAt(position)
	TreasureService.SpawnWorld(def, CFrame.new(ground), kind == "Market" and "Field" or (kind or "Field"), { Lifetime = 60, Region = "Dropped" })
end

tryPickup = function(player: Player, uid: string)
	local record = TreasureService.World[uid]
	local session = S.DataService.Session(player)
	local data = S.DataService.Get(player)
	if not record or not session or not data then
		return false
	end
	local hrp = hrpOf(player)
	if not hrp then
		return false
	end
	if (record.Model:GetPivot().Position - hrp.Position).Magnitude > Config.Spawns.PickupDistance + 4 then
		return false
	end
	if session.Trade then
		S.NetService.Notify(player, "Finish your trade first", "error")
		return false
	end
	if not S.CarryService.CanCarry(player) then
		S.NetService.Notify(player, "Your hands are full! Bring your treasure home first.", "error")
		return false
	end
	if TreasureService.IsFull(player, S.CarryService.Count(player) + 1) then
		S.NetService.Notify(player, "Your base & storage are full! Sell or expand.", "error")
		return false
	end
	if record.Price then
		if data.Money < record.Price then
			S.NetService.Notify(player, ("You need %s more!"):format(Util.Money(record.Price - data.Money)), "error")
			return false
		end
		data.Money -= record.Price
	end
	TreasureService.RemoveWorld(uid)
	S.CarryService.Add(player, { Id = record.Id, Source = record.Kind })
	Remotes.Effect:FireClient(player, "Pickup", TreasureData.Get(record.Id).Rarity)
	if record.Price then
		S.NetService.Notify(player, "Purchased! Carry it back to your base.", "success")
	end
	S.StateService.PushStats(player)
	return true
end
TreasureService.TryPickup = tryPickup

local function countKind(kind: string, region): number
	local n = 0
	for _, w in pairs(TreasureService.World) do
		if w.Kind == kind and w.Region == region then
			n += 1
		end
	end
	return n
end

local function spawnInField(field, pool)
	local r = rng:NextNumber(0, field.Radius)
	local a = rng:NextNumber(0, math.pi * 2)
	local pos = field.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local ground = groundAt(pos)
	local def = TreasureData.RollFromPool(pool or Config.SpawnPools.Field, rng)
	return TreasureService.SpawnWorld(def, CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), "Field", { Region = field.Name })
end
TreasureService.SpawnInField = spawnInField

local function restockMarket()
	-- clear old stock
	for uid, w in pairs(TreasureService.World) do
		if w.Kind == "Market" then
			TreasureService.RemoveWorld(uid)
		end
	end
	for _, stall in ipairs(S.MapBuilder.Map.Stalls) do
		local def = TreasureData.RollFromPool(Config.SpawnPools.Market, rng)
		local price = math.floor(def.Value * Config.Market.PriceMultiplier)
		TreasureService.SpawnWorld(def, stall.CFrame, "Market", { Price = price, Region = "Stall" .. stall.Index, Lifetime = math.huge })
	end
	nextRestock = now() + Config.Market.RestockSeconds
	workspace:SetAttribute("MarketRestock", nextRestock)
end

-- Remote handlers ------------------------------------------------------------------
function TreasureService.Init(services)
	S = services
end

function TreasureService.Start()
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "WorldTreasures"
	worldFolder.Parent = workspace

	local gem = S.MapBuilder.Map.FountainGem
	if gem then
		local _, label = S.MapBuilder.Billboard(gem, "", Color3.fromRGB(255, 255, 255), UDim2.fromOffset(300, 50), 9)
		marketSign = label
	end

	S.NetService.Handle("Store", function(player, uid)
		return TreasureService.Store(player, uid)
	end)
	S.NetService.Handle("Place", function(player, uid, plot)
		return TreasureService.Place(player, uid, plot)
	end)
	S.NetService.Handle("Sell", function(player, uid)
		return TreasureService.Sell(player, uid)
	end)
	S.NetService.Handle("SellStorage", function(player, maxRank)
		return TreasureService.SellStorage(player, maxRank)
	end)
	S.NetService.Handle("PlaceAll", function(player)
		local data = S.DataService.Get(player)
		if not data then
			return false, "Not ready"
		end
		local placed = 0
		for uid, entry in pairs(data.Treasures) do
			if not entry.Plot then
				local plot = S.BaseService.FreePlot(player)
				if not plot then
					break
				end
				entry.Plot = plot
				placed += 1
			end
		end
		S.BaseService.Refresh(player)
		S.StateService.MarkFull(player)
		return placed > 0, placed > 0 and ("Placed %d treasures"):format(placed) or "No free platforms"
	end)

	restockMarket()

	-- spawn + cleanup loop
	task.spawn(function()
		local fieldTimer, secretTimer = 0, 0
		while true do
			task.wait(1)
			fieldTimer += 1
			secretTimer += 1
			if fieldTimer >= Config.Spawns.FieldInterval then
				fieldTimer = 0
				for _, field in ipairs(S.MapBuilder.Map.Fields) do
					if countKind("Field", field.Name) < Config.Spawns.MaxPerField and rng:NextNumber() < 0.6 then
						spawnInField(field)
					end
				end
			end
			if secretTimer >= Config.Spawns.SecretInterval then
				secretTimer = 0
				for _, secret in ipairs(S.MapBuilder.Map.Secrets) do
					if countKind("Secret", secret.Name) < Config.Spawns.MaxPerSecret then
						local spot = secret.Spawns[rng:NextInteger(1, #secret.Spawns)]
						local def = TreasureData.RollFromPool(Config.SpawnPools.Secret, rng)
						TreasureService.SpawnWorld(def, CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), "Secret", { Region = secret.Name })
					end
				end
			end
			-- despawn expired
			local t = os.clock()
			for uid, w in pairs(TreasureService.World) do
				if w.Kind ~= "Market" and t - w.Spawned > w.Lifetime then
					TreasureService.RemoveWorld(uid)
				end
			end
			-- market restock
			local remaining = nextRestock - now()
			if remaining <= 0 then
				restockMarket()
				remaining = Config.Market.RestockSeconds
			end
			if marketSign then
				marketSign.Text = ("🛒 New stock in %ds"):format(math.ceil(remaining))
			end
		end
	end)

	-- secret discovery + treasure magnet
	task.spawn(function()
		local tickN = 0
		while true do
			task.wait(0.5)
			tickN += 1
			for _, player in ipairs(Players:GetPlayers()) do
				local data = S.DataService.Get(player)
				local hrp = hrpOf(player)
				if data and hrp then
					if tickN % 2 == 0 then
						for _, secret in ipairs(S.MapBuilder.Map.Secrets) do
							if not data.Secrets[secret.Name] then
								local rel = secret.Zone.CFrame:PointToObjectSpace(hrp.Position)
								local half = secret.Zone.Size / 2
								if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
									data.Secrets[secret.Name] = true
									local reward = 2500 * (1 + data.Rebirths)
									S.EconomyService.AddMoney(player, reward)
									S.EconomyService.AddXP(player, 100)
									S.NetService.Notify(player, ("🗺️ SECRET FOUND: %s! +%s"):format(secret.Name, Util.Money(reward)), "discovery")
									Remotes.Effect:FireClient(player, "Confetti")
									S.StateService.MarkFull(player)
								end
							end
						end
					end
					if data.Abilities.Magnet then
						local radius = 18
						for uid, w in pairs(TreasureService.World) do
							if w.Kind ~= "Market" and w.Model then
								if (w.Model:GetPivot().Position - hrp.Position).Magnitude <= radius then
									if not S.CarryService.CanCarry(player) then
										break
									end
									-- pull it close then pick up (server validates distance)
									w.Model:PivotTo(CFrame.new(hrp.Position))
									tryPickup(player, uid)
								end
							end
						end
					end
				end
			end
		end
	end)
end

return TreasureService
