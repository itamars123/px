-- LoadingScreen.client.luau
-- Replaces the default Roblox loading screen (skill: game-scaffold loading
-- screen). Shows the title, a progress bar and gameplay tips while the game
-- and the server-built world load, then fades out. Lives in ReplicatedFirst so
-- it runs before anything else replicates.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(22, 20, 44)
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(70, 40, 140), Color3.fromRGB(20, 20, 50))
grad.Rotation = 90
grad.Parent = bg

local function label(text: string, y: number, size: number, color: Color3, font: Enum.Font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(0.9, 0, size, 0)
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(15, 10, 30)
	st.Parent = l
	l.Parent = bg
	return l
end

local gem = label("💎", 0.3, 0.16, Color3.new(1, 1, 1), Enum.Font.FredokaOne)
label("STEAL A TREASURE", 0.45, 0.1, Color3.fromRGB(255, 205, 60), Enum.Font.FredokaOne)
local tip = label("", 0.72, 0.04, Color3.fromRGB(200, 205, 240), Enum.Font.GothamBold)

local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5, 0.5)
barBg.Position = UDim2.fromScale(0.5, 0.62)
barBg.Size = UDim2.fromScale(0.42, 0.028)
barBg.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
barBg.Parent = bg
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(255, 196, 50)
fill.Parent = barBg
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

local TIPS = {
	"Buy treasures on the Parade — they walk home by themselves!",
	"Step on a stand's green plate to collect its cash.",
	"Lock your base before you go stealing!",
	"Bonk thieves with your bat to get your treasure back.",
	"Gold, Diamond and Rainbow mutations multiply income.",
	"Pets boost your income, luck, speed and gems.",
}
local tipIndex = 1
tip.Text = "💡 " .. TIPS[1]

local spin = TweenService:Create(gem, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 12, Size = UDim2.new(0.95, 0, 0.18, 0) })
spin:Play()

local progress = 0
local function setProgress(p: number)
	progress = math.max(progress, p)
	TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(progress, 1) }):Play()
end

task.spawn(function()
	while gui.Parent do
		task.wait(3)
		tipIndex = tipIndex % #TIPS + 1
		tip.Text = "💡 " .. TIPS[tipIndex]
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(0.4)
-- wait for the server-built world and remotes
local start = os.clock()
while os.clock() - start < 25 do
	local map = workspace:FindFirstChild("Map")
	local bases = workspace:FindFirstChild("Bases")
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local ready = (map and 1 or 0) + (bases and 1 or 0) + (remotes and 1 or 0)
	setProgress(0.4 + ready * 0.15)
	if ready == 3 and player:GetAttribute("Loaded") then
		break
	end
	task.wait(0.25)
end
pcall(function()
	ContentProvider:PreloadAsync({ gui })
end)
setProgress(1)
task.wait(0.4)
spin:Cancel()
local fade = TweenInfo.new(0.6)
TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
for _, d in ipairs(bg:GetDescendants()) do
	if d:IsA("TextLabel") then
		TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, fade, { Transparency = 1 }):Play()
	end
end
task.wait(0.7)
gui:Destroy()
