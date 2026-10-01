# jev-aquarium — plan

Comfort aquarium toy for Steam (commercial). Godot 4, one fixed tank view, no HUD.
Free / commercially safe resources first; paid assets only where free ones fall short.

## Decisions (2026-10-01)

- Platform: Steam only (Windows + Linux builds; Steam Deck nice-to-have). GodotSteam for
  achievements and Steam Cloud saves.
- Sold commercially, so every asset needs a license that allows commercial use
  (CC0 preferred, CC-BY with credits screen OK, no "non-commercial" or unclear licenses).
- Art direction: picked by Claude ("most fancy"), shown to user as concept images before
  production starts.
- Fish population: user-controllable, fixed or random.
- Hunger system with death after long neglect.

## Art direction (chosen 2026-10-01): C "Lantern Garden"

Reference: `concept/C_lantern_garden_chosen.webp`. Freshwater nature aquascape in warm
golden light: mossy driftwood, carpet plants, red/green stem plants, dragon-stone rocks,
floating leaves on the surface, sunbeams, golden dust motes.

Launch fish (from the concept): calico fantail goldfish, red-white ranchu, turquoise
discus, fan-tail guppies, neon tetra school.

Keep from the concept: glass edges at the sides (reads as a real tank), surface-level
floating plants and their shadows, warm sun shafts, fish seen mostly in side profile.

Change for the game: show a little more open water in the middle for fish and food, use
darker depth at the back for contrast, and add a cooler blue tone to the shadows so
fish colors pop.

## Look

Fixed-camera 3D tank. Stylized semi-realism: believable fish shapes, anime-saturated color,
soft toon-leaning shading, strong rim light, caustics, god rays, depth haze, floating motes.
Fish swim from a vertex shader (no rigging, no hand animation); behavior comes from steering
code with a personality per species.

## Interaction

| Input          | Result                                                                 |
|----------------|------------------------------------------------------------------------|
| Mouse move     | Curious fish follow the "finger on glass"; shy ones keep distance       |
| Click          | Glass tap: ripple + sound; fish startle, then return curious           |
| Double click   | Drop food: pellets sink with physics, fish compete                     |
| Triple click   | Bubble burst / toy drop (ball, ring) that fish nudge around            |
| Drag           | Hand stirs water: plants sway, bubbles and small fish ride the current |
| Idle           | Fish rest, explore, gather by coral; light drifts slowly               |

Settings live behind Esc / right-click only.

## Population

- Mode **Fixed**: per-species count chosen in settings.
- Mode **Random**: total min..max, species picked by weighted rarity; reroll button.
- Hard cap tuned for 60 fps on Steam Deck-class hardware (target ~40 individuals plus schools
  rendered with MultiMesh).
- New fish can be added from settings; later maybe eggs/breeding when well fed.

## Hunger and death

Each fish has `satiety` 100 → 0, draining in real time (also while the game is closed,
computed from the save timestamp). Rates differ per species.

| Satiety | State    | Visible behavior                                                    |
|---------|----------|---------------------------------------------------------------------|
| 70–100  | Full     | Lazy, playful, ignores some food                                    |
| 40–70   | Content  | Normal                                                              |
| 15–40   | Hungry   | Patrols surface, follows cursor eagerly, begs at the glass          |
| 1–15    | Starving | Colors fade, slower, fins droop, rests on the bottom                |
| 0       | Dies     | Gentle: drifts up belly-up, fades softly; leaves a small memorial    |

Default timings (tunable): hungry after ~8 h, starving after ~36 h, death after ~72 h without
food. Settings: Normal / Relaxed (slower drain) / Peaceful (no death). Overfeeding: leftover
food slowly clouds the water; dragging along the bottom cleans it.

## Free, commercially safe resource plan

| Need               | Source                                                                  |
|--------------------|-------------------------------------------------------------------------|
| Fish bodies        | Procedural: Blender Python lofts body from profile curves + fin planes, so every species is ours, no license risk |
| Fish patterns      | Painted textures generated locally (Z-Image Turbo / Qwen-Image, both Apache-2.0), hand-picked, projected onto the procedural body |
| Coral, plants      | Procedural (Blender geometry nodes / code) + Poly Haven (CC0)            |
| Sand, rock, HDRI   | ambientCG, Poly Haven (CC0)                                              |
| Sound effects      | Sonniss GDC bundles (royalty-free), Kenney audio + Freesound CC0, own recordings |
| Music              | CC0 ambient first; commission or license a track set before launch       |
| Concept art        | Local generation, used as reference only                                 |

Avoid: Hunyuan3D (license excludes EU/UK/KR), any "non-commercial" model or asset.

## Phases

- **P0 Direction:** concept images → user picks look.
- **P1 Feel prototype** (built 2026-10-01): procedural tank in the Lantern Garden look, 5 species
  as procedural meshes with shader swimming, all mouse interactions, hunger and death, random or
  fixed population, settings menu, save with offline hunger. Tested on software OpenGL only;
  Forward+ on the real GPU still needs a first run. Waiting on user feel feedback.
- **P2 Visual target:** one corner at final quality (water, light, one hero fish, coral).
- **P3 Content:** 8–15 species, decorations, toys, procedural fish pipeline.
- **P4 Sound and music.**
- **P5 Steam:** GodotSteam, achievements, cloud save, settings, performance, store page
  assets (capsules, trailer).
