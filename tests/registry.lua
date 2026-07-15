local registry = dofile('src/games/registry.lua')
local resolve = dofile('src/core/resolve.lua')
local resolver = resolve({}, registry)

local function equal(actual, expected, label)
	if actual ~= expected then
		error((label or 'value')..': expected '..tostring(expected)..', got '..tostring(actual), 2)
	end
end

local expected_places = {
	{77790193039862, 'arena_1_8'},
	{80041634734121, 'arena_1_8', 77790193039862},
	{893973440, 'flee_the_facility'},
	{16483433878, 'blocktales'},
	{106431012459431, 'blocktales', 16483433878},
	{139566161526375, 'bridge_duel'},
	{5938036553, 'frontlines'},
	{123804558118054, 'frontlines', 5938036553},
	{131465939650733, 'frontlines', 5938036553},
	{83413351472244, 'frontlines', 5938036553},
	{606849621, 'jailbreak'},
	{155615604, 'prison_life'},
	{135564683255158, 'prison_life', 155615604},
	{115875349872417, 'redliner'},
	{126691165749976, 'redliner', 115875349872417},
	{94987506187454, 'redliner', 115875349872417},
	{8768229691, 'skywars_voxel'},
	{8542259458, 'skywars_lobby'},
	{8542275097, 'skywars_voxel', 8768229691},
	{8592115909, 'skywars_voxel', 8768229691},
	{8951451142, 'skywars_voxel', 8768229691},
	{13246639586, 'skywars_voxel', 8768229691},
	{15133985014, 'freestyle_football'},
	{18124732355, 'freestyle_football'},
	{18935841239, 'freestyle_football'},
	{18972674759, 'freestyle_football'},
	{78336452877060, 'freestyle_football'}
}

local expected_games = {
	{9984669476, 'arena_1_8'},
	{372226183, 'flee_the_facility'},
	{5678284602, 'blocktales'},
	{8907796617, 'blocktales'},
	{9137416017, 'bridge_duel'},
	{2132866904, 'frontlines'},
	{7521877734, 'frontlines'},
	{245662005, 'jailbreak'},
	{73885730, 'prison_life'},
	{7265339759, 'redliner'},
	{3258873704, 'skywars_voxel'},
	{5215846239, 'freestyle_football'}
}

equal(#registry.places, #expected_places, 'place count')
equal(#registry.games, #expected_games, 'game count')

for index, expected in ipairs(expected_places) do
	local route = registry.places[index]
	local entry = resolver:resolve(expected[1])

	equal(route.id, expected[1], 'place id')
	equal(route.family, expected[2], 'place family')
	equal(route.alias, expected[3], 'place alias')
	equal(entry.match, 'place', 'place match')
	equal(entry.family_id, expected[2], 'resolved family')
end

for index, expected in ipairs(expected_games) do
	local route = registry.games[index]
	local entry = resolver:resolve(nil, expected[1])

	equal(route.id, expected[1], 'game id')
	equal(route.family, expected[2], 'game family')
	equal(entry.match, 'game', 'game match')
	equal(entry.family_id, expected[2], 'resolved game family')
end

local override = resolver:resolve(606849621, 5215846239)
equal(override.match, 'place', 'place override')
equal(override.family_id, 'jailbreak', 'place override family')

local fallback = resolver:resolve(1, 5215846239)
equal(fallback.match, 'game', 'game fallback')
equal(fallback.family_id, 'freestyle_football', 'fallback family')

equal(resolver:resolve(6872274481, 2619619496), nil, 'BedWars exclusion')
local universal = resolver:resolve(1, 2)
equal(universal.match, 'universal', 'universal fallback')
equal(universal.family_id, 'universal', 'universal family')

equal(registry.shared[1], 'src/modules/shared/keybinds.lua', 'keybind order')
equal(registry.shared[2], 'src/modules/shared/gui_bind.lua', 'gui order')
equal(registry.shared[3], 'src/modules/shared/vape_mode.lua', 'mode order')
equal(#registry.shared, 3, 'shared module count')
equal(registry.families.freestyle_football.modules[1], 'src/modules/freestyle_football/stamina.lua', 'stamina order')
equal(registry.families.freestyle_football.modules[2], 'src/modules/freestyle_football/ball.lua', 'ball order')
equal(registry.families.freestyle_football.profile, 15133985014, 'profile scope')

print('registry tests passed: '..#registry.places..' places, '..#registry.games..' games')
