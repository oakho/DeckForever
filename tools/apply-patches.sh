#!/bin/bash
# Other addons' patches (tools/patches/*.patch, paths a/<Addon>/... b/<Addon>/...), applied again when an
# update has put the addon's own files back. Run by the wow-addon-patches user service (a path unit watching
# AddOns/), at login, and by hand. A patch that no longer fits (the addon's code changed) is reported on
# the desktop, never forced.
ADDONS="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ADDONS" || exit 1
for p in "$ADDONS"/DeckForever/tools/patches/*.patch; do
	[ -f "$p" ] || continue
	name=$(basename "$p")
	# (git apply: SteamOS has no patch; whitespace ignored: an update brings the files back in CRLF)
	if git apply -p1 -R --check --ignore-whitespace "$p" >/dev/null 2>&1; then continue; fi   # (in place)
	if git apply -p1 --check --ignore-whitespace "$p" >/dev/null 2>&1; then
		git apply -p1 --ignore-whitespace "$p" && msg="réappliqué" || msg="ÉCHEC"
	else
		msg="ne s'applique plus (code de l'addon changé) : à refaire"
	fi
	echo "$name: $msg"
	notify-send -a "DeckForever" -i dialog-information "Correctif d'addon" "$name : $msg" 2>/dev/null
done
