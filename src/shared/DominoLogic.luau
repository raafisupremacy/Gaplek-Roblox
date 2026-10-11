--!strict
--[=[
	DominoLogic.luau
	Logika murni permainan Domino Gaplek (GAME_RULES.md, LOGIC_SPEC.md).
	
	ATURAN KETAT:
	- Nol Instance, nol remote, nol waktu nyata (os.time), nol API khusus Roblox.
	- Keacakan murni di-inject lewat interface Rng.
	- Deterministik: input yang sama menghasilkan output yang sama.
	- Fungsi validasi tidak pernah memodifikasi state ketika menolak langkah.
]=]

local Types = require(script.Parent.Types)
local GameConfig = require(script.Parent.GameConfig)
local RngModule = require(script.Parent.Rng)

export type Tile = Types.Tile
export type Side = Types.Side
export type Mode = Types.Mode
export type Placed = Types.Placed
export type Board = Types.Board
export type Move = Types.Move
export type RoundState = Types.RoundState
export type GameState = Types.GameState
export type RoundResult = Types.RoundResult
export type GameResult = Types.GameResult
export type RngInterface = RngModule.RngInterface

local DominoLogic = {}

--[=[
	Membuat deck baru berisi 28 kartu domino double-six unik (0-0 s/d 6-6).
	Setiap kartu memiliki a <= b.
]=]
function DominoLogic.NewDeck(): { Tile }
	local deck: { Tile } = {}
	for i = 0, 6 do
		for j = i, 6 do
			table.insert(deck, { a = i, b = j })
		end
	end
	return deck
end

--[=[
	Mengocok deck kartu secara acak menggunakan algoritma Fisher-Yates.
	TIDAK memodifikasi array input (mengembalikan array baru).
]=]
function DominoLogic.Shuffle(deck: { Tile }, rng: RngInterface): { Tile }
	local shuffled: { Tile } = {}
	for _, tile in ipairs(deck) do
		table.insert(shuffled, { a = tile.a, b = tile.b })
	end

	for i = #shuffled, 2, -1 do
		local j = rng:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	return shuffled
end

--[=[
	Membagikan 28 kartu ke 4 kursi (masing-masing 7 kartu).
]=]
function DominoLogic.Deal(deck: { Tile }): { [number]: { Tile } }
	local hands: { [number]: { Tile } } = {
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {},
	}

	for idx, tile in ipairs(deck) do
		local seat = ((idx - 1) % GameConfig.TOTAL_SEATS) + 1
		table.insert(hands[seat], { a = tile.a, b = tile.b })
	end

	return hands
end

--[=[
	Menghitung jumlah titik (pips) sebuah kartu (a + b).
]=]
function DominoLogic.Pips(tile: Tile): number
	return tile.a + tile.b
end

--[=[
	Mengecek apakah sebuah kartu adalah balak (kembar: a == b).
]=]
function DominoLogic.IsDouble(tile: Tile): boolean
	return tile.a == tile.b
end

--[=[
	Mengembalikan string identifikasi kartu "a-b" dengan a <= b.
]=]
function DominoLogic.TileKey(tile: Tile): string
	local low = math.min(tile.a, tile.b)
	local high = math.max(tile.a, tile.b)
	return string.format("%d-%d", low, high)
end

--[=[
	Mengecek kesamaan dua kartu tanpa mempedulikan orientasi.
]=]
function DominoLogic.TilesEqual(t1: Tile, t2: Tile): boolean
	return (t1.a == t2.a and t1.b == t2.b) or (t1.a == t2.b and t1.b == t2.a)
end

--[=[
	Membuat board meja baru yang kosong.
]=]
function DominoLogic.NewBoard(): Board
	return {
		placed = {},
		left = nil,
		right = nil,
	}
end

--[=[
	Mengembalikan giliran kursi berikutnya: (seat % 4) + 1.
]=]
function DominoLogic.NextTurn(seat: number): number
	return (seat % GameConfig.TOTAL_SEATS) + 1
end

--[=[
	Menentukan pihak/tim dari kursi tertentu.
	Mode 2v2: Kursi 1 & 3 -> Tim 1; Kursi 2 & 4 -> Tim 2.
	Mode Solo: Nomor kursi masing-masing (1, 2, 3, 4).
]=]
function DominoLogic.SideOf(mode: Mode, seat: number): number
	if mode == "2v2" then
		return if (seat == 1 or seat == 3) then 1 else 2
	else
		return seat
	end
end

--[=[
	Mengecek apakah hand memiliki kartu tertentu.
	Mengembalikan indeks kartu di hand atau nil jika tidak ada.
]=]
function DominoLogic.FindTileInHand(hand: { Tile }, tile: Tile): number?
	for idx, t in ipairs(hand) do
		if DominoLogic.TilesEqual(t, tile) then
			return idx
		end
	end
	return nil
end

--[=[
	Mengambil daftar langkah pembuka yang legal untuk ronde ini.
	Ronde 1: HANYA [6-6] yang legal.
	Ronde >= 2: Semua balak (a == b) yang ada di hand legal (GAME_RULES.md §4, D-01).
]=]
function DominoLogic.GetOpeningMoves(hand: { Tile }, isFirstRound: boolean): { Move }
	local moves: { Move } = {}
	if isFirstRound then
		for _, tile in ipairs(hand) do
			if tile.a == 6 and tile.b == 6 then
				table.insert(moves, {
					tile = { a = 6, b = 6 },
					side = "center",
					newEnd = 6,
				})
			end
		end
	else
		for _, tile in ipairs(hand) do
			if DominoLogic.IsDouble(tile) then
				table.insert(moves, {
					tile = { a = tile.a, b = tile.b },
					side = "center",
					newEnd = tile.a,
				})
			end
		end
	end
	return moves
end

--[=[
	Mengambil semua langkah legal yang dapat dimainkan dari hand pada board saat ini.
	Jika board kosong, fungsi ini mengembalikan tabel kosong (gunakan GetOpeningMoves).
]=]
function DominoLogic.GetPlayableMoves(hand: { Tile }, board: Board): { Move }
	if #board.placed == 0 or board.left == nil or board.right == nil then
		return {}
	end

	local moves: { Move } = {}
	local leftEnd = board.left
	local rightEnd = board.right

	for _, tile in ipairs(hand) do
		-- Cek kecocokan di sisi kiri
		if tile.a == leftEnd then
			table.insert(moves, {
				tile = { a = tile.a, b = tile.b },
				side = "left",
				newEnd = tile.b,
			})
		elseif tile.b == leftEnd then
			table.insert(moves, {
				tile = { a = tile.a, b = tile.b },
				side = "left",
				newEnd = tile.a,
			})
		end

		-- Cek kecocokan di sisi kanan
		if tile.a == rightEnd then
			table.insert(moves, {
				tile = { a = tile.a, b = tile.b },
				side = "right",
				newEnd = tile.b,
			})
		elseif tile.b == rightEnd then
			table.insert(moves, {
				tile = { a = tile.a, b = tile.b },
				side = "right",
				newEnd = tile.a,
			})
		end
	end

	return moves
end

--[=[
	Menentukan pembuka ronde sesuai aturan ketat GAME_RULES.md §4:
	Ronde 1: Pemegang kartu 6-6.
	Ronde >= 2:
	- Cek starterSeat (pemenang ronde sebelumnya). Jika punya balak, dia pembuka.
	- Jika starterSeat tidak punya balak: cek pemain berikutnya ((starterSeat % 4) + 1). Jika punya balak, dia pembuka.
	- Jika KEDUA pemain tersebut tidak punya balak: reshuffle = true.
	- Pemain ke-3 dan ke-4 TIDAK DICEK sama sekali.
]=]
function DominoLogic.ChooseOpener(
	game: GameState,
	hands: { [number]: { Tile } },
	_rng: RngInterface?
): { seat: number?, reshuffle: boolean }
	if game.roundNumber == 1 or game.starterSeat == nil then
		-- Ronde 1: Pemegang kartu [6-6]
		for seat = 1, GameConfig.TOTAL_SEATS do
			for _, tile in ipairs(hands[seat]) do
				if tile.a == 6 and tile.b == 6 then
					return { seat = seat, reshuffle = false }
				end
			end
		end
		-- Seharusnya tidak terjadi pada set 28 kartu lengkap
		return { seat = nil, reshuffle = true }
	else
		-- Ronde >= 2: Pembuka awal adalah starterSeat
		local candidate1 = game.starterSeat
		local candidate1Moves = DominoLogic.GetOpeningMoves(hands[candidate1], false)
		if #candidate1Moves > 0 then
			return { seat = candidate1, reshuffle = false }
		end

		-- Jika candidate1 tidak punya balak: cek pemain berikutnya
		local candidate2 = DominoLogic.NextTurn(candidate1)
		local candidate2Moves = DominoLogic.GetOpeningMoves(hands[candidate2], false)
		if #candidate2Moves > 0 then
			return { seat = candidate2, reshuffle = false }
		end

		-- Kedua pemain tidak punya balak: wajib reshuffle (pemain 3 & 4 tidak dicek)
		return { seat = nil, reshuffle = true }
	end
end

--[=[
	Inisialisasi state ronde baru.
]=]
function DominoLogic.NewRound(openerSeat: number, hands: { [number]: { Tile } }): RoundState
	return {
		hands = hands,
		board = DominoLogic.NewBoard(),
		currentSeat = openerSeat,
		passStreak = 0,
		passCount = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 },
		lastMover = nil,
		openerSeat = openerSeat,
		phase = "playing",
	}
end

--[=[
	Memvalidasi dan mengeksekusi pemasangan kartu pemain ke board.
	JIKA GAGAL: State tidak berubah sama sekali, mengembalikan (false, errorCode).
	JIKA BERHASIL: Kartu dicopot dari hand, board diperbarui, passStreak di-reset ke 0,
	lastMover dicatat, dan currentSeat berpindah ke pemain berikutnya. Mengembalikan (true, nil).
]=]
function DominoLogic.ApplyMove(
	round: RoundState,
	seat: number,
	tile: Tile,
	side: Side
): (boolean, string?)
	-- 1. Validasi giliran
	if round.currentSeat ~= seat then
		return false, "NOT_YOUR_TURN"
	end

	-- 2. Validasi kepemilikan kartu
	local hand = round.hands[seat]
	if not hand then
		return false, "INVALID_SEAT"
	end
	local tileIndex = DominoLogic.FindTileInHand(hand, tile)
	if not tileIndex then
		return false, "TILE_NOT_IN_HAND"
	end

	local actualTile = hand[tileIndex]
	local isDouble = DominoLogic.IsDouble(actualTile)

	-- 3. Validasi pemasangan pada board
	local board = round.board
	local newEnd: number

	if #board.placed == 0 then
		-- Board kosong: Hanya menerima langkah pembuka di side = "center"
		if side ~= "center" then
			return false, "FIRST_MOVE_MUST_BE_CENTER"
		end

		-- Verifikasi syarat pembuka
		if round.lastMover == nil and round.openerSeat == seat then
			-- Jika kartu pembuka, pastikan sesuai aturan
			-- (Jika ronde 1: harus [6-6]; jika ronde >= 2: harus balak)
			-- Catatan: jika pembuka adalah balak, maka valid
			if not isDouble and (actualTile.a ~= 6 or actualTile.b ~= 6) then
				return false, "OPENING_MUST_BE_DOUBLE"
			end
		end

		newEnd = actualTile.a
		-- Pemasangan berhasil pada board kosong
		table.remove(hand, tileIndex)
		table.insert(board.placed, {
			tile = { a = actualTile.a, b = actualTile.b },
			side = "center",
			isDouble = isDouble,
			endLeft = actualTile.a,
			endRight = actualTile.b,
		})
		board.left = actualTile.a
		board.right = actualTile.b
	else
		-- Board terisi: Harus dipasang di "left" atau "right"
		if side == "center" then
			return false, "CANNOT_PLAY_CENTER_ON_EXISTING_BOARD"
		end

		local targetEnd = if side == "left" then board.left else board.right
		if targetEnd == nil then
			return false, "INVALID_BOARD_STATE"
		end

		if actualTile.a == targetEnd then
			newEnd = actualTile.b
		elseif actualTile.b == targetEnd then
			newEnd = actualTile.a
		else
			return false, "TILE_DOES_NOT_MATCH_END"
		end

		-- Pemasangan berhasil pada board terisi
		table.remove(hand, tileIndex)
		if side == "left" then
			board.left = newEnd
			table.insert(board.placed, {
				tile = { a = actualTile.a, b = actualTile.b },
				side = "left",
				isDouble = isDouble,
				endLeft = newEnd,
				endRight = board.right :: number,
			})
		else
			board.right = newEnd
			table.insert(board.placed, {
				tile = { a = actualTile.a, b = actualTile.b },
				side = "right",
				isDouble = isDouble,
				endLeft = board.left :: number,
				endRight = newEnd,
			})
		end
	end

	-- Update status ronde
	round.passStreak = 0
	round.lastMover = seat
	round.currentSeat = DominoLogic.NextTurn(seat)

	return true, nil
end

--[=[
	Memvalidasi dan mengeksekusi aksi Pas (pass/skip turn).
	HANYA diizinkan jika pemain TIDAK memiliki langkah legal pada board saat ini.
	Jika pemain punya langkah legal: DITOLAK (GAME_RULES.md §3 poin 6).
]=]
function DominoLogic.Pass(round: RoundState, seat: number): (boolean, string?)
	if round.currentSeat ~= seat then
		return false, "NOT_YOUR_TURN"
	end

	local hand = round.hands[seat]
	if not hand then
		return false, "INVALID_SEAT"
	end

	-- Jika board kosong, pembuka tidak boleh pas jika memiliki kartu pembuka yang legal
	if #round.board.placed == 0 then
		local openingMoves = DominoLogic.GetOpeningMoves(hand, false)
		if #openingMoves > 0 then
			return false, "HAS_LEGAL_MOVES"
		end
	else
		local playableMoves = DominoLogic.GetPlayableMoves(hand, round.board)
		if #playableMoves > 0 then
			return false, "HAS_LEGAL_MOVES"
		end
	end

	-- Pas valid
	round.passStreak += 1
	round.passCount[seat] = (round.passCount[seat] or 0) + 1
	round.currentSeat = DominoLogic.NextTurn(seat)

	return true, nil
end

--[=[
	Mengecek kondisi berakhirnya ronde:
	- "emptied": Jika ada pemain yang kartunya habis (0 kartu).
	- "blocked": Jika buntu (4 pemain berturut-turut melakukan pas, passStreak >= 4).
	- nil: Jika ronde masih berlanjut.
]=]
function DominoLogic.CheckRoundEnd(round: RoundState): ("emptied" | "blocked" | nil)
	for seat = 1, GameConfig.TOTAL_SEATS do
		if #round.hands[seat] == 0 then
			return "emptied"
		end
	end

	if round.passStreak >= GameConfig.TOTAL_SEATS then
		return "blocked"
	end

	return nil
end

--[=[
	Menyelesaikan kondisi buntu (blocked) sesuai GAME_RULES.md §5:
	1. Hitung total titik sisa kartu per pemain. Yang terendah menang.
	2. Seri titik terendah: Pemain yang paling sedikit pas menang.
	3. Masih seri:
	   - Jika semua pemain yang seri berada dalam satu tim (2v2): Tim itu menang.
	   - Jika seri melibatkan dua pihak berbeda: Ronde dibatalkan (cancelled), diulang dengan pembuka sama.
]=]
function DominoLogic.ResolveBlocked(round: RoundState, mode: Mode): RoundResult
	local remaining: { [number]: number } = {}
	local minPips = math.huge

	for seat = 1, GameConfig.TOTAL_SEATS do
		local total = 0
		for _, tile in ipairs(round.hands[seat]) do
			total += DominoLogic.Pips(tile)
		end
		remaining[seat] = total
		if total < minPips then
			minPips = total
		end
	end

	-- Kumpulkan semua pemain dengan total titik terendah
	local lowestSeats: { number } = {}
	for seat = 1, GameConfig.TOTAL_SEATS do
		if remaining[seat] == minPips then
			table.insert(lowestSeats, seat)
		end
	end

	-- Jika hanya ada 1 pemain terendah tunggal
	if #lowestSeats == 1 then
		local winnerSeat = lowestSeats[1]
		return {
			reason = "blocked",
			winnerSeat = winnerSeat,
			winnerSide = DominoLogic.SideOf(mode, winnerSeat),
			remaining = remaining,
		}
	end

	-- Seri titik terendah: Bandingkan jumlah pas (yang paling sedikit pas menang)
	local minPass = math.huge
	for _, seat in ipairs(lowestSeats) do
		local passes = round.passCount[seat] or 0
		if passes < minPass then
			minPass = passes
		end
	end

	local lowestPassSeats: { number } = {}
	for _, seat in ipairs(lowestSeats) do
		local passes = round.passCount[seat] or 0
		if passes == minPass then
			table.insert(lowestPassSeats, seat)
		end
	end

	-- Jika tie-break pas menghasilkan satu pemenang tunggal
	if #lowestPassSeats == 1 then
		local winnerSeat = lowestPassSeats[1]
		return {
			reason = "blocked",
			winnerSeat = winnerSeat,
			winnerSide = DominoLogic.SideOf(mode, winnerSeat),
			remaining = remaining,
		}
	end

	-- Masih seri: Cek apakah semua pemain yang seri satu tim (mode 2v2)
	if mode == "2v2" then
		local firstSide = DominoLogic.SideOf(mode, lowestPassSeats[1])
		local allSameTeam = true
		for _, seat in ipairs(lowestPassSeats) do
			if DominoLogic.SideOf(mode, seat) ~= firstSide then
				allSameTeam = false
				break
			end
		end

		if allSameTeam then
			-- Satu tim: Tim itu menang. Pembuka berikutnya: nomor kursi terkecil di antara mereka
			local winnerSeat = lowestPassSeats[1]
			for _, seat in ipairs(lowestPassSeats) do
				if seat < winnerSeat then
					winnerSeat = seat
				end
			end
			return {
				reason = "blocked",
				winnerSeat = winnerSeat,
				winnerSide = firstSide,
				remaining = remaining,
			}
		end
	end

	-- Seri melibatkan dua pihak berbeda: Ronde dibatalkan (cancelled)
	return {
		reason = "cancelled",
		winnerSeat = nil,
		winnerSide = nil,
		remaining = remaining,
	}
end

--[=[
	Menghitung perolehan poin ronde sesuai GAME_RULES.md §6:
	- Hanya pihak yang kalah yang dihitung. Pemenang dan rekannya selalu mendapat 0 poin (+0).
	- Mode 2v2: Poin tim kalah = jumlah titik sisa kartu kedua pemain di tim itu.
	  Jika total tim > 10: Ditambahkan penuh.
	  Jika total tim <= 10: Tambah 0 poin (+0).
	- Mode Solo: Tiap pemain kalah dicek sendiri.
	  Jika titik pemain > 10: Ditambahkan penuh.
	  Jika titik pemain <= 10: Tambah 0 poin (+0).
]=]
function DominoLogic.ScoreRound(
	game: GameState,
	round: RoundState,
	result: RoundResult
): { deltas: { [number]: number }, perSide: { [number]: number } }
	local deltas: { [number]: number } = {}
	local perSide: { [number]: number } = {}

	if result.reason == "cancelled" or result.winnerSide == nil then
		-- Ronde dibatalkan: tidak ada perubahan poin
		if game.mode == "2v2" then
			deltas[1] = 0
			deltas[2] = 0
			perSide[1] = 0
			perSide[2] = 0
		else
			for seat = 1, GameConfig.TOTAL_SEATS do
				deltas[seat] = 0
				perSide[seat] = 0
			end
		end
		return { deltas = deltas, perSide = perSide }
	end

	local winnerSide = result.winnerSide

	if game.mode == "2v2" then
		-- 2v2: Hitung total tim kalah
		local losingSide = if winnerSide == 1 then 2 else 1
		local losingTeamSeats = if losingSide == 1 then { 1, 3 } else { 2, 4 }

		local teamTotal = 0
		for _, seat in ipairs(losingTeamSeats) do
			teamTotal += (result.remaining[seat] or 0)
		end

		perSide[winnerSide] = 0
		perSide[losingSide] = teamTotal

		-- Pemenang selalu 0
		deltas[winnerSide] = 0

		-- Tim kalah: > 10 dihitung penuh, <= 10 dihitung 0
		if teamTotal > GameConfig.SCORE_THRESHOLD then
			deltas[losingSide] = teamTotal
		else
			deltas[losingSide] = 0
		end
	else
		-- Mode Solo: Periksa masing-masing pemain kalah
		for seat = 1, GameConfig.TOTAL_SEATS do
			local pips = result.remaining[seat] or 0
			perSide[seat] = pips

			if seat == result.winnerSeat then
				deltas[seat] = 0
			else
				if pips > GameConfig.SCORE_THRESHOLD then
					deltas[seat] = pips
				else
					deltas[seat] = 0
				end
			end
		end
	end

	return { deltas = deltas, perSide = perSide }
end

--[=[
	Menginisialisasi match game baru.
]=]
function DominoLogic.NewGame(mode: Mode): GameState
	local scores: { [number]: number } = {}
	if mode == "2v2" then
		scores[1] = 0
		scores[2] = 0
	else
		for seat = 1, GameConfig.TOTAL_SEATS do
			scores[seat] = 0
		end
	end

	return {
		mode = mode,
		scores = scores,
		roundNumber = 1,
		starterSeat = nil,
		finished = false,
	}
end

--[=[
	Menerapkan perolehan skor round deltas ke akumulasi game.
]=]
function DominoLogic.ApplyScore(game: GameState, deltas: { [number]: number }): ()
	for side, delta in pairs(deltas) do
		game.scores[side] = (game.scores[side] or 0) + delta
	end
end

--[=[
	Mengecek kondisi akhir match (GAME_RULES.md §7):
	Pihak dengan akumulasi skor >= TARGET_SCORE (100) kalah.
	- Mode 2v2: Hanya satu tim yang bertambah poin per ronde, sehingga tidak mungkin mencapai 100 bersamaan.
	- Mode Solo: Jika ada beberapa pemain >= 100 sekaligus, semua yang >= 100 kalah,
	  peringkat diurutkan dari skor terendah (terbaik) ke tertinggi (terburuk) sesuai D-02.
]=]
function DominoLogic.CheckGameEnd(game: GameState): GameResult
	local losers: { number } = {}
	local hasLoser = false

	for side, score in pairs(game.scores) do
		if score >= GameConfig.TARGET_SCORE then
			hasLoser = true
			table.insert(losers, side)
		end
	end

	if not hasLoser then
		return {
			finished = false,
			losers = {},
			ranking = {},
		}
	end

	-- Buat daftar ranking dari skor terendah ke tertinggi
	local entries: { { side: number, score: number } } = {}
	for side, score in pairs(game.scores) do
		table.insert(entries, { side = side, score = score })
	end

	table.sort(entries, function(a, b)
		return a.score < b.score
	end)

	local ranking: { number } = {}
	for _, entry in ipairs(entries) do
		table.insert(ranking, entry.side)
	end

	game.finished = true
	return {
		finished = true,
		losers = losers,
		ranking = ranking,
	}
end

--[=[
	Menghasilkan token unik acak untuk kartu di hand per ronde (TECH_SPEC §5).
	Mencegah eksploit tebakan indeks kartu dari client.
]=]
function DominoLogic.GenerateTileToken(seat: number, tileIndex: number, rng: RngInterface): string
	local randPart = rng:NextInteger(100000, 999999)
	return string.format("t_%d_%d_%d", seat, tileIndex, randPart)
end

return table.freeze(DominoLogic)
