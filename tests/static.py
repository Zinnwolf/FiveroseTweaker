from pathlib import Path
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
]

for name in required:
    assert (root / name).is_file(), f'missing file: {name}'

assert not (root / '.git').exists(), '.git must not be published'

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
    'redliner.lua': 16,
    'skywars.lua': 16,
}

total = 0
for name, expected in counts.items():
    text = (bundles / name).read_text(encoding='utf-8')
    found = text.count('CreateModule({') + text.count('CreateOverlay({')
    assert found == expected, f'{name}: expected {expected}, got {found}'
    total += found

assert total == 207, total
assert "sessioninfo:AddItem('Kills')" in (bundles / 'skywars_lobby.lua').read_text(encoding='utf-8')

runtime_files = list((root / 'src').rglob('*.lua')) + [root / 'main.lua', root / 'FiveroseTweaker.lua']
runtime = '\n'.join(path.read_text(encoding='utf-8') for path in runtime_files)

assert 'CreateWindow(' not in runtime
assert 'fiverose_gui_bind_multi' not in runtime
assert 'MultiKeybind' not in runtime
assert "Text = 'Use Vape Modules'" in runtime
assert "lib.ToggleKeybind = blocked" in runtime
assert "lib.ToggleKeybind = Enum.KeyCode.Unknown" not in runtime
assert "Blacklisted = {'MB1', 'MB2'}" in runtime
assert 'local function adoptconnections(item, mark)' in runtime
assert 'local function releaseconnections(item)' in runtime
assert "trackmethod(item, obj, 'SetVisible')" in runtime
assert "trackmethod(item, obj, 'Tween')" in runtime
assert 'releaseconnections(self)' in runtime
assert "local inputneeds = {" in runtime
assert "Dropdown = {began = true}" in runtime
assert "Slider = {changed = true, ended = true}" in runtime
assert "KeyPicker = {began = true, ended = true}" in runtime
assert "ColorPicker = {began = true, changed = true, ended = true}" in runtime
assert "state.inputcons[#state.inputcons + 1] = input.InputBegan:Connect" in runtime
assert "state.inputcons[#state.inputcons + 1] = input.InputChanged:Connect" in runtime
assert "state.inputcons[#state.inputcons + 1] = input.InputEnded:Connect" in runtime
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
assert "return blocked(value.Key or value.Value or value[1])" in runtime
assert "or value == Enum.KeyCode.Unknown" in runtime
assert "item.Fallback = tostring(fallback or 'None')" in runtime
assert "function item:Repair()" in runtime
assert "force(item.Fallback)" in runtime
assert "api.ui:wrapkey(native, id, 'E')" in runtime
assert "Enum.KeyCode[value] or Enum.UserInputType[value]" in runtime
assert "pcall(panel.SetMenuVisible, value)" in runtime
assert "local function keychange(value)" in runtime
assert "obj.Callback = function() end" in runtime
assert "flags[flag..'_RAINBOW_FLAG'] = nil" in runtime
assert "rawget(family, 'native') == true" in runtime
assert "for index = #state.created, 1, -1 do" in runtime

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
