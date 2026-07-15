from pathlib import Path
import re


root = Path(__file__).resolve().parents[1]
ui = (root / 'src/core/ui_universal.lua').read_text(encoding='utf-8')
attach = (root / 'src/core/attach.lua').read_text(encoding='utf-8')
bridge = (root / 'src/vape/games/bridge.lua').read_text(encoding='utf-8')
vape_api = (root / 'src/vape/api.lua').read_text(encoding='utf-8')


def scope(source, start, end):
    begin = source.index(start)
    finish = source.index(end, begin)
    return source[begin:finish]


# The universal adapter must fail closed when no root-linked UI metatable exists.
candidate_selection = scope(
    ui,
    '\tfor meta, candidate in pairs(candidates) do',
    "\tif score < 12000 or type(lib) ~= 'table' then",
)
assert candidate_selection.count('for meta, candidate in pairs(candidates) do') == 1
assert 'candidate.linked and candidate.score > score' in candidate_selection
assert 'if not lib then' not in candidate_selection

# A linked candidate is not enough: every adopted object must itself be rooted in
# the detected Fiverose ScreenGui.
assert 'local function linkeditems(items)' in ui
object_collection = scope(
    ui,
    '\tfor index, obj in ipairs(gc) do',
    '\tlocal panel',
)
assert re.search(
    r"getmetatable\(obj\) == lib\s+and linkeditems\(rawget\(obj, 'Items'\)\)"
    r"\s+then\s+objects\[#objects \+ 1\] = obj",
    object_collection,
)
assert "screen ~= root" in ui

# Never rediscover ownership by recursively walking arbitrary Native.Items tables.
# Only exact, newly-created roots inside the detected screen may be destroyed.
assert 'destroyroots' not in ui
assert 'local function ownroot(obj)' in ui
assert 'local function destroyowned(...)' in ui
destroy_owned = scope(ui, '\tlocal function destroyowned(...)', '\tlocal function base(')
assert 'state.ownedroots[obj]' in destroy_owned
assert 'obj ~= screen and inside(obj, screen)' in destroy_owned
assert 'pcall(obj.Destroy, obj)' in destroy_owned
assert 'pairs(value)' not in destroy_owned

# Rollback is ownership-led. It must not infer "new" global connections, holder
# children, flags, or config entries from before/after snapshots and mass-delete them.
rollback = scope(ui, '\tfunction state:mark()', '\tapi.backend = ')
for forbidden in (
    'mark.connections',
    'mark.holder',
    'mark.children',
    'mark.flags',
    'mark.config',
    "rawget(lib, 'Connections')",
    'holder:GetChildren()',
    'table.remove(',
):
    assert forbidden not in rollback, forbidden
assert re.search(
    r"function state:mark\(\)\s+return \{\s+created = #self\.created,"
    r"\s+owned = #self\.owneditems\s+\}",
    rollback,
)
assert 'for index = #self.owneditems, (mark.owned or 0) + 1, -1 do' in rollback

# Attach must never purge a tab merely because its display name matches ours, and
# public removal must reject tabs this loader did not create and explicitly own.
assert "tabname == 'fiverosetweaker'" not in attach.lower()
assert "name == 'fiverosetweaker'" not in attach.lower()
assert 'api._owned_tabs = setmetatable({}, {__mode = \'k\'})' in attach
assert 'function api:own_tab(item)' in attach
remove_tab = scope(
    attach,
    '\tfunction api:remove_tab(item, fallback)',
    '\tapi:clean(function()',
)
assert 'if not self._owned_tabs[item] then' in remove_tab
assert 'return false' in remove_tab
assert remove_tab.index('if not self._owned_tabs[item] then') < remove_tab.index('removetab(')

# Hiding a native tab reparents its page. Preserve and restore the exact page,
# button, wrapper visibility, and active-tab state rather than only its button.
hide_tab = scope(vape_api, '\tlocal function hidetab(', '\tlocal function showkept(')
for expected in (
    'state.parent = container.Parent',
    'state.pagevisible = container.Visible',
    'state.buttonvisible = button.Visible',
    "active = rawget(api.lib, 'ActiveTab') == tab",
):
    assert expected in hide_tab
restore_tabs = scope(vape_api, '\tlocal function restoretabs()', '\tbridge = {')
for expected in (
    'container.Parent = data.parent',
    'container.Visible = data.pagevisible == true',
    'button.Visible = data.buttonvisible == true',
    'data.tab.Visible = data.visible',
    'if data.active then',
    "local show = rawget(active, 'Show')",
):
    assert expected in restore_tabs

# Bridge modules may not initialize while Roblox is still replacing PlayerGui.
player_gui_gate = "child(lplr, 'PlayerGui', 30)"
assert player_gui_gate in bridge
assert bridge.index(player_gui_gate) < bridge.index('local baseok, baseerr = run(function()')
child_helper = scope(bridge, '\tlocal function child(', '\tlocal function path(')
assert ':WaitForChild(name, timeout or 30)' in child_helper
assert "error('missing '..parent:GetFullName()..'.'..name, 0)" in child_helper
assert "error('movement slowdown function is unavailable', 0)" in bridge
assert "error('bow targeting function is unavailable', 0)" in bridge


print('UI safety checks passed')
