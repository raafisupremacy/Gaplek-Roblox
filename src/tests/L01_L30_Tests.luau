--!strict
--[=[
	L01_L30_Tests.luau
	Unit test lengkap L01 s/d L30 untuk logika permainan Domino Gaplek (TEST_PLAN.md §1).
	Menggunakan fixture R1 s/d R10 persis sesuai GAME_RULES.md §9.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")

local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local Types = require(sharedFolder:WaitForChild("Types"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

export type Tile = Types.Tile
export type Side = Types.Side
export type RoundState = Types.RoundState
export type GameState = Types.GameState

local L01_L30_Tests = {}

export type TestResult = {
	id: string,
	name: string,
	passed: boolean,
	message: string?,
}

function L01_L30_Tests.run(): { [string]: any }
	local results: { TestResult } = {}
	local passedCount = 0
	local failedCount = 0
	local rng = Rng.deterministic(12345)

	local function assertTest(id: string, name: string, condition: boolean, failMsg: string)
		if condition then
			passedCount += 1
			table.insert(results, { id = id, name = name, passed = true })
		else
			failedCount += 1
			table.insert(results, { id = id, name = name, passed = false, message = failMsg })
			warn(string.format("[%s FAIL] %s: %s", id, name, failMsg))
		end
	end

	-- L01: NewDeck - 28 unik, a <= b, semua pasangan 0..6
	do
		local deck = DominoLogic.NewDeck()
		local count = #deck
		local uniqueKeys: { [string]: boolean } = {}
		local allOrdered = true
		for _, tile in ipairs(deck) do
			if tile.a > tile.b or tile.a < 0 or tile.b > 6 then
				allOrdered = false
			end
			uniqueKeys[DominoLogic.TileKey(tile)] = true
		end
		local uniqueCount = 0
		for _ in pairs(uniqueKeys) do uniqueCount += 1 end
		assertTest("L01", "NewDeck", count == 28 and uniqueCount == 28 and allOrdered, "Harus 28 kartu unik berurutan a<=b")
	end

	-- L02: Shuffle - permutasi sah, input tidak berubah
	do
		local original = DominoLogic.NewDeck()
		local originalCopy: { string } = {}
		for _, t in ipairs(original) do table.insert(originalCopy, DominoLogic.TileKey(t)) end

		local shuffled = DominoLogic.Shuffle(original, rng)
		local countSame = (#shuffled == 28)
		local keysShuffled: { [string]: boolean } = {}
		for _, t in ipairs(shuffled) do keysShuffled[DominoLogic.TileKey(t)] = true end
		local allOriginalPresent = true
		for _, k in ipairs(originalCopy) do
			if not keysShuffled[k] then allOriginalPresent = false end
		end
		-- Pastikan original tidak berubah
		local inputUnchanged = true
		for idx, t in ipairs(original) do
			if DominoLogic.TileKey(t) ~= originalCopy[idx] then inputUnchanged = false end
		end
		assertTest("L02", "Shuffle", countSame and allOriginalPresent and inputUnchanged, "Permutasi sah dan tidak memodifikasi input")
	end

	-- L03: Deal - 4 tangan x 7, tak ada duplikat, gabungan 28
	do
		local deck = DominoLogic.NewDeck()
		local hands = DominoLogic.Deal(deck)
		local allSeven = (#hands[1] == 7 and #hands[2] == 7 and #hands[3] == 7 and #hands[4] == 7)
		local combinedKeys: { [string]: boolean } = {}
		local duplicateFound = false
		for seat = 1, 4 do
			for _, t in ipairs(hands[seat]) do
				local k = DominoLogic.TileKey(t)
				if combinedKeys[k] then duplicateFound = true end
				combinedKeys[k] = true
			end
		end
		assertTest("L03", "Deal", allSeven and not duplicateFound, "4 tangan x 7 tanpa duplikat")
	end

	-- L04: Pembuka ronde 1 - pemegang 6-6, hanya [6-6] legal
	do
		local hands: { [number]: { Tile } } = {
			[1] = { { a = 0, b = 1 }, { a = 2, b = 3 } },
			[2] = { { a = 6, b = 6 }, { a = 1, b = 1 } },
			[3] = { { a = 4, b = 5 } },
			[4] = { { a = 0, b = 0 } },
		}
		local game = DominoLogic.NewGame("2v2")
		game.roundNumber = 1
		local openerResult = DominoLogic.ChooseOpener(game, hands, rng)
		local openingMoves = DominoLogic.GetOpeningMoves(hands[2], true)
		local onlySixSix = (#openingMoves == 1 and openingMoves[1].tile.a == 6 and openingMoves[1].tile.b == 6)
		assertTest("L04", "PembukaRonde1", openerResult.seat == 2 and not openerResult.reshuffle and onlySixSix, "Kursi 2 pemegang 6-6 membuka hanya dengan [6-6]")
	end

	-- L05: Pembuka ronde >= 2 - hanya balak yang legal
	do
		local hand = { { a = 1, b = 2 }, { a = 3, b = 3 }, { a = 5, b = 5 }, { a = 0, b = 4 } }
		local moves = DominoLogic.GetOpeningMoves(hand, false)
		local validDoubles = true
		for _, m in ipairs(moves) do
			if m.tile.a ~= m.tile.b then validDoubles = false end
		end
		assertTest("L05", "PembukaRonde2_HanyaBalak", #moves == 2 and validDoubles, "Hanya balak [3-3] dan [5-5] legal")
	end

	-- L06: Pembuka tanpa balak -> pemain berikut punya (R8)
	do
		local hands: { [number]: { Tile } } = {
			[1] = { { a = 0, b = 1 } },
			[2] = { { a = 1, b = 2 } },
			[3] = { { a = 2, b = 3 }, { a = 0, b = 4 } }, -- Kursi 3 menang sebelumnya tapi tanpa balak
			[4] = { { a = 5, b = 5 }, { a = 2, b = 3 } }, -- Kursi 4 punya balak 5-5
		}
		local game = DominoLogic.NewGame("2v2")
		game.roundNumber = 2
		game.starterSeat = 3
		local res = DominoLogic.ChooseOpener(game, hands, rng)
		assertTest("L06", "PembukaTanpaBalak_PemainBerikut", res.seat == 4 and not res.reshuffle, "Kursi 4 harus membuka karena kursi 3 tanpa balak")
	end

	-- L07: Dua pemain tanpa balak -> reshuffle, dicek ulang dari pembuka sama
	do
		local hands: { [number]: { Tile } } = {
			[1] = { { a = 1, b = 1 } }, -- Pemain 1 punya balak
			[2] = { { a = 2, b = 2 } }, -- Pemain 2 punya balak
			[3] = { { a = 0, b = 1 } }, -- Pemain 3 tanpa balak (starter)
			[4] = { { a = 0, b = 2 } }, -- Pemain 4 tanpa balak (berikutnya)
		}
		local game = DominoLogic.NewGame("2v2")
		game.roundNumber = 2
		game.starterSeat = 3
		local res = DominoLogic.ChooseOpener(game, hands, rng)
		assertTest("L07", "DuaPemainTanpaBalak_Reshuffle", res.seat == nil and res.reshuffle == true, "Wajib reshuffle jika kursi 3 & 4 tanpa balak")
	end

	-- L08: Pemain 3 dan 4 tidak dicek
	do
		local hands: { [number]: { Tile } } = {
			[1] = { { a = 0, b = 1 } }, -- starter 1 tanpa balak
			[2] = { { a = 0, b = 2 } }, -- berikut 2 tanpa balak
			[3] = { { a = 6, b = 6 } }, -- pemain 3 punya 6-6
			[4] = { { a = 5, b = 5 } }, -- pemain 4 punya 5-5
		}
		local game = DominoLogic.NewGame("2v2")
		game.roundNumber = 2
		game.starterSeat = 1
		local res = DominoLogic.ChooseOpener(game, hands, rng)
		assertTest("L08", "Pemain3Dan4TidakDicek", res.seat == nil and res.reshuffle == true, "Reshuffle walau pemain 3 & 4 punya balak")
	end

	-- L09: Pasang kartu cocok - board diperbarui
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 6 }, { a = 6, b = 2 } },
			[2] = { { a = 2, b = 5 } },
			[3] = {}, [4] = {}
		})
		-- Langkah 1: Kursi 1 pasang 6-6
		local ok1 = DominoLogic.ApplyMove(round, 1, { a = 6, b = 6 }, "center")
		-- Langkah 2: Kursi 2 pasang 2-5 pada board [6, 6] (tidak cocok) -> harus ditolak
		local badMove = DominoLogic.ApplyMove(round, 2, { a = 2, b = 5 }, "left")
		-- Pasang kartu cocok 6-2 (simulasikan kursi 2 punya 6-3)
		round.hands[2] = { { a = 3, b = 6 } }
		local ok2 = DominoLogic.ApplyMove(round, 2, { a = 3, b = 6 }, "left")
		assertTest("L09", "PasangKartuCocok", ok1 and not badMove and ok2 and round.board.left == 3 and round.board.right == 6, "Board diperbarui menjadi left 3, right 6")
	end

	-- L10: Pasang kartu tidak cocok - ditolak, state utuh
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 6 } },
			[2] = { { a = 1, b = 2 } },
			[3] = {}, [4] = {}
		})
		DominoLogic.ApplyMove(round, 1, { a = 6, b = 6 }, "center")
		local handBefore = #round.hands[2]
		local ok, err = DominoLogic.ApplyMove(round, 2, { a = 1, b = 2 }, "left")
		local handAfter = #round.hands[2]
		assertTest("L10", "PasangTidakCocok_Ditolak", not ok and err == "TILE_DOES_NOT_MATCH_END" and handBefore == handAfter and round.currentSeat == 2, "Ditolak dan state tidak berubah")
	end

	-- L11: Balak pasang - ujung = angka balak
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 3, b = 3 } },
			[2] = { { a = 3, b = 5 } },
			[3] = { { a = 5, b = 5 } },
			[4] = {},
		})
		DominoLogic.ApplyMove(round, 1, { a = 3, b = 3 }, "center")
		DominoLogic.ApplyMove(round, 2, { a = 3, b = 5 }, "right") -- board: left 3, right 5
		DominoLogic.ApplyMove(round, 3, { a = 5, b = 5 }, "right") -- pasang balak 5-5 di right
		assertTest("L11", "BalakPasang_UjungTetap", round.board.right == 5, "Ujung kanan tetap 5 setelah pasang balak 5-5")
	end

	-- L12: Dua sisi valid - kedua langkah dikembalikan
	do
		local board: Types.Board = {
			placed = {
				{ tile = { a = 3, b = 3 }, side = "center", isDouble = true, endLeft = 3, endRight = 3 }
			},
			left = 3,
			right = 3,
		}
		local hand = { { a = 2, b = 3 } }
		local moves = DominoLogic.GetPlayableMoves(hand, board)
		assertTest("L12", "DuaSisiValid", #moves == 2, "Kartu 2-3 dapat dipasang di left dan right")
	end

	-- L13: Pas dengan langkah legal - ditolak (R9)
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 6 } },
			[2] = { { a = 6, b = 3 } }, -- punya kartu cocok
			[3] = {}, [4] = {}
		})
		DominoLogic.ApplyMove(round, 1, { a = 6, b = 6 }, "center")
		local ok, err = DominoLogic.Pass(round, 2)
		assertTest("L13", "PasDenganLangkahLegal_Ditolak", not ok and err == "HAS_LEGAL_MOVES" and round.currentSeat == 2, "Pas ditolak jika ada langkah legal")
	end

	-- L14: Pas tanpa langkah - diterima, passStreak naik
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 6 } },
			[2] = { { a = 1, b = 2 } }, -- tidak ada kartu cocok dengan 6
			[3] = {}, [4] = {}
		})
		DominoLogic.ApplyMove(round, 1, { a = 6, b = 6 }, "center")
		local ok = DominoLogic.Pass(round, 2)
		assertTest("L14", "PasTanpaLangkah_Diterima", ok and round.passStreak == 1 and round.passCount[2] == 1 and round.currentSeat == 3, "Pas diterima dan passStreak naik")
	end

	-- L15: 4 pas beruntun - blocked
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 6 } },
			[2] = { { a = 1, b = 2 } },
			[3] = { { a = 1, b = 3 } },
			[4] = { { a = 1, b = 4 } },
		})
		DominoLogic.ApplyMove(round, 1, { a = 6, b = 6 }, "center")
		-- Semua pemain pas 4x
		round.hands[1] = { { a = 1, b = 5 } } -- k1 tidak cocok lagi
		DominoLogic.Pass(round, 2)
		DominoLogic.Pass(round, 3)
		DominoLogic.Pass(round, 4)
		DominoLogic.Pass(round, 1)
		local endStatus = DominoLogic.CheckRoundEnd(round)
		assertTest("L15", "EmpatPasBeruntun_Blocked", endStatus == "blocked" and round.passStreak == 4, "Ronde berakhir buntu (blocked)")
	end

	-- L16: Habis - emptied
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 6 } },
			[2] = { { a = 6, b = 1 } },
			[3] = {}, [4] = {}
		})
		DominoLogic.ApplyMove(round, 1, { a = 6, b = 6 }, "center")
		local endStatus = DominoLogic.CheckRoundEnd(round)
		assertTest("L16", "KartuHabis_Emptied", endStatus == "emptied", "Ronde berakhir emptied")
	end

	-- L17: Buntu terendah - R5, R4 (titik terendah menang)
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 2, b = 1 } }, -- titik 3
			[2] = { { a = 2, b = 3 } }, -- titik 5
			[3] = { { a = 4, b = 5 } }, -- titik 9
			[4] = { { a = 6, b = 6 } }, -- titik 12
		})
		local res = DominoLogic.ResolveBlocked(round, "solo")
		assertTest("L17", "BuntuTerendah_R5", res.winnerSeat == 1, "Kursi 1 (titik 3) menang atas kursi 2 (titik 5)")
	end

	-- L18: Buntu seri -> pas lebih sedikit - R6
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 2, b = 2 } }, -- titik 4, beda tim (k1)
			[2] = { { a = 1, b = 3 } }, -- titik 4, beda tim (k2)
			[3] = { { a = 5, b = 5 } }, -- titik 10
			[4] = { { a = 6, b = 6 } }, -- titik 12
		})
		round.passCount[1] = 1
		round.passCount[2] = 2
		local res = DominoLogic.ResolveBlocked(round, "2v2")
		assertTest("L18", "BuntuSeri_PasLebihSedikit_R6", res.winnerSeat == 1 and res.reason == "blocked", "Kursi 1 menang karena pas 1x vs kursi 2 pas 2x")
	end

	-- L19: Buntu seri -> pas sama -> cancelled - R6
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 2, b = 2 } }, -- titik 4, tim 1
			[2] = { { a = 1, b = 3 } }, -- titik 4, tim 2
			[3] = { { a = 5, b = 5 } },
			[4] = { { a = 6, b = 6 } },
		})
		round.passCount[1] = 1
		round.passCount[2] = 1
		local res = DominoLogic.ResolveBlocked(round, "2v2")
		assertTest("L19", "BuntuSeri_PasSama_Cancelled_R6", res.reason == "cancelled" and res.winnerSeat == nil, "Ronde dibatalkan (cancelled) jika seri beda tim dengan pas sama")
	end

	-- L20: Seri satu tim - R7
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 2, b = 2 } }, -- titik 4, tim 1 (kursi 1)
			[2] = { { a = 5, b = 5 } }, -- titik 10, tim 2
			[3] = { { a = 1, b = 3 } }, -- titik 4, tim 1 (kursi 3)
			[4] = { { a = 6, b = 6 } }, -- titik 12, tim 2
		})
		round.passCount[1] = 1
		round.passCount[3] = 1
		local res = DominoLogic.ResolveBlocked(round, "2v2")
		assertTest("L20", "SeriSatuTim_R7", res.reason == "blocked" and res.winnerSide == 1 and res.winnerSeat == 1, "Tim 1 menang dan pembuka kursi 1")
	end

	-- L21: Skor tim total > 10 - R1 (+18)
	do
		local game = DominoLogic.NewGame("2v2")
		local round = DominoLogic.NewRound(1, {
			[1] = {}, -- pemenang habis
			[2] = { { a = 2, b = 3 }, { a = 1, b = 1 } }, -- 5 + 2 = 7
			[3] = { { a = 5, b = 5 } }, -- k3 (teman k1), sisa diabaikan
			[4] = { { a = 4, b = 5 }, { a = 0, b = 2 } }, -- 9 + 2 = 11
		})
		local result: Types.RoundResult = {
			reason = "emptied",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 0, [2] = 7, [3] = 10, [4] = 11 },
		}
		local scoreData = DominoLogic.ScoreRound(game, round, result)
		assertTest("L21", "SkorTimTotal_LebihDari10_R1", scoreData.deltas[2] == 18 and scoreData.deltas[1] == 0, "Tim 2&4 mendapat +18, Tim 1&3 mendapat +0")
	end

	-- L22: Skor tim total = 10 - R2 (+0)
	do
		local game = DominoLogic.NewGame("2v2")
		local round = DominoLogic.NewRound(1, { [1] = {}, [2] = {}, [3] = {}, [4] = {} })
		local result: Types.RoundResult = {
			reason = "emptied",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 0, [2] = 4, [3] = 5, [4] = 6 }, -- tim 2&4 = 4+6 = 10
		}
		local scoreData = DominoLogic.ScoreRound(game, round, result)
		assertTest("L22", "SkorTimTotal_Tepat10_R2", scoreData.deltas[2] == 0, "Total 10 mendapat +0")
	end

	-- L23: Skor tim total = 11 - R2 (+11)
	do
		local game = DominoLogic.NewGame("2v2")
		local round = DominoLogic.NewRound(1, { [1] = {}, [2] = {}, [3] = {}, [4] = {} })
		local result: Types.RoundResult = {
			reason = "emptied",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 0, [2] = 5, [3] = 5, [4] = 6 }, -- tim 2&4 = 5+6 = 11
		}
		local scoreData = DominoLogic.ScoreRound(game, round, result)
		assertTest("L23", "SkorTimTotal_11_R2", scoreData.deltas[2] == 11, "Total 11 mendapat +11")
	end

	-- L24: Skor solo per pemain - R3
	do
		local game = DominoLogic.NewGame("solo")
		local round = DominoLogic.NewRound(1, { [1] = {}, [2] = {}, [3] = {}, [4] = {} })
		local result: Types.RoundResult = {
			reason = "blocked",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 3, [2] = 5, [3] = 12, [4] = 9 },
		}
		local scoreData = DominoLogic.ScoreRound(game, round, result)
		-- k1 pemenang (0), k2 (5 <= 10 -> 0), k3 (12 > 10 -> 12), k4 (9 <= 10 -> 0)
		assertTest("L24", "SkorSoloPerPemain_R3", scoreData.deltas[1] == 0 and scoreData.deltas[2] == 0 and scoreData.deltas[3] == 12 and scoreData.deltas[4] == 0, "Solo: k1=0, k2=0, k3=+12, k4=0")
	end

	-- L25: Pemenang tak dapat poin, teman tak dihitung - R1/R4
	do
		local game = DominoLogic.NewGame("2v2")
		local round = DominoLogic.NewRound(1, { [1] = {}, [2] = {}, [3] = {}, [4] = {} })
		local result: Types.RoundResult = {
			reason = "blocked",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 3, [2] = 5, [3] = 9, [4] = 20 },
		}
		local scoreData = DominoLogic.ScoreRound(game, round, result)
		-- k3 (titik 9) teman pemenang k1 diabaikan, tim 2&4 total 25 > 10 -> +25
		assertTest("L25", "TemanPemenangDiabaikan_R4", scoreData.deltas[1] == 0 and scoreData.deltas[2] == 25, "Tim 1&3 tetap 0, Tim 2&4 +25")
	end

	-- L26: Akhir game >= 100 - R10
	do
		local game = DominoLogic.NewGame("2v2")
		game.scores[2] = 92
		DominoLogic.ApplyScore(game, { [1] = 0, [2] = 14 })
		local gameResult = DominoLogic.CheckGameEnd(game)
		assertTest("L26", "AkhirGame_100_R10", gameResult.finished == true and gameResult.losers[1] == 2 and gameResult.ranking[1] == 1 and gameResult.ranking[2] == 2, "Tim 2 kalah dengan akumulasi 106 >= 100")
	end

	-- L27: Solo: dua pemain >= 100 sekaligus (D-02)
	do
		local game = DominoLogic.NewGame("solo")
		game.scores[1] = 20
		game.scores[2] = 30
		game.scores[3] = 95
		game.scores[4] = 90
		DominoLogic.ApplyScore(game, { [1] = 0, [2] = 0, [3] = 15, [4] = 12 })
		-- Skor akhir: k1=20, k2=30, k3=110, k4=102
		local gameResult = DominoLogic.CheckGameEnd(game)
		local losersCount = #gameResult.losers
		local rank1 = gameResult.ranking[1] -- k1 (20)
		local rank2 = gameResult.ranking[2] -- k2 (30)
		local rank3 = gameResult.ranking[3] -- k4 (102)
		local rank4 = gameResult.ranking[4] -- k3 (110)
		assertTest("L27", "Solo_DuaPemain100_D02", gameResult.finished == true and losersCount == 2 and rank1 == 1 and rank2 == 2 and rank3 == 4 and rank4 == 3, "Kedua pemain kalah, diurutkan skor terendah ke tertinggi")
	end

	-- L28: Giliran bukan miliknya - ditolak
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 6 } },
			[2] = { { a = 6, b = 2 } },
			[3] = {}, [4] = {}
		})
		local ok, err = DominoLogic.ApplyMove(round, 2, { a = 6, b = 2 }, "left")
		assertTest("L28", "GiliranBukanMiliknya_Ditolak", not ok and err == "NOT_YOUR_TURN" and round.currentSeat == 1, "Ditolak jika bukan gilirannya")
	end

	-- L29: Tile bukan miliknya - ditolak
	do
		local round = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 6 } },
			[2] = {}, [3] = {}, [4] = {}
		})
		local ok, err = DominoLogic.ApplyMove(round, 1, { a = 1, b = 2 }, "center")
		assertTest("L29", "TileBukanMiliknya_Ditolak", not ok and err == "TILE_NOT_IN_HAND", "Ditolak jika kartu tidak ada di tangan")
	end

	-- L30: Tile token tidak bisa ditebak
	do
		local token1 = DominoLogic.GenerateTileToken(1, 1, rng)
		local token2 = DominoLogic.GenerateTileToken(1, 1, rng)
		local token3 = DominoLogic.GenerateTileToken(2, 1, rng)
		assertTest("L30", "TileTokenUnik", token1 ~= token2 and token1 ~= token3 and #token1 > 5, "Token kartu acak berbeda setiap generate")
	end

	return {
		passed = (failedCount == 0),
		passedCount = passedCount,
		failedCount = failedCount,
		total = #results,
		details = results,
	}
end

return L01_L30_Tests
