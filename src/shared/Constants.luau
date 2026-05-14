local Constants = {
	DECK_SIZE = 28,
	MAX_PLAYERS = 4,
	TILES_PER_PLAYER = 7,
	MAX_PIP_VALUE = 6,

	PENALTY_THRESHOLD = 10,
	GAME_OVER_SCORE = 100,

	TURN_TIME_LIMIT = 15,

	SEAT_POSITIONS = { 1, 2, 3, 4 },

	-- Team pairs: opposite seats
	TEAM_PAIRS = {
		{ 1, 3 }, -- Team A
		{ 2, 4 }, -- Team B
	},
}

return Constants
