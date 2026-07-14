return function(api)
	local tweenservice = game:GetService('TweenService')
	local lighting = game:GetService('Lighting')
	local tabs = api.tabs
	local toggles = api.toggles
	local id = 'smooth_ui_animations'
	local enabled = false
	local serial = 0
	local cons = {}
	local made = {}
	local tweens = setmetatable({}, {__mode = 'k'})
	local bound = setmetatable({}, {__mode = 'k'})
	local scales = setmetatable({}, {__mode = 'k'})
	local blur
	local main
	local lastopen

	local function alive(obj)
		return typeof(obj) == 'Instance' and obj.Parent ~= nil
	end

	local function cancel(obj)
		local item = tweens[obj]

		if item then
			pcall(item.Cancel, item)
			tweens[obj] = nil
		end
	end

	local function play(obj, time, style, direction, goal)
		if not alive(obj) then
			return
		end

		cancel(obj)
		local item = tweenservice:Create(obj, TweenInfo.new(
			time,
			style or Enum.EasingStyle.Quint,
			direction or Enum.EasingDirection.Out
		), goal)
		tweens[obj] = item
		item:Play()
		return item
	end

	local function connect(signal, callback)
		local ok, con = pcall(function()
			return signal:Connect(callback)
		end)

		if ok and con then
			cons[#cons + 1] = con
			return con
		end
	end

	local function scale(root, name)
		if not alive(root) or not root:IsA('GuiObject') then
			return
		end

		local item = scales[root]

		if alive(item) then
			return item
		end

		item = Instance.new('UIScale')
		item.Name = name or 'FiveroseTweakerScale'
		item.Scale = 1
		item.Parent = root
		scales[root] = item
		made[#made + 1] = item
		return item
	end

	local function canvas(root)
		if not alive(root) then
			return
		end

		if root:IsA('CanvasGroup') then
			return root
		end

		for _, child in ipairs(root:GetChildren()) do
			if child:IsA('CanvasGroup') then
				return child
			end
		end
	end

	local function rootsof(tab)
		local result = {}
		local seen = {}

		local function add(obj)
			if alive(obj) and obj:IsA('GuiObject') and not seen[obj] then
				seen[obj] = true
				result[#result + 1] = obj
			end
		end

		add(type(tab) == 'table' and rawget(tab, 'Container'))

		local native = type(tab) == 'table' and rawget(tab, 'Native')
		local items = type(native) == 'table' and rawget(native, 'Items')
		add(type(items) == 'table' and rawget(items, 'Page'))

		if #result == 0 then
			for _, side in ipairs(type(tab) == 'table' and rawget(tab, 'Sides') or {}) do
				add(side)
			end
		end

		return result
	end

	local function animatepage(tab)
		if not enabled then
			return
		end

		for index, root in ipairs(rootsof(tab)) do
			local ticket = serial

			task.delay((index - 1) * 0.025, function()
				if not enabled or ticket ~= serial or not alive(root) or root.Visible == false then
					return
				end

				local item = scale(root, 'FiveroseTweakerPageScale')

				if item then
					item.Scale = 0.975
					play(item, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
						Scale = 1
					})
				end

				local group = canvas(root)

				if alive(group) then
					group.GroupTransparency = math.max(group.GroupTransparency, 0.28)
					play(group, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
						GroupTransparency = 0
					})
				end
			end)
		end
	end

	local function findmain()
		if alive(main) then
			return main
		end

		if api.backend == 'universal' then
			local panel = api.native_panel
			local items = type(panel) == 'table' and rawget(panel, 'Items')

			for _, name in ipairs({'Window', 'Background', 'Outline'}) do
				local item = type(items) == 'table' and rawget(items, name)

				if alive(item) and item:IsA('GuiObject') then
					main = item
					break
				end
			end
		else
			local item = type(api.lib) == 'table' and rawget(api.lib, 'WindowContainer')

			if alive(item) and item:IsA('GuiObject') then
				main = item
			end
		end

		return main
	end

	local function getblur()
		if alive(blur) then
			return blur
		end

		blur = Instance.new('BlurEffect')
		blur.Name = 'FiveroseTweakerBlur'
		blur.Size = 0
		blur.Parent = lighting
		made[#made + 1] = blur
		return blur
	end

	local function openstate()
		if api.backend == 'universal' then
			local panel = api.native_panel
			local value = type(panel) == 'table' and rawget(panel, 'Open')

			if type(value) == 'boolean' then
				return value
			end
		end

		local root = findmain()

		if alive(root) then
			return root.Visible
		end

		return alive(api.gui) and api.gui.Enabled
	end

	local function animateopen()
		if not enabled or not openstate() then
			return
		end

		local root = findmain()

		if alive(root) then
			local item = scale(root, 'FiveroseTweakerWindowScale')

			if item then
				item.Scale = 0.94
				play(item, 0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
					Scale = 1
				})
			end

			local group = canvas(root)

			if alive(group) then
				group.GroupTransparency = math.max(group.GroupTransparency, 0.34)
				play(group, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
					GroupTransparency = 0
				})
			end
		end

		local effect = getblur()
		effect.Size = math.min(effect.Size, 2)
		play(effect, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			Size = 6
		})
	end

	local function animateclose()
		if alive(blur) then
			play(blur, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				Size = 0
			})
		end
	end

	local function bindtab(tab)
		if type(tab) ~= 'table' or bound[tab] then
			return
		end

		bound[tab] = true

		for _, root in ipairs(rootsof(tab)) do
			connect(root:GetPropertyChangedSignal('Visible'), function()
				if enabled and alive(root) and root.Visible then
					task.defer(animatepage, tab)
				end
			end)
		end

		local native = rawget(tab, 'Native')
		local button = rawget(tab, 'Button')

		if not alive(button) and type(native) == 'table' then
			local items = rawget(native, 'Items')
			button = type(items) == 'table' and rawget(items, 'Outline')
		end

		if alive(button) and button:IsA('GuiButton') then
			connect(button.Activated, function()
				if enabled then
					task.defer(animatepage, tab)
				end
			end)

			local item = scale(button, 'FiveroseTweakerHoverScale')

			if item then
				connect(button.MouseEnter, function()
					if enabled then
						play(item, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
							Scale = 1.025
						})
					end
				end)

				connect(button.MouseLeave, function()
					if enabled then
						play(item, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
							Scale = 1
						})
					end
				end)
			end
		end
	end

	local function stop()
		serial = serial + 1

		for _, con in ipairs(cons) do
			pcall(con.Disconnect, con)
		end

		table.clear(cons)

		for obj, item in pairs(tweens) do
			pcall(item.Cancel, item)
			tweens[obj] = nil
		end

		for index = #made, 1, -1 do
			local item = made[index]

			if alive(item) then
				pcall(item.Destroy, item)
			end

			made[index] = nil
		end

		blur = nil
		main = nil
		lastopen = nil
		bound = setmetatable({}, {__mode = 'k'})
		scales = setmetatable({}, {__mode = 'k'})
	end

	local function start()
		stop()
		enabled = true
		serial = serial + 1
		local ticket = serial
		lastopen = openstate()

		for _, tab in pairs(tabs) do
			bindtab(tab)
		end

		task.spawn(function()
			while enabled and ticket == serial and api:isactive() do
				for _, tab in pairs(tabs) do
					bindtab(tab)
				end

				local current = openstate()

				if current ~= lastopen then
					lastopen = current

					if current then
						animateopen()
					else
						animateclose()
					end
				end

				task.wait(0.05)
			end
		end)

		if lastopen then
			task.defer(animateopen)
		end
	end

	local box = api.vape_settings_box
	local ownbox = false

	if type(box) ~= 'table' then
		local settings

		for _, wanted in ipairs({'ui settings', 'settings'}) do
			for key, tab in pairs(tabs) do
				local name = tostring(key):lower()
				local other = type(tab) == 'table'
					and tostring(rawget(tab, 'Name') or ''):lower()
					or ''

				if name == wanted or other == wanted then
					settings = tab
					break
				end
			end

			if settings then
				break
			end
		end

		if not settings then
			error('Fiverose UI Settings tab not found')
		end

		box = settings:AddRightGroupbox('Interface')
		ownbox = true
	end

	box:AddToggle(id, {
		Text = 'Smooth UI Animations',
		Default = false
	})

	local toggle = toggles[id]

	if type(toggle) ~= 'table' then
		error('Smooth UI Animations toggle was not created')
	end

	api:own(id)
	api.nokey = api.nokey or {}
	api.nokey[id] = true

	toggle:OnChanged(function()
		if toggle.Value == true then
			start()
		else
			enabled = false
			stop()
		end
	end)

	api:clean(function()
		enabled = false
		stop()
		api.nokey[id] = nil
		api:disown(id)

		if ownbox and type(box) == 'table' and type(rawget(box, 'Destroy')) == 'function' then
			pcall(box.Destroy, box)
		elseif type(toggle) == 'table' and type(rawget(toggle, 'Destroy')) == 'function' then
			pcall(toggle.Destroy, toggle)
		end
	end)

	return toggle
end
