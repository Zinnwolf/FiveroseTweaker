return function(api)
	local http = game:GetService('HttpService')
	local root = 'fiverosetweaker/profiles'
	local scope = tostring(api.game.family.profile or api.game.alias or api.game.id or api.gameid)
	local folder = root..'/'..scope
	local fileapi = type(readfile) == 'function' and type(writefile) == 'function'
	local stopped = false
	local restoring = false
	local pending = 0
	local wrapped = {}
	local watchclean = false

	local function name(value)
		if type(value) ~= 'string' or #value < 1 or #value > 64 then
			return
		end

		return value:match('^[%w_-]+$') and value
	end

	local function folders(path)
		if type(makefolder) ~= 'function' then
			return
		end

		local current = ''

		for part in path:gmatch('[^/]+') do
			current = current == '' and part or current..'/'..part
			pcall(makefolder, current)
		end
	end

	local function read(path)
		if type(readfile) ~= 'function' then
			return
		end

		local ok, body = pcall(readfile, path)

		if ok and type(body) == 'string' and body:match('%S') then
			local head = body:sub(1, 256):lower()

			if not head:find('<html', 1, true) and not head:find('<!doctype', 1, true) then
				return body
			end
		end
	end

	local function write(path, body)
		if not fileapi or type(body) ~= 'string' or not body:match('%S') then
			return false
		end

		folders(path:match('^(.*)/[^/]+$') or root)
		return pcall(writefile, path, body)
	end

	local function value(item, depth)
		depth = depth or 0

		if depth > 5 then
			return
		end

		local roblox = type(typeof) == 'function' and typeof(item)

		if roblox == 'Color3' then
			return {
				__type = 'Color3',
				r = item.R,
				g = item.G,
				b = item.B
			}
		end

		local kind = type(item)

		if kind == 'string' or kind == 'number' or kind == 'boolean' then
			return item
		end

		if kind ~= 'table' then
			return
		end

		local result = {}

		for key, child in pairs(item) do
			local saved = value(child, depth + 1)

			if saved ~= nil and (type(key) == 'string' or type(key) == 'number') then
				result[key] = saved
			end
		end

		return result
	end

	local active = name(tostring(getgenv().fiverosetweaker_profile or ''))

	if not active then
		active = name(read(folder..'/active.txt')) or 'default'
	end

	local profile = {
		name = active,
		scope = scope,
		folder = folder,
		enabled = fileapi
	}

	api.profile = profile

	local function snapshot()
		local data = {
			version = 1,
			profile = profile.name,
			family = api.game.family_id,
			place = api.place,
			game = api.gameid,
			toggles = {},
			options = {}
		}

		for id in pairs(api.owned) do
			local toggle = api.toggles[id]
			local option = api.options[id]

			if type(toggle) == 'table' and type(rawget(toggle, 'Value')) == 'boolean' then
				data.toggles[id] = toggle.Value
			elseif type(option) == 'table' then
				if rawget(option, 'Type') == 'KeyPicker' then
					data.options[id] = {
						kind = 'keybind',
						value = tostring(rawget(option, 'Value') or 'None'),
						mode = tostring(rawget(option, 'Mode') or 'Toggle'),
						modifiers = value(rawget(option, 'Modifiers') or {})
					}
				elseif rawget(option, 'Type') == 'ColorPicker'
					and type(typeof) == 'function'
					and typeof(rawget(option, 'Value')) == 'Color3' then

					local color = rawget(option, 'Value')
					data.options[id] = {
						kind = 'color',
						r = color.R,
						g = color.G,
						b = color.B,
						transparency = tonumber(rawget(option, 'Transparency')) or 0
					}
				else
					local saved = value(rawget(option, 'Value'))

					if saved ~= nil then
						data.options[id] = saved
					end
				end
			end
		end

		return data
	end

	function api:save()
		if not profile.enabled or restoring or stopped then
			return false
		end

		local ok, body = pcall(http.JSONEncode, http, snapshot())

		if not ok or not body then
			return false
		end

		local saved = write(folder..'/'..profile.name..'.json', body)

		if saved then
			write(folder..'/active.txt', profile.name)
		end

		return saved
	end

	function api:queue_save()
		if not profile.enabled or restoring or stopped then
			return
		end

		pending = pending + 1
		local ticket = pending

		task.delay(1, function()
			if not stopped and not restoring and ticket == pending then
				api:save()
			end
		end)
	end

	local function apply(item, saved)
		if type(item) ~= 'table' then
			return
		end

		if type(saved) == 'table'
			and saved.kind == 'keybind'
			and type(rawget(item, 'SetValue')) == 'function' then

			pcall(item.SetValue, item, {
				tostring(saved.value or 'None'),
				tostring(saved.mode or 'Toggle'),
				type(saved.modifiers) == 'table' and saved.modifiers or {}
			})
		elseif type(saved) == 'table'
			and saved.kind == 'color'
			and type(rawget(item, 'SetValueRGB')) == 'function' then

			pcall(item.SetValueRGB, item, Color3.new(
				tonumber(saved.r) or 0,
				tonumber(saved.g) or 0,
				tonumber(saved.b) or 0
			), tonumber(saved.transparency) or 0)
		elseif type(saved) == 'table'
			and saved.__type == 'Color3'
			and type(rawget(item, 'SetValue')) == 'function' then

			pcall(item.SetValue, item, Color3.new(
				tonumber(saved.r) or 0,
				tonumber(saved.g) or 0,
				tonumber(saved.b) or 0
			))
		elseif type(rawget(item, 'SetValue')) == 'function' then
			pcall(item.SetValue, item, saved)
		end
	end

	local function watch(item)
		if type(item) ~= 'table' or wrapped[item] then
			return
		end

		local old = rawget(item, 'Changed')
		local changed = function(...)
			api:queue_save()

			if type(old) == 'function' then
				pcall(old, ...)
			end
		end

		item.Changed = changed
		wrapped[item] = {old = old, changed = changed}
	end

	local function unwatch()
		for item, data in pairs(wrapped) do
			if rawget(item, 'Changed') == data.changed then
				item.Changed = data.old
			end
		end

		table.clear(wrapped)
	end

	local function data()
		if not profile.enabled then
			return
		end

		local body = read(folder..'/'..profile.name..'.json')

		if not body then
			return
		end

		local ok, result = pcall(http.JSONDecode, http, body)

		if ok and type(result) == 'table' then
			return result
		end
	end

	function api:restoremode()
		local saved = data()
		local value = saved
			and type(saved.toggles) == 'table'
			and saved.toggles.use_vape_modules

		if type(value) == 'boolean' and self.owned.use_vape_modules then
			restoring = true
			apply(self.toggles.use_vape_modules, value)
			restoring = false
		end
	end

	function api:restore(skipmode)
		if not watchclean then
			watchclean = true
			self:clean(unwatch)
		end

		local saved = data()

		if saved then
			restoring = true

			for id, value in pairs(type(saved.options) == 'table' and saved.options or {}) do
				if self.owned[id] then
					apply(self.options[id], value)
				end
			end

			for id, value in pairs(type(saved.toggles) == 'table' and saved.toggles or {}) do
				if (not skipmode or id ~= 'use_vape_modules')
					and self.owned[id]
					and type(value) == 'boolean' then

					apply(self.toggles[id], value)
				end
			end

			restoring = false
		end

		for id in pairs(self.owned) do
			watch(self.toggles[id])
			watch(self.options[id])
		end

		return true
	end

	function api:setprofile(value)
		value = name(value)

		if not value then
			return false
		end

		self:save()
		profile.name = value
		getgenv().fiverosetweaker_profile = profile.name
		write(folder..'/active.txt', profile.name)
		self:restore()
		self:save()
		return true
	end

	local thread = task.spawn(function()
		while not stopped do
			task.wait(30)

			if not stopped then
				api:save()
			end
		end
	end)

	api:clean(function()
		stopped = true
		pending = pending + 1

		if type(task.cancel) == 'function' then
			pcall(task.cancel, thread)
		end

	end)

	return profile
end
