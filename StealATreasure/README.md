# 💎 STEAL A TREASURE

A colorful multiplayer Roblox simulator. Collect treasures, earn passive income, upgrade and protect your base, sneak into other players' bases to steal their loot, trade, rebirth and become the richest player.

The whole game is generated from Luau code: the terrain and map, all 112 treasure characters, 52 pets, the bases, the animations, the UI and even the background music. You don't need to upload any assets.

## ✨ What's in the game

- **Treasure Parade**
  - Treasures walk along a red carpet through the middle of the map; buy them as they pass by holding **E**.
  - What you buy walks to your base by itself. It can't be stolen until it reaches its stand.
- **Base rows**: 4 bases line each side of the parade, and the market plaza sits at the parade's start.
- **Per-stand cash**
  - Every stand fills its own green collect plate; step on it to grab the money.
  - The HUD "Collect" button grabs everything while you're in your base.
- **Mutations**
  - Gold ×1.25, Diamond ×1.5, Rainbow ×2, Lava ×2.5 (event only) and Galaxy ×4.
  - Mutated treasures are recoloured, sparkle, and keep their mutation when stolen or traded.
  - Lava Eruption and Rainbow Storm events make mutations common.
- **Gear shop**
  - Bat tiers (Wooden → Iron → Diamond → Galaxy) give longer reach, longer stun and bigger knockback.
  - Speed Coil, Grapple Hook, and Bear Traps that catch thieves and make them drop the loot.
- **Rebirth requirements**: each rebirth also needs certain treasures (e.g. 1 Epic, then 1 Legendary, then 2 Legendary…).

- **World**
  - Real Terrain grass that sways in the wind, plus a lake with a dock, a lighthouse and an island.
  - Rolling hills, border mountains and 3 pine forests with glowing mushrooms.
  - A windmill farm, the marketplace, and Pet and Gem shops.
- **Day, night and weather**
  - A 12-minute day/night cycle. Lamps switch on at night and music changes mood.
  - Weather (Clear, Cloudy, Rain, Storm with lightning and thunder, Fog) and clouds that move with the wind.
- **Animated environment**
  - Swaying trees, waving flags, spinning windmills and portal rings.
  - Bobbing gems, glowing lights, a flowing waterfall, a rotating lighthouse beam and chests whose lids open.
- **Secrets and travel**
  - Secret areas: Crystal Cave, Sky Island and Hidden Vault.
  - Event locations: Meteor Crater and Celestial Shrine.
  - 3 animated portals from the plaza. Sky Island's portal unlocks after you find the island on foot.
- **Treasure characters**: 108 collectable treasures over 9 rarities (now including **Celestial**), plus 4 rebirth exclusives.
  - Each has a face that blinks and changes expression: happy, surprised, sleepy at night, excited.
  - Each has an idle personality: Hop, Dance, Float, Spin, Wiggle or Bounce.
  - Field treasures **roam**: they walk, run, jump and dance.
  - Legendary and up do a power spin-jump. Mythical and up have an income **Aura** ability.
  - Treasures pop in when they spawn and shrink away when they disappear.
- **Player animations**
  - Walk, run and jump use Roblox's defaults.
  - Custom procedural poses: sprint lean (Shift, with stamina), crouch-and-reach while stealing, arms-up carry, celebrate, cheer, wave, flex, dance and a victory spin.
- **Pets**
  - 52 pets in 25 species across 9 rarities, hatched from 4 eggs with an animated hatch sequence.
  - Pets follow you: walkers trot with moving legs and hop when you jump; flyers flap their wings. Tails wag and ears twitch.
  - Pets give income, luck, speed or gem bonuses. You can equip up to 6.
- **Bases**
  - Display stands on 2 floors (up to 36), wall materials you can upgrade (Wood → Diamond), sliding doors and a laser lock.
  - Security cameras that spot intruders, plus laser traps that zap thieves escaping with your loot.
  - Alarms, 12 colours to choose from, tower banners, a floating gem statue, and a 💰 collector pad (or buy an Auto Collector).
- **Economy**
  - Money and gems, 9 upgrades (Speed, Carry, Base, Protection, Income, Luck, Security, Walls, Second Floor) and 4 abilities.
  - Gem shop boosts, rebirth, levels and 25 achievements.
- **Events**: Double Money, Meteor Shower, Golden Treasure Rain (collectable coins), Treasure Apocalypse (red sky), Secret Treasure Spawn, Lucky Treasure (2× luck) and Divine Descent. Each has a banner, sky tint, sounds and camera shake.
- **Multiplayer**
  - Stealing and trading, now including pets.
  - Global leaderboards, multiplayer events and server-wide announcements.
- **Graphics**
  - Future lighting (dynamic shadows from every light), reflective water and glass, bloom, sun rays and colour grading.
  - A cinematic intro with letterbox and depth of field, FOV effects, and scrolling Beam textures.
- **Console**: gamepad bindings, plus D-pad menus that work with the gamepad cursor.

---

## 🚀 Getting it into Roblox Studio

**Option A: open the place file (quickest)**
1. Open `StealATreasure.rbxlx` in Roblox Studio.
2. Press **Play**. The map builds itself when the server starts.

**Option B: Rojo (for development)**
1. Install [Rojo](https://rojo.space) and the Studio plugin.
2. Run `rojo serve` in this folder and connect from Studio.

To rebuild the place file after you edit the code, run `python3 tools/build_place.py`.

**Before you publish:**
- *Game Settings → Security → Enable Studio Access to API Services*, so progress saves while testing in Studio. Without it the game still runs, but saving is off and a warning toast appears.
- *Game Settings → Places → Max Players = 8*. There are 8 bases, and a 9th player is told the server is full.
- *Avatar*: R15 and R6 both work, including the carry pose.
- Optional: put your own uploaded audio IDs in `Config.Sounds`. Background music is off until you set `Config.Sounds.Music`.

---

## 🎮 How to play

| Action | PC | Mobile |
|---|---|---|
| Grab, buy or steal a treasure | Hold **E** on the prompt | Tap and hold the prompt |
| Move your own treasure to storage | **G** | Tap the prompt |
| Bonk a thief | Equip the **Bonk Hammer** (1) and click | Tap |
| Dash / Super Jump / Cloak | **Q / R / F** | On-screen buttons |
| Lock base | **L**, the HUD button or the red button in your base | HUD button |
| Inventory / Index / Upgrades / Pets | **B / N / M / P** | Left menu |
| Sprint | Hold **Shift** (L3 on gamepad) | Sprint button |
| Emotes | **T** (X on gamepad) | Emote button |
| Collect income | Step on the 💰 pad in your base | HUD "Collect" button while you're in your base |

1. **Collect.** Free treasures spawn in the 8 Treasure Fields. The central market's 10 stalls restock every 45s with treasures you can buy.
2. **Carry home.** Treasures ride above your head (arms-raised carry pose) and a guide beam points to your base. Walk into your base to deliver them; they go straight onto a free display platform.
3. **Earn.** Every placed treasure fills your base vault each second, boosted by upgrades, pets, auras, rebirths and events. Collect it from the 💰 pad. You also get 10% offline income for up to 8 hours.
4. **Steal.** Walk into another base and hold **E** on a treasure. The owner gets a full-screen alarm, and the sirens and lights on their base go off. Make it back to your own base before they bonk you!
5. **Defend.** Lock your base, buy Fortress Security, and bonk thieves with the hammer so stolen treasure goes back home.

---

## 🗂️ Project structure

```
src/
├─ shared/            (ReplicatedStorage.Shared)
│  ├─ Config.lua          all tuning values
│  ├─ Rarities.lua        8 rarity tiers + effect rules
│  ├─ TreasureData.lua    112 treasures (108 collectable + 4 rebirth exclusives), personalities, auras
│  ├─ TreasureModels.lua  procedural 3D models (25 shapes) + faces + particle/beam/halo/orbit FX
│  ├─ Motion.lua          deterministic roaming path shared by server (validation) and clients
│  ├─ PetData.lua         52 pets, 25 species, 4 eggs, luck-weighted rolls
│  ├─ PetModels.lua       procedural pet builder with animatable parts
│  ├─ AchievementData.lua 25 achievements
│  ├─ UpgradeData.lua     shop upgrades, abilities, derived stats
│  ├─ Remotes.lua         RemoteEvent/RemoteFunction declarations
│  └─ Util.lua            number formatting, deep copy, uid
├─ server/            (ServerScriptService.Server)
│  ├─ Main.server.lua     boots services in order
│  └─ Services/
│     ├─ NetService         single validated, rate-limited request entry point
│     ├─ DataService        DataStore load/save, session locking, autosave, BindToClose
│     ├─ MapBuilder         the whole world (terrain, plaza, base slots, secrets, events)
│     ├─ MapDetails         lake, hills, forests, windmills, shops, portals, animated tags
│     ├─ WorldService       day/night clock, weather, chests, portals, event coins
│     ├─ PetService         hatching, equipping, pet bonuses
│     ├─ AchievementService achievements + gem rewards
│     ├─ BaseService        bases, platforms, door barrier, lock, alarm, sign
│     ├─ CarryService       carrying, pose, delivery, drop/return
│     ├─ TreasureService    world spawns, market, give/place/store/sell, secrets, magnet
│     ├─ StealService       steal validation, alarm, transfer, lockdown, Bonk Hammer
│     ├─ EconomyService     passive income, XP/levels, offline earnings
│     ├─ StateService       debounced state replication to clients
│     ├─ PlayerService      leaderstats, spawning, overhead tag, trails, settings
│     ├─ ShopService        upgrades + abilities
│     ├─ RebirthService     rebirth + milestone rewards
│     ├─ TradeService       trading
│     ├─ LeaderboardService global OrderedDataStore boards + physical board
│     └─ EventService       Golden Hour, Meteor Shower, Treasure Rain, Divine Descent
└─ client/            (StarterPlayerScripts.Client)
   ├─ Main.client.lua     builds UI, responsive scaling, starts controllers
   ├─ Controllers/        State, Sound, WorldFX (effects/prompts), TreasureAnimator,
   │                      Emotes, PetFollower, Ambience, Music, Cinematic, Input
   └─ UI/                 Lib, Windows, HUD, Notifications, Preview, and the
                          Inventory, Pets, Index, Upgrades, Gem Shop, Rebirth,
                          Leaderboard, Achievements, Settings and Trade windows
```

---

## 🔐 Server-side validation

The client never decides anything. It only sends requests through one rate-limited `Action` RemoteFunction (12 requests/second), and the server checks each one.

- **Stealing** checks:
  - the thief isn't the owner
  - the target base isn't locked
  - the owner's new-player shield has expired
  - the thief's steal cooldown and the same-victim cooldown have expired
  - the thief isn't trading
  - the thief has free carry capacity and room at home
  - the thief is alive and physically within range of that exact treasure
  - nobody else is already stealing it

  Ownership only transfers when the thief physically enters their own base, and the server checks again at that moment.
- **Picking up and buying** check distance, capacity, storage room and money on the server. Prices come from server data, never from the client.
- **Trading:**
  - Every offered uid is checked against the giver's data.
  - Money is clamped to the balance.
  - Offered items are pulled off platforms so they can't be stolen or earn mid-trade.
  - Any change cancels "ready", and there's a 3-second confirm countdown.
  - At execution the server re-validates ownership, stealing state, money and both players' capacity. Then it removes everything before adding anything and saves both players immediately.
- **Saving** uses `UpdateAsync` with a session lock, so two servers never overwrite each other. It also retries with backoff, autosaves every 90s, saves on leave and on shutdown (`BindToClose`), and reconciles old saves with the current template.

---

## ⚖️ Fair-play systems

- **New-player shield**: 90s of protection after joining. It ends early if you steal.
- **Thief cooldown**: 25s between successful steals, and 75s before you can rob the same player again.
- **Post-robbery lockdown**: a robbed base auto-locks for 20s, plus 4s per Protection level.
- **Manual lock**: 30s base duration (+8s per level), then a recharge (60s, −3s per level). Intruders are pushed out when the lock engages. The owner can always walk through their own barrier.
- **Steal hold time**: 1.6s, plus 0.25s per Protection level of the victim.
- **Thieves are slowed** to 85% speed. Stolen loot goes back home after 120s, or if the thief dies, leaves or gets bonked.
- If an owner leaves mid-theft, the treasure stays with them.

---

## 💰 Progression

- **Rarities**: Common → Uncommon → Rare → Epic → Legendary → Mythical → Secret → Divine. Income ranges from $1/s to $1.5M/s.
- **Upgrades**:
  - Swift Boots (speed)
  - Treasure Backpack (carry up to 6)
  - Base Expansion (6 → 24 platforms, +5% income per level)
  - Fortress Security
  - Golden Vault (+10% income per level)
- **Abilities**: Dash, Super Jump, Shadow Cloak, Treasure Magnet (passive).
- **Levels**: XP for collecting, buying, stealing, defending and selling. Each level-up gives a cash reward.
- **Index**: your first copy of each treasure pays a discovery bonus.
- **Secrets**: the first visit to each secret area pays a reward:
  - **Crystal Cave**: walk through the waterfall at the north edge.
  - **Sky Island**: parkour spiral in the south-east.
  - **Hidden Vault**: the hollow tree in the south-west.
- **Rebirth**:
  - Starts at $250K and costs 3.5× more each time.
  - Gives +50% income and +1 speed forever, plus more starting cash.
  - You keep abilities, index, secrets, titles and exclusive treasures.
  - Rebirths 1, 3, 5 and 10 unlock exclusive treasures, titles and trails.
- **Events** (every 4–6 min):
  - Golden Hour (2× income)
  - Meteor Shower (Epic+ loot at the Meteor Crater)
  - Treasure Rain
  - Divine Descent (a Mythical+ relic on the Celestial Shrine)

---

## 📱 Performance and mobile

- The UI scales to the screen (designed at 1280×720) and has a user scale setting. Touch players get on-screen ability buttons placed clear of the jump button.
- Treasure spin/bob animation runs only on the client, and only within 140 studs. The server never moves treasures.
- **Performance Mode** turns off treasure particles, beams, lights, shadows, bloom and animation.
- State replication is debounced: a full snapshot only when something changes, plus small stats packets.
- Decoration parts are anchored, with shadows off where they don't matter.

## 🧪 Testing in Studio

When you run in Studio, Settings shows **Studio test** buttons that start any world event straight away. Multiplayer can be tested with *Test → Clients and Servers*.

## 🔊 Sounds

Default sound effects use `rbxasset://sounds/...` files that ship with the Roblox client. Footstep and jump sounds come from Roblox's built-in character sounds.

**Background music** is a built-in procedural soundtrack (`Controllers/Music.lua`): melody, bass and arpeggios played by pitching one note sample. Day, night and event moods each have their own tempo and scale. To use a real track instead, set `Config.Sounds.Music` to an uploaded audio ID.

You can replace any entry in `Config.Sounds` with your own `rbxassetid://` audio for a more polished sound.
