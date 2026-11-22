# Zombie Waves — first-person Roblox zombie survival

Survive endless rounds of zombies that get tougher every wave. Earn points for every hit and kill,
buy guns off the walls, gamble on the Mystery Box, open doors to new areas and drink perks.

## Install (1 minute)

1. Open **Roblox Studio** → New → **Baseplate**.
2. Open **View → Command Bar**.
3. Open [`Install.lua`](Install.lua), copy **all** of it, paste it into the Command Bar and press **Enter**.
   You should see `Zombie Waves installed!` in the Output window.
4. Press **Play (F5)**. The map builds itself and round 1 starts after a short countdown.

Test multiplayer: **Test → Clients and Servers → 2 Players → Start**.

> Prefer doing it by hand? Create these scripts and paste each file's contents:
>
> | Studio location | Type | Name | File |
> |---|---|---|---|
> | ReplicatedStorage | ModuleScript | `ZombieConfig` | `src/ReplicatedStorage/ZombieConfig.lua` |
> | ServerScriptService | ModuleScript | `ZombieMapBuilder` | `src/ServerScriptService/ZombieMapBuilder.lua` |
> | ServerScriptService | Script | `ZombieServer` | `src/ServerScriptService/ZombieServer.server.lua` |
> | StarterPlayer → StarterPlayerScripts | LocalScript | `ZombieClient` | `src/StarterPlayerScripts/ZombieClient.client.lua` |
>
> Rojo users: `rojo serve` (uses `default.project.json`).

## Controls

| Key | Action |
|---|---|
| Mouse | Aim |
| Left click | Shoot (hold for automatic guns) |
| R | Reload |
| 1 / 2 / mouse wheel | Switch gun |
| Shift | Sprint |
| E | Buy (wall gun, door, box, perk) |

## How it plays

- **Rounds:** more zombies each round (and more with more players). Their health grows every round
  and they get faster. Round number is in red in the top-left with zombies remaining under it.
- **Points:** +10 per hit, +60 per kill, +100 per headshot kill. You start with 500.
- **Wall-buys:** SMG (1200) and Shotgun (1500) in the start room, Assault Rifle (2500) behind the door.
  Buying a gun you already own refills its ammo for half price. You can carry 2 guns.
- **Door (750):** opens room B, which has the rifle, the Mystery Box and a perk. Zombies start spawning there too.
- **Mystery Box (950):** random gun — including the Heavy LMG and the Ray Blaster.
- **Perks:** Tough Brew (2500, 250 health) and Quick Hands (3000, reload twice as fast).
- **Health** regenerates after 4 seconds without being hit. If you go down you lose your guns and perks
  and respawn at the start of the next round. When everyone is down it's game over and the game restarts.

## Effects

- Blood-moon night: red fog, colour grade, bloom glow on eyes, fire and neon, a giant moon.
- Zombies walk, sway and swipe at you (animated on each player's computer, so the server stays fast).
- Blocky blood on every hit. Headshot kills pop the head off with a gore burst and a **HEADSHOT!** pop-up.
- Camera shake when you shoot and when you're hit; the round number slams in with a red flash each round.
- Burning barrels with flickering firelight and embers, blood pools, a boarded-up door and a light beam
  over the Mystery Box so you can find it from anywhere.

## Customise

Everything is in **`ZombieConfig`**: weapon damage/fire rate/ammo/price, zombie health/speed/damage per round,
points, perk prices, round timings. Add sound ids under `Config.Sounds` (`"rbxassetid://..."`).

**Build your own map:** make a Folder called `ZombieMap` in Workspace before pressing Play (the built-in map is
then skipped). Inside it put a `SpawnLocation` and parts with these attributes:

| Thing | Setup |
|---|---|
| Zombie spawn | Part named `ZombieSpawn`, ~3 studs above the floor, attribute `Area` = `"A"` |
| Wall-buy | `Interact` = `"WallBuy"`, `Weapon` = `"SMG"` (any key from `Config.Weapons`), optional `Cost` |
| Door | `Interact` = `"Door"`, `Cost` = `750`, `OpensArea` = `"B"` (spawns with `Area` `"B"` start after it opens) |
| Mystery Box | `Interact` = `"MysteryBox"` |
| Perk machine | `Interact` = `"Perk"`, `Perk` = `"ToughBrew"` or `"QuickHands"` |

## Security notes

The server owns every decision: it checks fire rate, ammo, reload state and shot origin, does its own raycasts,
awards points and charges for purchases. The client only says "I pulled the trigger", so exploiters can't
give themselves points, infinite ammo or instant kills.

## Rebuilding the installer

After editing anything in `src/`, run `python3 tools/build_installer.py` to regenerate `Install.lua`.
