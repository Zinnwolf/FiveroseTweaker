local made = 0
local universal = 0
local gamebundle = 0
local destroyed = 0
local cleanup
local toggles = {}
local box = {}

function box:AddToggle(id, info)
	local toggle = {
		Value = info.Default == true,
		Text = info.Text
	}

	function toggle:OnChanged(fn)
		self.Changed = fn
	end

	function toggle:SetValue(value)
		self.Value = value == true

		if self.Changed then
			self.Changed(self.Value)
		end
	end

	toggles[id] = toggle
	return toggle
end

function box:Destroy()
	self.Destroyed = true
end

local settings = {}
function settings:AddRightGroupbox(name)
	assert(name == 'Vape Modules')
	return box
end

local api = {
	tabs = {['UI Settings'] = settings},
	toggles = toggles,
	state = 'loading',
	owned = {},
	nokey = {}
}

function api:own(id)
	self.owned[id] = true
end

function api:disown(id)
	self.owned[id] = nil
end

function api:clean(fn)
	cleanup = fn
end

function api:import(path)
	if path == 'src/vape/api.lua' then
		return function()
			made = made + 1
			local bridge = {}

			function bridge:destroy()
				destroyed = destroyed + 1
			end

			return bridge
		end
	end

	if path == 'src/vape/games/universal.lua' then
		return function()
			universal = universal + 1
		end
	end

	if path == 'src/vape/games/example.lua' then
		return function()
			gamebundle = gamebundle + 1
		end
	end

	error(path)
end

local entry = {
	family = {
		vape = 'src/vape/games/example.lua'
	}
}

local setup = dofile('src/modules/shared/vape_mode.lua')
local toggle = setup(api, entry)

assert(toggle.Text == 'Use Vape Modules')
assert(api.nokey.use_vape_modules == true)

toggle:SetValue(true)
assert(made == 1)
assert(universal == 1)
assert(gamebundle == 1)
assert(api.vape_enabled == true)

toggle:SetValue(false)
assert(destroyed == 1)
assert(api.vape_enabled == false)

cleanup()
assert(box.Destroyed == true)
assert(api.owned.use_vape_modules == nil)

print('vape mode tests passed')
