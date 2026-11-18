-- Main.server.lua
-- Boots every server service in dependency order: Init() wires references,
-- Start() begins loops and connections.

local servicesFolder = script.Parent:WaitForChild("Services")

local ORDER = {
	"NetService",
	"DataService",
	"MapBuilder",
	"StateService",
	"EconomyService",
	"BaseService",
	"CarryService",
	"TreasureService",
	"StealService",
	"PlayerService",
	"GearService",
	"PetService",
	"AchievementService",
	"WorldService",
	"ShopService",
	"RebirthService",
	"MonetizationService",
	"TradeService",
	"LeaderboardService",
	"EventService",
}

local Services = {}
for _, name in ipairs(ORDER) do
	Services[name] = require(servicesFolder:WaitForChild(name))
end

for _, name in ipairs(ORDER) do
	local svc = Services[name]
	if svc.Init then
		svc.Init(Services)
	end
end

for _, name in ipairs(ORDER) do
	local svc = Services[name]
	if svc.Start then
		local ok, err = pcall(svc.Start)
		if not ok then
			warn(("[Boot] %s failed to start: %s"):format(name, tostring(err)))
		end
	end
end

-- every periodic job runs from one Heartbeat (skill: consolidated Heartbeat)
require(script.Parent.Modules.Scheduler).Start()

print(("[STEAL A TREASURE] Server ready — %d services online"):format(#ORDER))
