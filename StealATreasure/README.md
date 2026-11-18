# 💎 STEAL A TREASURE

A colorful multiplayer Roblox simulator. Collect treasures, earn passive income, upgrade and protect your base, sneak into other players' bases to steal their loot, trade, rebirth and become the richest player.

The whole game is generated from Luau code: the map, all 106 treasure models, the bases and the UI. You don't need to upload any assets.

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
| Inventory / Index / Shop | **B / N / M** | Left menu |

1. **Collect.** Free treasures spawn in the 8 Treasure Fields. The central market's 10 stalls restock every 45s with treasures you can buy.
2. **Carry home.** Treasures ride above your head (arms-raised carry pose) and a guide beam points to your base. Walk into your base to deliver them; they go straight onto a free display platform.
3. **Earn.** Every placed treasure makes money every second, boosted by upgrades, rebirths and events. You also get 10% offline income for up to 8 hours.
4. **Steal.** Walk into another base and hold **E** on a treasure. The owner gets a full-screen alarm, and the sirens and lights on their base go off. Make it back to your own base before they bonk you!
5. **Defend.** Lock your base, buy Fortress Security, and bonk thieves with the hammer so stolen treasure goes back home.

---

## 🗂️ Project structure

```
src/
├─ shared/            (ReplicatedStorage.Shared)
│  ├─ Config.lua          all tuning values
│  ├─ Rarities.lua        8 rarity tiers + effect rules
│  ├─ TreasureData.lua    106 treasures (102 collectable + 4 rebirth exclusives)
│  ├─ TreasureModels.lua  procedural 3D models (25 shapes) + particle/beam/halo FX
│  ├─ UpgradeData.lua     shop upgrades, abilities, derived stats
│  ├─ Remotes.lua         RemoteEvent/RemoteFunction declarations
│  └─ Util.lua            number formatting, deep copy, uid
├─ server/            (ServerScriptService.Server)
│  ├─ Main.server.lua     boots services in order
│  └─ Services/
│     ├─ NetService         single validated, rate-limited request entry point
│     ├─ DataService        DataStore load/save, session locking, autosave, BindToClose
│     ├─ MapBuilder         the whole world
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
   ├─ Controllers/        State, Sound, WorldFX (animations/effects/prompts), Input
   └─ UI/                 Lib, Windows, HUD, Notifications, Preview, and the
                          Inventory, Index, Shop, Rebirth, Leaderboard, Settings
                          and Trade windows
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

## 🔊 Sounds

Default sound effects use `rbxasset://sounds/...` files that ship with the Roblox client. You can replace any entry in `Config.Sounds` with your own uploaded `rbxassetid://` audio.
