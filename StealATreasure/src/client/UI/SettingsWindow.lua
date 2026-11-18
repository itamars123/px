-- SettingsWindow.lua
-- Music, sound effects, graphics quality, treasure effects and UI scale.
-- Settings are saved on the server with the rest of your progress.

local Lib = require(script.Parent.Lib)
local State = require(script.Parent.Parent.Controllers.State)

local T = Lib.Theme
local new = Lib.new

local Settings = {}

local toggles = {}
local scaleLabel: TextLabel
local saveLabel: TextLabel
local statsLabel: TextLabel

local OPTIONS = {
	{ Key = "Music", Text = "🎵 Music", Desc = "Background music" },
	{ Key = "Sfx", Text = "🔊 Sound Effects", Desc = "Pickups, alarms, purchases" },
	{ Key = "Effects", Text = "✨ Treasure Effects", Desc = "Particles, beams and glow on treasures" },
	{ Key = "LowGfx", Text = "📱 Performance Mode", Desc = "Lower quality for older phones (no shadows, no treasure animation)" },
}

local function current()
	return State.Full and State.Full.Settings or {}
end

local function refresh()
	local s = current()
	for key, b in pairs(toggles) do
		local on = s[key] == true
		b.Text = on and "ON" or "OFF"
		Lib.setButtonColor(b, on and T.Green or T.Red)
	end
	scaleLabel.Text = ("%d%%"):format(math.floor((s.UIScale or 1) * 100 + 0.5))
	if State.Full then
		saveLabel.Text = State.Full.CanSave and "💾 Progress saves automatically." or "⚠️ Saving disabled (Studio without API access)."
		local st = State.Full.Stats or {}
		statsLabel.Text = ("📊 Steals: %d   Robbed: %d   Defends: %d   Collected: %d   Trades: %d   Secrets: %d/3"):format(
			st.Steals or 0,
			st.Robbed or 0,
			st.Defends or 0,
			st.Collected or 0,
			st.Trades or 0,
			#(State.Full.Secrets or {})
		)
	end
end

function Settings.Build(content: Frame)
	local scroll = Lib.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
	Lib.list(Enum.FillDirection.Vertical, 8).Parent = scroll
	Lib.padding(4).Parent = scroll
	for i, opt in ipairs(OPTIONS) do
		local row = Lib.panel({ Size = UDim2.new(1, -8, 0, 62), LayoutOrder = i, Parent = scroll })
		local t = Lib.label({ Size = UDim2.new(1, -140, 0, 28), Position = UDim2.fromOffset(14, 6), Text = opt.Text, Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = row })
		Lib.textStroke(1.5).Parent = t
		Lib.label({ Size = UDim2.new(1, -140, 0, 20), Position = UDim2.fromOffset(14, 34), Text = opt.Desc, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 14, Parent = row })
		toggles[opt.Key] = Lib.button({
			Text = "",
			Size = UDim2.fromOffset(100, 42),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = row,
			OnClick = function()
				local s = current()
				State.Ask("UpdateSettings", { [opt.Key] = not (s[opt.Key] == true) })
			end,
		})
	end
	local row = Lib.panel({ Size = UDim2.new(1, -8, 0, 62), LayoutOrder = 10, Parent = scroll })
	local t = Lib.label({ Size = UDim2.new(0.5, 0, 1, -12), Position = UDim2.fromOffset(14, 6), Text = "🔍 Interface Size", Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = row })
	Lib.textStroke(1.5).Parent = t
	local function change(d)
		local s = current()
		State.Ask("UpdateSettings", { UIScale = math.clamp((s.UIScale or 1) + d, 0.6, 1.4) })
	end
	Lib.button({ Text = "−", Size = UDim2.fromOffset(46, 42), Position = UDim2.new(1, -170, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = T.Panel2, Parent = row, OnClick = function()
		change(-0.1)
	end })
	scaleLabel = Lib.label({ Size = UDim2.fromOffset(60, 42), Position = UDim2.new(1, -120, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Text = "100%", Font = T.Title, Parent = row })
	Lib.button({ Text = "+", Size = UDim2.fromOffset(46, 42), Position = UDim2.new(1, -58, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = T.Panel2, Parent = row, OnClick = function()
		change(0.1)
	end })
	saveLabel = Lib.label({ Size = UDim2.new(1, -8, 0, 26), LayoutOrder = 20, TextColor3 = T.SubText, MaxText = 16, Parent = scroll })
	statsLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 44),
		LayoutOrder = 21,
		Font = T.Body,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = T.SubText,
		Parent = scroll,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 120),
		LayoutOrder = 22,
		Font = T.Body,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.SubText,
		Text = "HOW TO PLAY\n• Grab free treasures in the fields or buy them at the market, then carry them home.\n• Treasures on your platforms earn money every second.\n• Sneak into other bases and hold [E] on a treasure to steal it — get it home before they bonk you!\n• Lock your base with the red button. Upgrade protection in the shop.\n• Keys: Q Dash • R Super Jump • F Cloak",
		Parent = scroll,
	})
	State.FullChanged.Event:Connect(refresh)
end

function Settings.OnOpen()
	refresh()
end

return Settings
