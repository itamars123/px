-- PlayerService.lua
-- Player lifecycle: leaderstats, base assignment, character setup (spawn at
-- base, movement stats, Bonk Hammer, overhead name tag, rebirth trail),
-- death handling and the settings / title remotes.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local UpgradeData = require(Shared.UpgradeData)

local S

local PlayerService = {}

function PlayerService.ApplyMovement(player: Player)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not session or not hum then
		return
	end
	local speed = UpgradeData.WalkSpeed(data)
	if #session.Carrying > 0 then
		speed *= S.CarryService.IsCarryingStolen(player) and 0.85 or 0.95
	end
	hum.WalkSpeed = speed
	hum.UseJumpPower = true
	hum.JumpPower = session.SuperJump and 115 or Config.BaseJumpPower
end

function PlayerService.UpdateOverhead(player: Player)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local bb = head:FindFirstChild("Overhead")
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "Overhead"
		bb.Size = UDim2.fromOffset(200, 64)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.MaxDistance = 90
		bb.LightInfluence = 0
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.3)
		title.Font = Enum.Font.GothamBlack
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 200, 80)
		local s1 = Instance.new("UIStroke")
		s1.Thickness = 2
		s1.Parent = title
		title.Parent = bb
		local name = Instance.new("TextLabel")
		name.Name = "PlayerName"
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0, 0.3)
		name.Size = UDim2.fromScale(1, 0.4)
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		local s2 = Instance.new("UIStroke")
		s2.Thickness = 2
		s2.Parent = name
		name.Parent = bb
		local info = Instance.new("TextLabel")
		info.Name = "Info"
		info.BackgroundTransparency = 1
		info.Position = UDim2.fromScale(0, 0.7)
		info.Size = UDim2.fromScale(1, 0.3)
		info.Font = Enum.Font.GothamBold
		info.TextScaled = true
		info.TextColor3 = Color3.fromRGB(150, 230, 255)
		local s3 = Instance.new("UIStroke")
		s3.Thickness = 2
		s3.Parent = info
		info.Parent = bb
		bb.Parent = head
	end
	bb.Title.Text = data.Title ~= "" and ("« " .. data.Title .. " »") or ""
	bb.PlayerName.Text = player.DisplayName
	bb.Info.Text = ("⭐ Lv.%d   🌀 %d"):format(data.Level, data.Rebirths)
	bb.Enabled = not (session and session.Cloaked)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

function PlayerService.ApplyTrail(player: Player)
	local data = S.DataService.Get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not data or not hrp then
		return
	end
	local old = hrp:FindFirstChild("RebirthTrail")
	if old then
		old:Destroy()
	end
	if not data.Trail or data.Trail == "" then
		return
	end
	local ok, color = pcall(Color3.fromHex, data.Trail)
	if not ok then
		return
	end
	local a0 = hrp:FindFirstChild("TrailA0") or Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = hrp
	local a1 = hrp:FindFirstChild("TrailA1") or Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -0.8, 0)
	a1.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Name = "RebirthTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 0.8
	trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = hrp
end

local function setupCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hum or not hrp then
		return
	end
	local session = S.DataService.Session(player)
	if session then
		session.Cloaked = false
		session.SuperJump = false
	end
	task.defer(function()
		local cf = S.BaseService.SpawnCFrame(player)
		if cf and hrp.Parent then
			hrp.CFrame = cf
		end
	end)
	PlayerService.ApplyMovement(player)
	PlayerService.UpdateOverhead(player)
	PlayerService.ApplyTrail(player)
	S.StealService.GiveHammer(player)
	hum.Died:Connect(function()
		S.CarryService.OnDied(player, hrp.Position)
	end)
end

local function onLoaded(player: Player)
	-- NOTE: BindableEvents copy tables, so always use the live profile table.
	local data = S.DataService.Get(player)
	if not player.Parent or not data then
		return
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local money = Instance.new("StringValue")
	money.Name = "Money"
	money.Parent = ls
	local rb = Instance.new("IntValue")
	rb.Name = "Rebirths"
	rb.Parent = ls
	local lvl = Instance.new("IntValue")
	lvl.Name = "Level"
	lvl.Parent = ls
	ls.Parent = player

	local index = S.BaseService.Assign(player)
	if not index then
		player:Kick("This server is full (all bases taken). Please join another server!")
		return
	end
	-- treasures on now-locked plots (data from older versions) go to storage
	local plots = UpgradeData.PlotCount(data)
	for _, t in pairs(data.Treasures) do
		if t.Plot and (t.Plot > plots or t.Plot < 1) then
			t.Plot = nil
		end
	end
	S.BaseService.Refresh(player)
	S.EconomyService.GrantOffline(player)
	S.StateService.MarkFull(player)
	player:SetAttribute("Loaded", true)

	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
	if not S.DataService.CanSave() then
		task.delay(4, function()
			S.NetService.Notify(player, "⚠️ Saving is off in this session (Studio without API access).", "warn")
		end)
	end
end

function PlayerService.Init(services)
	S = services
	Players.CharacterAutoLoads = true
end

function PlayerService.Start()
	S.DataService.Loaded.Event:Connect(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		S.BaseService.Release(player)
	end)

	S.NetService.Handle("UpdateSettings", function(player, settings)
		local data = S.DataService.Get(player)
		if not data or typeof(settings) ~= "table" then
			return false, "Bad request"
		end
		for _, key in ipairs({ "Music", "Sfx", "LowGfx", "Effects" }) do
			if typeof(settings[key]) == "boolean" then
				data.Settings[key] = settings[key]
			end
		end
		if typeof(settings.UIScale) == "number" then
			data.Settings.UIScale = math.clamp(settings.UIScale, 0.6, 1.4)
		end
		S.StateService.MarkFull(player)
		return true
	end)

	S.NetService.Handle("SetTitle", function(player, title)
		local data = S.DataService.Get(player)
		if not data or typeof(title) ~= "string" then
			return false, "Bad request"
		end
		if title ~= "" and not table.find(data.Titles, title) then
			return false, "You haven't unlocked that title"
		end
		data.Title = title
		PlayerService.UpdateOverhead(player)
		S.StateService.MarkFull(player)
		return true, title == "" and "Title removed" or ("Title set: " .. title)
	end)
end

return PlayerService
