return function(api)
	local toggles = api.toggles
	local options = api.options
	local created = {}
	local guarded = {}

	local function cleanup()
		for index = #created, 1, -1 do
			local item = created[index]
			local picker = item.picker

			if options[item.id] == picker and type(rawget(picker, 'Destroy')) == 'function' then
				pcall(picker.Destroy, picker)
			end

			if options[item.id] == picker then
				options[item.id] = nil
			end
		end

		for index = #guarded, 1, -1 do
			local item = guarded[index]
			local picker = item.picker
			local list = item.list

			if rawget(picker, 'Blacklisted') == list then
				local found = table.find(list, 'MB1')

				if found then
					table.remove(list, found)
				end

				if item.empty and #list == 0 then
					picker.Blacklisted = nil
				end
			end
		end
	end

	api:clean(cleanup)

	local function has(toggle)
		for _, addon in ipairs(type(toggle) == 'table' and rawget(toggle, 'Addons') or {}) do
			if type(addon) == 'table'
				and rawget(addon, 'Type') == 'KeyPicker'
				and rawget(addon, 'Destroyed') ~= true then

				return true
			end
		end

		return false
	end

	local function guard(picker)
		if type(picker) ~= 'table' or rawget(picker, 'Type') ~= 'KeyPicker' then
			return
		end

		local list = rawget(picker, 'Blacklisted')

		if type(list) ~= 'table' then
			list = {}
			picker.Blacklisted = list
			guarded[#guarded + 1] = {picker = picker, list = list, empty = true}
		elseif not table.find(list, 'MB1') then
			list[#list + 1] = 'MB1'
			guarded[#guarded + 1] = {picker = picker, list = list}
		end
	end

	function api:addkey(toggle, id, text, default)
		if type(self.active) == 'function' then
			self:active()
		end

		if type(toggle) ~= 'table' or has(toggle) or options[id] ~= nil then
			return
		end

		local ok, add = pcall(function()
			return toggle.AddKeyPicker
		end)

		if not ok or type(add) ~= 'function' then
			return
		end

		local before = options[id]
		ok = pcall(add, toggle, id, {
			Default = default or 'None',
			SyncToggleState = true,
			Mode = 'Toggle',
			Text = text or tostring(rawget(toggle, 'Text') or id),
			NoUI = false,
			Blacklisted = {'MB1'}
		})

		local picker = options[id]

		if not ok then
			if picker ~= before and type(picker) == 'table' and type(rawget(picker, 'Destroy')) == 'function' then
				pcall(picker.Destroy, picker)
			end

			if options[id] == picker then
				options[id] = before
			end

			return
		end

		if type(picker) ~= 'table' then
			return
		end

		self:own(id)
		created[#created + 1] = {id = id, picker = picker}
		return picker
	end

	function api:finish_keybinds()
		for _, picker in pairs(options) do
			guard(picker)
		end

		local ids = {}

		for id, toggle in pairs(toggles) do
			if type(toggle) == 'table' then
				ids[#ids + 1] = id
			end
		end

		table.sort(ids, function(a, b)
			local left = tostring(a)
			local right = tostring(b)

			if left == right then
				return type(a) < type(b)
			end

			return left < right
		end)

		for _, toggleid in ipairs(ids) do
			if not (api.nokey and api.nokey[toggleid]) then
				local toggle = toggles[toggleid]
				local slug = tostring(toggleid):lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
				local base = 'fiverose_tweaker_auto_'..(slug ~= '' and slug or 'module')
				local id = base
				local suffix = 1

				while options[id] ~= nil do
					suffix = suffix + 1
					id = base..'_'..suffix
				end

				api:addkey(toggle, id, rawget(toggle, 'Text') or tostring(toggleid), 'None')
			end
		end

		for _, picker in pairs(options) do
			guard(picker)
		end

		return created
	end

	return created
end
