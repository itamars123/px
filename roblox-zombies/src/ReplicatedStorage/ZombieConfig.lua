-- ZombieConfig (ModuleScript) — put in ReplicatedStorage
-- Every number that controls the game lives here. Tweak freely.

local Config = {}

---------------------------------------------------------------- players
Config.StartingPoints = 500
Config.StartingWeapon = "Pistol"
Config.MaxWeapons = 2               -- buying a 3rd gun replaces the one in your hands
Config.PlayerMaxHealth = 100
Config.PlayerRegenDelay = 4         -- seconds without taking damage before health regenerates
Config.PlayerRegenRate = 25         -- health per second while regenerating
Config.WalkSpeed = 16
Config.SprintSpeed = 24

---------------------------------------------------------------- points
Config.PointsPerHit = 10
Config.PointsPerKill = 60
Config.PointsPerHeadshotKill = 100

---------------------------------------------------------------- rounds
Config.FirstRoundDelay = 8          -- countdown before round 1
Config.IntermissionTime = 10        -- break between rounds
Config.MaxZombiesAlive = 24         -- cap on zombies alive at once (performance)
Config.MinSpawnDistance = 25        -- prefer spawn points at least this far from players

-- How many zombies a round has (more players = more zombies)
function Config.ZombiesForRound(round, playerCount)
	return math.floor((6 + round * 3) * (1 + 0.5 * (math.max(playerCount, 1) - 1)))
end

-- Zombie health: grows linearly until round 9, then by 10% per round (like the classics)
function Config.ZombieHealth(round)
	if round <= 9 then
		return 100 + 80 * (round - 1)
	end
	return math.floor(740 * 1.1 ^ (round - 9))
end

-- Zombie walk speed (players walk at 16, sprint at 24)
function Config.ZombieSpeed(round)
	return math.min(7 + round * 0.9, 21)
end

-- Seconds between zombie spawns
function Config.SpawnInterval(round)
	return math.max(2 - round * 0.12, 0.35)
end

Config.ZombieDamage = 34            -- 3 hits kills a 100 hp player
Config.ZombieAttackRange = 4.5
Config.ZombieAttackCooldown = 1.1

---------------------------------------------------------------- weapons
-- FireRate = seconds between shots. Spread = degrees. Pellets > 1 = shotgun.
-- Cost = wall-buy price (ammo costs half). InBox = can come out of the Mystery Box.
Config.Weapons = {
	Pistol = {
		DisplayName = "M9 Pistol", Damage = 35, HeadshotMultiplier = 2.5,
		FireRate = 0.22, Automatic = false, MagSize = 8, ReserveAmmo = 80,
		ReloadTime = 1.4, Range = 300, Spread = 0.6, Pellets = 1, Recoil = 0.9,
		Cost = 500, InBox = false,
		Color = Color3.fromRGB(40, 40, 45), Length = 1.0, TracerColor = Color3.fromRGB(255, 220, 140),
	},
	SMG = {
		DisplayName = "Vector SMG", Damage = 28, HeadshotMultiplier = 2,
		FireRate = 0.075, Automatic = true, MagSize = 32, ReserveAmmo = 256,
		ReloadTime = 1.9, Range = 220, Spread = 2.2, Pellets = 1, Recoil = 0.45,
		Cost = 1200, InBox = true,
		Color = Color3.fromRGB(60, 60, 72), Length = 1.4, TracerColor = Color3.fromRGB(255, 220, 140),
	},
	Shotgun = {
		DisplayName = "Pump Shotgun", Damage = 40, HeadshotMultiplier = 1.5,
		FireRate = 0.85, Automatic = false, MagSize = 6, ReserveAmmo = 48,
		ReloadTime = 2.6, Range = 80, Spread = 6, Pellets = 8, Recoil = 2.2,
		Cost = 1500, InBox = true,
		Color = Color3.fromRGB(95, 62, 38), Length = 2.0, TracerColor = Color3.fromRGB(255, 200, 120),
	},
	Rifle = {
		DisplayName = "Assault Rifle", Damage = 55, HeadshotMultiplier = 2.5,
		FireRate = 0.11, Automatic = true, MagSize = 30, ReserveAmmo = 210,
		ReloadTime = 2.2, Range = 400, Spread = 1.3, Pellets = 1, Recoil = 0.7,
		Cost = 2500, InBox = true,
		Color = Color3.fromRGB(52, 58, 46), Length = 1.9, TracerColor = Color3.fromRGB(255, 220, 140),
	},
	LMG = {
		DisplayName = "Heavy LMG", Damage = 70, HeadshotMultiplier = 2,
		FireRate = 0.09, Automatic = true, MagSize = 100, ReserveAmmo = 400,
		ReloadTime = 4.5, Range = 400, Spread = 2.5, Pellets = 1, Recoil = 0.8,
		Cost = 3000, InBox = true,
		Color = Color3.fromRGB(38, 44, 38), Length = 2.2, TracerColor = Color3.fromRGB(255, 220, 140),
	},
	WonderGun = {
		DisplayName = "Ray Blaster", Damage = 1000, HeadshotMultiplier = 1.5,
		FireRate = 0.35, Automatic = false, MagSize = 20, ReserveAmmo = 160,
		ReloadTime = 2.5, Range = 500, Spread = 0.4, Pellets = 1, Recoil = 1.4,
		Cost = 5000, InBox = true, Neon = true,
		Color = Color3.fromRGB(40, 210, 90), Length = 1.4, TracerColor = Color3.fromRGB(80, 255, 120),
	},
}

-- Mystery Box price
Config.MysteryBoxCost = 950

---------------------------------------------------------------- perks
Config.Perks = {
	ToughBrew = { DisplayName = "Tough Brew", Cost = 2500, MaxHealth = 250, Color = Color3.fromRGB(200, 30, 30), Short = "TB" },
	QuickHands = { DisplayName = "Quick Hands", Cost = 3000, ReloadMultiplier = 0.5, Color = Color3.fromRGB(40, 190, 80), Short = "QH" },
}

---------------------------------------------------------------- sounds (optional)
-- Paste Roblox audio ids like "rbxassetid://1234567890". Empty = silent.
Config.Sounds = {
	Fire = "",
	Reload = "",
	Hitmarker = "",
	Hurt = "",
	RoundStart = "",
	Purchase = "",
}

return Config
