-- Windows.lua
-- Window manager: one menu open at a time, animated open/close, shared
-- title bar and close button. Each window module implements:
--   Build(content: Frame, api)  -- called once
--   OnOpen(arg)?                -- every time it opens
--   OnClose()?                  -- every time it closes

local TweenService = game:GetService("TweenService")

local Lib = require(script.Parent.Lib)
local Sound = require(script.Parent.Parent.Controllers.Sound)

local T = Lib.Theme
local new = Lib.new

local Windows = {}
Windows.Registry = {}
Windows.Current = nil :: string?
Windows.Changed = Instance.new("BindableEvent")

local gui: ScreenGui
local dim: Frame

function Windows.Register(name: string, module, opts)
	opts = opts or {}
	local frame = Lib.panel({
		Name = name .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = opts.Size or UDim2.fromScale(0.74, 0.8),
		BackgroundColor3 = T.Bg,
		Visible = false,
		ZIndex = 10,
		Radius = 18,
		Parent = gui,
	})
	new("UISizeConstraint", { MaxSize = opts.MaxSize or Vector2.new(920, 640), MinSize = Vector2.new(300, 260), Parent = frame })
	Lib.stroke(opts.Color or T.Accent, 3).Parent = frame
	local scale = new("UIScale", { Parent = frame })

	local header = Lib.panel({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = opts.Color or T.Accent,
		Radius = 18,
		ZIndex = 11,
		Parent = frame,
	})
	Lib.gradient(Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180)).Parent = header
	-- square off the header's bottom corners
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundColor3 = opts.Color or T.Accent,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = header,
	}, { Lib.gradient(Color3.fromRGB(200, 200, 200), Color3.fromRGB(180, 180, 180)) })
	local title = Lib.label({
		Size = UDim2.new(1, -120, 1, -12),
		Position = UDim2.fromOffset(18, 6),
		Font = T.Title,
		Text = (opts.Icon or "") .. "  " .. (opts.Title or name),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = header,
		MaxText = 30,
	})
	Lib.textStroke(2).Parent = title
	Lib.button({
		Name = "Close",
		Text = "✕",
		Color = T.Red,
		Size = UDim2.fromOffset(42, 38),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		ZIndex = 13,
		Parent = header,
		OnClick = function()
			Windows.Close()
		end,
	})
	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.new(1, -28, 1, -74),
		ZIndex = 11,
		Parent = frame,
	})
	local entry = { Name = name, Frame = frame, Scale = scale, Module = module, Content = content, Title = title }
	Windows.Registry[name] = entry
	module.Build(content, Windows)
	return entry
end

function Windows.IsOpen(name: string): boolean
	return Windows.Current == name
end

function Windows.Open(name: string, arg: any?)
	local entry = Windows.Registry[name]
	if not entry then
		return
	end
	if Windows.Current and Windows.Current ~= name then
		Windows.Close(true)
	end
	Windows.Current = name
	entry.Frame.Visible = true
	dim.Visible = true
	entry.Scale.Scale = 0.7
	TweenService:Create(entry.Scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Sound.Play("Hover", 0.5)
	if entry.Module.OnOpen then
		task.spawn(entry.Module.OnOpen, arg)
	end
	Windows.Changed:Fire(name)
end

function Windows.Close(instant: boolean?)
	local name = Windows.Current
	if not name then
		return
	end
	local entry = Windows.Registry[name]
	Windows.Current = nil
	if entry.Module.OnClose then
		task.spawn(entry.Module.OnClose)
	end
	if instant then
		entry.Frame.Visible = false
	else
		local tw = TweenService:Create(entry.Scale, TweenInfo.new(0.15), { Scale = 0.7 })
		tw:Play()
		tw.Completed:Once(function()
			if Windows.Current ~= name then
				entry.Frame.Visible = false
			end
		end)
	end
	dim.Visible = false
	Windows.Changed:Fire(nil)
end

function Windows.Toggle(name: string, arg: any?)
	if Windows.Current == name then
		Windows.Close()
	else
		Windows.Open(name, arg)
	end
end

function Windows.Init(parentGui: ScreenGui)
	gui = parentGui
	dim = new("TextButton", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 9,
		Parent = gui,
	})
	dim.Activated:Connect(function()
		Windows.Close()
	end)
end

return Windows
