local files = {
	['fiverosetweaker/profiles/42/default.json'] = 'profile'
}
local env = {}
local clean = {}
local log = {}
local encoded
local decoded = {
	options = {
		speed = 9,
		bind = {
			kind = 'keybind',
			value = 'None',
			mode = 'Toggle',
			modifiers = {}
		}
	},
	toggles = {module = true}
}

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
	return decoded
end


function http:JSONEncode(value)
	encoded = value
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
local bind_old = function()
	log[#log + 1] = 'bind_callback'
end
local toggle = {Value = false, Changed = toggle_old}
local option = {Value = 1, Changed = option_old}
local bind = {
	Type = 'KeyPicker',
	Value = 'V',
	Mode = 'Toggle',
	Modifiers = {},
	Changed = bind_old
}

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

function bind:SetValue(value)
	self.Value = type(value) == 'table' and value[1] or value
	self.Mode = type(value) == 'table' and value[2] or self.Mode
	self.Modifiers = type(value) == 'table' and value[3] or self.Modifiers
	log[#log + 1] = 'bind_set'
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
	owned = {module = true, speed = true, bind = true},
	toggles = {module = toggle},
	options = {speed = option, bind = bind}
}

function api:clean(fn)
	clean[#clean + 1] = fn
end

local setup = dofile('src/core/profile.lua')
setup(api)
api:restore()

assert(option.Value == 9)
assert(toggle.Value == true)
assert(bind.Value == 'None')
assert(option.Changed ~= option_old)
assert(toggle.Changed ~= toggle_old)
assert(bind.Changed ~= bind_old)

api:save()
assert(encoded.options.bind.value == 'None')
assert(encoded.options.bind.mode == 'Toggle')

bind.Value = 'V'
decoded = encoded
api:restore()
assert(bind.Value == 'None')

bind.Value = 'MB3'
api:save()
assert(encoded.options.bind.value == 'MouseButton3')

decoded = {
	options = {
		bind = {
			kind = 'keybind',
			value = 'NONE',
			mode = 'Toggle',
			modifiers = {}
		}
	},
	toggles = {}
}
bind.Value = 'V'
api:restore()
assert(bind.Value == 'None')

local broken_old = function() end
local after_old = function() end
local broken = {Value = 0, Changed = broken_old}
local after = {Value = 0, Changed = after_old}

function broken:SetValue()
	error('intentional restore failure')
end

function after:SetValue(value)
	self.Value = value
end

api.owned.broken = true
api.owned.after = true
api.options.broken = broken
api.options.after = after
decoded = {
	options = {broken = 5, after = 7},
	toggles = {}
}
api:restore()
assert(after.Value == 7)
assert(type(api.profile_restore_errors) == 'table')
assert(#api.profile_restore_errors == 1)
assert(api.profile_restore_errors[1].id == 'broken')

assert(api:setprofile('practice') == true)
assert(env.fiverosetweaker_profile == 'practice')
assert(files['fiverosetweaker/profiles/42/active.txt'] == 'practice')

for index = #clean, 1, -1 do
	clean[index]()
end

assert(option.Changed == option_old)
assert(toggle.Changed == toggle_old)
assert(bind.Changed == bind_old)
assert(broken.Changed == broken_old)
assert(after.Changed == after_old)

print('profile tests passed')
