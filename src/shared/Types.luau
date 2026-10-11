--!strict
--[=[
	Types.luau
	Definisi tipe data Luau bersama untuk Gaplek Pos Ronda.
	Sumber: LOGIC_SPEC.md §1, TECH_SPEC.md §1, §5.
]=]

-- Kartu domino gaplek (a <= b, rentang 0..6)
export type Tile = {
	a: number,
	b: number,
}

-- Sisi pemasangan kartu pada board: "left", "right", atau "center" (pembuka)
export type Side = "left" | "right" | "center"

-- Mode permainan: "2v2" (tim hadap-hadapan) atau "solo" (individu)
export type Mode = "2v2" | "solo"

-- Kartu yang sudah terpasang di meja permainan
export type Placed = {
	tile: Tile,
	side: Side,
	isDouble: boolean,
	endLeft: number,
	endRight: number,
}

-- Kondisi papan meja permainan
export type Board = {
	placed: { Placed },
	left: number?,
	right: number?,
}

-- Langkah valid pemain
export type Move = {
	tile: Tile,
	side: Side,
	newEnd: number,
}

-- State satu ronde aktif
export type RoundState = {
	hands: { [number]: { Tile } }, -- Kursi 1..4
	board: Board,
	currentSeat: number,
	passStreak: number,
	passCount: { [number]: number },
	lastMover: number?,
	openerSeat: number,
	phase: string,
}

-- State satu match keseluruhan
export type GameState = {
	mode: Mode,
	scores: { [number]: number }, -- 2v2: 1 (tim 1&3), 2 (tim 2&4); solo: 1..4 (kursi)
	roundNumber: number,
	starterSeat: number?, -- nil di ronde 1
	finished: boolean,
}

-- Hasil akhir ronde
export type RoundResult = {
	reason: "emptied" | "blocked" | "cancelled",
	winnerSeat: number?,
	winnerSide: number?,
	remaining: { [number]: number },
}

-- Hasil akhir match/game
export type GameResult = {
	finished: boolean,
	losers: { number },
	ranking: { number },
}

-- Pengaturan pemain yang disimpan via DataStore (M6)
export type PlayerSettings = {
	masterVolume: number,
	sfxVolume: number,
	ambienceVolume: number,
	uiVolume: number,
	reduceShake: boolean,
	sensitivity: number,
	graphicsQuality: string,
	hasSeenTutorial: boolean,
}

return {}
