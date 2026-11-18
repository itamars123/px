-- Main.client.lua
-- Client bootstrap: builds the interface, starts controllers and applies
-- player settings (UI scale for PC/mobile, sound, graphics).

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local State = require(Controllers.State)
local Sound = require(Controllers.Sound)
local WorldFX = require(Controllers.WorldFX)
local Input = require(Controllers.Input)
local Emotes = require(Controllers.Emotes)
local PetFollower = require(Controllers.PetFollower)
local Ambience = require(Controllers.Ambience)
local Music = require(Controllers.Music)
local Cinematic = require(Controllers.Cinematic)

local Lib = require(UI.Lib)
local Windows = require(UI.Windows)
local Notifications = require(UI.Notifications)
local HUD = require(UI.HUD)

local gui = Lib.new("ScreenGui", {
	Name = "StealATreasureUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = false,
	Parent = player:WaitForChild("PlayerGui"),
})
local uiScale = Lib.new("UIScale", { Parent = gui })

-- Responsive scaling: designed for 1280x720, scaled for phones/tablets/4K
local userScale = 1
local function rescale()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	local base = math.min(vp.X / 1280, vp.Y / 720)
	uiScale.Scale = math.clamp(base, 0.62, 1.5) * userScale
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
end)

State.Init()
Sound.Init()
Notifications.Init(gui)
State.SetNotifier(Notifications.Toast)
Windows.Init(gui)
HUD.Init(gui)

Windows.Register("Inventory", require(UI.InventoryWindow), { Title = "Inventory", Icon = "🎒", Color = Lib.Theme.Blue })
Windows.Register("Index", require(UI.IndexWindow), { Title = "Treasure Index", Icon = "📖", Color = Lib.Theme.Purple })
Windows.Register("Shop", require(UI.ShopWindow), { Title = "Upgrades & Abilities", Icon = "🛒", Color = Lib.Theme.Green })
Windows.Register("GemShop", require(UI.GemShopWindow), { Title = "Gem Shop & Base Style", Icon = "💎", Color = Lib.Theme.Blue })
Windows.Register("Pets", require(UI.PetsWindow), { Title = "Pets", Icon = "🐾", Color = Lib.Theme.Orange })
Windows.Register("Achievements", require(UI.AchievementsWindow), { Title = "Achievements", Icon = "🎖️", Color = Lib.Theme.Accent })
Windows.Register("Rebirth", require(UI.RebirthWindow), { Title = "Rebirth", Icon = "🌀", Color = Lib.Theme.Pink })
Windows.Register("Leaderboard", require(UI.LeaderboardWindow), { Title = "Leaderboards", Icon = "🏆", Color = Lib.Theme.Accent })
Windows.Register("Settings", require(UI.SettingsWindow), { Title = "Settings", Icon = "⚙️", Color = Lib.Theme.Panel2, Size = UDim2.fromScale(0.6, 0.8), MaxSize = Vector2.new(700, 620) })
Windows.Register("Trade", require(UI.TradeWindow), { Title = "Trading", Icon = "🤝", Color = Lib.Theme.Orange })

WorldFX.Init(Windows, Notifications)
WorldFX.Start()
Emotes.Start()
PetFollower.Start()
Ambience.Start()
Music.Start()
Cinematic.Start()
Input.Init(Windows, HUD)

local function applySettings(full)
	local s = full.Settings or {}
	userScale = s.UIScale or 1
	rescale()
	Sound.SetSettings(s)
	WorldFX.SetSettings(s)
	Ambience.SetSettings(s)
	Music.SetEnabled(s.Music ~= false)
	PetFollower.LowGfx = s.LowGfx == true
end
State.FullChanged.Event:Connect(applySettings)
if State.Full then
	applySettings(State.Full)
end

-- Cinematic intro on the first state (once per join)
local introDone = false
State.FullChanged.Event:Connect(function(full)
	if introDone then
		return
	end
	introDone = true
	if (full.Settings or {}).Intro ~= false then
		task.wait(1)
		Cinematic.PlayIntro(gui)
	end
end)

-- Welcome
task.delay(2, function()
	Notifications.Banner("💎 Welcome to STEAL A TREASURE! 💎", "Legendary")
	Notifications.Toast("Grab treasures in the fields or buy them at the market, then bring them home!", "info")
end)
