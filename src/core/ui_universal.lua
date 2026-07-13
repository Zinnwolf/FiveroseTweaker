return function(api, root)
	local gc = type(getgc) == 'function' and getgc(true) or {}
	local score = -1
	local lib
	local objects = {}

	local function alive(obj)
		return typeof(obj) == 'Instance' and obj.Parent ~= nil
	end

	local function inside(obj, parent)
		return alive(obj)
			and alive(parent)
			and (obj == parent or obj:IsDescendantOf(parent))
	end

	local function metascore(meta)
		if type(meta) ~= 'table' then
			return -1
		end

		local value = rawget(meta, '__index') == meta and 2000 or 0

		for _, name in ipairs({
			'Window',
			'Panel',
			'Tab',
			'Column',
			'Section',
			'Toggle',
			'Slider',
			'Dropdown',
			'Textbox',
			'Button',
			'Label',
			'Keybind'
		}) do
			if type(rawget(meta, name)) == 'function' then
				value = value + 1000
			end
		end

		if type(rawget(meta, 'Flags')) == 'table' then
			value = value + 1000
		end

		if type(rawget(meta, 'ConfigFlags')) == 'table' then
			value = value + 1000
		end

		if alive(rawget(meta, 'Items')) then
			value = value + 1000
		end

		return value
	end

	local seen = {}

	for index, obj in ipairs(gc) do
		if type(obj) == 'table' then
			local meta = getmetatable(obj)

			if type(meta) == 'table' and not seen[meta] then
				seen[meta] = true
				local value = metascore(meta)

				if value > score then
					score = value
					lib = meta
				end
			end
		end

		if index % 4000 == 0 then
			task.wait()
		end
	end

	if score < 12000 or type(lib) ~= 'table' then
		error('Universal Fiverose library not found')
	end

	for index, obj in ipairs(gc) do
		if type(obj) == 'table' and getmetatable(obj) == lib then
			objects[#objects + 1] = obj
		end

		if index % 4000 == 0 then
			task.wait()
		end
	end

	local panel
	local tabs = {}
	local native = {}
	local menu

	for _, obj in ipairs(objects) do
		local items = rawget(obj, 'Items')

		if type(items) == 'table'
			and type(rawget(obj, 'SetMenuVisible')) == 'function'
			and type(rawget(obj, 'ToggleMenu')) == 'function'
			and alive(rawget(items, 'TabButtonHolder'))
			and alive(rawget(items, 'PageHolder')) then

			panel = obj
		elseif type(items) == 'table'
			and type(rawget(obj, 'OpenTab')) == 'function'
			and alive(rawget(items, 'Outline'))
			and alive(rawget(items, 'Page'))
			and type(rawget(obj, 'Name')) == 'string' then

			tabs[#tabs + 1] = obj
		elseif type(items) == 'table'
			and type(rawget(obj, 'Set')) == 'function'
			and type(rawget(obj, 'Flag')) == 'string' then

			native[#native + 1] = obj

			if rawget(obj, 'Flag') == 'Menu Bind'
				and rawget(obj, 'Key') ~= nil then

				menu = obj
			end
		end
	end

	if type(panel) ~= 'table' then
		error('Universal Fiverose panel not found')
	end

	local screen = rawget(lib, 'Items')

	if not alive(screen) or not screen:IsA('ScreenGui') then
		local holder = type(rawget(panel, 'Items')) == 'table'
			and rawget(rawget(panel, 'Items'), 'Window')

		screen = alive(holder) and holder:FindFirstAncestorOfClass('ScreenGui') or root
	end

	if alive(root)
		and alive(screen)
		and root ~= screen
		and not inside(screen, root)
		and not inside(root, screen) then

		error('Universal Fiverose library does not match the detected UI')
	end

	local state = {
		lib = lib,
		panel = panel,
		screen = screen,
		objects = objects,
		native = native,
		menu = menu,
		tabs = {},
		wrapped = {},
		created = {},
		serial = 0
	}

	local toggles = {}
	local options = {}
	local tabmap = {}
	local facade = {
		Backend = 'universal',
		Tabs = tabmap,
		Toggles = toggles,
		Options = options,
		Window = nil,
		ActiveTab = nil
	}

	local function keyname(value)
		if typeof(value) == 'EnumItem' then
			return value.Name
		end

		value = tostring(value or 'NONE')
		value = value:gsub('Enum%.KeyCode%.', '')
		value = value:gsub('Enum%.UserInputType%.', '')
		return value == 'NONE' and 'None' or value
	end

	local function keyenum(value)
		if typeof(value) == 'EnumItem' then
			return value
		end

		value = tostring(value or 'None')

		if value == 'None' or value == 'NONE' or value == 'Unknown' then
			return 'NONE'
		end

		return Enum.KeyCode[value] or Enum.UserInputType[value] or 'NONE'
	end

	local function blocked(value)
		if type(value) == 'table' then
			return blocked(value.Key or value.Value or value[1])
		end

		return value == Enum.UserInputType.MouseButton1
			or value == Enum.UserInputType.MouseButton2
			or value == Enum.KeyCode.Unknown
			or value == 'MB1'
			or value == 'MB2'
			or value == 'MouseButton1'
			or value == 'MouseButton2'
			or value == 'Unknown'
	end

	local function emit(item)
		if type(rawget(item, 'Changed')) == 'function' then
			pcall(item.Changed, item.Value)
		end

		for _, callback in ipairs(rawget(item, '_changed') or {}) do
			pcall(callback, item.Value)
		end
	end

	local function rootof(obj, names)
		local items = type(obj) == 'table' and rawget(obj, 'Items')

		if type(items) ~= 'table' then
			return
		end

		for _, name in ipairs(names) do
			local value = rawget(items, name)

			if alive(value) then
				return value
			end
		end
	end

	local function setvisible(obj, value)
		if type(obj) ~= 'table' then
			return
		end

		for _, name in ipairs({
			'Toggle',
			'Slider',
			'Dropdown',
			'Textbox',
			'Button',
			'Label',
			'Keybind',
			'ColorpickerObject',
			'Outline',
			'Page'
		}) do
			local item = type(rawget(obj, 'Items')) == 'table'
				and rawget(rawget(obj, 'Items'), name)

			if alive(item) then
				item.Visible = value == true
			end
		end
	end

	local function clearflag(flag)
		if type(flag) ~= 'string' then
			return
		end

		local flags = rawget(lib, 'Flags')
		local config = rawget(lib, 'ConfigFlags')

		if type(flags) == 'table' then
			flags[flag] = nil
			flags[flag..'_MODE'] = nil
			flags[flag..'_LIST'] = nil
			flags[flag..'_RAINBOW_FLAG'] = nil
		end

		if type(config) == 'table' then
			config[flag] = nil
			config[flag..'_MODE'] = nil
			config[flag..'_LIST'] = nil
			config[flag..'_RAINBOW_FLAG'] = nil
		end
	end

\tlocal function connectionmark()
\t\tlocal cons = rawget(lib, 'Connections')
\t\treturn type(cons) == 'table' and #cons or 0
\tend

\tlocal function adoptconnections(item, mark)
\t\tif type(item) ~= 'table' or rawget(item, '_owned') ~= true then
\t\t\treturn
\t\tend

\t\tlocal cons = rawget(lib, 'Connections')

\t\tif type(cons) ~= 'table' then
\t\t\treturn
\t\tend

\t\tlocal list = rawget(item, '_connections')
\t\tlocal found = rawget(item, '_connectionset')

\t\tfor index = (tonumber(mark) or #cons) + 1, #cons do
\t\t\tlocal con = cons[index]

\t\t\tif con ~= nil and not found[con] then
\t\t\t\tfound[con] = true
\t\t\t\tlist[#list + 1] = con
\t\t\tend
\t\tend
\tend

\tlocal function releaseconnections(item)
\t\tif type(item) ~= 'table' then
\t\t\treturn
\t\tend

\t\tlocal list = rawget(item, '_connections') or {}
\t\tlocal found = rawget(item, '_connectionset') or {}
\t\tlocal native = rawget(item, 'Native')
\t\tlocal binding = type(native) == 'table' and rawget(native, 'Binding')

\t\tif binding ~= nil and not found[binding] then
\t\t\tfound[binding] = true
\t\t\tlist[#list + 1] = binding
\t\tend

\t\tfor _, con in ipairs(list) do
\t\t\tpcall(function()
\t\t\t\tif con.Connected ~= false then
\t\t\t\t\tcon:Disconnect()
\t\t\t\tend
\t\t\tend)
\t\tend

\t\tlocal cons = rawget(lib, 'Connections')

\t\tif type(cons) == 'table' then
\t\t\tfor index = #cons, 1, -1 do
\t\t\t\tif found[cons[index]] then
\t\t\t\t\ttable.remove(cons, index)
\t\t\t\tend
\t\t\tend
\t\tend

\t\ttable.clear(list)
\t\ttable.clear(found)
\tend

\tlocal function trackmethod(item, obj, name)
\t\tif type(item) ~= 'table'
\t\t\tor rawget(item, '_owned') ~= true
\t\t\tor type(obj) ~= 'table' then

\t\t\treturn
\t\tend

\t\tlocal old = rawget(obj, name)

\t\tif type(old) ~= 'function' then
\t\t\treturn
\t\tend

\t\tlocal wrapped

\t\twrapped = function(...)
\t\t\tlocal mark = connectionmark()
\t\t\tlocal result = table.pack(pcall(old, ...))
\t\t\tadoptconnections(item, mark)

\t\t\tif not result[1] then
\t\t\t\terror(result[2], 0)
\t\t\tend

\t\t\treturn table.unpack(result, 2, result.n)
\t\tend

\t\tobj[name] = wrapped
\t\titem._hooks[#item._hooks + 1] = {
\t\t\tobj = obj,
\t\t\tname = name,
\t\t\told = old,
\t\t\twrapped = wrapped
\t\t}
\tend

\tlocal function tracknative(item, obj, mark)
\t\tif type(item) ~= 'table' or rawget(item, '_owned') ~= true then
\t\t\treturn item
\t\tend

\t\tadoptconnections(item, mark)
\t\ttrackmethod(item, obj, 'SetVisible')
\t\ttrackmethod(item, obj, 'Tween')
\t\treturn item
\tend

	local function destroyroots(obj, extra)
		local roots = {}
		local found = {}
		local seen = {}

		local function collect(value, depth)
			if alive(value) then
				if not found[value] then
					found[value] = true
					roots[#roots + 1] = value
				end

				return
			end

			if type(value) ~= 'table' or seen[value] or depth > 5 then
				return
			end

			seen[value] = true

			for key, item in pairs(value) do
				if key ~= '__index' and key ~= 'Library' then
					collect(item, depth + 1)
				end
			end
		end

		local items = type(obj) == 'table' and rawget(obj, 'Items')

		if type(items) == 'table' then
			collect(items, 0)
		end

		for _, value in ipairs(extra or {}) do
			collect(value, 0)
		end

		table.sort(roots, function(a, b)
			local left = 0
			local right = 0
			local current = a

			while current do
				left = left + 1
				current = current.Parent
			end

			current = b

			while current do
				right = right + 1
				current = current.Parent
			end

			return left < right
		end)

		for _, value in ipairs(roots) do
			if alive(value) then
				pcall(value.Destroy, value)
			end
		end
	end

	local function base(kind, id, obj, owned)
		local item = {
			Type = kind,
			Id = id,
			Native = obj,
			Container = rootof(obj, {
				'Toggle',
				'Slider',
				'Dropdown',
				'Textbox',
				'Button',
				'Label',
				'Keybind',
				'ColorpickerObject'
			}),
			Destroyed = false,
			_changed = {},
			_owned = owned ~= false,
			_extra = {},
			_hooks = {},
			_connections = {},
			_connectionset = {}
		}

		function item:OnChanged(callback)
			if type(callback) == 'function' then
				self._changed[#self._changed + 1] = callback
			end

			return self
		end

		function item:SetVisible(value)
			setvisible(self.Native, value)
			return self
		end

		function item:Destroy()
			if self.Destroyed then
				return false
			end

			self.Destroyed = true

			for index = #self._hooks, 1, -1 do
				local hook = self._hooks[index]

				if type(hook) == 'table'
					and rawget(hook.obj, hook.name) == hook.wrapped then

					hook.obj[hook.name] = hook.old
				end

				self._hooks[index] = nil
			end

			releaseconnections(self)

			if type(self._restore) == 'function' then
				pcall(self._restore)
				self._restore = nil
			end

			if self._owned then
				destroyroots(self.Native, self._extra)
				clearflag(self._flag or self.Id)
			end

			if self.Id ~= nil and toggles[self.Id] == self then
				toggles[self.Id] = nil
			end

			if self.Id ~= nil and options[self.Id] == self then
				options[self.Id] = nil
			end

			return true
		end

		return item
	end

	local function listchildren()
		local holder = type(rawget(lib, 'KeybindList')) == 'table'
			and type(rawget(rawget(lib, 'KeybindList'), 'Items')) == 'table'
			and rawget(rawget(rawget(lib, 'KeybindList'), 'Items'), 'Holder')
		local result = {}

		if alive(holder) then
			for _, child in ipairs(holder:GetChildren()) do
				result[child] = true
			end
		end

		return holder, result
	end

	local function wrapkey(obj, id, owned, mark, fallback)
		if type(obj) ~= 'table' or type(rawget(obj, 'Set')) ~= 'function' then
			return
		end

		local item = base('KeyPicker', id, obj, owned)
		tracknative(item, obj, mark)
		local old = rawget(obj, 'Set')
		local config = rawget(lib, 'ConfigFlags')
		local oldconfig = type(config) == 'table' and rawget(config, rawget(obj, 'Flag'))
		item._flag = rawget(obj, 'Flag') or id
		item.Value = keyname(rawget(obj, 'Key'))
		item.Mode = tostring(rawget(obj, 'Mode') or 'Toggle')
		item.Modifiers = {}
		item.Blacklisted = {'MB1', 'MB2'}
		item.Fallback = tostring(fallback or 'None')

		local function update()
			item.Value = keyname(rawget(obj, 'Key'))
			item.Mode = tostring(rawget(obj, 'Mode') or 'Toggle')
			emit(item)
		end

		local function keychange(value)
			return typeof(value) == 'EnumItem'
				or type(value) == 'table'
				and (value.Key ~= nil or value.Value ~= nil or value[1] ~= nil)
		end

		local function force(value)
			local callback = rawget(obj, 'Callback')
			local mode = tostring(rawget(obj, 'Mode') or 'Toggle')

			if mode == 'Press' then
				mode = 'Toggle'
			end

			obj.Callback = function() end

			local ok, err = pcall(old, {
				Key = keyenum(value),
				Mode = mode,
				Active = false
			})

			obj.Callback = callback

			if not ok then
				error(err, 0)
			end

			obj.Active = false
			update()
		end

		local function set(value)
			if blocked(value) then
				if blocked(rawget(obj, 'Key')) then
					force(item.Fallback)
				else
					update()
				end

				return
			end

			if keychange(value) then
				local callback = rawget(obj, 'Callback')
				obj.Callback = function() end
				local ok, err = pcall(old, value)
				obj.Callback = callback

				if not ok then
					error(err, 0)
				end
			else
				old(value)
			end

			update()
		end

		obj.Set = set

		if type(config) == 'table' then
			config[item._flag] = set
		end

		item._restore = function()
			if rawget(obj, 'Set') == set then
				obj.Set = old
			end

			if type(config) == 'table' and rawget(config, item._flag) == set then
				config[item._flag] = oldconfig
			end
		end

		function item:Repair()
			if blocked(rawget(obj, 'Key')) then
				force(self.Fallback)
				return true
			end

			return false
		end

		item:Repair()

		function item:SetValue(value)
			local key = value
			local mode = self.Mode

			if type(value) == 'table' then
				key = value[1] or value.Key or value.Value
				mode = value[2] or value.Mode or mode
			end

			if mode == 'Press' then
				mode = 'Toggle'
			end

			set({
				Key = keyenum(key),
				Mode = mode,
				Active = rawget(obj, 'Active')
			})
		end

		return item
	end

	local function directchildren(page)
		local result = {}

		if alive(page) then
			for _, child in ipairs(page:GetChildren()) do
				if child:IsA('Frame')
					and child:FindFirstChildOfClass('UIListLayout') then

					result[#result + 1] = child
				end
			end
		end

		table.sort(result, function(a, b)
			if a.AbsolutePosition.X == b.AbsolutePosition.X then
				return a.LayoutOrder < b.LayoutOrder
			end

			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end)

		return result
	end

	local wraptab
	local wrapbox

	local function wrapcolumn(frame)
		return setmetatable({
			Items = {
				Column = frame
			}
		}, lib)
	end

	local function create(class, props)
		local ok, obj = pcall(lib.Create, lib, class, props)

		if ok and alive(obj) then
			return obj
		end

		obj = Instance.new(class)

		for key, value in pairs(props or {}) do
			pcall(function()
				obj[key] = value
			end)
		end

		return obj
	end

	local function scrollcolumn(tab, order)
		local accent = Color3.fromRGB(19, 128, 225)
		local flags = rawget(lib, 'Flags')
		local value = type(flags) == 'table' and rawget(flags, 'Accent')

		if type(value) == 'table' and typeof(rawget(value, 'Color')) == 'Color3' then
			accent = value.Color
		end

		local frame = create('ScrollingFrame', {
			Parent = tab.Container,
			Name = 'FiveroseTweakerColumn',
			LayoutOrder = order,
			Size = UDim2.new(0, 100, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = accent,
			ScrollingDirection = Enum.ScrollingDirection.Y
		})

		create('UIListLayout', {
			Parent = frame,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = UDim.new(0, 11)
		})

		create('UIPadding', {
			Parent = frame,
			PaddingRight = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4)
		})

		return wrapcolumn(frame)
	end

	wrapbox = function(obj, tab, title)
		local box = {
			Name = tostring(title or 'Section'),
			Native = obj,
			Tab = tab,
			Destroyed = false,
			_items = {}
		}

		local function add(item)
			if item then
				box._items[#box._items + 1] = item
			end

			return item
		end

		function box:SetVisible(value)
			setvisible(self.Native, value)
			return self
		end

		function box:Destroy()
			if self.Destroyed then
				return false
			end

			self.Destroyed = true

			for index = #self._items, 1, -1 do
				local item = self._items[index]

				if type(item) == 'table'
					and type(rawget(item, 'Destroy')) == 'function' then

					pcall(item.Destroy, item)
				end

				self._items[index] = nil
			end

			destroyroots(self.Native)
			return true
		end

		function box:AddToggle(id, info)
			info = info or {}
			local item
			local mark = connectionmark()
			local obj = self.Native:Toggle({
				Name = info.Text or id,
				Flag = id,
				Default = info.Default == true,
				Callback = function(value)
					if item then
						item.Value = value == true
						emit(item)
					end
				end
			})

			item = base('Toggle', id, obj)
			tracknative(item, obj, mark)
			item.Text = tostring(info.Text or id)
			item.Value = rawget(obj, 'Enabled') == true
			item.Addons = {}
			item._flag = id

			function item:SetValue(value)
				value = value == true

				if self.Value == value and rawget(self.Native, 'Enabled') == value then
					return
				end

				self.Native.Enabled = value
				self.Native.Set(value)
			end

			function item:AddKeyPicker(keyid, keyinfo)
				keyinfo = keyinfo or {}
				local holder, before = listchildren()
				local mark = connectionmark()
				local key
				local obj = self.Native:Keybind({
					Name = keyinfo.Text or self.Text,
					Flag = keyid,
					Key = keyenum(keyinfo.Default),
					Mode = keyinfo.Mode == 'Press' and 'Toggle' or (keyinfo.Mode or 'Toggle'),
					Default = self.Value,
					ShowInList = keyinfo.NoUI ~= true,
					Callback = function(value)
						if keyinfo.SyncToggleState and item then
							item:SetValue(value == true)
						end
					end
				})

				key = wrapkey(obj, keyid, true, mark)

				if key then
					key.Blacklisted = {'MB1', 'MB2'}
					self.Addons[#self.Addons + 1] = key
					options[keyid] = key

					if alive(holder) then
						for _, child in ipairs(holder:GetChildren()) do
							if not before[child] then
								key._extra[#key._extra + 1] = child
							end
						end
					end
				end

				return key
			end

			local olddestroy = item.Destroy

			function item:Destroy()
				for index = #self.Addons, 1, -1 do
					local addon = self.Addons[index]

					if type(addon) == 'table'
						and type(rawget(addon, 'Destroy')) == 'function' then

						pcall(addon.Destroy, addon)
					end

					self.Addons[index] = nil
				end

				return olddestroy(self)
			end

			toggles[id] = item
			item:SetVisible(info.Visible ~= false)
			return add(item)
		end

		function box:AddSlider(id, info)
			info = info or {}
			local item
			local step = 10 ^ -(tonumber(info.Rounding) or 0)
			local mark = connectionmark()
			local obj = self.Native:Slider({
				Name = info.Text or id,
				Flag = id,
				Default = tonumber(info.Default) or 0,
				Min = tonumber(info.Min) or 0,
				Max = tonumber(info.Max) or 100,
				Decimal = step,
				Suffix = tostring(info.Suffix or ''),
				Callback = function(value)
					if item then
						item.Value = value
						emit(item)
					end
				end
			})

			item = base('Slider', id, obj)
			tracknative(item, obj, mark)
			item.Value = rawget(obj, 'Value')
			item.Min = rawget(obj, 'Min')
			item.Max = rawget(obj, 'Max')
			item._flag = id

			function item:SetValue(value)
				self.Native.Set(tonumber(value) or self.Value)
				self.Value = rawget(self.Native, 'Value')
			end

			options[id] = item
			item:SetVisible(info.Visible ~= false)
			return add(item)
		end

		function box:AddDropdown(id, info)
			info = info or {}
			local item
			local values = type(info.Values) == 'table' and table.clone(info.Values) or {}
			local mark = connectionmark()
			local obj = self.Native:Dropdown({
				Name = info.Text or id,
				Flag = id,
				Options = values,
				Default = info.Default or values[1],
				Callback = function(value)
					if item then
						item.Value = value
						emit(item)
					end
				end
			})

			item = base('Dropdown', id, obj)
			tracknative(item, obj, mark)
			item.Value = rawget(obj, 'Default') or info.Default
			item.Values = values
			item._flag = id

			function item:SetValue(value)
				self.Native.Set(value)
				self.Value = type(rawget(self.Native, 'Multi')) == 'boolean'
					and rawget(self.Native, 'Multi')
					and rawget(self.Native, 'MultiItems')
					or value
			end

			function item:SetValues(values)
				self.Values = type(values) == 'table' and table.clone(values) or {}
				self.Native.Options = self.Values

				if type(rawget(self.Native, 'RefreshOptions')) == 'function' then
					self.Native.RefreshOptions(self.Values)
				end
			end

			options[id] = item
			item:SetVisible(info.Visible ~= false)
			return add(item)
		end

		function box:AddInput(id, info)
			info = info or {}
			local item
			local mark = connectionmark()
			local obj = self.Native:Textbox({
				Name = info.Text or id,
				Flag = id,
				Default = tostring(info.Default or ''),
				PlaceHolder = tostring(info.Placeholder or ''),
				Callback = function(value)
					if item then
						item.Value = tostring(value or '')
						emit(item)
					end
				end
			})

			item = base('Input', id, obj)
			tracknative(item, obj, mark)
			item.Value = tostring(rawget(obj, 'Default') or info.Default or '')
			item._flag = id

			function item:SetValue(value)
				self.Native.Set(tostring(value or ''))
				self.Value = tostring(value or '')
			end

			options[id] = item
			item:SetVisible(info.Visible ~= false)
			return add(item)
		end

		function box:AddLabel(text)
			local mark = connectionmark()
			local obj = self.Native:Label({
				Name = tostring(text or '')
			})
			local item = base('Label', nil, obj)
			tracknative(item, obj, mark)
			item.Text = tostring(text or '')
			item._children = {}
			local olddestroy = item.Destroy

			function item:Destroy()
				for index = #self._children, 1, -1 do
					local child = self._children[index]

					if type(child) == 'table'
						and type(rawget(child, 'Destroy')) == 'function' then

						pcall(child.Destroy, child)
					end

					self._children[index] = nil
				end

				return olddestroy(self)
			end

			function item:AddColorPicker(id, info)
				info = info or {}
				local color
				local mark = connectionmark()
				local obj = self.Native:Colorpicker({
					Name = info.Title or item.Text,
					Flag = id,
					Color = typeof(info.Default) == 'Color3' and info.Default or Color3.new(1, 1, 1),
					Alpha = tonumber(info.Transparency) or 0,
					Callback = function(value, alpha)
						if color then
							color.Value = value
							color.Transparency = alpha
							emit(color)
						end
					end
				})

				color = base('ColorPicker', id, obj)
				tracknative(color, obj, mark)
				color.Value = rawget(obj, 'Color')
				color.Transparency = rawget(obj, 'Alpha')
				color._flag = id

				function color:SetValueRGB(value, alpha)
					self.Native.Set(value, alpha)
					self.Value = value
					self.Transparency = alpha
				end

				function color:SetValue(value)
					self:SetValueRGB(value, self.Transparency)
				end

				options[id] = color
				self._children[#self._children + 1] = color
				return color
			end

			function item:AddKeyPicker(id, info)
				info = info or {}
				local holder, before = listchildren()
				local mark = connectionmark()
				local obj = self.Native:Keybind({
					Name = info.Text or item.Text,
					Flag = id,
					Key = keyenum(info.Default),
					Mode = info.Mode == 'Press' and 'Toggle' or (info.Mode or 'Toggle'),
					Default = false,
					ShowInList = info.NoUI ~= true,
					Callback = function() end
				})
				local key = wrapkey(obj, id, true, mark)

				if key then
					key.Blacklisted = {'MB1', 'MB2'}
					options[id] = key

					if alive(holder) then
						for _, child in ipairs(holder:GetChildren()) do
							if not before[child] then
								key._extra[#key._extra + 1] = child
							end
						end
					end
				end

				if key then
					self._children[#self._children + 1] = key
				end

				return key
			end

			return add(item)
		end

		function box:AddButton(info)
			info = info or {}
			local mark = connectionmark()
			local obj = self.Native:Button({
				Name = info.Text or 'Button',
				Callback = info.Func or function() end
			})
			local item = base('Button', nil, obj)
			tracknative(item, obj, mark)
			item.Text = tostring(info.Text or 'Button')
			return add(item)
		end

		return box
	end

	wraptab = function(obj, owned)
		local items = rawget(obj, 'Items')
		local tab = {
			Name = tostring(rawget(obj, 'Name') or 'Tab'),
			Native = obj,
			Sides = {
				type(items) == 'table' and rawget(items, 'Page')
			},
			Button = type(items) == 'table' and rawget(items, 'Outline'),
			Container = type(items) == 'table' and rawget(items, 'Page'),
			Visible = true,
			Destroyed = false,
			_owned = owned == true,
			_columns = {}
		}

		function tab:SetVisible(value)
			value = value == true
			self.Visible = value

			if alive(self.Button) then
				self.Button.Visible = value
			end

			if not value then
				self:Hide()
			end

			return self
		end

		function tab:Hide()
			local page = self.Container

			if alive(page) then
				page.Visible = false

				if alive(rawget(lib, 'Other')) then
					page.Parent = lib.Other
				end
			end

			if rawget(panel, 'TabInfo') == self.Native then
				panel.TabInfo = nil
			end

			if facade.ActiveTab == self then
				facade.ActiveTab = nil
			end

			return self
		end

		function tab:Show()
			if self.Destroyed then
				return self
			end

			self.Visible = true

			if alive(self.Button) then
				self.Button.Visible = true
			end

			self.Native.Tweening = false
			pcall(self.Native.OpenTab)
			facade.ActiveTab = self
			return self
		end

		local function column(side)
			if tab._columns[side] then
				return tab._columns[side]
			end

			local columns = directchildren(tab.Container)
			local frame

			if tab._owned then
				if side == 'left' then
					frame = columns[1]
				elseif #columns >= 2 then
					frame = columns[#columns]
				end
			elseif #columns > 0 then
				frame = side == 'right' and columns[#columns] or columns[1]
			end

			local obj

			if alive(frame) then
				obj = wrapcolumn(frame)
			elseif tab._owned then
				obj = scrollcolumn(tab, side == 'right' and 2 or 1)
			else
				obj = tab.Native:Column({})
			end

			tab._columns[side] = obj
			return obj
		end

		function tab:AddLeftGroupbox(title)
			local obj = column('left'):Section({
				Name = tostring(title or 'Section')
			})
			return wrapbox(obj, self, title)
		end

		function tab:AddRightGroupbox(title)
			local obj = column('right'):Section({
				Name = tostring(title or 'Section')
			})
			return wrapbox(obj, self, title)
		end

		function tab:Destroy()
			if self.Destroyed then
				return false
			end

			self.Destroyed = true

			if rawget(panel, 'TabInfo') == self.Native then
				panel.TabInfo = nil
			end

			if facade.ActiveTab == self then
				facade.ActiveTab = nil
			end

			if self._owned then
				destroyroots(self.Native)
			end

			for key, value in pairs(tabmap) do
				if value == self then
					tabmap[key] = nil
				end
			end

			return true
		end

		return tab
	end

	for _, obj in ipairs(tabs) do
		local tab = wraptab(obj, false)
		local name = tostring(rawget(obj, 'Name') or 'Tab')
		tabmap[name] = tab

		if rawget(panel, 'TabInfo') == obj then
			facade.ActiveTab = tab
		end
	end

	local win = {}

	function win:AddTab(info)
		info = info or {}
		local obj = panel:Tab({
			Name = info.Name or 'Tab'
		})
		local tab = wraptab(obj, true)
		tabmap[tab.Name] = tab
		state.created[#state.created + 1] = tab
		return tab
	end

	facade.Window = win

	function facade:Notify(info)
		info = info or {}
		local title = tostring(info.Title or 'FiveroseTweaker')
		local text = tostring(info.Description or '')
		local name = text ~= '' and title..' | '..text or title

		return pcall(lib.Notification, lib, {
			Name = name,
			Lifetime = tonumber(info.Time) or 3
		})
	end

	function facade:Toggle()
		local value = rawget(panel, 'Open') ~= true
		panel.Open = value
		return pcall(panel.SetMenuVisible, value)
	end

	function state:findflag(flag)
		for _, obj in ipairs(self.native) do
			if rawget(obj, 'Flag') == flag then
				return obj
			end
		end
	end

	function state:wrapkey(obj, id, fallback)
		return wrapkey(obj, id, false, nil, fallback)
	end

	function state:mark()
		local cons = rawget(lib, 'Connections')
		local holder, children = listchildren()
		local flags = {}
		local config = {}

		for key in pairs(type(rawget(lib, 'Flags')) == 'table' and lib.Flags or {}) do
			flags[key] = true
		end

		for key in pairs(type(rawget(lib, 'ConfigFlags')) == 'table' and lib.ConfigFlags or {}) do
			config[key] = true
		end

		return {
			connections = type(cons) == 'table' and #cons or 0,
			holder = holder,
			children = children,
			created = #self.created,
			flags = flags,
			config = config,
			open = rawget(lib, 'OpenElement')
		}
	end

	function state:rollback(mark)
		if type(mark) ~= 'table' then
			return
		end

		for index = #self.created, (mark.created or 0) + 1, -1 do
			local item = self.created[index]

			if type(item) == 'table' and type(rawget(item, 'Destroy')) == 'function' then
				pcall(item.Destroy, item)
			end

			self.created[index] = nil
		end

		local cons = rawget(lib, 'Connections')

		if type(cons) == 'table' then
			for index = #cons, (mark.connections or 0) + 1, -1 do
				local con = cons[index]

				if con then
					pcall(con.Disconnect, con)
				end

				table.remove(cons, index)
			end
		end

		if alive(mark.holder) then
			for _, child in ipairs(mark.holder:GetChildren()) do
				if not mark.children[child] then
					pcall(child.Destroy, child)
				end
			end
		end

		local flags = rawget(lib, 'Flags')

		if type(flags) == 'table' then
			for key in pairs(flags) do
				if not mark.flags[key] then
					flags[key] = nil
				end
			end
		end

		local config = rawget(lib, 'ConfigFlags')

		if type(config) == 'table' then
			for key in pairs(config) do
				if not mark.config[key] then
					config[key] = nil
				end
			end
		end

		if rawget(lib, 'OpenElement') ~= mark.open then
			local open = rawget(lib, 'OpenElement')

			if type(open) == 'table'
				and type(rawget(open, 'SetVisible')) == 'function' then

				pcall(open.SetVisible, false)
			end

			lib.OpenElement = mark.open
		end
	end

	api.backend = 'universal'
	api.ui = state
	api.native_lib = lib
	api.native_panel = panel
	api.native_toggles = native
	api.lib = facade
	api.win = win
	api.gui = screen
	api.tab = nil
	api.tabs = tabmap

	local family = type(api.game) == 'table' and rawget(api.game, 'family')

	if type(family) == 'table' and rawget(family, 'native') == true then
		api.tab = win:AddTab({
			Name = 'FiveroseTweaker'
		})
	end
	api.toggles = toggles
	api.options = options
	api.owned = {}

	function api:own(id)
		self.owned[id] = true
		return id
	end

	function api:disown(id)
		self.owned[id] = nil

		if self.nokey then
			self.nokey[id] = nil
		end
	end

	function api:notify(title, text, time)
		return facade:Notify({
			Title = title,
			Description = text,
			Time = time
		})
	end

	local con

	if alive(screen) then
		con = screen.AncestryChanged:Connect(function(_, parent)
			if parent == nil and api.state ~= 'unloaded' then
				api:unload()
			end
		end)

		api:clean(con)
	end

	api:clean(function()
		local list = {}

		for _, item in pairs(options) do
			list[#list + 1] = item
		end

		for _, item in pairs(toggles) do
			list[#list + 1] = item
		end

		for index = #list, 1, -1 do
			local item = list[index]

			if type(item) == 'table'
				and type(rawget(item, 'Destroy')) == 'function' then

				pcall(item.Destroy, item)
			end
		end

		for index = #state.created, 1, -1 do
			local item = state.created[index]

			if type(item) == 'table'
				and type(rawget(item, 'Destroy')) == 'function' then

				pcall(item.Destroy, item)
			end

			state.created[index] = nil
		end
	end)

	return api
end
