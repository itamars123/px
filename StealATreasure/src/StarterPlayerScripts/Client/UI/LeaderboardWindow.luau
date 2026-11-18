-- LeaderboardWindow.lua
-- Server board (live) and global boards (Richest, Rebirths).

local Players = game:GetService("Players")

local Lib = require(script.Parent.Lib)
local State = require(script.Parent.Parent.Controllers.State)
local Shared = game:GetService("ReplicatedStorage").Shared
local Util = require(Shared.Util)

local T = Lib.Theme
local new = Lib.new

local Board = {}

local tab = "Server"
local list: ScrollingFrame
local tabs = {}
local isOpen = false

local MEDAL = { "🥇", "🥈", "🥉" }

local function refresh()
	if not isOpen then
		return
	end
	Lib.clear(list)
	for name, b in pairs(tabs) do
		Lib.setButtonColor(b, name == tab and T.Accent or T.Panel2)
	end
	local board = State.Leaderboard
	local entries = board and board[tab] or {}
	if #entries == 0 then
		Lib.label({
			Size = UDim2.new(1, 0, 0, 40),
			Text = tab == "Server" and "Loading..." or "Global boards update every 2 minutes (requires a published game with DataStores).",
			TextColor3 = T.SubText,
			MaxText = 16,
			Parent = list,
		})
		return
	end
	for i, e in ipairs(entries) do
		local isMe = e.UserId == Players.LocalPlayer.UserId
		local row = Lib.panel({
			Size = UDim2.new(1, -8, 0, 48),
			BackgroundColor3 = isMe and T.Accent:Lerp(T.Panel, 0.6) or (i % 2 == 0 and T.Panel or T.Panel2),
			LayoutOrder = i,
			Parent = list,
		})
		Lib.label({ Size = UDim2.fromOffset(60, 40), Position = UDim2.fromOffset(6, 4), Text = MEDAL[i] or ("#" .. i), Font = T.Title, MaxText = 24, Parent = row })
		new("ImageLabel", {
			Size = UDim2.fromOffset(38, 38),
			Position = UDim2.fromOffset(70, 5),
			BackgroundColor3 = T.Bg,
			Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(e.UserId),
			Parent = row,
		}, { Lib.corner(19) })
		local name = Lib.label({ Size = UDim2.new(0.5, -120, 1, -8), Position = UDim2.fromOffset(116, 4), Text = e.Name, Font = T.Title, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Parent = row })
		Lib.textStroke(1.5).Parent = name
		local valueText
		if tab == "Rebirths" then
			valueText = ("🌀 %s"):format(Util.Commas(e.Value))
		elseif tab == "Server" then
			valueText = ("%s  •  %s/s  •  🌀%d"):format(Util.Money(e.Value), Util.Abbreviate(e.MPS or 0), e.Rebirths or 0)
		else
			valueText = Util.Money(e.Value)
		end
		local v = Lib.label({ Size = UDim2.new(0.5, -10, 1, -8), Position = UDim2.new(0.5, 0, 0, 4), Text = valueText, TextColor3 = T.Green, TextXAlignment = Enum.TextXAlignment.Right, MaxText = 18, Parent = row })
		Lib.textStroke(1.5).Parent = v
	end
end

function Board.Build(content: Frame)
	local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = content }, {
		Lib.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	for i, info in ipairs({ { "Server", "🖥️ This Server" }, { "Richest", "🌍 Richest" }, { "Rebirths", "🌍 Rebirths" } }) do
		tabs[info[1]] = Lib.button({
			Text = info[2],
			Color = T.Panel2,
			Size = UDim2.fromOffset(150, 34),
			LayoutOrder = i,
			Parent = top,
			OnClick = function()
				tab = info[1]
				refresh()
			end,
		})
	end
	list = Lib.scroll({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), Parent = content })
	Lib.list(Enum.FillDirection.Vertical, 6).Parent = list
	Lib.padding(4).Parent = list
	State.LeaderboardChanged.Event:Connect(refresh)
end

function Board.OnOpen()
	isOpen = true
	refresh()
	State.Ask("GetLeaderboard")
end

function Board.OnClose()
	isOpen = false
end

return Board
