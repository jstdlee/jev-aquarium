# jev-aquarium

A cozy aquarium toy for Steam, built with Godot 4.7. One tank view, no HUD. You feed and play with the fish using the mouse.

## Run

```bash
godot --path ~/dev/jev/jev-aquarium
```

## Controls

| Input | What happens |
|---|---|
| Move the mouse | Curious fish come to your finger on the glass; shy ones keep away |
| Click | Tap the glass (ring, fish startle, then come back to look) |
| Double-click | Sprinkle food; fish compete for it |
| Triple-click | Bubble burst, and a beach ball the fish nudge around |
| Drag | Stir the water; plants, leaves, food and fish follow the current. Sweeping low over the sand clears cloudy water |
| Esc / right-click | Settings: random or chosen fish, restock, care mode, hunger test speed, memorial |
| F1 | Fish names and hunger |
| F11 | Fullscreen |

## Hunger

Hunger keeps running while the game is closed. With the default timings a fish becomes hungry after about 8 hours, starving after about 36, and dies after about 72 without food. Relaxed mode halves the speed; Peaceful mode never lets a fish die.

## Layout

- `scripts/` contains the game logic: `main.gd` (input), `tank.gd` (scene), `fish.gd` (behaviour), `fish_mesh.gd` (procedural fish), `game.gd` (state, hunger, save), `species.gd` (fish catalogue).
- `shaders/` contains the swim motion, caustics, water surface, plants, sand, glass and particles.
- `tools/shot.sh` runs scripted input on a private display and saves screenshots.
- `concept/` holds the chosen art direction.
- `PLAN.md` has the plan and decisions.
