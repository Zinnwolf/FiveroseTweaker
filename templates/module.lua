return function(api)
	local id = 'example_module'
	local box = api.tab:AddLeftGroupbox('example module', 'wrench')
	local enabled = false

	box:AddToggle(id, {
		Text = 'example module',
		Default = false
	})

	api:own(id)
	api:addkey(api.toggles[id], 'fiverose_tweaker_example_key', 'Example Module', 'None')

	api.toggles[id]:OnChanged(function()
		enabled = api.toggles[id].Value == true
	end)

	api:clean(function()
		enabled = false
	end)

	return function()
		return enabled
	end
end
