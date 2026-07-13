return function(api, entry)
	local tabs = api.tabs
	local toggles = api.toggles
	local id = 'use_vape_modules'
	local gen = 0
	local bridge
	local loading = false

	local function find()
		for _, wanted in ipairs({'ui settings', 'settings'}) do
			for key, tab in pairs(tabs) do
				local name = tostring(key):lower()
				local other = type(tab) == 'table'
					and tostring(rawget(tab, 'Name') or ''):lower()
					or ''

				if name == wanted or other == wanted then
					return tab
				end
			end
		end
	end

	local tab = find()

	if not tab then
		error('Fiverose UI Settings tab not found')
	end

	local box = tab:AddRightGroupbox('Vape Modules')
	box:AddToggle(id, {
		Text = 'Use Vape Modules',
		Default = false
	})

	local toggle = toggles[id]

	if type(toggle) ~= 'table' then
		error('Use Vape Modules toggle was not created')
	end

	api:own(id)
	api.nokey = api.nokey or {}
	api.nokey[id] = true

	local function drop()
		gen = gen + 1
		loading = false

		local current = bridge or api.vape_bridge

		if current and type(rawget(current, 'destroy')) == 'function' then
			pcall(current.destroy, current)
		end

		bridge = nil
		api.vape_enabled = false
	end

	local function load()
		if loading or bridge then
			return
		end

		gen = gen + 1
		local token = gen
		loading = true

		local ok, result = xpcall(function()
			local make = api:import('src/vape/api.lua')
			local current = make(api, entry)

			if token ~= gen or toggle.Value ~= true then
				current:destroy()
				return
			end

			bridge = current
			api:import('src/vape/games/universal.lua')(api)

			if entry.family.vape then
				api:import(entry.family.vape)(api, entry)
			end

			if token ~= gen or toggle.Value ~= true then
				current:destroy()
				bridge = nil
				return
			end

			api.vape_enabled = true
		end, function(err)
			if debug and type(debug.traceback) == 'function' then
				return debug.traceback(tostring(err), 2)
			end

			return tostring(err)
		end)

		loading = false

		if not ok then
			warn('[fiverosetweaker] Vape modules: '..tostring(result))
			drop()

			if toggle.Value == true then
				pcall(toggle.SetValue, toggle, false)
			end

			return
		end

		if api.state == 'loaded' then
			if type(api.finish_keybinds) == 'function' then
				api:finish_keybinds()
			end

			if type(api.restore) == 'function' then
				api:restore(true)
			end
		end
	end

	local function set(value)
		if value then
			load()
		else
			if type(api.save) == 'function' and bridge then
				pcall(api.save, api)
			end

			drop()
		end
	end

	function api:disable_vape()
		if toggle.Value == true and type(rawget(toggle, 'SetValue')) == 'function' then
			return toggle:SetValue(false)
		end

		drop()
	end

	toggle:OnChanged(function()
		set(toggle.Value == true)
	end)

	api:clean(function()
		drop()
		api.disable_vape = nil
		api.nokey[id] = nil
		api:disown(id)

		if type(box) == 'table' and type(rawget(box, 'Destroy')) == 'function' then
			pcall(box.Destroy, box)
		end
	end)

	return toggle
end
