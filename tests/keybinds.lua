if not table.find then
	function table.find(list, wanted)
		for index, value in ipairs(list) do
			if value == wanted then
				return index
			end
		end
	end
end

local options = {}
local order = {}
local owned = {}
local cleanup
local methods = {}

function methods:AddKeyPicker(id, info)
	local picker = {
		Type = 'KeyPicker',
		Value = info.Default,
		Blacklisted = info.Blacklisted,
		Destroy = function(self)
			self.Destroyed = true
		end
	}

	self.Addons[#self.Addons + 1] = picker
	options[id] = picker
	order[#order + 1] = id
	return self
end

local function toggle(text)
	return setmetatable({Text = text, Addons = {}}, {__index = methods})
end

local native = toggle('native')
local picker = {Type = 'KeyPicker', Blacklisted = {}}
native.Addons[1] = picker
options.native_picker = picker

local api = {
	toggles = {
		zeta = toggle('zeta'),
		alpha = toggle('alpha'),
		native = native
	},
	options = options,
	owned = owned
}

function api:own(id)
	owned[id] = true
end

function api:clean(fn)
	cleanup = fn
end

local setup = dofile('src/modules/shared/keybinds.lua')
local created = setup(api)

assert(#created == 0)

local extra = toggle('extra')
local explicit = api:addkey(extra, 'fiverose_tweaker_extra_key', 'extra', 'None')
assert(explicit == options.fiverose_tweaker_extra_key)
api:finish_keybinds()

assert(#created == 3)
assert(order[1] == 'fiverose_tweaker_extra_key')
assert(order[2] == 'fiverose_tweaker_auto_alpha')
assert(order[3] == 'fiverose_tweaker_auto_zeta')
assert(table.find(picker.Blacklisted, 'MB1'))
assert(options.fiverose_tweaker_auto_native == nil)
assert(owned.fiverose_tweaker_auto_alpha)
assert(options.fiverose_tweaker_auto_alpha.Blacklisted[1] == 'MB1')

cleanup()

assert(table.find(picker.Blacklisted, 'MB1') == nil)
assert(options.fiverose_tweaker_auto_alpha == nil)
assert(options.fiverose_tweaker_auto_zeta == nil)
assert(options.fiverose_tweaker_extra_key == nil)
assert(explicit.Destroyed == true)

print('keybind tests passed')
