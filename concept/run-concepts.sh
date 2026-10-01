#!/bin/bash
# Generate the three art-direction concept images with Codex's image tool (via magpie on :3425).
# Output: A_jewel_reef.png, B_moonlit_glow.png, C_lantern_garden.png (+ .log each) in this folder.
cd "$(dirname "$0")"

gen() {
  # Direct to OpenAI: the built-in image_gen tool is unavailable through the magpie proxy.
  codex exec --skip-git-repo-check -s workspace-write -m gpt-6-luna \
    -c openai_base_url='"https://chatgpt.com/backend-api/codex"' \
    "Use ONLY your built-in image_gen tool (do not use any MCP server or script) to create ONE image in 16:9 landscape, then copy the resulting PNG into the current directory as $1.png. Do nothing else. Image prompt: $2" \
    </dev/null >"$1.log" 2>&1
}

COMMON="Concept art for a premium relaxing aquarium video game on Steam. Wide 16:9 front view straight into the aquarium, the water scene fills the whole frame edge to edge (no visible tank frame, no room, no UI, no text, no watermark). Stylized semi-realism with anime-saturated color, like a background from a high-end anime film, painterly yet crisp. Fish have cute, expressive but believable shapes, glossy scales, translucent glowing fins with soft rim light. Calm, cozy, magical, polished commercial quality."

gen A_jewel_reef "$COMMON Theme: tropical saltwater JEWEL REEF in bright daylight. Glowing pink, violet and orange corals, a sea anemone, swaying sea grass, white sand with caustic light patterns, soft god rays from the surface, floating sparkling particles, teal-blue depth haze. Fish: clownfish in the anemone, blue tang, yellow tang, a mandarin dragonet with intricate patterns, a school of small neon cardinal tetras." &
gen B_moonlit_glow "$COMMON Theme: MOONLIT BIOLUMINESCENT tank at night. Deep indigo and violet water, corals and mushroom anemones glowing cyan, magenta and gold, soft moonbeams from above, drifting glowing plankton motes, gentle bubbles catching light. Fish: a royal blue and crimson halfmoon betta with huge flowing fins, glowing lanternfish school, a small cute pufferfish, a ghost-white angelfish. Dreamy and soothing." &
gen C_lantern_garden "$COMMON Theme: freshwater NATURE AQUASCAPE garden (Takashi Amano style) in warm golden afternoon light. Lush green carpet plants, mossy driftwood branches, red and green stem plants, dragon stone rocks, tiny floating leaves on the surface casting soft shadows, warm sunbeams, golden dust particles. Fish: a pair of calico fancy fantail goldfish, a red-and-white ranchu, a school of neon tetras, rainbow guppies with fan tails, a turquoise discus." &
wait
ls -la *.png
