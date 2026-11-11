#!/bin/bash
# Installs the dev addon !DiagErreurs next to DeckForever (F10 runs DeckForever's Placements.lua live).
HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/../!DiagErreurs"; DST="$HERE/../../../!DiagErreurs"
mkdir -p "$DST"
cp "$SRC/!DiagErreurs.toc" "$SRC/DiagErreurs.lua" "$DST/"
luac -p "$DST/DiagErreurs.lua" && echo "!DiagErreurs installed"
