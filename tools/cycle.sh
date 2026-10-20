#!/bin/bash
# usage: tools/cycle.sh NAME [go] : /reload (loads the new code), /df go if asked (then /reload), screenshot,
# /reload again (the game writes !DiagErreurs' survey), then the overlap check.
# Writes $OUT/NAME.png (screenshot), $OUT/NAME-go.png, $OUT/NAME.lua (DiagErreursDB). OUT defaults to /tmp/deckforever-test.
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-/tmp/deckforever-test}; mkdir -p "$OUT"
F=$(ls -t "$HERE"/../../../../WTF/Account/*/SavedVariables/\!DiagErreurs.lua | head -1)
wait() { local s=$(date +%s); until [ $(( $(date +%s) - s )) -ge $1 ]; do sleep 2; done; }
"$HERE/wowcmd.sh" "/reload" >/dev/null; wait 30
if [ "$2" = "go" ]; then "$HERE/wowcmd.sh" "/df go" >/dev/null; sleep 1.5; timeout 15 spectacle -b -n -f -o "$OUT/$1-go.png"; "$HERE/wowcmd.sh" "/reload" >/dev/null; wait 30; fi
timeout 15 spectacle -b -n -f -o "$OUT/$1.png"
m=$(stat -c %Y "$F"); "$HERE/wowcmd.sh" "/reload" >/dev/null
s=$(date +%s); until [ $(stat -c %Y "$F") -gt $m ] || [ $(( $(date +%s) - s )) -ge 60 ]; do sleep 2; done
cp "$F" "$OUT/$1.lua"; wait 25
lua "$HERE/check.lua" "$OUT/$1.lua"
echo "-- erreurs / actions bloquées :"
lua -e 'local e={} assert(loadfile(arg[1],"t",e))() local d=e.DiagErreursDB local n=0
for _,x in ipairs(d.errors or {}) do n=n+1 print("  erreur "..x.at.." "..x.msg) end
for k,v in pairs(d.blocked or {}) do n=n+1 print("  bloqué "..v.."x "..k) end
if n==0 then print("  aucune") end' "$OUT/$1.lua"
