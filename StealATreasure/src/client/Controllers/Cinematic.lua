-- Cinematic.lua
-- Cinematic intro flyover (letterbox, title card, depth of field) shown when
-- you join, plus camera effects (sprint FOV, portal warp).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Lib = require(script.Parent.Parent.UI.Lib)

local Cinematic = {}
Cinematic.Playing = false

local player = Players.LocalPlayer

local function lerpCF(a: CFrame, b: CFrame, t: number)
	return a:Lerp(b, t * t * (3 - 2 * t))
end

function Cinematic.PlayIntro(gui: ScreenGui)
	if Cinematic.Playing then
		return
	end
	Cinematic.Playing = true
	local cam = workspace.CurrentCamera
	local T = Lib.Theme
	local top = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(), BorderSizePixel = 0, ZIndex = 80, Parent = gui })
	local bottom = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.new(), BorderSizePixel = 0, ZIndex = 80, Parent = gui })
	TweenService:Create(top, TweenInfo.new(0.6), { Size = UDim2.new(1, 0, 0.11, 0) }):Play()
	TweenService:Create(bottom, TweenInfo.new(0.6), { Size = UDim2.new(1, 0, 0.11, 0) }):Play()
	local title = Lib.label({
		Size = UDim2.fromScale(0.8, 0.16),
		Position = UDim2.fromScale(0.5, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = T.Title,
		Text = "💎 STEAL A TREASURE 💎",
		TextColor3 = T.Accent,
		TextTransparency = 1,
		ZIndex = 81,
		Parent = gui,
		MaxText = 90,
	})
	Lib.textStroke(4).Parent = title
	local sub = Lib.label({
		Size = UDim2.fromScale(0.7, 0.05),
		Position = UDim2.fromScale(0.5, 0.41),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "Collect. Steal. Become the richest!",
		TextTransparency = 1,
		ZIndex = 81,
		Parent = gui,
		MaxText = 30,
	})
	local skip = Lib.button({
		Text = "Skip ⏭",
		Color = T.Panel2,
		Size = UDim2.fromOffset(120, 40),
		Position = UDim2.new(1, -20, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 82,
		Parent = gui,
	})
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.4
	dof.FocusDistance = 60
	dof.InFocusRadius = 40
	dof.NearIntensity = 0.2
	dof.Parent = Lighting

	local skipped = false
	skip.Activated:Connect(function()
		skipped = true
	end)
	cam.CameraType = Enum.CameraType.Scriptable
	local baseIndex = player:GetAttribute("BaseIndex")
	local baseModel = baseIndex and workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild("Base" .. baseIndex)
	local basePos = baseModel and baseModel:GetPivot().Position or Vector3.new(0, 0, 200)
	local shots = {
		{ CFrame.lookAt(Vector3.new(-220, 140, -220), Vector3.new(0, 10, 0)), CFrame.lookAt(Vector3.new(220, 120, -200), Vector3.new(0, 10, 0)), 3.5 },
		{ CFrame.lookAt(Vector3.new(60, 30, 80), Vector3.new(0, 8, 0)), CFrame.lookAt(Vector3.new(-60, 22, 60), Vector3.new(0, 8, 0)), 3 },
		{ CFrame.lookAt(basePos + Vector3.new(0, 90, 0) - basePos.Unit * 120, basePos), CFrame.lookAt(basePos + Vector3.new(0, 30, 0) - basePos.Unit * 60, basePos), 3 },
	}
	TweenService:Create(title, TweenInfo.new(1), { TextTransparency = 0 }):Play()
	TweenService:Create(sub, TweenInfo.new(1.5), { TextTransparency = 0 }):Play()
	for _, shot in ipairs(shots) do
		local start = os.clock()
		while os.clock() - start < shot[3] and not skipped do
			cam.CFrame = lerpCF(shot[1], shot[2], (os.clock() - start) / shot[3])
			RunService.RenderStepped:Wait()
		end
		if skipped then
			break
		end
	end
	TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	TweenService:Create(sub, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	TweenService:Create(top, TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	TweenService:Create(bottom, TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 95
	TweenService:Create(cam, TweenInfo.new(1, Enum.EasingStyle.Quad), { FieldOfView = 70 }):Play()
	TweenService:Create(dof, TweenInfo.new(1), { FarIntensity = 0, NearIntensity = 0 }):Play()
	skip:Destroy()
	task.delay(1.2, function()
		title:Destroy()
		sub:Destroy()
		top:Destroy()
		bottom:Destroy()
		dof:Destroy()
	end)
	Cinematic.Playing = false
end

-- Smoothly widen FOV while sprinting
function Cinematic.Start()
	RunService.RenderStepped:Connect(function(dt)
		if Cinematic.Playing then
			return
		end
		local char = player.Character
		local cam = workspace.CurrentCamera
		if not char or not cam then
			return
		end
		local target = char:GetAttribute("Sprinting") and 80 or 70
		if math.abs(cam.FieldOfView - target) > 0.2 and math.abs(cam.FieldOfView - 70) < 12 then
			cam.FieldOfView += (target - cam.FieldOfView) * math.min(1, dt * 5)
		end
	end)
end

return Cinematic
