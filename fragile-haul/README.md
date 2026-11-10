# Fragile Haul

A first-person salvage horror game that runs in the browser. It's an original game in the same genre as co-op "loot extraction" horror games.

You work the night shift clearing out an abandoned estate. Find valuables, float them back to the glowing **drop zone** with your grab beam, and cash out once you meet the night's quota. Every bump knocks money off an item's value, and loud noises draw the things that live in the house.

## Play

Open `index.html` in a desktop browser. It works straight from the file, with no server or build step.

| Control | Action |
| --- | --- |
| W A S D | Move |
| Mouse | Look |
| Hold left click | Grab beam (release to drop) |
| Right click | Throw the held item |
| Mouse wheel | Pull the held item closer or push it away |
| Shift | Sprint (fast but loud) |
| C / Ctrl | Crouch (slow, quiet, harder to spot) |
| E | Cash out while standing in the drop zone |
| Esc / P | Pause |

## How it works

- **Procedural estate:** every night builds a new maze of rooms with furniture, flickering lamps and randomly placed valuables. It gets bigger each night.
- **Physics and damage:** items bounce, roll and collide. An impact harder than a safe speed costs money based on the item's fragility, and an item that drops below 10% of its value shatters. Heavy items sag on the beam and slow you down.
- **Monsters:** they wander the house, hear impacts and sprinting footsteps and come to check, and chase you when they see you. A hit costs 34 health and makes you drop what you're holding. More of them appear on later nights.
- **Quota:** starts at $4,000 and rises $3,000 each night. Your best total is saved in the browser.

## Files

- `index.html`: page, HUD and menus
- `style.css`: HUD and menu styling
- `game.js`: the whole game (level generation, physics, AI, audio and HUD)
- `lib/three.min.js`: [three.js](https://threejs.org) r160 (MIT license, see `lib/THREE-LICENSE`)
