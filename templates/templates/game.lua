return function(api, entry)
	local status = api:import('src/games/shared/base.lua')
	status(api, entry)

	api.example_game = {
		place = api.place,
		game = api.gameid
	}

	return api.example_game
end
