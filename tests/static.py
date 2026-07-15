from pathlib import Path
import hashlib
import re

root = Path(__file__).resolve().parents[1]
registry = (root / 'src/games/registry.lua').read_text(encoding='utf-8')

required = [
    'main.lua',
    'FiveroseTweaker.lua',
    'LICENSE',
    'README.md',
    'src/loader.lua',
    'src/core/attach.lua',
    'src/core/clean.lua',
    'src/core/profile.lua',
    'src/core/resolve.lua',
    'src/core/ui_universal.lua',
    'src/games/registry.lua',
    'src/modules/shared/keybinds.lua',
    'src/modules/shared/gui_bind.lua',
    'src/modules/shared/vape_mode.lua',
    'src/vape/api.lua',
    'src/vape/games/universal.lua',
    'tests/stamina.lua',
    'tests/prediction.lua',
    'tests/ui_safety.py',
]

for name in required:
    assert (root / name).is_file(), f'missing file: {name}'

assert not (root / '.git').exists(), '.git must not be published'
assert hashlib.sha256((root / 'README.md').read_bytes()).hexdigest() == (
    'fe2dfa993009953cc0372c1ac1b0ac6bd4cae0c9f011f65e1e66159a0b4eef55'
), 'README.md changed'

places = [int(value) for value in re.findall(r'^place\((\d+),', registry, re.M)]
games = [int(value) for value in re.findall(r'^universe\((\d+),', registry, re.M)]

assert len(places) == 27, len(places)
assert len(places) == len(set(places)), 'duplicate PlaceId'
assert len(games) == 12, len(games)
assert len(games) == len(set(games)), 'duplicate GameId'

expected_places = {
    77790193039862, 80041634734121, 893973440, 16483433878,
    106431012459431, 139566161526375, 5938036553,
    123804558118054, 131465939650733, 83413351472244,
    606849621, 155615604, 135564683255158, 115875349872417,
    126691165749976, 94987506187454, 8768229691, 8542259458,
    8542275097, 8592115909, 8951451142, 13246639586,
    15133985014, 18124732355, 18935841239, 18972674759,
    78336452877060,
}
expected_games = {
    9984669476, 372226183, 5678284602, 8907796617, 9137416017,
    2132866904, 7521877734, 245662005, 73885730, 7265339759,
    3258873704, 5215846239,
}

assert set(places) == expected_places, set(places) ^ expected_places
assert set(games) == expected_games, set(games) ^ expected_games

for value in (6872265039, 6872274481, 8444591321, 8560631822):
    assert f'[{value}] = true' in registry, f'BedWars place not blocked: {value}'
    assert value not in places, f'BedWars place routed: {value}'

assert '[2619619496] = true' in registry, 'BedWars universe not blocked'
assert 2619619496 not in games, 'BedWars universe routed'
assert "fallback = 'universal'" in registry

paths = set(re.findall(r"'(src/[^']+\.lua)'", registry))
for name in paths:
    assert (root / name).is_file(), f'missing registry path: {name}'
    assert '..' not in name and '\\' not in name and not name.startswith('/'), name

bundles = root / 'src/vape/games'
counts = {
    'universal.lua': 67,
    'arena.lua': 15,
    'flee.lua': 7,
    'blocktales.lua': 14,
    'bridge.lua': 13,
    'frontlines.lua': 15,
    'jailbreak.lua': 10,
    'prison.lua': 34,
    'redliner.lua': 12,
    'skywars.lua': 16,
}

total = 0
for name, expected in counts.items():
    text = (bundles / name).read_text(encoding='utf-8')
    found = text.count('CreateModule({') + text.count('CreateOverlay({')
    assert found == expected, f'{name}: expected {expected}, got {found}'
    total += found

assert total == 203, total
assert "sessioninfo:AddItem('Kills')" in (bundles / 'skywars_lobby.lua').read_text(encoding='utf-8')

scope_bundles = ('universal.lua', 'arena.lua', 'blocktales.lua')
for name in scope_bundles:
    text = (bundles / name).read_text(encoding='utf-8')
    assert len(re.findall(r'^\tlocal Fly = \{Enabled = false\}$', text, re.M)) == 1, name
    assert len(re.findall(r'^\tlocal LongJump = \{Enabled = false\}$', text, re.M)) == 1, name
    assert not re.search(r'^\t\t+local Fly\b', text, re.M), name
    assert not re.search(r'^\t\t+local LongJump\b', text, re.M), name
    assert re.search(r'^\t\t+Fly = .*:CreateModule\(\{$', text, re.M), name
    assert re.search(r'^\t\tLongJump = .*:CreateModule\(\{$', text, re.M), name
    assert 'not Fly.Enabled and not LongJump.Enabled' in text, name
    assert 'for _, module in pairs(api.vape and api.vape.Modules or {}) do' in text, name
    assert 'pcall(module.Destroy, module)' in text, name

universal_scope = (bundles / 'universal.lua').read_text(encoding='utf-8')
speed_marker = '\t-- source: src/games/universal - base/Blatant/Speed.lua'
spider_marker = '\t-- source: src/games/universal - base/Blatant/Spider.lua'
speed_scope = universal_scope[
    universal_scope.index(speed_marker):universal_scope.index(spider_marker)
]
assert '\n\t\tlocal CustomProperties\n' in speed_scope
assert 'frictionTable.Speed = callback and CustomProperties.Enabled or nil' in speed_scope
assert '\n\t\tCustomProperties = Speed:CreateToggle({' in speed_scope
assert 'oldroot = nil' not in universal_scope
assert len(re.findall(r'^\tlocal mouseClicked = false$', universal_scope, re.M)) == 1
assert not re.search(r'^\t\t+local mouseClicked\b', universal_scope, re.M)

bootstrap_counts = {
    'universal.lua': 2,
    'arena.lua': 2,
    'blocktales.lua': 1,
    'flee.lua': 2,
    'frontlines.lua': 2,
    'jailbreak.lua': 2,
    'prison.lua': 4,
    'skywars.lua': 2,
    'skywars_lobby.lua': 1,
}
for name, expected in bootstrap_counts.items():
    text = (bundles / name).read_text(encoding='utf-8')
    marker = text.find('\t-- source:')
    prefix = text if marker < 0 else text[:marker]
    assert prefix.count('\trequired(function()') == expected, name
    assert '\trun(function()' not in prefix, name
    assert "error('required bundle initialization failed: '" in text, name
    assert 'pcall(module.Destroy, module)' in text, name

bridge_scope = (bundles / 'bridge.lua').read_text(encoding='utf-8')
assert 'local baseok, baseerr = run(function()' in bridge_scope
assert "error('Bridge Duel bootstrap failed: '" in bridge_scope
assert "error('Bridge Duel bootstrap missing '" in bridge_scope
assert "error('getconnections is unavailable', 0)" in bridge_scope
assert "error('knockback connection is unavailable', 0)" in bridge_scope
assert 'local nextItem, nextTier' in bridge_scope
assert '\n\t\tlocal Pickaxe\n' in bridge_scope
assert 'Functions[3] = callback and function(currencytable, shop)' in bridge_scope
assert '\n\t\tlocal Range\n' in bridge_scope
assert 'local blockpos = checkAdjacent(currentpos)' in bridge_scope
assert 'those = nil' not in bridge_scope

redliner_scope = (bundles / 'redliner.lua').read_text(encoding='utf-8')
redliner_modules = {
    'AntiParry', 'AutoParry', 'Fly', 'HighJump', 'InfiniteDash', 'Killaura',
    'Reach', 'SilentAim', 'HitSound', 'KillSound', 'AutoQueue', 'AutoToxic',
}
for name in redliner_modules:
    assert f"Name = '{name}'" in redliner_scope, name
for name in {'ClashSpoofer', 'LongJump', 'Speed', 'TargetStrafe', 'AutoLeave', 'Gravity'}:
    assert f'/{name}.lua' not in redliner_scope, name
assert 'Start.Client.ClientRoot is not visible from the caller VM' in redliner_scope
assert "error('Redliner entity bootstrap failed: '" in redliner_scope
assert "error('Redliner client bootstrap failed: '" in redliner_scope
assert "error('Redliner client bootstrap missing '" in redliner_scope

flee_scope = (bundles / 'flee.lua').read_text(encoding='utf-8')
assert 'mapboj' not in flee_scope
assert 'local function getEnv(mod)' in flee_scope
assert 'local env = getEnv(mod)' in flee_scope

jailbreak_scope = (bundles / 'jailbreak.lua').read_text(encoding='utf-8')
assert '\n\tlocal remotes = {}\n' in jailbreak_scope
assert 'Wallcheck = Target.Walls.Enabled or nil' in jailbreak_scope
assert 'fireserver and hook' in jailbreak_scope
assert 'cashfunc and cashhook' in jailbreak_scope
assert "type(restorefunction) == 'function'" in jailbreak_scope

frontlines_scope = (bundles / 'frontlines.lua').read_text(encoding='utf-8')
assert '\n\t\tlocal GunModifications\n' in frontlines_scope
assert 'if old then\n\t\t\t\t\t\thookfunction(frontlines.SpawnThrowable, old)' in frontlines_scope

skywars_scope = (bundles / 'skywars.lua').read_text(encoding='utf-8')
assert 'table.clear(RemoteTable)' not in skywars_scope
assert 'table.clear(remotes)' in skywars_scope
assert 'local blockpos = checkAdjacent(currentpos)' in skywars_scope
assert 'if oldMobile then' in skywars_scope

prison_scope = (bundles / 'prison.lua').read_text(encoding='utf-8')
assert 'local oldshoot, oldequip, vtool' in prison_scope
assert 'local getcustomasset = vape.Libraries.getcustomasset' in prison_scope
assert '\n\t\tlocal vtool\n' not in prison_scope

arena_scope = (bundles / 'arena.lua').read_text(encoding='utf-8')
assert '\n\t\tlocal SpiderShift = false\n' in arena_scope
assert 'Arena character controller did not become ready within 30 seconds' in arena_scope
assert "error('Arena bootstrap missing '..name, 0)" in arena_scope

blocktales_scope = (bundles / 'blocktales.lua').read_text(encoding='utf-8')
assert "error('Block Tales bootstrap missing '..name, 0)" in blocktales_scope

assert 'Flee player stats did not become ready within 30 seconds' in flee_scope
assert 'Jailbreak vehicle controller did not become ready within 30 seconds' in jailbreak_scope
assert "error('Prison Life bootstrap missing '..name, 0)" in prison_scope
assert 'SkyWars Flamework did not ignite within 30 seconds' in skywars_scope
assert "error('SkyWars bootstrap missing '..name, 0)" in skywars_scope
assert "error('SkyWars remote discovery missing '..name, 0)" in skywars_scope

runtime_files = list((root / 'src').rglob('*.lua')) + [root / 'main.lua', root / 'FiveroseTweaker.lua']
runtime = '\n'.join(path.read_text(encoding='utf-8') for path in runtime_files)
ui_universal = (root / 'src/core/ui_universal.lua').read_text(encoding='utf-8')
attach_scope = (root / 'src/core/attach.lua').read_text(encoding='utf-8')
profile_scope = (root / 'src/core/profile.lua').read_text(encoding='utf-8')
clean_scope = (root / 'src/core/clean.lua').read_text(encoding='utf-8')
api_scope = (root / 'src/vape/api.lua').read_text(encoding='utf-8')
entity_scope = (root / 'src/vape/libraries/entity.lua').read_text(encoding='utf-8')
prediction_scope = (root / 'src/vape/libraries/prediction.lua').read_text(encoding='utf-8')
stamina_scope = (root / 'src/modules/freestyle_football/stamina.lua').read_text(encoding='utf-8')

assert 'CreateWindow(' not in runtime
assert 'fiverose_gui_bind_multi' not in runtime
assert 'MultiKeybind' not in runtime
assert "Text = 'Use Vape Modules'" in runtime
assert "lib.ToggleKeybind = picker" in runtime
assert "lib.ToggleKeybind = blocked" not in runtime
assert "lib.ToggleKeybind = Enum.KeyCode.Unknown" not in runtime
assert "Blacklisted = {'MB1', 'MB2'}" in runtime
assert "local bind = {" in runtime
assert "function bind:begin(picker)" in runtime
assert "function bind:cancel(picker)" in runtime
assert "function bind:commit(key, value)" in runtime
assert "function bind:pick(key)" in runtime
assert "key == 'Backspace' or key == 'Delete' or key == old" in runtime
assert "if key == 'Escape' then" in runtime
assert "if self.skip[key] then" in runtime
assert "if self.down[key] then" in runtime
assert 'local wanted = mouseitem()' in runtime
assert 'if item == wanted then' in runtime
assert "input:GetFocusedTextBox() ~= nil" in runtime
assert "function item:CancelCapture(oldvalue)" in runtime
assert 'local function adoptconnections(item, mark)' in runtime
assert "result[fn] = (result[fn] or 0) + 1" in runtime
assert "current[fn] > (before[fn] or 0)" in runtime
assert "result[con] = true" not in runtime
assert "item._input[name] = list" in runtime
assert 'local function releaseconnections(item)' in runtime
assert "trackmethod(item, obj, 'SetVisible')" in runtime
assert "trackmethod(item, obj, 'Tween')" in runtime
assert "connectionmark(item.Type)" in runtime
assert 'releaseconnections(self)' in runtime
assert "local inputneeds = {" in runtime
assert "Dropdown = {began = true}" in runtime
assert "Slider = {changed = true, ended = true}" in runtime
assert "KeyPicker = {began = true, ended = true}" in runtime
assert "ColorPicker = {began = true, changed = true, ended = true}" in runtime
assert runtime.count("state.inputcons[#state.inputcons + 1] = input.InputBegan:Connect") == 1
assert runtime.count("state.inputcons[#state.inputcons + 1] = input.InputChanged:Connect") == 1
assert runtime.count("state.inputcons[#state.inputcons + 1] = input.InputEnded:Connect") == 1
assert "con = input.InputBegan:Connect" not in runtime
assert "connectionmark('Dropdown')" in runtime
assert "connectionmark('Slider')" in runtime
assert "connectionmark('KeyPicker')" in runtime
assert "connectionmark('ColorPicker')" in runtime
assert 'local current = make(api, entry)' in runtime
assert "Place = tonumber(entry and entry.alias)" in runtime
assert "warn('[fiverosetweaker] unsupported game" in runtime
assert "api.backend = 'universal'" in runtime
assert "panel:Tab({" in runtime
assert "self.Native:Toggle({" in runtime
assert "self.Native:Keybind({" in runtime
assert "Universal Fiverose Menu Bind" in runtime
assert "MouseButton1" in runtime and "MouseButton2" in runtime
assert "MB3 = 'MouseButton3'" in runtime
assert "return value == Enum.KeyCode.Unknown or keyname(value) == 'None'" in runtime
assert "item.Fallback = tostring(fallback or 'None')" in runtime
assert "function item:Repair()" in runtime
assert "force(self.Fallback)" in runtime
assert "api.ui:wrapkey(native, id, 'E')" in runtime
assert "Enum.KeyCode[value] or Enum.UserInputType[value]" in runtime
assert "pcall(panel.SetMenuVisible, value)" in runtime
assert "local function keychange(value)" in runtime
assert "and (bind.active == item or rawget(obj, 'Open') == true) then" in runtime
assert "bind:pick(keyname(key))" in runtime
assert "obj.Callback = function() end" in runtime
assert "obj.Modifiers = modifiers" in runtime
assert "Modifiers = table.clone(self.Modifiers)" in runtime
assert "flags[flag..'_RAINBOW_FLAG'] = nil" in runtime
assert "rawget(family, 'native') == true" in runtime
assert "for index = #state.owneditems, 1, -1 do" in runtime
assert "not safe(name, settings.Function, value) and value" in runtime
assert "return value.Name" not in ui_universal

assert 'local ok, result = pcall(getgc, true)' in ui_universal
assert 'candidate.linked = true' in ui_universal
assert 'local ok, connections = pcall(getconnections, signal)' in ui_universal
assert "warn('[fiverosetweaker/ui] '..key..': '..tostring(err))" in ui_universal
assert 'function api:remove_tab(item)' in ui_universal
assert 'self.toggles[id] = nil' in ui_universal
assert 'self.options[id] = nil' in ui_universal

assert 'local function purgetab(lib, tab)' in attach_scope
assert 'api._owned_prior = {}' in attach_scope
assert 'self.toggles[id] = prior.toggle' in attach_scope
assert 'self.options[id] = prior.option' in attach_scope
assert 'function api:remove_tab(item, fallback)' in attach_scope

assert 'profile.restore_errors = errors' in profile_scope
assert 'api.profile_restore_errors = errors' in profile_scope
assert "warn('[fiverosetweaker/profile] '..message..': '..first.error)" in profile_scope
assert 'self.save_error = tostring(err)' in clean_scope
assert "' cleanup action(s) failed; first: '" in clean_scope

assert 'local priorvape = shared.vape' in api_scope
assert 'pcall(api.remove_tab, api, tab)' in api_scope
assert 'pcall(libs.entity.kill)' in api_scope
assert 'shared.vape = priorvape' in api_scope
assert "Profile = api.profile and api.profile.name or 'default'" in api_scope
assert 'function vape:Load(_, profile)' in api_scope
assert 'local ok, result = pcall(api.setprofile, api, profile)' in api_scope
assert 'bridge.libs = api.vapelibs' in api_scope
assert 'api.vapelibs = {}' in api_scope
assert "api.vapelibs.entity = fresh('src/vape/libraries/entity.lua')" in api_scope
assert api_scope.index('bridge.libs = api.vapelibs') < api_scope.index("api.vapelibs.entity = fresh(")
font_scope = api_scope[api_scope.index("\t\tif method == 'Font' then"):api_scope.index("\t\tif method == 'Targets' then")]
assert '\n\t\t\tlocal obj\n' in font_scope
assert 'obj.Value = face' in font_scope

assert 'if char and entitylib.EntityThreads[char] then' in entity_scope
assert 'local killed = false' in entity_scope
assert 'if killed then' in entity_scope
assert 'entitylib.IgnoreObject:Destroy()' not in entity_scope
assert entity_scope.count('entitylib.start()') == 1

assert 'local function solveLinearIntercept' in prediction_scope
assert 'if math.abs(gravity) <= eps then' in prediction_scope
assert 'if isFinite(v) and v > eps then' in prediction_scope
assert 'table.sort(posRoots)' in prediction_scope

assert 'local function installed()' in stamina_scope
assert 'local function watch(generation)' in stamina_scope
assert 'while state.enabled and state.generation == generation do' in stamina_scope
assert 'task.spawn(watch, state.generation)' in stamina_scope
assert "task.delay(1, function()" not in stamina_scope

assert 'src/modules/shared/animations.lua' not in registry
assert not (root / 'src/modules/shared/animations.lua').exists()
assert 'BlurEffect' not in runtime
assert 'UIScale' not in runtime

for path in runtime_files:
    text = path.read_text(encoding='utf-8')
    assert '\r' not in text, path
    assert not re.search(r'AddTab\s*\(\s*\{(?:(?!\}\s*\)).)*\bDescription\s*=', text, re.S), path

private_patterns = {
    'email': re.compile(r'(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'),
    'windows user path': re.compile(r'(?i)[A-Z]:\\Users\\[^\\\s\'\"]+'),
    'webhook': re.compile(r'(?i)discord(?:app)?\.com/api/webhooks/'),
    'github token': re.compile(r'(?i)(?:ghp_|github_pat_)[A-Za-z0-9_]{20,}'),
    'private key': re.compile(r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----'),
}

for path in root.rglob('*'):
    if not path.is_file() or '.git' in path.parts:
        continue

    text = path.read_text(encoding='utf-8', errors='ignore')
    for label, pattern in private_patterns.items():
        assert not pattern.search(text), f'{label}: {path.relative_to(root)}'


def strip_source(src):
    out = []
    index = 0

    while index < len(src):
        if src.startswith('--[=[', index):
            end = src.find(']=]', index + 5)
            index = len(src) if end < 0 else end + 3
            out.append(' ')
        elif src.startswith('--[[', index):
            end = src.find(']]', index + 4)
            index = len(src) if end < 0 else end + 2
            out.append(' ')
        elif src.startswith('--', index):
            end = src.find('\n', index + 2)
            index = len(src) if end < 0 else end
            out.append('\n')
        elif src[index] in "'\"":
            quote = src[index]
            index += 1
            while index < len(src):
                if src[index] == '\\':
                    index += 2
                elif src[index] == quote:
                    index += 1
                    break
                else:
                    index += 1
            out.append(' ')
        elif src.startswith('[=[', index):
            end = src.find(']=]', index + 3)
            index = len(src) if end < 0 else end + 3
            out.append(' ')
        elif src.startswith('[[', index):
            end = src.find(']]', index + 2)
            index = len(src) if end < 0 else end + 2
            out.append(' ')
        else:
            out.append(src[index])
            index += 1

    return ''.join(out)

pairs = {')': '(', ']': '[', '}': '{'}
for path in root.rglob('*.lua'):
    stack = []
    for char in strip_source(path.read_text(encoding='utf-8')):
        if char in '([{':
            stack.append(char)
        elif char in pairs:
            assert stack and stack[-1] == pairs[char], f'unbalanced delimiter: {path}'
            stack.pop()
    assert not stack, f'unbalanced delimiter: {path}'


assert "local overlayscreen = Instance.new('ScreenGui')" in runtime
assert "overlayscreen.Enabled = true" in runtime
assert "overlay.Parent = overlayscreen" in runtime
assert "pcall(overlayscreen.Destroy, overlayscreen)" in runtime
assert "overlay.Parent = api.gui" not in runtime


assert 'local function guarddropdown(obj)' in runtime
assert "local olddropdown = rawget(lib, 'Dropdown')" in runtime
assert 'if dropdead(obj) then' in runtime
assert 'obj.SetVisible = safevisible' in runtime
assert 'obj.Tween = safetween' in runtime
assert "lib.Dropdown = safedropdown" in runtime
assert not any(line.startswith(r'\t') for line in runtime.splitlines())

print(f'static checks passed: {len(runtime_files)} runtime files, {total} Vape modules')
