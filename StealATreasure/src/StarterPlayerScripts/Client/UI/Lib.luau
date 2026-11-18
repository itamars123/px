-- Lib.lua
-- Tiny declarative UI helper + theme used by every window.

local TweenService = game:GetService("TweenService")

local Lib = {}

Lib.Theme = {
	Bg = Color3.fromRGB(22, 24, 44),
	Panel = Color3.fromRGB(34, 37, 66),
	Panel2 = Color3.fromRGB(46, 50, 88),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(190, 195, 230),
	Accent = Color3.fromRGB(255, 196, 50),
	Green = Color3.fromRGB(70, 210, 100),
	Red = Color3.fromRGB(240, 70, 80),
	Blue = Color3.fromRGB(70, 160, 255),
	Purple = Color3.fromRGB(160, 90, 255),
	Pink = Color3.fromRGB(255, 100, 190),
	Orange = Color3.fromRGB(255, 140, 50),
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
	Light = Enum.Font.Gotham,
}
local T = Lib.Theme

-- Lib.new("Frame", { Size = ..., Parent = ... }, { children })
function Lib.new(className: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = Lib.new

function Lib.corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

function Lib.stroke(color: Color3?, thickness: number?, transparency: number?)
	return new("UIStroke", {
		Color = color or Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Lib.textStroke(thickness: number?)
	return new("UIStroke", { Color = Color3.fromRGB(15, 15, 30), Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

function Lib.gradient(c1: Color3, c2: Color3, rotation: number?)
	return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 90 })
end

function Lib.padding(px: number)
	local u = UDim.new(0, px)
	return new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Lib.list(direction: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?)
	return new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Lib.grid(cell: UDim2, padding: number?)
	return new("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(padding or 8, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
end

function Lib.label(props)
	local p = {
		BackgroundTransparency = 1,
		Font = T.Body,
		TextColor3 = T.Text,
		TextScaled = true,
		Text = "",
	}
	for k, v in pairs(props) do
		if k ~= "MaxText" then
			p[k] = v
		end
	end
	local l = new("TextLabel", p)
	if props.TextScaled ~= false then
		new("UITextSizeConstraint", { MaxTextSize = props.MaxText or 28, MinTextSize = 8, Parent = l })
	end
	return l
end

-- Animated button. props.Color, props.OnClick, props.Text ...
local Sound -- lazily required (avoid cyclic requires)
function Lib.button(props)
	local color = props.Color or T.Blue
	local b = new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(140, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = props.Text or "",
		Font = props.Font or T.Title,
		TextColor3 = props.TextColor or T.Text,
		TextScaled = true,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, {
		Lib.corner(props.Radius or 10),
		Lib.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90),
		Lib.stroke(color:Lerp(Color3.new(0, 0, 0), 0.45), 2.5),
		new("UITextSizeConstraint", { MaxTextSize = props.MaxText or 24, MinTextSize = 8 }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
		Lib.textStroke(1.5),
	})
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	if props.OnClick then
		b.Activated:Connect(function()
			Sound = Sound or require(script.Parent.Parent.Controllers.Sound)
			Sound.Play("Click")
			props.OnClick(b)
		end)
	end
	return b
end

function Lib.setButtonColor(b: GuiObject, color: Color3)
	b.BackgroundColor3 = color
	for _, s in ipairs(b:GetChildren()) do
		if s:IsA("UIStroke") and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			s.Color = color:Lerp(Color3.new(0, 0, 0), 0.45)
		end
	end
end

function Lib.panel(props)
	local p = {
		BackgroundColor3 = T.Panel,
		BorderSizePixel = 0,
	}
	for k, v in pairs(props) do
		if k ~= "Radius" then
			p[k] = v
		end
	end
	local f = new("Frame", p)
	Lib.corner(props.Radius or 12).Parent = f
	return f
end

function Lib.scroll(props)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return new("ScrollingFrame", p)
end

function Lib.clear(container: Instance)
	for _, c in ipairs(container:GetChildren()) do
		if not c:IsA("UIGridStyleLayout") and not c:IsA("UIPadding") and not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

-- Progress bar; returns frame and a setter(fraction)
function Lib.bar(props)
	local bg = Lib.panel({
		Name = props.Name or "Bar",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = Color3.fromRGB(15, 15, 30),
		Radius = 8,
		Parent = props.Parent,
		LayoutOrder = props.LayoutOrder or 0,
	})
	Lib.stroke(Color3.fromRGB(0, 0, 0), 2).Parent = bg
	local fill = Lib.panel({ Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = props.Color or T.Accent, Radius = 8, Parent = bg })
	Lib.gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)).Parent = fill
	local text = Lib.label({ Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 3, Parent = bg, MaxText = 18 })
	Lib.textStroke(1.5).Parent = text
	return bg, function(f: number, t: string?)
		f = math.clamp(f, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(f, 1) }):Play()
		if t then
			text.Text = t
		end
	end
end

return Lib
