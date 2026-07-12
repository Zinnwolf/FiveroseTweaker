return function(api)
	local input = game:GetService('UserInputService')
	local lib = api.lib
	local tabs = api.tabs
	local options = api.options
	local original = rawget(lib, 'ToggleKeybind')
	local con

	local function alive(obj)
		return typeof(obj) == 'Instance' and obj.Parent ~= nil
	end

	local function has(tab, wanted)
		wanted = wanted:lower()

		for _, side in ipairs(type(tab) == 'table' and rawget(tab, 'Sides') or {}) do
			if alive(side) then
				for _, obj in ipairs(side:GetDescendants()) do
					if (obj:IsA('TextLabel') or obj:IsA('TextButton') or obj:IsA('TextBox'))
						and tostring(obj.Text):lower() == wanted then

						return true
					end
				end
			end
		end

		return false
	end

	local function info()
		for _, tab in pairs(tabs) do
			if type(tab) == 'table'
				and type(rawget(tab, 'AddLeftGroupbox')) == 'function'
				and has(tab, 'account')
				and has(tab, 'script status') then

				return tab
			end
		end
	end

	local function default()
		if type(original) == 'table' and type(rawget(original, 'Value')) == 'string' then
			return original.Value
		end

		if typeof(original) == 'EnumItem' and original.EnumType == Enum.KeyCode then
			return original.Name
		end

		return 'RightShift'
	end

	local function match(picker, obj)
		if type(picker) ~= 'table' or rawget(picker, 'Type') ~= 'KeyPicker' then
			return false
		end

		local value = tostring(rawget(picker, 'Value') or 'None')

		if value == 'None' or value == 'Unknown' then
			return false
		end

		for _, name in ipairs(rawget(picker, 'Modifiers') or {}) do
			local key = ({
				LAlt = Enum.KeyCode.LeftAlt,
				RAlt = Enum.KeyCode.RightAlt,
				LCtrl = Enum.KeyCode.LeftControl,
				RCtrl = Enum.KeyCode.RightControl,
				LShift = Enum.KeyCode.LeftShift,
				RShift = Enum.KeyCode.RightShift,
				LMeta = Enum.KeyCode.LeftMeta,
				RMeta = Enum.KeyCode.RightMeta
			})[name]

			if key and not input:IsKeyDown(key) then
				return false
			end
		end

		return obj.UserInputType == Enum.UserInputType.Keyboard and obj.KeyCode.Name == value
	end

	local tab = info()

	if not tab then
		warn('[fiverosetweaker] Fiverose info tab not found; GUI rebind skipped')
		return
	end

	local box = tab:AddLeftGroupbox('gui keybind', 'keyboard')
	local id = 'fiverose_gui_bind'
	local before = options[id]
	local label = box:AddLabel('gui key')

	label:AddKeyPicker(id, {
		Default = default(),
		SyncToggleState = false,
		Mode = 'Press',
		Text = 'gui key',
		NoUI = false,
		Blacklisted = {'MB1'}
	})

	local picker = options[id]

	if type(picker) ~= 'table' then
		error('GUI key picker was not created')
	end

	api:own(id)
	api.gui_bind = picker

	-- The original window listener compares against this field directly.
	lib.ToggleKeybind = Enum.KeyCode.Unknown

	con = input.InputBegan:Connect(function(obj)
		if api.state == 'unloaded'
			or rawget(lib, 'IsPicking')
			or input:GetFocusedTextBox() then

			return
		end

		if match(options[id], obj) and type(rawget(lib, 'Toggle')) == 'function' then
			lib:Toggle()
		end
	end)

	api:clean(function()
		if con then
			con:Disconnect()
			con = nil
		end

		lib.ToggleKeybind = original

		local item = options[id]

		if item ~= before and type(item) == 'table' and type(rawget(item, 'Destroy')) == 'function' then
			pcall(item.Destroy, item)
		end

		if options[id] == item and item ~= before then
			options[id] = before
		end

		if type(box) == 'table' and type(rawget(box, 'Destroy')) == 'function' then
			pcall(box.Destroy, box)
		end
	end)

	return picker
end
