loadstring = loadstring or load

local module = dofile('src/core/import.lua')
local invalid = {
	'',
	'   ',
	'../main.lua',
	'src/../main.lua',
	'./main.lua',
	'/main.lua',
	'C:/main.lua',
	'C:\\main.lua',
	'https://example.com/main.lua',
	'src//main.lua',
	'src/',
	'src/evil\nmain.lua',
	'src/main.lua:stream'
}

for _, path in ipairs(invalid) do
	assert(module.valid(path) == false, path)
end

assert(module.valid('src/core/clean.lua') == true)

local reads = 0
local api = {}

function api:source(path)
	reads = reads + 1
	assert(path == 'src/test.lua')
	return 'return {value = 7}'
end

module.setup(api)

local first = api:import('src/test.lua')
local second = api:import('src/test.lua')
assert(first == second)
assert(first.value == 7)
assert(reads == 1)

local ok, err = pcall(api.import, api, '../bad.lua')
assert(ok == false)
assert(tostring(err):find('invalid import path', 1, true))

print('import tests passed')
