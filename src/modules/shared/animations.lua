return function(api)
	local tweenservice = game:GetService('TweenService')
	local lighting = game:GetService('Lighting')
	local coregui = game:GetService('CoreGui')
	local tabs = api.tabs
	local toggles = api.toggles
	local id = 'smooth_ui_animations'
	local enabled = false
	local serial = 0
	local cons = {}
	local made = {}
	local tweens = setmetatable({}, {__mode = 'k'})
	local bound = setmetatable({}, {__mode = 'k'})
	local pulseat = setmetatable({}, {__mode = 'k'})
	local blur
	local layer
	local main
	local lastopen

	local function instance(obj)
		return typeof(obj) == 'Instance'
	end

	local function alive(obj)
		return instance(obj) and obj.Parent ~= nil
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
		local ok, item = pcall(function()
			return tweenservice:Create(obj, TweenInfo.new(
				time,
				style or Enum.EasingStyle.Quint,
				direction or Enum.EasingDirection.Out
			), goal)
		end)

		if not ok or not item then
			return
		end

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

	local function removelegacy()
		local gui = api.gui

		if instance(gui) then
			for _, obj in ipairs(gui:GetDescendants()) do
				if obj:IsA('UIScale') and (
					obj.Name == 'FiveroseTweakerScale'
					or obj.Name == 'FiveroseTweakerWindowScale'
					or obj.Name == 'FiveroseTweakerPageScale'
					or obj.Name == 'FiveroseTweakerHoverScale'
				) then
					pcall(obj.Destroy, obj)
				end
			end
		end

		for _, obj in ipairs(lighting:GetChildren()) do
			if obj:IsA('BlurEffect') and obj.Name == 'FiveroseTweakerBlur' then
				pcall(obj.Destroy, obj)
			end
		end
	end

	local function getlayer()
		if alive(layer) then
			return layer
		end

		local parent

		if type(gethui) == 'function' then
			pcall(function()
				parent = gethui()
			end)
		end

		if not instance(parent) then
			parent = alive(api.gui) and api.gui.Parent or coregui
		end

		layer = Instance.new('ScreenGui')
		layer.Name = 'FiveroseTweakerAnimations'
		layer.ResetOnSpawn = false
		layer.ZIndexBehavior = Enum.ZIndexBehavior.Global
		layer.DisplayOrder = 2147483000

		if alive(api.gui) and api.gui:IsA('ScreenGui') then
			layer.IgnoreGuiInset = api.gui.IgnoreGuiInset
		else
			layer.IgnoreGuiInset = true
		end

		local ok = pcall(function()
			layer.Parent = parent
		end)

		if not ok then
			layer.Parent = coregui
		end

		made[#made + 1] = layer
		return layer
	end

	local function getblur()
		if alive(blur) then
			return blur
		end

		for _, obj in ipairs(lighting:GetChildren()) do
			if obj:IsA('BlurEffect') and obj.Name == 'FiveroseTweakerBlur' then
				pcall(obj.Destroy, obj)
			end
		end

		blur = Instance.new('BlurEffect')
		blur.Name = 'FiveroseTweakerBlur'
		blur.Size = 0
		blur.Parent = lighting
		made[#made + 1] = blur
		return blur
	end

	local function copycorner(root, frame)
		local source = alive(root) and root:FindFirstChildOfClass('UICorner')

		if source then
			local corner = Instance.new('UICorner')
			corner.CornerRadius = source.CornerRadius
			corner.Parent = frame
		end
	end

	local function pulse(root, kind)
		if not enabled or not alive(root) or not root:IsA('GuiObject') then
			return
		end

		local now = os.clock()

		if now - (pulseat[root] or 0) < 0.08 then
			return
		end

		pulseat[root] = now
		local size = root.AbsoluteSize
		local pos = root.AbsolutePosition

		if size.X < 4 or size.Y < 4 then
			return
		end

		local holder = getlayer()

		if not alive(holder) then
			return
		end

		local frame = Instance.new('Frame')
		frame.Name = 'FiveroseTweakerPulse'
		frame.Active = false
		frame.Selectable = false
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = kind == 'open' and 0.965 or 0.977
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.ZIndex = 1000

		local center = UDim2.fromOffset(pos.X + size.X / 2, pos.Y + size.Y / 2)
		local targetsize = UDim2.fromOffset(size.X, size.Y)

		if kind == 'open' then
			frame.Position = center
			frame.Size = UDim2.fromOffset(size.X * 0.94, size.Y * 0.94)
		elseif kind == 'tab' then
			frame.Position = center + UDim2.fromOffset(8, 0)
			frame.Size = targetsize
		else
			frame.Position = center
			frame.Size = targetsize
		end

		copycorner(root, frame)

		local stroke = Instance.new('UIStroke')
		stroke.Name = 'FiveroseTweakerPulseStroke'
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = kind == 'open' and 1.5 or 1
		stroke.Transparency = kind == 'hover' and 0.76 or 0.58
		stroke.Parent = frame

		frame.Parent = holder
		made[#made + 1] = frame

		play(frame, kind == 'open' and 0.24 or 0.18, kind == 'open' and Enum.EasingStyle.Back or Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
			Position = center,
			Size = targetsize,
			BackgroundTransparency = 1
		})

		play(stroke, kind == 'open' and 0.24 or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			Transparency = 1,
			Thickness = 0.5
		})

		task.delay(kind == 'open' and 0.28 or 0.22, function()
			cancel(frame)
			cancel(stroke)

			if alive(frame) then
				pcall(frame.Destroy, frame)
			end
		end)
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

			task.delay((index - 1) * 0.02, function()
				if enabled and ticket == serial and alive(root) and root.Visible ~= false then
					pulse(root, 'tab')
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

			for _, name in ipairs({'Main', 'Window', 'Background', 'Outline', 'PageHolder'}) do
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

	local function openstate()
		local root = findmain()

		if alive(root) then
			if root.Visible == false then
				return false
			end

			local size = root.AbsoluteSize

			if size.X <= 4 or size.Y <= 4 then
				return false
			end
		end

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

	local function animateopen()
		if not enabled or not openstate() then
			return
		end

		local root = findmain()

		if alive(root) then
			pulse(root, 'open')
		end

		local effect = getblur()
		effect.Size = math.min(effect.Size, 1)
		play(effect, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {Size = 5})
	end

	local function animateclose()
		if alive(blur) then
			play(blur, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {Size = 0})
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

			connect(button.MouseEnter, function()
				if enabled then
					pulse(button, 'hover')
				end
			end)
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
		layer = nil
		main = nil
		lastopen = nil
		bound = setmetatable({}, {__mode = 'k'})
		pulseat = setmetatable({}, {__mode = 'k'})
	end

	local function start()
		stop()
		removelegacy()
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

	removelegacy()

	local box = api.vape_settings_box
	local ownbox = false

	if type(box) ~= 'table' then
		local settings

		for _, wanted in ipairs({'ui settings', 'settings'}) do
			for key, tab in pairs(tabs) do
				local name = tostring(key):lower()
				local other = type(tab) == 'table' and tostring(rawget(tab, 'Name') or ''):lower() or ''

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

	box:AddToggle(id, {Text = 'Smooth UI Animations', Default = false})
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
			removelegacy()
		end
	end)

	api:clean(function()
		enabled = false
		stop()
		removelegacy()
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
