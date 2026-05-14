local Enums = {}

Enums.GamePhase = {
	Lobby = "Lobby",
	RoundInit = "RoundInit",
	Playing = "Playing",
	RoundEnd = "RoundEnd",
	GameOver = "GameOver",
}

Enums.TurnAction = {
	Play = "Play",
	Pass = "Pass",
}

Enums.RoundEndReason = {
	NormalWin = "NormalWin",
	Deadlock = "Deadlock",
}

Enums.GameMode = {
	Solo = "Solo",
	Team = "Team",
}

Enums.PlaySide = {
	Left = "Left",
	Right = "Right",
}

return Enums
