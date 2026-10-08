#!/bin/bash
# Reference solution for gamecraft-bench/puzzle-echo-vault.
#
# Drops a complete time-loop puzzle platformer into /workspace/game/:
#   - Fixed-tick (60 Hz) platformer physics; echoes re-simulate recorded inputs.
#   - Loops anchored on the player's first input so replayed traces are stable.
#   - Five chambers: plate+door, plate-powered lift, lever+timed gate,
#     twin plates with a pulsing laser, and a combined final chamber.
#   - Paradox detection (echo diverges from its recorded path), stability,
#     defeat/retry, chamber clear with vault progress, victory.
#   - Seven demo traces covering the instruction's required demo table.
#
# Source files live next to this script under files/; Kenney sprites and
# fonts are copied from the mounted asset library.
set -eu

GAME=/workspace/game
SRC="$(dirname "$(readlink -f "$0")")/files"
LIB=/workspace/assets/library/2D

mkdir -p "$GAME/assets"
cp -r "$SRC"/. "$GAME"/

cp "$LIB/pixel-platformer/Tilemap/tilemap_packed.png"                  "$GAME/assets/tiles.png"
cp "$LIB/pixel-platformer-industrial-expansion/Tilemap/tilemap_packed.png" "$GAME/assets/ind.png"
cp "$LIB/pixel-platformer/Tilemap/tilemap-characters_packed.png"       "$GAME/assets/chars.png"
cp "$LIB/ui-pack/Font/Kenney Future.ttf"                               "$GAME/assets/KenneyFuture.ttf"
cp "$LIB/ui-pack/Font/Kenney Future Narrow.ttf"                        "$GAME/assets/KenneyFutureNarrow.ttf"

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
