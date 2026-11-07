#!/bin/bash
# Installs the dev addon !DiagErreurs next to DeckForever, with placements.lua ahead of it (F10 runs it live).
HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/../!DiagErreurs"; DST="$HERE/../../../!DiagErreurs"
mkdir -p "$DST"
cp "$SRC/!DiagErreurs.toc" "$DST/"
{ cat "$HERE/placements.lua"; echo; cat "$SRC/DiagErreurs.lua"; } > "$DST/DiagErreurs.lua"
luac -p "$DST/DiagErreurs.lua" && echo "!DiagErreurs installed"
