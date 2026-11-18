-- AchievementData.lua
-- Achievements: a stat, a goal and a gem reward. Checked on the server.

local AchievementData = {}

-- Stat keys: Collected, Steals, Defends, Trades, Hatched, Earned, Rebirths,
-- Level, Discovered, Secrets, Celestial, ChestsOpened, EventsJoined
AchievementData.List = {
	{ Id = "first_find", Name = "First Find", Icon = "✨", Stat = "Collected", Goal = 1, Gems = 10 },
	{ Id = "collector", Name = "Collector", Icon = "🎒", Stat = "Collected", Goal = 25, Gems = 25 },
	{ Id = "hoarder", Name = "Hoarder", Icon = "🏰", Stat = "Collected", Goal = 150, Gems = 75 },
	{ Id = "dragon_hoard", Name = "Dragon's Hoard", Icon = "🐉", Stat = "Collected", Goal = 600, Gems = 200 },
	{ Id = "first_heist", Name = "First Heist", Icon = "🦹", Stat = "Steals", Goal = 1, Gems = 15 },
	{ Id = "master_thief", Name = "Master Thief", Icon = "🎭", Stat = "Steals", Goal = 15, Gems = 60 },
	{ Id = "legendary_thief", Name = "Legendary Thief", Icon = "💎", Stat = "Steals", Goal = 75, Gems = 200 },
	{ Id = "guardian", Name = "Guardian", Icon = "🛡️", Stat = "Defends", Goal = 3, Gems = 25 },
	{ Id = "fortress", Name = "Fortress", Icon = "🏯", Stat = "Defends", Goal = 25, Gems = 100 },
	{ Id = "trader", Name = "Trader", Icon = "🤝", Stat = "Trades", Goal = 1, Gems = 20 },
	{ Id = "merchant", Name = "Merchant", Icon = "💼", Stat = "Trades", Goal = 20, Gems = 80 },
	{ Id = "hatcher", Name = "Egg Hatcher", Icon = "🥚", Stat = "Hatched", Goal = 1, Gems = 10 },
	{ Id = "pet_lover", Name = "Pet Lover", Icon = "🐾", Stat = "Hatched", Goal = 30, Gems = 80 },
	{ Id = "rich", Name = "Getting Rich", Icon = "💵", Stat = "Earned", Goal = 10000, Gems = 15 },
	{ Id = "millionaire", Name = "Millionaire", Icon = "💰", Stat = "Earned", Goal = 1e6, Gems = 50 },
	{ Id = "billionaire", Name = "Billionaire", Icon = "🤑", Stat = "Earned", Goal = 1e9, Gems = 200 },
	{ Id = "reborn", Name = "Reborn", Icon = "🌀", Stat = "Rebirths", Goal = 1, Gems = 50 },
	{ Id = "eternal", Name = "Eternal", Icon = "♾️", Stat = "Rebirths", Goal = 10, Gems = 300 },
	{ Id = "level10", Name = "Rising Star", Icon = "⭐", Stat = "Level", Goal = 10, Gems = 25 },
	{ Id = "level30", Name = "Superstar", Icon = "🌟", Stat = "Level", Goal = 30, Gems = 100 },
	{ Id = "index25", Name = "Curator", Icon = "📖", Stat = "Discovered", Goal = 25, Gems = 30 },
	{ Id = "index75", Name = "Historian", Icon = "📚", Stat = "Discovered", Goal = 75, Gems = 150 },
	{ Id = "explorer", Name = "Explorer", Icon = "🗺️", Stat = "Secrets", Goal = 3, Gems = 75 },
	{ Id = "celestial", Name = "Touched the Stars", Icon = "🌌", Stat = "Celestial", Goal = 1, Gems = 250 },
	{ Id = "chest_opener", Name = "Chest Cracker", Icon = "🧰", Stat = "ChestsOpened", Goal = 10, Gems = 40 },
}

AchievementData.ById = {}
for i, a in ipairs(AchievementData.List) do
	a.Order = i
	AchievementData.ById[a.Id] = a
end

return AchievementData
