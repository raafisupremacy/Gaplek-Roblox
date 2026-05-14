--!strict
local Types = {}

export type DominoTile = {
	id: number,
	left: number,
	right: number,
}

export type PlacedTile = {
	tile: DominoTile,
	displayLeft: number,
	displayRight: number,
}

export type BoardState = {
	chain: { PlacedTile },
	leftEnd: number,
	rightEnd: number,
}

export type PlayerState = {
	player: Player?,
	seatIndex: number,
	hand: { DominoTile },
	totalScore: number,
	isConnected: boolean,
}

export type RoundResult = {
	reason: string,
	winnerSeat: number,
	winnerTeam: number?,
	penalties: { [number]: number },
	remainingPips: { [number]: number },
}

export type PlayAction = {
	tileId: number,
	side: string,
}

return Types
