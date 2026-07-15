if not table.clear then
	function table.clear(value)
		for key in pairs(value) do
			value[key] = nil
		end
	end
end

local threads = {}
task = {}

function task.spawn(func, ...)
	local args = {...}
	local thread = coroutine.create(function()
		func(table.unpack(args))
	end)
	threads[#threads + 1] = thread
	assert(coroutine.resume(thread))
	return thread
end

function task.wait()
	coroutine.yield()
end

local function step()
	for index = #threads, 1, -1 do
		local thread = threads[index]

		if coroutine.status(thread) == 'dead' then
			table.remove(threads, index)
		else
			local ok, err = coroutine.resume(thread)
			assert(ok, err)
		end
	end
end

local function signal()
	local value = {connections = {}}

	function value:Connect(func)
		local connection = {Connected = true}
		self.connections[connection] = func

		function connection:Disconnect()
			self.Connected = false
			value.connections[self] = nil
		end

		return connection
	end

	function value:Fire(...)
		for connection, func in pairs(self.connections) do
			if connection.Connected then
				func(...)
			end
		end
	end

	return value
end

local characterAdded = signal()
local remote = {OnClientEvent = {}}
local remoteConnection = {Enabled = true, disabled = 0, enabled = 0}

function remoteConnection:Disable()
	self.Enabled = false
	self.disabled = self.disabled + 1
end

function remoteConnection:Enable()
	self.Enabled = true
	self.enabled = self.enabled + 1
end

function getconnections(value)
	assert(value == remote.OnClientEvent)
	return {remoteConnection}
end

function getrawmetatable(value)
	return getmetatable(value)
end

function isreadonly()
	return false
end

function setreadonly()
end

local function stamina(value)
	local function assign(target, key, nextvalue)
		rawset(target, key, nextvalue)
	end

	return setmetatable({Value = value}, {__newindex = assign}), assign
end

local current, firstAssign = stamina(100)
local service = {}

function service:GetKey(name)
	assert(name == 'UpdateStamina')
	return remote
end

local knit = {
	GetService = function(name)
		assert(name == 'KeyHandlerService')
		return service
	end
}
local context = {
	player = {CharacterAdded = characterAdded}
}

function context:knit()
	return knit
end

function context:stamina()
	return current
end

local api = {
	freestyle = context,
	options = {},
	toggles = {},
	owned = {},
	cleanups = {},
	active = true
}
local box = {}

function box:AddToggle(id, info)
	local item = {Value = info.Default == true}

	function item:OnChanged(func)
		self.Changed = func
	end

	function item:SetValue(value)
		self.Value = value == true
		self.Changed()
	end

	api.toggles[id] = item
	return item
end

function box:AddSlider(id, info)
	api.options[id] = {Value = info.Default}
	return api.options[id]
end

api.tab = {
	AddLeftGroupbox = function()
		return box
	end
}

function api:own(id)
	self.owned[id] = true
end

function api:addkey()
end

function api:isactive()
	return self.active
end

function api:notify()
	self.notified = true
end

function api:clean(func)
	self.cleanups[#self.cleanups + 1] = func
end

local setup = dofile('src/modules/freestyle_football/stamina.lua')
local state = setup(api)
local toggle = api.toggles.stamina_multiplier
api.options.stamina_multiplier_value.Value = 2

toggle:SetValue(true)
assert(state.object == current)
assert(remoteConnection.Enabled == false)
assert(getmetatable(current).__newindex == state.hook)

getmetatable(current).__newindex(current, 'Value', 50)
assert(current.Value == 75)

local first = current
local second, secondAssign = stamina(200)
current = second
characterAdded:Fire({})
assert(getmetatable(first).__newindex == firstAssign)
assert(remoteConnection.Enabled == true)

step()
assert(state.object == second)
assert(getmetatable(second).__newindex == state.hook)
assert(remoteConnection.Enabled == false)

toggle:SetValue(false)
assert(state.object == nil)
assert(getmetatable(second).__newindex == secondAssign)
assert(remoteConnection.Enabled == true)
step()

for index = #api.cleanups, 1, -1 do
	api.cleanups[index]()
end

assert(state.enabled == false)
assert(remoteConnection.Enabled == true)
print('stamina tests passed')
