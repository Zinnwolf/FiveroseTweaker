if not table.find then
	function table.find(list, wanted)
		for index, value in ipairs(list) do
			if value == wanted then
				return index
			end
		end
	end
end

if not table.clear then
	function table.clear(value)
		for key in pairs(value) do
			value[key] = nil
		end
	end
end

local deferred = {}
local input = {focused = false}

function input:GetFocusedTextBox()
	return self.focused and {} or nil
end

task = {
	defer = function(fn)
		deferred[#deferred + 1] = fn
	end
}

game = {
	GetService = function(_, name)
		assert(name == 'UserInputService')
		return input
	end
}

local function flush()
	local list = deferred
	deferred = {}

	for _, fn in ipairs(list) do
		fn()
	end
end

local options = {}
local order = {}
local owned = {}
local cleanup
local saves = 0
local clicks = 0
local methods = {}

local function setvalue(self, value)
	if type(value) == 'table' then
		self.Value = value[1] or value.Key or value.Value
		self.Mode = value[2] or value.Mode or self.Mode
		self.Modifiers = value[3] or value.Modifiers or self.Modifiers
	else
		self.Value = value
	end

	return self
end

function methods:AddKeyPicker(id, info)
	local picker = {
		Type = 'KeyPicker',
		Value = info.Default,
		Mode = info.Mode,
		Modifiers = {},
		Blacklisted = info.Blacklisted,
		SetValue = setvalue,
		Callback = function()
			clicks = clicks + 1
		end,
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
local nativepicker = {
	Type = 'KeyPicker',
	Value = 'MB3',
	Mode = 'Toggle',
	Modifiers = {},
	Blacklisted = {},
	SetValue = setvalue
}
native.Addons[1] = nativepicker
options.native_picker = nativepicker

local lib = {IsPicking = false}
local api = {
	backend = 'obsidian',
	input = input,
	lib = lib,
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

function api:queue_save()
	saves = saves + 1
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
assert(#nativepicker.Blacklisted == 0)
assert(options.fiverose_tweaker_auto_native == nil)
assert(owned.fiverose_tweaker_auto_alpha)
assert(options.fiverose_tweaker_auto_alpha.Blacklisted[1] == 'MB1')
assert(options.fiverose_tweaker_auto_alpha.Blacklisted[2] == 'MB2')

local alpha = options.fiverose_tweaker_auto_alpha
local zeta = options.fiverose_tweaker_auto_zeta
local bind = api.binds
local function key(name)
	return {UserInputType = 'Keyboard', KeyCode = name}
end

assert(bind:begin(alpha))
assert(bind:began(key('V'), false, false))
assert(alpha.Value == 'V')
assert(bind.skip.V == true)
alpha.Callback()
assert(clicks == 0)
assert(bind:ended(key('V')) == true)
alpha.Callback()
assert(clicks == 1)

alpha:SetValue({'G', 'Toggle'})
bind:begin(alpha)
assert(bind:pick('G'))
assert(alpha.Value == 'None')
assert(bind:began(key('G'), false, false) == true)
assert(bind:ended(key('G')) == true)

assert(bind:began(key('V'), false, false) == false)
assert(bind:began(key('V'), false, false) == true)
assert(bind:ended(key('V')) == false)

alpha:SetValue({'V', 'Toggle'})
bind:begin(alpha)
bind:began(key('V'), false, false)
assert(alpha.Value == 'None')
bind:ended(key('V'))

alpha:SetValue({'B', 'Toggle'})
bind:begin(alpha)
bind:began(key('Backspace'), false, false)
assert(alpha.Value == 'None')
bind:ended(key('Backspace'))

alpha:SetValue({'D', 'Toggle'})
bind:begin(alpha)
bind:began(key('Delete'), false, false)
assert(alpha.Value == 'None')
bind:ended(key('Delete'))

alpha:SetValue({'E', 'Toggle'})
bind:begin(alpha)
bind:began(key('Escape'), false, false)
assert(alpha.Value == 'E')
bind:ended(key('Escape'))

alpha.Open = true
zeta.Open = true
bind:begin(alpha)
bind:begin(zeta)
assert(bind.active == zeta)
assert(alpha.Open == false)

bind:cancel(zeta)
input.focused = true
assert(bind:began(key('F'), false, true) == true)
alpha.Callback()
assert(clicks == 1)
bind:ended(key('F'))
input.focused = false

alpha:SetValue({'MouseButton3', 'Toggle'})
assert(alpha.Value == 'MB3')

alpha:SetValue({'MouseButton2', 'Toggle'})
bind:begin(alpha)
bind:pick('MouseButton2')
assert(alpha.Value == 'None')
bind:ended({UserInputType = 'MouseButton2'})

alpha:SetValue({'Q', 'Toggle'})
lib.IsPicking = true
alpha:SetValue({'Q', 'Toggle'})
assert(alpha.Value == 'None')
assert(saves > 0)
alpha.Callback()
assert(clicks == 1)
flush()
alpha.Callback()
assert(clicks == 1)
bind:ended(key('Q'))
alpha.Callback()
assert(clicks == 2)

alpha:SetValue({'R', 'Toggle'})
lib.IsPicking = true
alpha:SetValue({'Escape', 'Toggle'})
assert(alpha.Value == 'R')
flush()

local orphan = {Open = true}
lib.IsPicking = true
lib.OpenElement = orphan
cleanup()

assert(api.binds == nil)
assert(lib.IsPicking == false)
assert(lib.OpenElement == nil)
assert(orphan.Open == false)
assert(#nativepicker.Blacklisted == 0)
assert(options.fiverose_tweaker_auto_alpha == nil)
assert(options.fiverose_tweaker_auto_zeta == nil)
assert(options.fiverose_tweaker_extra_key == nil)
assert(explicit.Destroyed == true)

print('keybind tests passed')
