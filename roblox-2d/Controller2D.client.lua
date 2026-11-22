--[[
	Controller2D  (LocalScript → StarterPlayer > StarterPlayerScripts)
	Side-view camera, left/right-only movement, Z-axis lock,
	on-screen buttons for mobile, and a Hebrew HUD.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local PLANE_Z = 0
local CAMERA_DISTANCE = 45
local CAMERA_HEIGHT = 4
local CAMERA_SMOOTH = 10

---------------------------------------------------------------------
-- Turn off Roblox's default 3D controls (we drive movement ourselves)
---------------------------------------------------------------------
local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
playerModule:GetControls():Disable()

---------------------------------------------------------------------
-- INPUT
---------------------------------------------------------------------
local leftHeld, rightHeld, jumpHeld = false, false, false

local LEFT_KEYS = { [Enum.KeyCode.A] = true, [Enum.KeyCode.Left] = true }
local RIGHT_KEYS = { [Enum.KeyCode.D] = true, [Enum.KeyCode.Right] = true }
local JUMP_KEYS = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.W] = true, [Enum.KeyCode.Up] = true }

local function onInput(input, isDown)
	local key = input.KeyCode
	if LEFT_KEYS[key] then leftHeld = isDown end
	if RIGHT_KEYS[key] then rightHeld = isDown end
	if JUMP_KEYS[key] then jumpHeld = isDown end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	onInput(input, true)
end)
UserInputService.InputEnded:Connect(function(input)
	onInput(input, false)
end)

---------------------------------------------------------------------
-- HUD (coins + messages) and mobile buttons
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "HUD2D"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local coinLabel = Instance.new("TextLabel")
coinLabel.Size = UDim2.fromOffset(220, 50)
coinLabel.Position = UDim2.fromOffset(20, 20)
coinLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
coinLabel.BackgroundTransparency = 0.3
coinLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
coinLabel.Font = Enum.Font.GothamBold
coinLabel.TextScaled = true
coinLabel.Text = "🪙 מטבעות: 0"
coinLabel.Parent = gui
Instance.new("UICorner", coinLabel).CornerRadius = UDim.new(0, 12)

local messageLabel = Instance.new("TextLabel")
messageLabel.Size = UDim2.new(0.6, 0, 0, 60)
messageLabel.Position = UDim2.new(0.2, 0, 0.15, 0)
messageLabel.BackgroundTransparency = 1
messageLabel.TextColor3 = Color3.new(1, 1, 1)
messageLabel.TextStrokeTransparency = 0
messageLabel.Font = Enum.Font.GothamBlack
messageLabel.TextScaled = true
messageLabel.Text = ""
messageLabel.Parent = gui

local messageToken = 0
local function showMessage(text)
	messageToken += 1
	local token = messageToken
	messageLabel.Text = text
	task.delay(2.5, function()
		if token == messageToken then
			messageLabel.Text = ""
		end
	end)
end

task.spawn(function()
	local stats = player:WaitForChild("leaderstats")
	local coins = stats:WaitForChild("Coins")
	local function update()
		coinLabel.Text = "🪙 מטבעות: " .. coins.Value
	end
	update()
	coins.Changed:Connect(update)
end)

ReplicatedStorage:WaitForChild("Game2DMessage").OnClientEvent:Connect(showMessage)
showMessage("⬅️ ➡️ לזוז   |   רווח = קפיצה")

if UserInputService.TouchEnabled then
	local function makeButton(text, position, onChange)
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(90, 90)
		button.Position = position
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		button.BackgroundTransparency = 0.35
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextScaled = true
		button.Font = Enum.Font.GothamBold
		button.Text = text
		button.Parent = gui
		Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then onChange(true) end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then onChange(false) end
		end)
	end
	makeButton("◀", UDim2.new(0, 30, 1, -130), function(v) leftHeld = v end)
	makeButton("▶", UDim2.new(0, 140, 1, -130), function(v) rightHeld = v end)
	makeButton("⬆", UDim2.new(1, -130, 1, -130), function(v) jumpHeld = v end)
end

---------------------------------------------------------------------
-- MOVEMENT + Z LOCK + CAMERA
---------------------------------------------------------------------
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 50

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then return end

	-- Move only along X
	local direction = (rightHeld and 1 or 0) - (leftHeld and 1 or 0)
	humanoid:Move(Vector3.new(direction, 0, 0), false)
	if jumpHeld then
		humanoid.Jump = true
	end

	-- Keep the character glued to the 2D plane
	local pos = root.Position
	if math.abs(pos.Z - PLANE_Z) > 0.05 then
		root.CFrame = root.CFrame + Vector3.new(0, 0, PLANE_Z - pos.Z)
	end
	local vel = root.AssemblyLinearVelocity
	if vel.Z ~= 0 then
		root.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y, 0)
	end

	-- Side-view camera that smoothly follows the player
	camera.CameraType = Enum.CameraType.Scriptable
	local target = Vector3.new(pos.X, pos.Y + CAMERA_HEIGHT, PLANE_Z)
	local desired = CFrame.lookAt(target + Vector3.new(0, 0, CAMERA_DISTANCE), target)
	local alpha = math.clamp(dt * CAMERA_SMOOTH, 0, 1)
	camera.CFrame = camera.CFrame:Lerp(desired, alpha)
end)
