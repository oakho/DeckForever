-- usage: lua check.lua survey.lua : the HUD's pieces in Deck pixels, their gaps to the edges, and every overlap
local e = {}
assert(loadfile(arg[1], "t", e))()
local k = 800 / 768
local WANT = {
  ["PlayerFrame"] = "Joueur", ["TargetFrame"] = "Cible", ["FocusFrame"] = "Focus",
  ["GamepadBar.topBar"] = "Barre principale", ["ChatFrame1"] = "Chat",
  ["BuffBarCooldownViewer"] = "Barres d'amélio.", ["EssentialCooldownViewer"] = "Recharges", ["UtilityCooldownViewer"] = "Utilitaires",
  ["BuffIconCooldownViewer"] = "Icônes amélio.", ["SwingTimerMainHandFrame"] = "Barre d'attaque",
  ["ObjectiveTrackerFrame"] = "Quêtes", ["StatusTrackingBarManager"] = "XP",
  ["PlayerCastingBarFrame"] = "Incantation", ["ChatFrame1EditBox"] = "Saisie chat", ["Minimap"] = "Carte carrée", ["MinimapCluster.3#Button"] = "Bandeau carte", ["DeckForeverLegend"] = "Aide (DF)", ["GamepadIcon.LeftClassAction"] = "Aura (LB+LT)", ["GamepadIcon.RightClassAction"] = "Action classe D", ["GamepadIcon.LeftInputPrompt"] = "Invite LB+LT", ["GamepadIcon.RightInputPrompt"] = "Invite droite", ["GamepadIcon.LeftShoulderIcon"] = "Icône LT", ["GamepadIcon.RightShoulderIcon"] = "Icône RT", ["ControllerKeyboardSupplies"] = "Sacs (EC)", ["BuffFrame"] = "Améliorations", ["DebuffFrame"] = "Affaiblissements", ["CastingBarFrame"] = "Incantation",
}
local items = {}
for _, line in ipairs(e.DiagErreursDB.layout) do
  local d, name, rect = line:match("^(%d)|(.-)|(.-)|")
  local l, b, w, h = rect:match("(-?%d+),(-?%d+),(-?%d+),(-?%d+)")
  local label = WANT[name]
  if not label and name:match("^UIParent%.%d+#Frame%.%d#Frame$") and tonumber(w) < 45 then label = "Palette " .. name:match("(%d)#Frame$") end
  if label then
    l, b, w, h = tonumber(l) * k, tonumber(b) * k, tonumber(w) * k, tonumber(h) * k
    items[#items + 1] = { label = label, x = l, y = 800 - (b + h), w = w, h = h }
  end
end
table.sort(items, function(a, b) return a.y < b.y end)
for _, it in ipairs(items) do
  print(("%-18s x=%5.0f..%5.0f  y=%5.0f..%5.0f   bords: g%4.0f d%4.0f h%4.0f b%4.0f"):format(it.label, it.x, it.x + it.w, it.y, it.y + it.h,
    it.x, 1280 - it.x - it.w, it.y, 800 - it.y - it.h))
end
print("-- chevauchements :")
local n = 0
for i = 1, #items do for j = i + 1, #items do
  local a, b = items[i], items[j]
  local ox = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
  local oy = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
  local blizz = (a.label:find("^Icône") and b.label == "Barre principale") or (b.label:find("^Icône") and a.label == "Barre principale")
  if ox > 0.5 and oy > 0.5 and not blizz and not (a.label:find("chat") and b.label == "Chat") and not (b.label:find("chat") and a.label == "Chat") then
    n = n + 1
    print(("  %s / %s : %.0f x %.0f px"):format(a.label, b.label, ox, oy))
  end
end end
print(n == 0 and "  aucun" or ("  " .. n .. " chevauchement(s)"))
