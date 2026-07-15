return function(api)
	local run = function(func)
		local before = {}

		for _, module in pairs(api.vape and api.vape.Modules or {}) do
			before[module] = true
		end

		local ok, err = xpcall(func, function(value)
			local trace = debug and debug.traceback
			return type(trace) == 'function' and trace(tostring(value), 2) or tostring(value)
		end)

		if not ok then
			local failed = {}

			for _, module in pairs(api.vape and api.vape.Modules or {}) do
				if not before[module] then
					failed[#failed + 1] = module
				end
			end

			for _, module in ipairs(failed) do
				if type(module) == 'table' and type(rawget(module, 'Destroy')) == 'function' then
					pcall(module.Destroy, module)
				end
			end

			warn('[fiverosetweaker/skywars_lobby] '..tostring(err))
		end

		return ok, err
	end
	local function required(func)
		local ok, err = run(func)

		if not ok then
			error('required bundle initialization failed: '..tostring(err), 0)
		end
	end
	local cloneref = cloneref or function(obj) 
		return obj 
	end
	local playersService = cloneref(game:GetService('Players'))
	local inputService = cloneref(game:GetService('UserInputService'))
	local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
	local collectionService = cloneref(game:GetService('CollectionService'))
	local httpService = cloneref(game:GetService('HttpService'))
	local coreGui = cloneref(game:GetService('CoreGui'))
	local gameCamera = workspace.CurrentCamera
	local lplr = playersService.LocalPlayer

	local vape = api.vape
	local sessioninfo = vape.Libraries.sessioninfo

	required(function()
		local kills = sessioninfo:AddItem('Kills')
		local eggs = sessioninfo:AddItem('Eggs')
		local wins = sessioninfo:AddItem('Wins')
		local games = sessioninfo:AddItem('Games')
	end)
end
