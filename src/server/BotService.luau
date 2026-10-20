--!strict
--[=[
	BotService.luau
	Layanan AI Bot untuk Gaplek Pos Ronda (BOT_SPEC.md).
	
	Level:
	- "easy" (Mudah): Memilih langkah legal secara acak. Tidak pernah salah aturan.
	- "normal" (Normal): Heuristik evaluasi kartu besar, penjagaan balak, sinergi tangan,
	  dan preferensi pola pas lawan/rekan di 2v2. Memiliki peluang kecil (5%) memilih
	  langkah terbaik kedua (blunder manusiawi).
	
	API murni: Hanya melihat publicView dan hand sendiri. Bebas manipulasi langsung.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")

local Types = require(sharedFolder:WaitForChild("Types"))
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local RngModule = require(sharedFolder:WaitForChild("Rng"))

export type Tile = Types.Tile
export type Side = Types.Side
export type Mode = Types.Mode
export type Board = Types.Board
export type Move = Types.Move
export type RngInterface = RngModule.RngInterface

export type BotLevel = "easy" | "normal"

export type BotProfile = {
	seat: number,
	level: BotLevel,
}

export type PublicView = {
	mode: Mode,
	board: Board,
	remainingCounts: { [number]: number }, -- Jumlah kartu per kursi
	passCount: { [number]: number },
	openerSeat: number,
	isOpening: boolean,
	isFirstRound: boolean,
	knownPassedEnds: { [number]: { [number]: boolean } }?, -- [seat][endNumber] = true jika pernah pas
}

export type BotDecision = {
	action: "play" | "pass",
	tile: Tile?,
	side: Side?,
}

local BotService = {}

--[=[
	Mengambil semua langkah legal yang tersedia untuk bot saat ini.
]=]
function BotService.GetLegalMoves(publicView: PublicView, hand: { Tile }): { Move }
	if publicView.isOpening or #publicView.board.placed == 0 then
		return DominoLogic.GetOpeningMoves(hand, publicView.isFirstRound)
	else
		return DominoLogic.GetPlayableMoves(hand, publicView.board)
	end
end

--[=[
	Menghitung skor evaluasi heuristik untuk sebuah langkah (Bot Normal).
]=]
local function evaluateMove(
	move: Move,
	hand: { Tile },
	publicView: PublicView,
	mySeat: number
): number
	local score = 0
	local tile = move.tile
	local pips = DominoLogic.Pips(tile)
	local isDouble = DominoLogic.IsDouble(tile)
	local myPartnerSeat = if mySeat == 1 then 3 elseif mySeat == 3 then 1 elseif mySeat == 2 then 4 else 2

	-- 1. Buang kartu bertitik besar terlebih dahulu (mengurangi risiko sisa > 10)
	score += (pips * 2.0)

	-- 2. Menahan balak jika kartu masih banyak (> 2 kartu di tangan)
	if isDouble and #hand > 2 then
		score -= 3.0
	end

	-- 3. Preferensi ujung masa depan yang cocok dengan sisa kartu di tangan sendiri
	local futureMatches = 0
	for _, handTile in ipairs(hand) do
		if not DominoLogic.TilesEqual(handTile, tile) then
			if handTile.a == move.newEnd or handTile.b == move.newEnd then
				futureMatches += 1
			end
		end
	end
	score += (futureMatches * 3.0)

	-- 4. Mode 2v2: Tinjau riwayat pas lawan dan partner
	if publicView.mode == "2v2" and publicView.knownPassedEnds then
		local passedEnds = publicView.knownPassedEnds

		-- Jika lawan pernah pas pada angka newEnd, beri bonus besar (+5)
		local opponent1 = if (mySeat % 2 == 1) then 2 else 1
		local opponent2 = if (mySeat % 2 == 1) then 4 else 3
		if passedEnds[opponent1] and passedEnds[opponent1][move.newEnd] then
			score += 5.0
		end
		if passedEnds[opponent2] and passedEnds[opponent2][move.newEnd] then
			score += 5.0
		end

		-- Jika rekan satu tim diketahui pernah pas pada angka newEnd, beri penalti (-4)
		if passedEnds[myPartnerSeat] and passedEnds[myPartnerSeat][move.newEnd] then
			score -= 4.0
		end
	end

	return score
end

--[=[
	Fungsi utama pengambil keputusan bot: Decide.
	Memenuhi kriteria BOT_SPEC.md:
	- Murni: Hanya menerima profile, publicView, privateHand, dan rng.
	- Tidak pernah menghasilkan langkah ilegal.
]=]
function BotService.Decide(
	profile: BotProfile,
	publicView: PublicView,
	hand: { Tile },
	rng: RngInterface
): BotDecision
	local legalMoves = BotService.GetLegalMoves(publicView, hand)

	-- Jika tidak ada langkah legal, bot wajib pas
	if #legalMoves == 0 then
		return { action = "pass" }
	end

	-- Bot Level "easy" (Mudah): Pilih langkah legal acak
	if profile.level == "easy" then
		local choiceIndex = rng:NextInteger(1, #legalMoves)
		local chosen = legalMoves[choiceIndex]
		return {
			action = "play",
			tile = chosen.tile,
			side = chosen.side,
		}
	end

	-- Bot Level "normal" (Normal): Evaluasi heuristik
	if #legalMoves == 1 then
		return {
			action = "play",
			tile = legalMoves[1].tile,
			side = legalMoves[1].side,
		}
	end

	-- Beri skor untuk setiap langkah legal
	type ScoredMove = { move: Move, score: number }
	local scoredList: { ScoredMove } = {}

	for _, move in ipairs(legalMoves) do
		local s = evaluateMove(move, hand, publicView, profile.seat)
		table.insert(scoredList, { move = move, score = s })
	end

	-- Urutkan dari skor tertinggi ke terendah
	table.sort(scoredList, function(a, b)
		return a.score > b.score
	end)

	-- Cek peluang blunder manusiawi (5% kemungkinan pilih opsi terbaik ke-2)
	local blunderRoll = rng:NextNumber()
	local selectedMoveIndex = 1
	if #scoredList >= 2 and blunderRoll < GameConfig.BOT_BLUNDER_CHANCE then
		selectedMoveIndex = 2
	end

	local chosen = scoredList[selectedMoveIndex].move
	return {
		action = "play",
		tile = chosen.tile,
		side = chosen.side,
	}
end

--[=[
	Wrapper kompatibilitas untuk GameService: DecideMove.
]=]
function BotService.DecideMove(
	seat: number,
	hand: { Tile },
	publicView: PublicView,
	level: BotLevel?,
	rng: RngInterface
): BotDecision
	local profile: BotProfile = {
		seat = seat,
		level = level or "normal",
	}
	return BotService.Decide(profile, publicView, hand, rng)
end

return BotService
