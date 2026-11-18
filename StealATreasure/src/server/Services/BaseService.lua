-- BaseService.lua
-- Personal bases: building the 8 base shells, assigning them to players,
-- rendering placed treasures on display platforms, the door barrier lock,
-- alarm lights and the owner sign.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local TreasureModels = require(Shared.TreasureModels)
local UpgradeData = require(Shared.UpgradeData)
local Rarities = require(Shared.Rarities)
local Util = require(Shared.Util)

local S -- services table

local BaseService = {}
BaseService.Bases = {} :: { any }

local BASE_COLORS = {
	Color3.fromRGB(255, 95, 95),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(250, 220, 70),
	Color3.fromRGB(100, 220, 110),
	Color3.fromRGB(70, 200, 255),
	Color3.fromRGB(120, 120, 255),
	Color3.fromRGB(200, 110, 255),
	Color3.fromRGB(255, 110, 200),
}

local function now()
	return workspace:GetServerTimeNow()
end

local function part(parent, size, cf, color, material, props)
	return S.MapBuilder.Part(parent, size, cf, color, material, props)
end

-- Shell -------------------------------------------------------------------------
local function plotLocal(index: number): Vector3
	local r = math.floor((index - 1) / Config.PlotColumns)
	local c = (index - 1) % Config.PlotColumns
	local x = (c - (Config.PlotColumns - 1) / 2) * Config.PlotSpacing
	local z = 2 + r * Config.PlotSpacing
	return Vector3.new(x, 0, z)
end

local function buildShell(index: number, cf: CFrame, parent: Instance)
	local color = BASE_COLORS[(index - 1) % #BASE_COLORS + 1]
	local half = Config.BaseSize / 2
	local wallH = Config.BaseWallHeight
	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model:SetAttribute("Index", index)
	model:SetAttribute("OwnerId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("LockEnd", 0)

	local function L(x, y, z)
		return cf * CFrame.new(x, y, z)
	end

	part(model, Vector3.new(Config.BaseSize, 1, Config.BaseSize), L(0, 0.5, 0), Color3.fromRGB(235, 230, 220), Enum.Material.WoodPlanks, { Name = "Floor" })
	part(model, Vector3.new(Config.BaseSize - 8, 0.2, Config.BaseSize - 30), L(0, 1.05, 12), color:Lerp(Color3.new(1, 1, 1), 0.55), Enum.Material.Fabric, { Name = "Carpet" })

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = model
	local wallColor = color:Lerp(Color3.new(1, 1, 1), 0.25)
	part(walls, Vector3.new(2, wallH, Config.BaseSize), L(-half + 1, wallH / 2 + 1, 0), wallColor, Enum.Material.Brick)
	part(walls, Vector3.new(2, wallH, Config.BaseSize), L(half - 1, wallH / 2 + 1, 0), wallColor, Enum.Material.Brick)
	part(walls, Vector3.new(Config.BaseSize, wallH, 2), L(0, wallH / 2 + 1, half - 1), wallColor, Enum.Material.Brick)
	local doorW = 16
	local sideW = (Config.BaseSize - doorW) / 2
	part(walls, Vector3.new(sideW, wallH, 2), L(-(doorW / 2 + sideW / 2), wallH / 2 + 1, -half + 1), wallColor, Enum.Material.Brick)
	part(walls, Vector3.new(sideW, wallH, 2), L(doorW / 2 + sideW / 2, wallH / 2 + 1, -half + 1), wallColor, Enum.Material.Brick)
	part(walls, Vector3.new(doorW, wallH - 14, 2), L(0, wallH - (wallH - 14) / 2 + 1, -half + 1), wallColor, Enum.Material.Brick)
	-- Wall trims
	part(walls, Vector3.new(Config.BaseSize + 1, 1.2, 3), L(0, wallH + 1.6, half - 1), color, Enum.Material.SmoothPlastic)
	part(walls, Vector3.new(Config.BaseSize + 1, 1.2, 3), L(0, wallH + 1.6, -half + 1), color, Enum.Material.SmoothPlastic)
	part(walls, Vector3.new(3, 1.2, Config.BaseSize + 1), L(-half + 1, wallH + 1.6, 0), color, Enum.Material.SmoothPlastic)
	part(walls, Vector3.new(3, 1.2, Config.BaseSize + 1), L(half - 1, wallH + 1.6, 0), color, Enum.Material.SmoothPlastic)
	-- corner towers
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local x, z = c[1] * (half - 1), c[2] * (half - 1)
		part(walls, Vector3.new(6, wallH + 6, 6), L(x, (wallH + 6) / 2 + 1, z), color, Enum.Material.Brick)
		part(walls, Vector3.new(7, 4, 7), L(x, wallH + 9, z), Color3.fromRGB(70, 60, 90), Enum.Material.Slate)
	end

	-- Door barrier (laser wall)
	local barrier = part(model, Vector3.new(doorW, 14, 1), L(0, 8, -half + 1), Color3.fromRGB(255, 40, 60), Enum.Material.ForceField, {
		Name = "Barrier",
		Transparency = 1,
		CanCollide = false,
	})
	for i = 0, 3 do
		part(model, Vector3.new(doorW, 0.25, 0.25), L(0, 2.5 + i * 3.2, -half + 1), Color3.fromRGB(255, 60, 80), Enum.Material.Neon, {
			Name = "Laser",
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
	end
	-- door frame lights
	for _, x in ipairs({ -doorW / 2 - 0.5, doorW / 2 + 0.5 }) do
		part(model, Vector3.new(1, 14, 2.4), L(x, 8, -half + 1), Color3.fromRGB(60, 255, 140), Enum.Material.Neon, { Name = "DoorLight" })
	end

	-- Lock button
	local button = part(model, Vector3.new(3, 3, 3), L(-12, 2.5, -half + 6), Color3.fromRGB(255, 60, 60), Enum.Material.Neon, { Name = "LockButton" })
	part(model, Vector3.new(4, 1, 4), L(-12, 1.5, -half + 6), Color3.fromRGB(50, 50, 60), Enum.Material.Metal)
	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.Name = "LockPrompt"
	lockPrompt.ActionText = "Lock Base"
	lockPrompt.ObjectText = "🔒 Security"
	lockPrompt.MaxActivationDistance = 10
	lockPrompt.RequiresLineOfSight = false
	lockPrompt:SetAttribute("OwnerOnly", true)
	lockPrompt.Parent = button

	-- Alarm lights + siren sound
	local alarms = Instance.new("Folder")
	alarms.Name = "AlarmLights"
	alarms.Parent = model
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local light = part(alarms, Vector3.new(2.5, 2.5, 2.5), L(c[1] * (half - 1), wallH + 12.5, c[2] * (half - 1)), Color3.fromRGB(90, 90, 100), Enum.Material.Glass, { Name = "Alarm", Shape = Enum.PartType.Ball })
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 30, 30)
		pl.Range = 40
		pl.Brightness = 4
		pl.Enabled = false
		pl.Parent = light
	end
	local siren = Instance.new("Sound")
	siren.Name = "Siren"
	siren.SoundId = Config.Sounds.Alarm
	siren.Volume = 1
	siren.PlaybackSpeed = 0.6
	siren.RollOffMaxDistance = 220
	siren.Looped = true
	siren.Parent = model:FindFirstChild("Floor")

	-- Sign above the door
	local signPart = part(model, Vector3.new(26, 7, 1), L(0, wallH + 6, -half - 0.6), Color3.fromRGB(30, 30, 50), Enum.Material.SmoothPlastic, { Name = "Sign" })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = signPart
	-- (the sign's Front face already points at the plaza, where visitors come from)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.6)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
	title.Text = "EMPTY BASE"
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(255, 230, 120)
	sub.Text = ""
	sub.Parent = gui

	-- Plots
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = model
	local plotParts = {}
	local total = Config.PlotColumns * Config.PlotRows
	for i = 1, total do
		local lp = plotLocal(i)
		local plot = part(plots, Vector3.new(6, 1.5, 6), L(lp.X, 1.75, lp.Z), Color3.fromRGB(250, 250, 255), Enum.Material.Marble, { Name = "Plot" .. i })
		plot:SetAttribute("Index", i)
		local rim = part(plots, Vector3.new(6.4, 0.3, 6.4), L(lp.X, 2.4, lp.Z), color, Enum.Material.Neon, { Name = "Rim" .. i, CanCollide = false })
		local lockBB, lockLabel = S.MapBuilder.Billboard(plot, "🔒", Color3.fromRGB(255, 255, 255), UDim2.fromOffset(40, 40), 2)
		lockBB.Name = "LockedLabel"
		lockBB.MaxDistance = 80
		lockLabel.Text = "🔒"
		plotParts[i] = { Plot = plot, Rim = rim, LockBB = lockBB }
	end

	local treasures = Instance.new("Folder")
	treasures.Name = "Treasures"
	treasures.Parent = model

	local zone = part(model, Vector3.new(Config.BaseSize - 2, 40, Config.BaseSize - 2), L(0, 20, 0), Color3.new(), nil, {
		Name = "Zone",
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	model.Parent = parent
	return {
		Index = index,
		Model = model,
		CFrame = cf,
		Color = color,
		Barrier = barrier,
		Button = button,
		LockPrompt = lockPrompt,
		Siren = siren,
		Alarms = alarms,
		Title = title,
		Sub = sub,
		Plots = plotParts,
		TreasureFolder = treasures,
		Zone = zone,
		PlotModels = {}, -- [plotIndex] = { Uid, Model }
		Owner = nil :: Player?,
		AlarmUntil = 0,
	}
end

-- Queries --------------------------------------------------------------------------
function BaseService.Get(player: Player)
	local session = S.DataService.Session(player)
	if not session or not session.BaseIndex then
		return nil
	end
	return BaseService.Bases[session.BaseIndex]
end

function BaseService.IsInside(base, position: Vector3): boolean
	local rel = base.Zone.CFrame:PointToObjectSpace(position)
	local half = base.Zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

function BaseService.BaseAt(position: Vector3)
	for _, base in ipairs(BaseService.Bases) do
		if BaseService.IsInside(base, position) then
			return base
		end
	end
	return nil
end

function BaseService.SpawnCFrame(player: Player): CFrame?
	local base = BaseService.Get(player)
	if not base then
		return nil
	end
	return base.CFrame * CFrame.new(0, 4, -Config.BaseSize / 2 + 12) * CFrame.Angles(0, math.pi, 0)
end

function BaseService.IsLocked(player: Player): boolean
	local session = S.DataService.Session(player)
	return session ~= nil and session.LockEnd > now()
end

-- Plot index (1..unlocked) that holds no treasure, or nil.
function BaseService.FreePlot(player: Player): number?
	local data = S.DataService.Get(player)
	if not data then
		return nil
	end
	local used = {}
	for _, t in pairs(data.Treasures) do
		if t.Plot then
			used[t.Plot] = true
		end
	end
	for i = 1, UpgradeData.PlotCount(data) do
		if not used[i] then
			return i
		end
	end
	return nil
end

function BaseService.CountPlaced(data): number
	local n = 0
	for _, t in pairs(data.Treasures) do
		if t.Plot then
			n += 1
		end
	end
	return n
end

function BaseService.CountStored(data): number
	local n = 0
	for _, t in pairs(data.Treasures) do
		if not t.Plot then
			n += 1
		end
	end
	return n
end

-- Rendering -------------------------------------------------------------------------
local function makeLabel(root: BasePart, def, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(180, 54)
	bb.StudsOffset = Vector3.new(0, height + 1.2, 0)
	bb.MaxDistance = 55
	bb.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.4)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = def.Name
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = name
	name.Parent = bb
	local rarity = Instance.new("TextLabel")
	rarity.BackgroundTransparency = 1
	rarity.Position = UDim2.fromScale(0, 0.4)
	rarity.Size = UDim2.fromScale(1, 0.3)
	rarity.Font = Enum.Font.GothamBlack
	rarity.TextScaled = true
	rarity.TextColor3 = Rarities.Color(def.Rarity)
	rarity.Text = def.Rarity:upper()
	local st2 = Instance.new("UIStroke")
	st2.Thickness = 2
	st2.Parent = rarity
	rarity.Parent = bb
	local mps = Instance.new("TextLabel")
	mps.BackgroundTransparency = 1
	mps.Position = UDim2.fromScale(0, 0.7)
	mps.Size = UDim2.fromScale(1, 0.3)
	mps.Font = Enum.Font.GothamBold
	mps.TextScaled = true
	mps.TextColor3 = Color3.fromRGB(120, 255, 120)
	mps.Text = Util.Money(def.MPS) .. "/s"
	local st3 = Instance.new("UIStroke")
	st3.Thickness = 2
	st3.Parent = mps
	mps.Parent = bb
	bb.Parent = root
	return bb
end
BaseService.MakeLabel = makeLabel

local function promptOn(root: BasePart, name: string, action: string, object: string, hold: number, kind: string)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = kind == "Steal" and Enum.KeyCode.E or Enum.KeyCode.G
	p:SetAttribute("Kind", kind)
	p.Parent = root
	return p
end

function BaseService.Refresh(player: Player)
	local base = BaseService.Get(player)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not base or not data or not session then
		return
	end
	local unlocked = UpgradeData.PlotCount(data)
	local desired = {}
	for uid, t in pairs(data.Treasures) do
		if t.Plot and not session.Stealing[uid] then
			desired[t.Plot] = uid
		end
	end
	for i, p in ipairs(base.Plots) do
		local isUnlocked = i <= unlocked
		p.Plot.Transparency = isUnlocked and 0 or 0.55
		p.Rim.Transparency = isUnlocked and 0 or 0.8
		p.LockBB.Enabled = not isUnlocked

		local current = base.PlotModels[i]
		local want = desired[i]
		if current and current.Uid ~= want then
			current.Model:Destroy()
			base.PlotModels[i] = nil
			current = nil
		end
		if want and not current then
			local entry = data.Treasures[want]
			local def = TreasureData.Get(entry.Id)
			if def then
				local cf = p.Plot.CFrame * CFrame.new(0, p.Plot.Size.Y / 2, 0)
				local model = TreasureModels.Build(def, { CFrame = cf, Scale = 1 })
				model:SetAttribute("Uid", want)
				model:SetAttribute("OwnerId", player.UserId)
				local root = model.PrimaryPart :: BasePart
				makeLabel(root, def, TreasureModels.Height(def))
				local hold = UpgradeData.StealHold(data)
				local steal = promptOn(root, "StealPrompt", "Steal", def.Name, hold, "Steal")
				local store = promptOn(root, "StorePrompt", "Pick Up", def.Name, 0.3, "Store")
				steal.Triggered:Connect(function(thief)
					S.StealService.TryStart(thief, player, want)
				end)
				store.Triggered:Connect(function(who)
					if who == player then
						S.TreasureService.Store(player, want)
					end
				end)
				model.Parent = base.TreasureFolder
				base.PlotModels[i] = { Uid = want, Model = model }
			end
		end
	end
	BaseService.UpdateSign(player)
end

-- Updates steal hold time on existing prompts (after a protection upgrade).
function BaseService.RefreshPrompts(player: Player)
	local base = BaseService.Get(player)
	local data = S.DataService.Get(player)
	if not base or not data then
		return
	end
	local hold = UpgradeData.StealHold(data)
	for _, pm in pairs(base.PlotModels) do
		local prompt = pm.Model.PrimaryPart and pm.Model.PrimaryPart:FindFirstChild("StealPrompt")
		if prompt then
			prompt.HoldDuration = hold
		end
	end
end

function BaseService.UpdateSign(player: Player)
	local base = BaseService.Get(player)
	local session = S.DataService.Session(player)
	if not base or not session then
		return
	end
	base.Title.Text = player.DisplayName .. "'s Base"
	local lockText = ""
	local remaining = session.LockEnd - now()
	if remaining > 0 then
		lockText = ("  🔒 %ds"):format(math.ceil(remaining))
	end
	base.Sub.Text = ("💰 %s/s%s"):format(Util.Abbreviate(session.MPS or 0), lockText)
end

-- Locking ----------------------------------------------------------------------------
local function applyLockVisual(base, locked: boolean)
	base.Barrier.Transparency = locked and 0.35 or 1
	base.Barrier.CanCollide = locked
	for _, c in ipairs(base.Model:GetChildren()) do
		if c.Name == "Laser" then
			c.Transparency = locked and 0 or 1
		elseif c.Name == "DoorLight" then
			c.Color = locked and Color3.fromRGB(255, 50, 60) or Color3.fromRGB(60, 255, 140)
		end
	end
	base.Button.Color = locked and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 60, 60)
	base.Locked = locked
end

-- Moves non-owners standing inside a base out of the door.
local function ejectIntruders(base)
	local owner = base.Owner
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= owner then
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and BaseService.IsInside(base, hrp.Position) then
				hrp.CFrame = base.CFrame * CFrame.new(math.random(-6, 6), 4, -Config.BaseSize / 2 - 8)
				S.NetService.Notify(p, "The base locked and kicked you out!", "warn")
			end
		end
	end
end

function BaseService.SetLock(player: Player, seconds: number)
	local base = BaseService.Get(player)
	local session = S.DataService.Session(player)
	if not base or not session then
		return
	end
	session.LockEnd = math.max(session.LockEnd, now() + seconds)
	base.Model:SetAttribute("LockEnd", session.LockEnd)
	applyLockVisual(base, true)
	ejectIntruders(base)
	S.StateService.PushStats(player)
end

function BaseService.RequestLock(player: Player)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session or not session.BaseIndex then
		return false, "No base"
	end
	local t = now()
	if session.LockEnd > t then
		return false, "Your base is already locked"
	end
	if session.LockCooldownEnd > t then
		return false, ("Lock recharging: %ds"):format(math.ceil(session.LockCooldownEnd - t))
	end
	local duration = UpgradeData.LockDuration(data)
	BaseService.SetLock(player, duration)
	session.LockCooldownEnd = session.LockEnd + UpgradeData.LockCooldown(data)
	S.StateService.PushStats(player)
	return true, ("Base locked for %ds!"):format(duration)
end

-- Alarm ----------------------------------------------------------------------------
function BaseService.TriggerAlarm(owner: Player)
	local base = BaseService.Get(owner)
	if not base then
		return
	end
	base.AlarmUntil = os.clock() + 6
	if not base.Siren.IsPlaying then
		base.Siren:Play()
	end
end

-- Assignment -----------------------------------------------------------------------
function BaseService.Assign(player: Player): number?
	for _, base in ipairs(BaseService.Bases) do
		if base.Owner == nil then
			base.Owner = player
			local session = S.DataService.Session(player)
			session.BaseIndex = base.Index
			base.Model:SetAttribute("OwnerId", player.UserId)
			base.Model:SetAttribute("OwnerName", player.DisplayName)
			base.Model:SetAttribute("LockEnd", 0)
			applyLockVisual(base, false)
			player:SetAttribute("BaseIndex", base.Index)
			return base.Index
		end
	end
	return nil
end

function BaseService.Release(player: Player)
	for _, base in ipairs(BaseService.Bases) do
		if base.Owner == player then
			base.Owner = nil
			for i, pm in pairs(base.PlotModels) do
				pm.Model:Destroy()
				base.PlotModels[i] = nil
			end
			base.Model:SetAttribute("OwnerId", 0)
			base.Model:SetAttribute("OwnerName", "")
			base.Model:SetAttribute("LockEnd", 0)
			base.Title.Text = "EMPTY BASE"
			base.Sub.Text = ""
			base.Siren:Stop()
			applyLockVisual(base, false)
			for _, p in ipairs(base.Plots) do
				p.Plot.Transparency = 0.55
				p.Rim.Transparency = 0.8
				p.LockBB.Enabled = true
			end
		end
	end
end

function BaseService.Init(services)
	S = services
end

function BaseService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "Bases"
	folder.Parent = workspace
	for i, cf in ipairs(S.MapBuilder.Map.BaseSlots) do
		local base = buildShell(i, cf, folder)
		BaseService.Bases[i] = base
		base.LockPrompt.Triggered:Connect(function(who)
			if base.Owner == who then
				local ok, msg = BaseService.RequestLock(who)
				S.NetService.Notify(who, msg or "", ok and "success" or "error")
			end
		end)
	end

	S.NetService.Handle("LockBase", function(player)
		return BaseService.RequestLock(player)
	end)

	-- Lock expiry, alarm flashing and sign updates
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.25)
			tick += 1
			local t = now()
			for _, base in ipairs(BaseService.Bases) do
				local owner = base.Owner
				if owner then
					local session = S.DataService.Session(owner)
					if session then
						if base.Locked and session.LockEnd <= t then
							applyLockVisual(base, false)
							base.Model:SetAttribute("LockEnd", 0)
							S.StateService.PushStats(owner)
						end
						if tick % 4 == 0 then
							BaseService.UpdateSign(owner)
						end
					end
				end
				local alarming = os.clock() < base.AlarmUntil
				for _, light in ipairs(base.Alarms:GetChildren()) do
					local on = alarming and (tick % 2 == 0)
					light.Color = on and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(90, 90, 100)
					light.Material = on and Enum.Material.Neon or Enum.Material.Glass
					local pl = light:FindFirstChildOfClass("PointLight")
					if pl then
						pl.Enabled = on
					end
				end
				if not alarming and base.Siren.IsPlaying then
					base.Siren:Stop()
				end
			end
		end
	end)
end

return BaseService
