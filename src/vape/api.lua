return function(api, entry)
	local tweenservice = game:GetService('TweenService')
	local textservice = game:GetService('TextService')
	local mods = {}
	local modlist = {}
	local count = {}
	local cats = {}
	local owned = {}
	local stack = {}
	local dead = false
	local prior = {}
	local bridge
	local priorvape = shared.vape
	local uimark = api.ui and api.ui.mark and api.ui:mark()
	local overlayscreen = Instance.new('ScreenGui')
	local overlay = Instance.new('Frame')

	for id in pairs(api.owned or {}) do
		prior[id] = true
	end

	overlayscreen.Name = 'FiveroseTweakerOverlay'
	overlayscreen.ResetOnSpawn = false
	overlayscreen.IgnoreGuiInset = true
	overlayscreen.DisplayOrder = 999999
	overlayscreen.ZIndexBehavior = Enum.ZIndexBehavior.Global
	overlayscreen.Enabled = true

	local guiparent = game:GetService('CoreGui')

	if type(gethui) == 'function' then
		local ok, result = pcall(gethui)

		if ok and typeof(result) == 'Instance' then
			guiparent = result
		end
	elseif typeof(api.gui) == 'Instance' and api.gui.Parent then
		guiparent = api.gui.Parent
	end

	if type(protectgui) == 'function' then
		pcall(protectgui, overlayscreen)
	elseif syn and type(syn.protect_gui) == 'function' then
		pcall(syn.protect_gui, overlayscreen)
	end

	overlayscreen.Parent = guiparent

	overlay.Name = 'Overlay'
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Active = false
	overlay.Parent = overlayscreen

	local function slug(value)
		local name = tostring(value or ''):lower()
		name = name:gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
		return name ~= '' and name or 'item'
	end

	local function newid(...)
		local list = {...}
		local parts = {'vape'}

		for _, value in ipairs(list) do
			parts[#parts + 1] = slug(value)
		end

		local base = table.concat(parts, '_')
		local num = count[base] or 0
		local id = base

		repeat
			num = num + 1
			id = num == 1 and base or base..'_'..num
		until api.toggles[id] == nil and api.options[id] == nil and not owned[id]

		count[base] = num
		owned[id] = true
		api:own(id)
		return id
	end

	local function drop(obj)
		if obj == nil then
			return
		end

		if type(obj) == 'function' then
			return obj()
		end

		if typeof(obj) == 'thread' and type(task.cancel) == 'function' then
			return task.cancel(obj)
		end

		for _, name in ipairs({'Disconnect', 'Destroy', 'Remove', 'Cancel'}) do
			local ok, func = pcall(function()
				return obj[name]
			end)

			if ok and type(func) == 'function' then
				return func(obj)
			end
		end
	end

	local function safe(name, func, ...)
		if type(func) ~= 'function' then
			return true
		end

		local args = table.pack(...)
		local ok, err = xpcall(function()
			func(table.unpack(args, 1, args.n))
		end, function(value)
			if debug and type(debug.traceback) == 'function' then
				return debug.traceback(tostring(value), 2)
			end

			return tostring(value)
		end)

		if not ok then
			warn('[fiverosetweaker/vape] '..tostring(name)..': '..tostring(err))
			api:notify(tostring(name), 'Module error; check console', 5)
		end

		return ok
	end

	local function setvisible(item, value)
		if type(item) ~= 'table' then
			return
		end

		local ok, func = pcall(function()
			return item.SetVisible
		end)

		if ok and type(func) == 'function' then
			pcall(func, item, value)
		end
	end

	local function proxy(items, value)
		if type(items) ~= 'table' then
			items = {items}
		elseif type(rawget(items, 'SetVisible')) == 'function'
			or rawget(items, 'Type') ~= nil
			or rawget(items, 'Container') ~= nil then

			items = {items}
		end

		local state = {
			visible = value ~= false,
			Bind = {Visible = false},
			Position = UDim2.new(),
			Size = UDim2.new(),
			AbsolutePosition = Vector2.zero,
			AbsoluteSize = Vector2.zero
		}

		return setmetatable({}, {
			__index = function(_, key)
				if key == 'Visible' then
					return state.visible
				end

				return state[key]
			end,
			__newindex = function(_, key, val)
				if key == 'Visible' then
					state.visible = val == true

					for _, item in ipairs(items) do
						setvisible(item, state.visible)
					end

					return
				end

				state[key] = val
			end
		})
	end

	local function clean(list)
		for index = #list, 1, -1 do
			pcall(drop, list[index])
			list[index] = nil
		end
	end

	local function hold(obj)
		if obj == nil then
			return obj
		end

		if dead then
			pcall(drop, obj)
			return obj
		end

		stack[#stack + 1] = obj
		return obj
	end

	local function rounding(decimal)
		decimal = tonumber(decimal) or 1

		if decimal <= 1 then
			return 0
		end

		return math.max(0, math.floor(math.log10(decimal) + 0.5))
	end

	local function suffix(value, default)
		if type(value) == 'string' then
			return value
		end

		if type(value) == 'function' then
			local ok, result = pcall(value, default)
			return ok and tostring(result) or ''
		end

		return ''
	end

	local function addlabel(box, text)
		local ok, label = pcall(box.AddLabel, box, text)
		return ok and label or nil
	end

	local function visible(obj, value)
		if obj then
			obj.Object.Visible = value == nil or value == true
		end

		return obj
	end

	local function bindable()
		local event = Instance.new('BindableEvent')
		hold(event)
		return event
	end

	local names = {'Combat', 'Blatant', 'Utility', 'World', 'Render', 'Legit', 'Inventory', 'Minigames'}
	local icons = {
		Combat = 'swords',
		Blatant = 'flame',
		Utility = 'wrench',
		World = 'globe',
		Render = 'eye',
		Legit = 'shield',
		Inventory = 'backpack',
		Minigames = 'gamepad-2'
	}
	local hidden = {}
	local paused = {}
	local replacements = {}
	local keep = {
		info = true,
		settings = true,
		['ui settings'] = true
	}

	local function tabname(key, tab)
		local name = tostring(key):lower()

		if name ~= '' then
			return name
		end

		return type(tab) == 'table'
			and tostring(rawget(tab, 'Name') or ''):lower()
			or ''
	end

	local function intab(obj, tab)
		if typeof(obj) ~= 'Instance' or type(tab) ~= 'table' then
			return false
		end

		for _, side in ipairs(rawget(tab, 'Sides') or {}) do
			if typeof(side) == 'Instance'
				and (obj == side or obj:IsDescendantOf(side)) then

				return true
			end
		end

		return false
	end

	local function pause(tab)
		for id, toggle in pairs(api.toggles) do
			local container = type(toggle) == 'table' and rawget(toggle, 'Container')

			if rawget(toggle, 'Value') == true and intab(container, tab) then
				paused[#paused + 1] = {
					id = id,
					toggle = toggle
				}

				local set = rawget(toggle, 'SetValue')

				if type(set) == 'function' then
					pcall(set, toggle, false)
				end
			end
		end

		if api.backend == 'universal' then
			for _, toggle in ipairs(api.native_toggles or {}) do
				local items = type(toggle) == 'table' and rawget(toggle, 'Items')
				local container = type(items) == 'table' and rawget(items, 'Toggle')

				if type(rawget(toggle, 'Enabled')) == 'boolean'
					and rawget(toggle, 'Enabled') == true
					and type(rawget(toggle, 'Set')) == 'function'
					and intab(container, tab) then

					paused[#paused + 1] = {
						toggle = toggle,
						native = true
					}

					toggle.Enabled = false
					pcall(toggle.Set, false)
				end
			end
		end
	end

	local function hidetab(key, tab)
		if type(tab) ~= 'table' then
			return
		end

		pause(tab)

		if rawget(api.lib, 'ActiveTab') == tab then
			local hide = rawget(tab, 'Hide')

			if type(hide) == 'function' then
				pcall(hide, tab)
			end

			if rawget(api.lib, 'ActiveTab') == tab then
				api.lib.ActiveTab = nil
			end
		end

		local visible = rawget(tab, 'SetVisible')
		local shown = rawget(tab, 'Visible') ~= false

		if type(visible) == 'function' then
			pcall(visible, tab, false)
		end

		hidden[#hidden + 1] = {
			key = key,
			tab = tab,
			visible = shown
		}

		if api.tabs[key] == tab then
			api.tabs[key] = nil
		end
	end

	local function showkept()
		if rawget(api.lib, 'ActiveTab') ~= nil then
			return
		end

		for _, wanted in ipairs({'ui settings', 'settings', 'info', 'fiverosetweaker'}) do
			for key, tab in pairs(api.tabs) do
				if tabname(key, tab) == wanted then
					local show = rawget(tab, 'Show')

					if type(show) == 'function' then
						pcall(show, tab)
					end

					return
				end
			end
		end
	end

	local function hidefeatures()
		local list = {}

		for key, tab in pairs(api.tabs) do
			list[#list + 1] = {key = key, tab = tab}
		end

		for _, item in ipairs(list) do
			if not keep[tabname(item.key, item.tab)] then
				hidetab(item.key, item.tab)
			end
		end

		showkept()
	end

	local function maketab(name)
		if replacements[name] then
			return replacements[name]
		end

		local tab = api.win:AddTab({
			Name = name,
			Icon = icons[name]
		})

		replacements[name] = tab
		return tab
	end

	local function restoretabs()
		for _, name in ipairs(names) do
			local tab = replacements[name]

			if tab then
				if type(api.remove_tab) == 'function' then
					pcall(api.remove_tab, api, tab)
				elseif type(rawget(tab, 'Destroy')) == 'function' then
					pcall(tab.Destroy, tab)
				end
			end

			replacements[name] = nil
		end

		for index = #hidden, 1, -1 do
			local data = hidden[index]

			if type(data.tab) == 'table' then
				api.tabs[data.key] = data.tab

				local visible = rawget(data.tab, 'SetVisible')

				if type(visible) == 'function' then
					pcall(visible, data.tab, data.visible)
				end
			end

			hidden[index] = nil
		end

		for index = #paused, 1, -1 do
			local data = paused[index]
			local toggle = data.native and data.toggle or api.toggles[data.id]

			if data.native then
				if type(toggle) == 'table'
					and type(rawget(toggle, 'Set')) == 'function'
					and rawget(toggle, 'Enabled') ~= true then

					toggle.Enabled = true
					pcall(toggle.Set, true)
				end
			elseif toggle == data.toggle
				and rawget(toggle, 'Destroyed') ~= true
				and rawget(toggle, 'Value') ~= true then

				local set = rawget(toggle, 'SetValue')

				if type(set) == 'function' then
					pcall(set, toggle, true)
				end
			end

			paused[index] = nil
		end

		showkept()
	end

	bridge = {
		overlay = overlay,
		overlayscreen = overlayscreen,
		owned = owned,
		tabs = replacements
	}

	function bridge:destroy()
		if dead then
			return false
		end

		dead = true
		local current = self.vape or api.vape
		local libs = self.libs or api.vapelibs

		if current then
			current.Loaded = nil
		end

		for index = #modlist, 1, -1 do
			local item = modlist[index]

			if type(item) == 'table' and type(rawget(item, 'Destroy')) == 'function' then
				pcall(item.Destroy, item)
			end

			modlist[index] = nil
		end

		clean(stack)

		if libs and type(libs.entity) == 'table' and type(rawget(libs.entity, 'kill')) == 'function' then
			pcall(libs.entity.kill)
		end

		self.libs = nil
		restoretabs()

		if uimark and api.ui and type(api.ui.rollback) == 'function' then
			pcall(api.ui.rollback, api.ui, uimark)
			uimark = nil
		end

		if overlayscreen then
			pcall(overlayscreen.Destroy, overlayscreen)
			overlayscreen = nil
			overlay = nil
		elseif overlay then
			pcall(overlay.Destroy, overlay)
			overlay = nil
		end

		for id in pairs(api.owned or {}) do
			if not prior[id] then
				api:disown(id)
			end
		end

		if current and shared.vape == current then
			shared.vape = priorvape
		end

		if current and api.vape == current then
			api.vape = nil
			api.vapelibs = nil
		end

		if api.vape_bridge == self then
			api.vape_bridge = nil
		end

		return true
	end

	api.vape_bridge = bridge
	api:clean(function()
		bridge:destroy()
	end)

	hidefeatures()

	for _, name in ipairs(names) do
		local category = {
			Name = name,
			Options = {},
			Modules = {},
			List = {},
			ListEnabled = {},
			Object = proxy(nil, true),
			Type = 'Category',
			_count = 0
		}

		function category:box(title)
			if dead then
				return
			end

			local tab = maketab(self.Name)
			self._count = self._count + 1

			if self._count % 2 == 1 then
				return tab:AddLeftGroupbox(title)
			end

			return tab:AddRightGroupbox(title)
		end

		cats[name] = category
	end

	local function fake(value)
		local item = {
			Enabled = value == true,
			Value = value,
			Object = proxy(nil, true)
		}

		function item:Toggle()
			self.Enabled = not self.Enabled
			self.Value = self.Enabled
		end

		function item:SetValue(new)
			self.Value = new

			if type(new) == 'boolean' then
				self.Enabled = new
			end
		end

		return item
	end

	local main = {
		Name = 'Main',
		Options = {
			['Use team color'] = fake(true),
			['Teams by server'] = fake(false),
			['GUI bind indicator'] = fake(false)
		},
		List = {},
		ListEnabled = {},
		Type = 'Category'
	}
	local friends = {
		Name = 'Friends',
		Options = {
			['Use friends'] = fake(false),
			['Recolor visuals'] = fake(true),
			['Friends color'] = {
				Hue = 0.44,
				Sat = 1,
				Value = 1,
				Opacity = 1,
				Object = proxy(nil, true)
			}
		},
		List = {},
		ListEnabled = {},
		ColorUpdate = bindable(),
		Type = 'Category'
	}
	local targets = {
		Name = 'Targets',
		Options = {},
		List = {},
		ListEnabled = {},
		Type = 'Category'
	}

	local friendupdate = bindable()
	local targetupdate = bindable()

	main.Update = {Event = bindable().Event}
	friends.Update = {Event = friendupdate.Event}
	targets.Update = {Event = targetupdate.Event}

	function friends.Update:Fire(...)
		friendupdate:Fire(...)
	end

	function targets.Update:Fire(...)
		targetupdate:Fire(...)
	end

	local vape = {
		Categories = cats,
		Modules = mods,
		Libraries = {},
		HeldKeybinds = {},
		Keybind = {'RightShift'},
		Loaded = true,
		Place = tonumber(entry and entry.alias) or tonumber(entry and entry.id) or game.PlaceId,
		Profile = api.profile and api.profile.name or 'default',
		Profiles = {},
		RainbowSpeed = {Value = 1},
		RainbowUpdateSpeed = {Value = 60},
		RainbowTable = {},
		ThreadFix = type(setthreadidentity) == 'function',
		ToggleNotifications = fake(false),
		gui = overlay,
		Version = 'Fiverose'
	}

	bridge.vape = vape

	cats.Main = main
	cats.Friends = friends
	cats.Targets = targets
	vape.Legit = cats.Legit
	vape.Legit.Modules = vape.Legit.Modules or {}

	local color = {}

	function color.Light(value, amount)
		local h, s, v = value:ToHSV()
		return Color3.fromHSV(h, s, math.clamp(v + (tonumber(amount) or 0), 0, 1))
	end

	function color.Dark(value, amount)
		local h, s, v = value:ToHSV()
		return Color3.fromHSV(h, s, math.clamp(v - (tonumber(amount) or 0), 0, 1))
	end

	local tweens = {tweens = {}, tweenstwo = {}}

	function tweens:Cancel(obj)
		local current = self.tweens[obj] or self.tweenstwo[obj]

		if current then
			pcall(current.Cancel, current)
			self.tweens[obj] = nil
			self.tweenstwo[obj] = nil
		end
	end

	function tweens:Tween(obj, info, goal, store)
		store = store or self.tweens

		if store[obj] then
			pcall(store[obj].Cancel, store[obj])
		end

		local ok, tween = pcall(tweenservice.Create, tweenservice, obj, info, goal)

		if not ok then
			for key, value in pairs(goal) do
				pcall(function()
					obj[key] = value
				end)
			end

			return
		end

		store[obj] = tween
		tween:Play()
		return tween
	end

	local sizeparam = Instance.new('GetTextBoundsParams')
	sizeparam.Width = math.huge
	hold(sizeparam)

	local function getsize(text, size, font)
		sizeparam.Text = tostring(text or '')
		sizeparam.Size = tonumber(size) or 14

		if typeof(font) == 'Font' then
			sizeparam.Font = font
		end

		local ok, result = pcall(textservice.GetTextBoundsAsync, textservice, sizeparam)
		return ok and result or Vector2.new(#sizeparam.Text * sizeparam.Size * 0.5, sizeparam.Size)
	end

	local assets = {
		['newvape/assets/new/arrowmodule.png'] = 'rbxassetid://14473354880',
		['newvape/assets/new/blockedicon.png'] = 'rbxassetid://14385669108',
		['newvape/assets/new/blockedtab.png'] = 'rbxassetid://14385672881',
		['newvape/assets/new/blur.png'] = 'rbxassetid://14898786664',
		['newvape/assets/new/radaricon.png'] = 'rbxassetid://14368343291',
		['newvape/assets/new/textguiicon.png'] = 'rbxassetid://14368355456',
		['newvape/assets/new/vape.png'] = 'rbxassetid://14373395239'
	}

	local function asset(path)
		return assets[path] or ''
	end

	vape.Libraries.color = color
	vape.Libraries.tween = tweens
	vape.Libraries.getfontsize = getsize
	vape.Libraries.getcustomasset = asset
	vape.Libraries.uipallet = {
		Main = Color3.fromRGB(26, 25, 26),
		Text = Color3.fromRGB(200, 200, 200),
		Font = Font.fromEnum(Enum.Font.Arial),
		FontSemiBold = Font.fromEnum(Enum.Font.Arial),
		Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear)
	}
	vape.Libraries.targetinfo = {Targets = {}}

	local function optionbase(module, settings, item, id)
		local obj = {
			Type = item and rawget(item, 'Type') or 'Option',
			Object = proxy(item, settings.Visible),
			Item = item,
			Id = id
		}

		module.Options[settings.Name or id] = obj
		if item ~= nil then
			module._items[#module._items + 1] = item
		end

		return obj
	end

	local function makeoption(module, method, settings)
		settings = settings or {}
		local name = settings.Name or method
		local id = newid(module.Category, module.Name, name)
		local box = module.Box

		if method == 'Toggle' then
			box:AddToggle(id, {
				Text = name,
				Default = settings.Default == true,
				Tooltip = settings.Tooltip,
				Visible = settings.Visible == nil or settings.Visible
			})

			local item = api.toggles[id]
			local obj = optionbase(module, settings, item, id)
			obj.Type = 'Toggle'
			obj.Enabled = item and item.Value == true or settings.Default == true
			api.nokey = api.nokey or {}
			api.nokey[id] = true

			function obj:Toggle()
				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(not item.Value)
				else
					self.Enabled = not self.Enabled
					safe(module.Name..'/'..name, settings.Function, self.Enabled)
				end
			end

			function obj:SetValue(value)
				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value == true)
				end
			end

			if item then
				item:OnChanged(function()
					obj.Enabled = item.Value == true
					safe(module.Name..'/'..name, settings.Function, obj.Enabled)
				end)
			end

			if obj.Enabled then
				hold(task.defer(safe, module.Name..'/'..name, settings.Function, true))
			end

			return obj
		end

		if method == 'Slider' then
			local default = tonumber(settings.Default) or tonumber(settings.Min) or 0
			box:AddSlider(id, {
				Text = name,
				Default = default,
				Min = tonumber(settings.Min) or 0,
				Max = tonumber(settings.Max) or 100,
				Rounding = rounding(settings.Decimal),
				Suffix = suffix(settings.Suffix, default),
				Tooltip = settings.Tooltip,
				Visible = settings.Visible == nil or settings.Visible
			})

			local item = api.options[id]
			local obj = optionbase(module, settings, item, id)
			obj.Type = 'Slider'
			obj.Value = item and item.Value or default
			obj.Max = tonumber(settings.Max) or 100

			function obj:SetValue(value, _, final)
				value = tonumber(value)

				if value and item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value)
				elseif value then
					self.Value = value
					safe(module.Name..'/'..name, settings.Function, value, final)
				end
			end

			if item then
				item:OnChanged(function()
					obj.Value = item.Value
					safe(module.Name..'/'..name, settings.Function, obj.Value, true)
				end)
			end

			return obj
		end

		if method == 'Dropdown' then
			local list = type(settings.List) == 'table' and table.clone(settings.List) or {}
			local default = settings.Default or list[1]
			box:AddDropdown(id, {
				Text = name,
				Values = list,
				Default = default,
				Tooltip = settings.Tooltip,
				Visible = settings.Visible == nil or settings.Visible
			})

			local item = api.options[id]
			local obj = optionbase(module, settings, item, id)
			obj.Type = 'Dropdown'
			obj.List = list
			obj.Value = item and item.Value or default or 'None'

			function obj:SetValue(value)
				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value)
				else
					self.Value = value
					safe(module.Name..'/'..name, settings.Function, value)
				end
			end

			function obj:ChangeValue()
				if item and type(rawget(item, 'SetValues')) == 'function' then
					item:SetValues(self.List)
				end
			end

			if item then
				item:OnChanged(function()
					obj.Value = item.Value
					safe(module.Name..'/'..name, settings.Function, obj.Value)
				end)
			end

			if obj.Value ~= nil then
				hold(task.defer(safe, module.Name..'/'..name, settings.Function, obj.Value))
			end

			return obj
		end

		if method == 'TextBox' then
			local default = tostring(settings.Default or '')
			box:AddInput(id, {
				Text = name,
				Default = default,
				Placeholder = settings.Placeholder or '',
				Finished = false,
				Visible = settings.Visible == nil or settings.Visible
			})

			local item = api.options[id]
			local obj = optionbase(module, settings, item, id)
			obj.Type = 'TextBox'
			obj.Value = item and item.Value or default

			function obj:SetValue(value, enter)
				value = tostring(value or '')

				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value)
				else
					self.Value = value
					safe(module.Name..'/'..name, settings.Function, enter)
				end
			end

			if item then
				item:OnChanged(function()
					obj.Value = tostring(item.Value or '')
					safe(module.Name..'/'..name, settings.Function, false)
				end)
			end

			return obj
		end

		if method == 'ColorSlider' then
			local colorvalue

			if typeof(settings.Color) == 'Color3' then
				colorvalue = settings.Color
			elseif typeof(settings.DefaultValue) == 'Color3' then
				colorvalue = settings.DefaultValue
			else
				colorvalue = Color3.fromHSV(
					tonumber(settings.DefaultHue) or 0.44,
					tonumber(settings.DefaultSat) or 1,
					type(settings.DefaultValue) == 'number' and settings.DefaultValue or 1
				)
			end

			local label = addlabel(box, name)
			local item

			if label and type(rawget(label, 'AddColorPicker')) == 'function' then
				local info = {
					Default = colorvalue,
					Title = name
				}

				if settings.DefaultOpacity ~= nil then
					info.Transparency = 1 - settings.DefaultOpacity
				end

				label:AddColorPicker(id, info)
				item = api.options[id]
			end

			local obj = optionbase(module, settings, item or label, id)
			obj.Object = proxy({label, item}, settings.Visible)
			obj.Type = 'ColorSlider'
			obj.Color = colorvalue
			obj.Hue, obj.Sat, obj.Value = colorvalue:ToHSV()
			obj.Opacity = tonumber(settings.DefaultOpacity) or 1

			function obj:SetValue(hue, sat, value, opacity)
				if typeof(hue) == 'Color3' then
					self.Color = hue
					self.Hue, self.Sat, self.Value = hue:ToHSV()
				else
					self.Hue = tonumber(hue) or self.Hue
					self.Sat = tonumber(sat) or self.Sat
					self.Value = tonumber(value) or self.Value
					self.Color = Color3.fromHSV(self.Hue, self.Sat, self.Value)
				end

				self.Opacity = tonumber(opacity) or self.Opacity

				if item and type(rawget(item, 'SetValueRGB')) == 'function' then
					item:SetValueRGB(self.Color, 1 - self.Opacity)
				else
					safe(module.Name..'/'..name, settings.Function, self.Hue, self.Sat, self.Value, self.Opacity)
				end
			end

			if item then
				item:OnChanged(function()
					obj.Color = item.Value
					obj.Hue, obj.Sat, obj.Value = item.Value:ToHSV()
					obj.Opacity = 1 - (tonumber(item.Transparency) or 0)
					safe(module.Name..'/'..name, settings.Function, obj.Hue, obj.Sat, obj.Value, obj.Opacity)
				end)
			end

			hold(task.defer(safe, module.Name..'/'..name, settings.Function, obj.Hue, obj.Sat, obj.Value, obj.Opacity))
			return obj
		end

		if method == 'TextList' then
			local defaults = type(settings.Default) == 'table' and table.clone(settings.Default) or {}
			local default = table.concat(defaults, ', ')
			box:AddInput(id, {
				Text = name,
				Default = default,
				Placeholder = settings.Placeholder or 'comma separated',
				Finished = false,
				Visible = settings.Visible == nil or settings.Visible
			})

			local item = api.options[id]
			local obj = optionbase(module, settings, item, id)
			obj.Type = 'TextList'
			obj.List = defaults
			obj.ListEnabled = table.clone(defaults)

			local function parse(value)
				table.clear(obj.List)
				table.clear(obj.ListEnabled)

				for part in tostring(value or ''):gmatch('[^,\n]+') do
					local text = part:match('^%s*(.-)%s*$')

					if text ~= '' then
						obj.List[#obj.List + 1] = text
						obj.ListEnabled[#obj.ListEnabled + 1] = text
					end
				end

				safe(module.Name..'/'..name, settings.Function, obj.List)
			end

			function obj:ChangeValue(value)
				if value ~= nil then
					value = tostring(value)
					local index = table.find(self.List, value)

					if index then
						table.remove(self.List, index)
						local enabled = table.find(self.ListEnabled, value)

						if enabled then
							table.remove(self.ListEnabled, enabled)
						end
					else
						self.List[#self.List + 1] = value
						self.ListEnabled[#self.ListEnabled + 1] = value
					end
				end

				local text = table.concat(self.List, ', ')

				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(text)
				else
					parse(text)
				end
			end

			if item then
				item:OnChanged(function()
					parse(item.Value)
				end)
			end

			return obj
		end

		if method == 'TwoSlider' then
			local minid = id..'_min'
			local maxid = id..'_max'
			owned[minid] = true
			owned[maxid] = true
			api:own(minid)
			api:own(maxid)
			local minvalue = tonumber(settings.DefaultMin) or tonumber(settings.Min) or 0
			local maxvalue = tonumber(settings.DefaultMax) or tonumber(settings.Max) or 100

			box:AddSlider(minid, {
				Text = name..' min',
				Default = minvalue,
				Min = tonumber(settings.Min) or 0,
				Max = tonumber(settings.Max) or 100,
				Rounding = rounding(settings.Decimal),
				Visible = settings.Visible == nil or settings.Visible
			})
			box:AddSlider(maxid, {
				Text = name..' max',
				Default = maxvalue,
				Min = tonumber(settings.Min) or 0,
				Max = tonumber(settings.Max) or 100,
				Rounding = rounding(settings.Decimal),
				Visible = settings.Visible == nil or settings.Visible
			})

			local minitem = api.options[minid]
			local maxitem = api.options[maxid]
			local obj = optionbase(module, settings, minitem, id)
			module._items[#module._items + 1] = maxitem
			obj.Type = 'TwoSlider'
			obj.Object = proxy({minitem, maxitem}, settings.Visible)
			obj.ValueMin = minitem and minitem.Value or minvalue
			obj.ValueMax = maxitem and maxitem.Value or maxvalue

			function obj:GetRandomValue()
				return Random.new():NextNumber(self.ValueMin, self.ValueMax)
			end

			function obj:SetValue(maximum, value)
				local item = maximum and maxitem or minitem

				if item and type(rawget(item, 'SetValue')) == 'function' then
					item:SetValue(value)
				end
			end

			if minitem then
				minitem:OnChanged(function()
					obj.ValueMin = math.min(minitem.Value, obj.ValueMax)
				end)
			end

			if maxitem then
				maxitem:OnChanged(function()
					obj.ValueMax = math.max(maxitem.Value, obj.ValueMin)
				end)
			end

			return obj
		end

		if method == 'Font' then
			local list = {}
			local default = tostring(settings.Default or '')
			local obj

			for _, font in ipairs(Enum.Font:GetEnumItems()) do
				if font.Name ~= settings.Blacklist then
					list[#list + 1] = font.Name
				end
			end

			if not table.find(list, default) then
				default = settings.Blacklist == 'Arial' and 'Gotham' or 'Arial'
			end

			local drop = makeoption(module, 'Dropdown', {
				Name = name,
				List = list,
				Default = default,
				Visible = settings.Visible,
				Function = function(value)
					local font = Enum.Font[value]

					if font then
						local face = Font.fromEnum(font)

						if obj then
							obj.Value = face
						end

						settings.Function = settings.Function or function() end
						safe(module.Name..'/'..name, settings.Function, face)
					end
				end
			})
			obj = drop
			obj.Type = 'Font'
			obj.Value = Font.fromEnum(Enum.Font[drop.Value] or Enum.Font.Arial)

			local oldset = obj.SetValue
			function obj:SetValue(value)
				if typeof(value) == 'Font' then
					self.Value = value
					safe(module.Name..'/'..name, settings.Function, value)
					return
				end

				oldset(self, value)
				self.Value = Font.fromEnum(Enum.Font[value] or Enum.Font.Arial)
			end

			return obj
		end

		if method == 'Targets' then
			local obj = {
				Type = 'Targets',
				Object = proxy(nil, settings.Visible)
			}

			local function target(part, default)
				local option = makeoption(module, 'Toggle', {
					Name = (name ~= 'Targets' and name..' ' or '')..part,
					Default = default == true,
					Visible = settings.Visible,
					Function = function()
						safe(module.Name..'/'..name, settings.Function)
					end
				})
				return option
			end

			obj.Players = target('players', settings.Players)
			obj.NPCs = target('npcs', settings.NPCs)
			obj.Invisible = target('ignore invisible', settings.Invisible)
			obj.Walls = target('ignore walls', settings.Walls)
			obj.Object = proxy({obj.Players.Item, obj.NPCs.Item, obj.Invisible.Item, obj.Walls.Item}, settings.Visible)
			module.Options[name] = obj
			return obj
		end

		if method == 'Button' then
			local button
			local ok, result = pcall(box.AddButton, box, {
				Text = name,
				Func = function()
					safe(module.Name..'/'..name, settings.Function)
				end
			})

			if ok then
				button = result
			end

			local obj = optionbase(module, settings, button, id)
			obj.Type = 'Button'
			return obj
		end

		return optionbase(module, settings, addlabel(box, name), id)
	end

	local function module(category, settings, isoverlay)
		settings = settings or {}
		local name = tostring(settings.Name or 'Module')

		if mods[name] then
			vape:Remove(name)
		end

		local box = category:box(name)

		if not box then
			return
		end
		local id = newid(category.Name, name)
		box:AddToggle(id, {
			Text = 'Enabled',
			Default = false,
			Tooltip = settings.Tooltip,
			Visible = settings.Visible == nil or settings.Visible
		})

		local toggle = api.toggles[id]
		local holder = Instance.new('Frame')
		holder.Name = slug(name)
		holder.Size = settings.Size or UDim2.fromOffset(220, 220)
		holder.Position = settings.Position or UDim2.fromOffset(20, 80)
		holder.BackgroundTransparency = 1
		holder.Visible = false
		holder.Parent = overlay

		local obj = {
			Name = name,
			Category = category.Name,
			Enabled = false,
			Options = {},
			Connections = {},
			Bind = {},
			Object = proxy(box, true),
			Children = holder,
			Button = nil,
			ToggleObject = toggle,
			Box = box,
			Id = id,
			_items = {toggle, holder},
			_overlay = isoverlay == true,
			_settings = settings
		}
		obj.Button = obj

		function obj:Clean(value)
			if value ~= nil then
				self.Connections[#self.Connections + 1] = value
			end

			return value
		end

		function obj:Drop()
			clean(self.Connections)
		end

		function obj:SetBind(value)
			self.Bind = type(value) == 'table' and table.clone(value) or {}
		end

		function obj:GetExtraText()
			if type(settings.ExtraText) ~= 'function' then
				return ''
			end

			local ok, value = pcall(settings.ExtraText)
			return ok and tostring(value or '') or ''
		end

		function obj:Toggle()
			if toggle and type(rawget(toggle, 'SetValue')) == 'function' then
				toggle:SetValue(not toggle.Value)
			end
		end

		function obj:Destroy()
			if self._dead then
				return
			end

			self._dead = true

			if self.Enabled then
				self.Enabled = false
				holder.Visible = false
				safe(name, settings.Function, false)
			end

			if toggle and toggle.Value == true and type(rawget(toggle, 'SetValue')) == 'function' then
				pcall(toggle.SetValue, toggle, false)
			end

			self:Drop()

			for index = #self._items, 1, -1 do
				local item = self._items[index]

				if type(item) == 'table' and type(rawget(item, 'Destroy')) == 'function' then
					pcall(item.Destroy, item)
				elseif typeof(item) == 'Instance' then
					pcall(item.Destroy, item)
				end
			end

			if type(box) == 'table' and type(rawget(box, 'Destroy')) == 'function' then
				pcall(box.Destroy, box)
			end

			mods[self.Name] = nil
			category.Modules[self.Name] = nil

			if vape.Legit.Modules[self.Name] == self then
				vape.Legit.Modules[self.Name] = nil
			end
		end

		for _, method in ipairs({'Toggle', 'Slider', 'Dropdown', 'ColorSlider', 'Targets', 'TextBox', 'TextList', 'TwoSlider', 'Font', 'Button'}) do
			obj['Create'..method] = function(self, values)
				return makeoption(self, method, values)
			end
		end

		local function changed()
			local value = toggle and toggle.Value == true or false
			obj.Enabled = value
			holder.Visible = value

			if not value then
				obj:Drop()
			end

			if not obj._dead and not safe(name, settings.Function, value) and value then
				obj.Enabled = false
				holder.Visible = false
				obj:Drop()

				if toggle and toggle.Value == true and type(rawget(toggle, 'SetValue')) == 'function' then
					pcall(toggle.SetValue, toggle, false)
				end
			end
		end

		if toggle then
			toggle:OnChanged(changed)
		end

		mods[name] = obj
		modlist[#modlist + 1] = obj
		category.Modules[name] = obj

		if category == vape.Legit then
			vape.Legit.Modules[name] = obj
		end

		hold(function()
			if mods[name] == obj then
				obj:Destroy()
			end
		end)

		return obj
	end

	for _, category in pairs(cats) do
		if type(category) == 'table' and type(rawget(category, 'box')) == 'function' then
			function category:CreateModule(settings)
				return module(self, settings, false)
			end
		end
	end

	function vape:CreateOverlay(settings)
		return module(cats.Render, settings, true)
	end

	function vape:Clean(value)
		return hold(value)
	end

	function vape:CreateNotification(title, text, time)
		api:notify(title, text, time)
	end

	function vape:Remove(name)
		local item = self.Modules[name] or self.Legit.Modules[name]

		if item and type(item.Destroy) == 'function' then
			item:Destroy()
		end
	end

	function vape:Save()
		if type(api.save) == 'function' then
			return api:save()
		end
	end

	function vape:Load(_, profile)
		if profile ~= nil and type(api.setprofile) == 'function' then
			local ok, result = pcall(api.setprofile, api, profile)

			if not ok or not result then
				return false, ok and 'profile was rejected' or result
			end

			self.Profile = api.profile and api.profile.name or tostring(profile)
		end

		self.Loaded = true
		return true
	end

	function vape:Uninject()
		if type(api.disable_vape) == 'function' then
			return api:disable_vape()
		end
	end

	function vape:UpdateTextGUI() end
	function vape:BlurCheck() end
	function vape:Color(value)
		return value
	end

	local function fresh(path)
		local source = api:source(path)
		local chunk, err = loadstring(source, '@fiverosetweaker/'..path)

		if not chunk then
			error(err, 2)
		end

		local ok, result = xpcall(chunk, function(value)
			if debug and type(debug.traceback) == 'function' then
				return debug.traceback(tostring(value), 2)
			end

			return tostring(value)
		end)

		if not ok then
			error(path..': '..tostring(result), 2)
		end

		return result
	end

	api.vape = vape
	api.vapelibs = {}
	bridge.libs = api.vapelibs
	api.vapelibs.entity = fresh('src/vape/libraries/entity.lua')
	api.vapelibs.prediction = fresh('src/vape/libraries/prediction.lua')
	api.vapelibs.hash = fresh('src/vape/libraries/hash.lua')
	api.vapelibs.vm = fresh('src/vape/libraries/vm.lua')
	api.vapelibs.drawing = fresh('src/vape/libraries/drawing.lua')

	vape.Libraries.entity = api.vapelibs.entity
	vape.Libraries.prediction = api.vapelibs.prediction
	vape.Libraries.hash = api.vapelibs.hash
	shared.vape = vape

	return bridge
end
