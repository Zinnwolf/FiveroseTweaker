local files = {
	['fiverosetweaker/profiles/42/default.json'] = 'profile'
}
local env = {}
local clean = {}
local log = {}

if not table.clear then
	function table.clear(value)
		for key in pairs(value) do
			value[key] = nil
		end
	end
end

function getgenv()
	return env
end

function readfile(path)
	if files[path] == nil then
		error('missing file')
	end

	return files[path]
end

function writefile(path, value)
	files[path] = value
end

function makefolder()
end

task = {
	spawn = function()
		return {}
	end,
	delay = function()
	end,
	cancel = function()
	end,
	wait = function()
	end
}

local http = {}

function http:JSONDecode()
	return {
		options = {speed = 9},
		toggles = {module = true}
	}
end

function http:JSONEncode()
	return '{}'
end

game = {
	GetService = function(_, name)
		assert(name == 'HttpService')
		return http
	end
}

local toggle_old = function()
	log[#log + 1] = 'toggle_callback'
end
local option_old = function()
	log[#log + 1] = 'option_callback'
end
local toggle = {Value = false, Changed = toggle_old}
local option = {Value = 1, Changed = option_old}

function toggle:SetValue(value)
	self.Value = value
	log[#log + 1] = 'toggle_set'
	self.Changed(value)
end

function option:SetValue(value)
	self.Value = value
	log[#log + 1] = 'option_set'
	self.Changed(value)
end

local api = {
	game = {
		id = 42,
		family_id = 'example',
		family = {}
	},
	place = 42,
	gameid = 7,
	owned = {module = true, speed = true},
	toggles = {module = toggle},
	options = {speed = option}
}

function api:clean(fn)
	clean[#clean + 1] = fn
end

local setup = dofile('src/core/profile.lua')
setup(api)
api:restore()

assert(table.concat(log, ',') == 'option_set,option_callback,toggle_set,toggle_callback')
assert(option.Value == 9)
assert(toggle.Value == true)
assert(option.Changed ~= option_old)
assert(toggle.Changed ~= toggle_old)

assert(api:setprofile('practice') == true)
assert(env.fiverosetweaker_profile == 'practice')
assert(files['fiverosetweaker/profiles/42/active.txt'] == 'practice')

for index = #clean, 1, -1 do
	clean[index]()
end

assert(option.Changed == option_old)
assert(toggle.Changed == toggle_old)

print('profile tests passed')
