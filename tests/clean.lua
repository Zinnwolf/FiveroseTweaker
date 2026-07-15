function typeof(value)
	return type(value)
end

local setup = dofile('src/core/clean.lua')
local env = {}
local api = {state = 'loading'}
local order = {}

env.fiverosetweaker = api
setup(api, env)

function api:save()
	order[#order + 1] = 'save'
end

api:clean(function()
	order[#order + 1] = 'first'
end)

api:clean({
	Destroy = function()
		order[#order + 1] = 'destroy'
	end
})

api:clean(function()
	order[#order + 1] = 'broken'
	error('expected cleanup failure')
end)

api:clean({
	Disconnect = function()
		order[#order + 1] = 'disconnect'
	end
})

assert(api:unload() == true)
assert(table.concat(order, ',') == 'save,disconnect,broken,destroy,first', table.concat(order, ','))
assert(#api.clean_errors == 1)
assert(api.state == 'unloaded')
assert(env.fiverosetweaker == nil)
assert(api:unload() == false)
assert(#order == 5)

api:clean(function()
	order[#order + 1] = 'late'
end)
assert(order[6] == 'late')

local methods = {'Disconnect', 'Destroy', 'Remove', 'Cancel'}

for _, method in ipairs(methods) do
	local called = 0
	local nextapi = {}
	setup(nextapi, {})
	nextapi:clean({
		[method] = function()
			called = called + 1
		end
	})
	nextapi:unload(true)
	assert(called == 1, method)
end

local failapi = {}
local failclean = false
setup(failapi, {})

function failapi:save()
	error('intentional save failure')
end

failapi:clean(function()
	failclean = true
end)
assert(failapi:unload() == true)
assert(failclean == true)
assert(type(failapi.save_error) == 'string')
assert(failapi.save_error:find('intentional save failure', 1, true))

print('cleanup tests passed')
