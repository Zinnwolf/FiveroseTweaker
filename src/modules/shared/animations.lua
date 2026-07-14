return function(api)
	local tweenservice = game:GetService('TweenService')
	local lighting = game:GetService('Lighting')
	local tabs = api.tabs
	local toggles = api.toggles
	local id = 'smooth_ui_animations'
	local enabled = false
	local serial = 0
	local patches = {}
	local cons = {}
	local made = {}
	local tweens = setmetatable({}, {__mode = 'k'})
	local bound = setmetatable({}, {__mode = 'k'})
	local scales = setmetatable({}, {__mode = 'k'})
	local positions = setmetatable({}, {__mode = 'k'})
	local blur
	local main

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
		local con = signal:Connect(callback)
		cons[#cons + 1] = con
		return con
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

	local function managed(root)
		if not alive(root) or not alive(root.Parent) then
			return true
		end

		return root.Parent:FindFirstChildOfClass('UIListLayout') ~= nil
			or root.Parent:FindFirstChildOfClass('UIGridLayout') ~= nil
			or root.Parent:FindFirstChildOfClass('UIPageLayout') ~= nil
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
				if not enabled or ticket ~= serial or not alive(root) then
					return
				end

				local item = scale(root, 'FiveroseTweakerPageScale')

				if item then
					item.Scale = 0.982
					play(item, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
						Scale = 1
					})
				end

				local group = canvas(root)
				local goal = {}

				if alive(group) then
					group.GroupTransparency = math.max(group.GroupTransparency, 0.22)

					if group == root then
						goal.GroupTransparency = 0
					else
						play(group, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
							GroupTransparency = 0
						})
					end
				end

				if not managed(root) then
					local target = root.Position
					positions[root] = target
					root.Position = target + UDim2.fromOffset(9, 0)
					goal.Position = target
				end

				if next(goal) then
					play(root, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, goal)
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
		local root = findmain()

		if api.backend == 'universal' then
			local panel = api.native_panel
			local value = type(panel) == 'table' and rawget(panel, 'Open')

			if type(value) == 'boolean' then
				return value
			end
		end

		if alive(root) then
			return root.Visible
		end

		return alive(api.gui) and api.gui.Enabled
	end

	local lastopen = 0

	local function animateopen()
		if not enabled or not openstate() then
			return
		end

		local now = os.clock()

		if now - lastopen < 0.08 then
			return
		end

		lastopen = now
		local root = findmain()

		if alive(root) then
			local item = scale(root, 'FiveroseTweakerWindowScale')

			if item then
				item.Scale = 0.945
				play(item, 0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
					Scale = 1
				})
			end

			local group = canvas(root)

			if alive(group) then
				group.GroupTransparency = math.max(group.GroupTransparency, 0.32)
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

	local function changed()
		task.defer(function()
			if not enabled then
				return
			end

			if openstate() then
				animateopen()
			else
				animateclose()
			end
		end)
	end

	local function patch(obj, name, callback)
		if type(obj) ~= 'table' then
			return
		end

		local ok, old = pcall(function()
			return obj[name]
		end)

		if not ok or type(old) ~= 'function' then
			return
		end

		local original = rawget(obj, name)
		local wrapped = function(...)
			local result = table.pack(old(...))

			if enabled then
				task.defer(callback)
			end

			return table.unpack(result, 1, result.n)
		end

		obj[name] = wrapped
		patches[#patches + 1] = {
			obj = obj,
			name = name,
			original = original,
			wrapped = wrapped
		}
	end

	local function bindtab(tab)
		if type(tab) ~= 'table' or bound[tab] then
			return
		end

		bound[tab] = true
		patch(tab, 'Show', function()
			animatepage(tab)
		end)

		local native = rawget(tab, 'Native')

		if type(native) == 'table' then
			patch(native, 'OpenTab', function()
				animatepage(tab)
			end)
			patch(native, 'Show', function()
				animatepage(tab)
			end)
		end

		local button = rawget(tab, 'Button')

		if not alive(button) and type(native) == 'table' then
			local items = rawget(native, 'Items')
			button = type(items) == 'table' and rawget(items, 'Outline')
		end

		if alive(button) and button:IsA('GuiObject') then
			local item = scale(button, 'FiveroseTweakerHoverScale')

			if item then
				connect(button.MouseEnter, function()
					if enabled then
						play(item, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
							Scale = 1.035
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

	local function bindmain()
		local root = findmain()

		if alive(root) then
			connect(root:GetPropertyChangedSignal('Visible'), changed)
		end

		if alive(api.gui) and api.gui:IsA('ScreenGui') then
			connect(api.gui:GetPropertyChangedSignal('Enabled'), changed)
		end

		if api.backend == 'universal' then
			patch(api.native_panel, 'SetMenuVisible', changed)
			patch(api.native_panel, 'ToggleMenu', changed)
			patch(api.lib, 'Toggle', changed)
		else
			patch(api.lib, 'Toggle', changed)
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

		for root, target in pairs(positions) do
			if alive(root) then
				root.Position = target
			end
		end

		table.clear(positions)

		for index = #patches, 1, -1 do
			local item = patches[index]

			if type(item.obj) == 'table' and rawget(item.obj, item.name) == item.wrapped then
				item.obj[item.name] = item.original
			end

			patches[index] = nil
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
		bound = setmetatable({}, {__mode = 'k'})
		scales = setmetatable({}, {__mode = 'k'})
	end

	local function start()
		stop()
		enabled = true
		serial = serial + 1
		local ticket = serial
		bindmain()

		task.spawn(function()
			while enabled and ticket == serial and api:isactive() do
				for _, tab in pairs(tabs) do
					bindtab(tab)
				end

				task.wait(0.35)
			end
		end)

		task.defer(animateopen)
	end

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

	local box = tab:AddRightGroupbox('Interface')
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

		if type(box) == 'table' and type(rawget(box, 'Destroy')) == 'function' then
			pcall(box.Destroy, box)
		end
	end)

	return toggle
end
