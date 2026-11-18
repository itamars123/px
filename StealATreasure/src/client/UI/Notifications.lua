-- Notifications.lua
-- Toasts, big announcement banners, the robbery alarm overlay, level-up /
-- rebirth splashes and confetti.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Lib = require(script.Parent.Lib)
local Sound = require(script.Parent.Parent.Controllers.Sound)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rarities = require(Shared.Rarities)

local T = Lib.Theme
local new = Lib.new

local Notifications = {}

local gui: ScreenGui
local toastHolder: Frame
local bannerHolder: Frame
local alarmFrame: Frame
local alarmText: TextLabel

local KIND_COLORS = {
	info = T.Blue,
	success = T.Green,
	error = T.Red,
	warn = T.Orange,
	discovery = T.Purple,
	level = T.Accent,
}

function Notifications.Toast(text: string, kind: string?)
	kind = kind or "info"
	local color = KIND_COLORS[kind] or T.Blue
	local toast = Lib.panel({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.1,
		Parent = toastHolder,
	})
	Lib.stroke(color, 2.5).Parent = toast
	Lib.padding(8).Parent = toast
	local bar = Lib.panel({ Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = color, Radius = 3, Parent = toast })
	bar.Position = UDim2.fromOffset(-4, 0)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		Position = UDim2.fromOffset(8, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = T.Body,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.Text,
		Text = text,
		Parent = toast,
	})
	local scale = new("UIScale", { Scale = 0.6, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if kind == "error" then
		Sound.Play("Error", 0.4)
	elseif kind == "discovery" or kind == "level" then
		Sound.Play("Legendary", 0.6)
	end
	task.delay(4, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.wait(0.3)
			toast:Destroy()
		end
	end)
	-- keep at most 5
	local toasts = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(toasts, c)
		end
	end
	if #toasts > 5 then
		toasts[1]:Destroy()
	end
end

function Notifications.Banner(text: string, rarity: string?)
	local color = rarity and Rarities.Color(rarity) or T.Accent
	if rarity == "Secret" then
		color = Color3.fromRGB(130, 255, 230)
	end
	local banner = Lib.panel({
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.05,
		Parent = bannerHolder,
	})
	Lib.stroke(color, 3).Parent = banner
	Lib.gradient(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 170), 90).Parent = banner
	local label = Lib.label({
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		Font = T.Title,
		Text = text,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35),
		Parent = banner,
		MaxText = 26,
	})
	Lib.textStroke(2).Parent = label
	local scale = new("UIScale", { Scale = 0.3, Parent = banner })
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Sound.Play(rarity and Rarities.Rank(rarity) >= 5 and "Legendary" or "Event", 0.6)
	Debris:AddItem(banner, 6)
	local count = 0
	for _, c in ipairs(bannerHolder:GetChildren()) do
		if c:IsA("Frame") then
			count += 1
		end
	end
	if count > 3 then
		for _, c in ipairs(bannerHolder:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
				break
			end
		end
	end
end

function Notifications.Alarm(thief: string, treasure: string)
	alarmText.Text = ("🚨 %s IS STEALING YOUR %s! 🚨\nBonk them with your hammer!"):format(thief:upper(), treasure:upper())
	alarmFrame.Visible = true
	task.spawn(function()
		for i = 1, 8 do
			alarmFrame.BackgroundTransparency = (i % 2 == 0) and 0.55 or 0.8
			if i % 2 == 1 then
				Sound.Play("Alarm", 0.8, 0.6)
			end
			task.wait(0.35)
		end
		alarmFrame.Visible = false
	end)
end

function Notifications.Splash(title: string, subtitle: string, color: Color3)
	local frame = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
		ZIndex = 50,
	})
	local t = Lib.label({
		Size = UDim2.fromScale(0.8, 0.14),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = T.Title,
		Text = title,
		TextColor3 = color,
		ZIndex = 51,
		Parent = frame,
		MaxText = 80,
	})
	Lib.textStroke(4).Parent = t
	local s = Lib.label({
		Size = UDim2.fromScale(0.7, 0.06),
		Position = UDim2.fromScale(0.5, 0.48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = T.Body,
		Text = subtitle,
		ZIndex = 51,
		Parent = frame,
		MaxText = 32,
	})
	Lib.textStroke(2).Parent = s
	local scale = new("UIScale", { Scale = 0.2, Parent = frame })
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.2, function()
		TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.6)
		frame:Destroy()
	end)
	Notifications.Confetti()
end

function Notifications.Confetti()
	local colors = { T.Accent, T.Pink, T.Blue, T.Green, T.Purple, T.Orange }
	for _ = 1, 40 do
		local piece = new("Frame", {
			Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
			Position = UDim2.new(math.random(), 0, -0.05, 0),
			BackgroundColor3 = colors[math.random(1, #colors)],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 60,
			Parent = gui,
		})
		local dur = math.random(15, 30) / 10
		TweenService:Create(piece, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-360, 360),
		}):Play()
		Debris:AddItem(piece, dur)
	end
end

-- Floating "+$123" near the money counter
function Notifications.MoneyPop(text: string, color: Color3?)
	local l = Lib.label({
		Size = UDim2.fromOffset(220, 36),
		Position = UDim2.new(0.5, math.random(-60, 60), 0, 92),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = T.Title,
		Text = text,
		TextColor3 = color or T.Green,
		ZIndex = 40,
		Parent = gui,
		MaxText = 30,
	})
	Lib.textStroke(2).Parent = l
	TweenService:Create(l, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Position = l.Position + UDim2.fromOffset(0, 50), TextTransparency = 1 }):Play()
	Debris:AddItem(l, 1.3)
end

function Notifications.Init(parentGui: ScreenGui)
	gui = parentGui
	toastHolder = new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(300, 400),
		Parent = gui,
	}, { Lib.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top) })
	bannerHolder = new("Frame", {
		Name = "Banners",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(640, 200),
		Parent = gui,
	}, {
		Lib.list(Enum.FillDirection.Vertical, 6),
		new("UISizeConstraint", { MaxSize = Vector2.new(640, 200) }),
	})
	bannerHolder.Size = UDim2.new(0.9, 0, 0, 200)
	alarmFrame = new("Frame", {
		Name = "Alarm",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 0, 20),
		BackgroundTransparency = 0.7,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	alarmText = Lib.label({
		Size = UDim2.fromScale(0.85, 0.16),
		Position = UDim2.fromScale(0.5, 0.25),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = T.Title,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 31,
		Parent = alarmFrame,
		MaxText = 48,
	})
	Lib.textStroke(3).Parent = alarmText
end

return Notifications
