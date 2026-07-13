return function(api)
	local run = function(func)
		local ok, err = xpcall(func, function(value)
			local trace = debug and debug.traceback
			return type(trace) == 'function' and trace(tostring(value), 2) or tostring(value)
		end)

		if not ok then
			warn('[fiverosetweaker/skywars_lobby] '..tostring(err))
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

	run(function()
		local kills = sessioninfo:AddItem('Kills')
		local eggs = sessioninfo:AddItem('Eggs')
		local wins = sessioninfo:AddItem('Wins')
		local games = sessioninfo:AddItem('Games')
	end)
end
