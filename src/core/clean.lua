return function(api, env)
	local stack = {}
	local done = false
	local methods = {'Disconnect', 'Destroy', 'Remove', 'Cancel'}

	local function drop(obj)
		if type(obj) == 'function' then
			return obj()
		end

		if typeof(obj) == 'thread' and type(task.cancel) == 'function' then
			return task.cancel(obj)
		end

		for _, name in ipairs(methods) do
			local ok, method = pcall(function()
				return obj[name]
			end)

			if ok and type(method) == 'function' then
				return method(obj)
			end
		end
	end

	function api:clean(obj)
		if obj == nil then
			return obj
		end

		if done then
			pcall(drop, obj)
			return obj
		end

		stack[#stack + 1] = obj
		return obj
	end

	function api:unload(skip)
		if done then
			return false
		end

		done = true
		self.state = 'unloading'

		if not skip and type(self.save) == 'function' then
			pcall(self.save, self, true)
		end

		local errors = {}

		for index = #stack, 1, -1 do
			local ok, err = pcall(drop, stack[index])

			if not ok then
				errors[#errors + 1] = tostring(err)
			end

			stack[index] = nil
		end

		self.clean_errors = errors
		self.state = 'unloaded'

		if rawget(env, 'fiverosetweaker') == self then
			env.fiverosetweaker = nil
		end

		if rawget(env, 'fiverosetweaker_boot_token') == self.boot_token then
			env.fiverosetweaker_boot_token = nil
		end

		return true
	end

	function api:reload()
		if self.state ~= 'loaded' then
			return false
		end

		self.state = 'reloading'

		local ok, source = pcall(self.source, self, 'main.lua')
		local current = self.state == 'reloading'
			and rawget(env, 'fiverosetweaker') == self
			and rawget(env, 'fiverosetweaker_boot_token') == self.boot_token

		if not ok then
			if not current then
				return false
			end

			self.state = 'loaded'
			error(source, 2)
		end

		if not current then
			return false
		end

		local chunk, err = loadstring(source, '@fiverosetweaker/main.lua')

		if not chunk then
			if self.state == 'reloading' then
				self.state = 'loaded'
			end

			error(err, 2)
		end

		if not self:unload() then
			return false
		end

		task.defer(chunk)
		return true
	end

	api._clean = stack
	return api
end
