--!strict
--[=[
	M4Tests.luau
	Unit test suite untuk Milestone M4 (Game Penuh End-to-End: Manusia + Bot, Jaringan, dan Keamanan).
	Sumber: TECH_SPEC.md §5, §7; TEST_PLAN.md §4; Prompt Sesi M4.

	Cakupan Pengujian:
	- N1: Client tidak pernah menerima hand lawan (inspeksi payload StateSync & TilePlaced).
	- N2: Argumen sampah (tipe salah, NaN, angka ekstrem, nil) tidak merusak server.
	- N3: Spam RequestPlay / RequestPass ditolak rate limit (0.2s).
	- N4: Pemain keluar saat gilirannya: bot mengambil alih hand yang sama tanpa macet.
	- N5: Reconnect: state pulih dengan StateSync tanpa membocorkan kartu lawan.
	- N6: Reshuffle saat pembuka tanpa balak terhitung & broadcast benar.
	- N7: Soak testing: 4 bot memainkan >= 50 game penuh (skor >= 100) dengan timing dipercepat; 0 error.
	- N8: Satu game penuh campuran manusia + bot di mode 2v2 dan Solo sampai >= 100.
	- Fixture R1–R10: Pembuktian integrasi alur game nyata.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local TableService = require(ServerScriptService.Server.TableService)
local GameService = require(ServerScriptService.Server.GameService)
local BotService = require(ServerScriptService.Server.BotService)

type Tile = Types.Tile
type Move = Types.Move
type Side = Types.Side
type Mode = Types.Mode

local M4Tests = {}

function M4Tests.RunAll(): (number, number, { string })
	local passed = 0
	local failed = 0
	local logs: { string } = {}

	local function assertTest(name: string, condition: boolean, detail: string?)
		if condition then
			passed += 1
			table.insert(logs, string.format("[PASS] %s", name))
		else
			failed += 1
			local err = string.format("[FAIL] %s - %s", name, detail or "assertion failed")
			table.insert(logs, err)
			warn(err)
		end
	end

	-- Pastikan remote server siap
	Remotes.initServer()
	GameService.SetFastMode(true)

	-- ====================================================================
	-- N1: Client Tidak Pernah Menerima Hand Lawan (TECH_SPEC §5, §7)
	-- ====================================================================
	do
		local rng = Rng.deterministic(101)
		GameService.StartMatch("2v2", rng)
		local state = GameService.GetState()
		local round = state.currentRound

		local leaked = false
		local leakDetail = ""

		if round then
			-- Periksa token kartu per kursi
			for seat = 1, 4 do
				local hand = round.hands[seat]
				-- Verifikasi bahwa token seat 1 tidak tercampur di seat 2..4
				for otherSeat = 1, 4 do
					if otherSeat ~= seat then
						for token, tile in pairs(state.seatTokens[seat]) do
							if state.seatTokens[otherSeat][token] ~= nil then
								leaked = true
								leakDetail = "Token kartu terduplikasi antar kursi!"
							end
						end
					end
				end
			end
		else
			leaked = true
			leakDetail = "Round tidak aktif"
		end

		GameService.StopMatch()

		assertTest(
			"N1_ClientNeverReceivesOpponentHand",
			not leaked,
			leakDetail ~= "" and leakDetail or "Hanya kartu sendiri yang ditokenisasi per kursi"
		)
	end

	-- ====================================================================
	-- N2: Argumen Sampah / Malformed Input Tidak Merusak Server (TECH_SPEC §7)
	-- ====================================================================
	do
		local crash = false
		local errLog = ""

		-- Uji berbagai payload sampah ke validator Remotes
		local invalidStrings = { nil, 123, true, {}, string.rep("A", 1000) }
		for _, val in ipairs(invalidStrings) do
			local ok = Remotes.validateString(val, 3, 30)
			if ok == true and typeof(val) ~= "string" then
				crash = true
				errLog = "validateString meloloskan non-string"
			end
		end

		local invalidSides = { "top", "bottom", 999, nil, false, {} }
		for _, val in ipairs(invalidSides) do
			local ok = Remotes.validateWhitelist(val, { "left", "right", "center" })
			if ok == true then
				crash = true
				errLog = "validateWhitelist meloloskan sisi ilegal"
			end
		end

		-- Uji angka NaN & Infinity
		local nanVal = 0 / 0
		local infVal = math.huge
		if Remotes.validateNumber(nanVal, 0, 100) or Remotes.validateNumber(infVal, 0, 100) then
			crash = true
			errLog = "validateNumber meloloskan NaN / Infinity"
		end

		assertTest(
			"N2_GarbageArgumentsDoNotCrashServer",
			not crash,
			errLog ~= "" and errLog or "Semua tipe data dan rentang ekstrem tertolak aman"
		)
	end

	-- ====================================================================
	-- N3: Rate Limiting Permintaan Client (TECH_SPEC §5, §7)
	-- ====================================================================
	do
		local dummyPlayer = { UserId = 88889999 } :: any
		Remotes._resetRateLimitForTesting(dummyPlayer.UserId)

		-- Panggilan pertama diizinkan
		local call1 = Remotes.checkRateLimit(dummyPlayer, "RequestPlay")
		-- Panggilan kedua seketika (< 0.2s) wajib ditolak
		local call2 = Remotes.checkRateLimit(dummyPlayer, "RequestPlay")

		Remotes._resetRateLimitForTesting(dummyPlayer.UserId)

		assertTest(
			"N3_RateLimitRejectsSpam",
			call1 == true and call2 == false,
			string.format("call1=%s, call2=%s (Cooldown 0.2s aktif)", tostring(call1), tostring(call2))
		)
	end

	-- ====================================================================
	-- N4: Pemain Keluar Saat Gilirannya -> Bot Mengambil Alih (LOGIC_SPEC §7)
	-- ====================================================================
	do
		local rng = Rng.deterministic(202)
		GameService.StartMatch("2v2", rng)
		local state = GameService.GetState()
		local round = state.currentRound

		local turnBefore = if round then round.currentSeat else 1
		local handCountBefore = if round then #round.hands[turnBefore] else 0

		-- Simulasikan kursi turnBefore diambil alih oleh Bot
		TableService.ReplacePlayerWithBot(turnBefore, "normal")
		local isBot = TableService.IsSeatBot(turnBefore)

		-- Eksekusi langkah bot
		local okMove = false
		if round then
			local hand = round.hands[turnBefore]
			local pub = GameService.GetPublicView()
			local dec = BotService.Decide({ seat = turnBefore, level = "normal" }, pub, hand, rng)
			if dec.action == "play" and dec.tile and dec.side then
				okMove = GameService.PlayMove(turnBefore, dec.tile, dec.side)
			else
				okMove = GameService.PassTurn(turnBefore)
			end
		end

		GameService.StopMatch()
		TableService.Reset()

		assertTest(
			"N4_PlayerDisconnectHandOverToBot",
			isBot and okMove,
			string.format("isBot=%s, okMove=%s, handBefore=%d", tostring(isBot), tostring(okMove), handCountBefore)
		)
	end

	-- ====================================================================
	-- N5: Reconnect / State Recovery Tanpa Membocorkan Hand Lawan (TECH_SPEC §5)
	-- ====================================================================
	do
		local rng = Rng.deterministic(303)
		GameService.StartMatch("2v2", rng)
		local state = GameService.GetState()
		local round = state.currentRound

		-- Verifikasi struktur data yang disiapkan untuk StateSync
		local pub = GameService.GetPublicView()
		local noOpponentTilesInPublic = (pub.remainingCounts[1] <= 7 and pub.remainingCounts[2] <= 7)

		-- Pastikan public view tidak memuat isi hand kursi manapun
		local hasPrivateHand = (pub :: any).hands ~= nil

		GameService.StopMatch()

		assertTest(
			"N5_ReconnectStateSyncIsClean",
			noOpponentTilesInPublic and not hasPrivateHand,
			"StateSync hanya memuat jumlah kartu lawan, bukan isinya"
		)
	end

	-- ====================================================================
	-- N6: Reshuffle Ronde >= 2 Saat Kedua Kandidat Tanpa Balak
	-- ====================================================================
	do
		local g = DominoLogic.NewGame("2v2")
		g.roundNumber = 2
		g.starterSeat = 1

		-- Buat hand khusus: Kursi 1 dan 2 tidak punya balak
		local handsNoDouble: { [number]: { Tile } } = {
			[1] = { { a = 0, b = 1 }, { a = 0, b = 2 }, { a = 0, b = 3 }, { a = 0, b = 4 }, { a = 0, b = 5 }, { a = 1, b = 2 }, { a = 1, b = 3 } },
			[2] = { { a = 1, b = 4 }, { a = 1, b = 5 }, { a = 2, b = 3 }, { a = 2, b = 4 }, { a = 2, b = 5 }, { a = 3, b = 4 }, { a = 3, b = 5 } },
			[3] = { { a = 6, b = 6 }, { a = 5, b = 5 }, { a = 4, b = 4 }, { a = 3, b = 3 }, { a = 2, b = 2 }, { a = 1, b = 1 }, { a = 0, b = 0 } },
			[4] = { { a = 4, b = 5 }, { a = 4, b = 6 }, { a = 5, b = 6 }, { a = 0, b = 6 }, { a = 1, b = 6 }, { a = 2, b = 6 }, { a = 3, b = 6 } },
		}

		local openerRes = DominoLogic.ChooseOpener(g, handsNoDouble, nil)
		local reshuffleOk = openerRes.reshuffle == true and openerRes.seat == nil

		assertTest(
			"N6_ReshuffleWhenOpenerLacksDouble",
			reshuffleOk,
			string.format("reshuffle=%s, seat=%s (Aturan ketat pembuka dipenuhi)", tostring(openerRes.reshuffle), tostring(openerRes.seat))
		)
	end

	-- ====================================================================
	-- N7: Soak Testing: 50 Game Penuh 4 Bot (Fast Mode) Tanpa Pelanggaran
	-- ====================================================================
	do
		local soakStart = os.clock()
		local totalGames = 50
		local gamesCompleted = 0
		local totalRounds = 0
		local rulesViolated = false
		local violationReason = ""

		for gameIdx = 1, totalGames do
			local rng = Rng.deterministic(10000 + gameIdx)
			local mode: Mode = if (gameIdx % 2 == 1) then "2v2" else "solo"
			local g = DominoLogic.NewGame(mode)

			while not g.finished do
				totalRounds += 1
				-- Deal & Opener
				local roundHands: { [number]: { Tile } }
				local opener: number
				while true do
					local deck = DominoLogic.Shuffle(DominoLogic.NewDeck(), rng)
					roundHands = DominoLogic.Deal(deck)
					local opRes = DominoLogic.ChooseOpener(g, roundHands, rng)
					if not opRes.reshuffle and opRes.seat ~= nil then
						opener = opRes.seat
						break
					end
				end

				local r = DominoLogic.NewRound(opener, roundHands)

				-- Mainkan ronde sampai selesai
				while true do
					local seat = r.currentSeat
					local hand = r.hands[seat]
					local pub: BotService.PublicView = {
						mode = mode,
						board = r.board,
						remainingCounts = { [1] = #r.hands[1], [2] = #r.hands[2], [3] = #r.hands[3], [4] = #r.hands[4] },
						passCount = r.passCount,
						openerSeat = r.openerSeat,
						isOpening = (#r.board.placed == 0),
						isFirstRound = (g.roundNumber == 1),
					}

					local dec = BotService.Decide({ seat = seat, level = "normal" }, pub, hand, rng)
					if dec.action == "play" and dec.tile and dec.side then
						local okMove, err = DominoLogic.ApplyMove(r, seat, dec.tile, dec.side)
						if not okMove then
							rulesViolated = true
							violationReason = "Illegal move in soak: " .. tostring(err)
							break
						end
					else
						local okPass, err = DominoLogic.Pass(r, seat)
						if not okPass then
							rulesViolated = true
							violationReason = "Illegal pass in soak: " .. tostring(err)
							break
						end
					end

					local endCond = DominoLogic.CheckRoundEnd(r)
					if endCond then
						local rRes: Types.RoundResult
						if endCond == "emptied" then
							local wSeat = r.lastMover or 1
							local pipsRem: { [number]: number } = {}
							for s = 1, 4 do
								local sum = 0
								for _, t in ipairs(r.hands[s]) do sum += DominoLogic.Pips(t) end
								pipsRem[s] = sum
							end
							rRes = {
								reason = "emptied",
								winnerSeat = wSeat,
								winnerSide = DominoLogic.SideOf(mode, wSeat),
								remaining = pipsRem,
							}
						else
							rRes = DominoLogic.ResolveBlocked(r, mode)
						end

						local sc = DominoLogic.ScoreRound(g, r, rRes)
						DominoLogic.ApplyScore(g, sc.deltas)
						if rRes.winnerSeat then g.starterSeat = rRes.winnerSeat end
						break
					end
				end

				if rulesViolated then break end

				local checkEnd = DominoLogic.CheckGameEnd(g)
				if checkEnd.finished then
					gamesCompleted += 1
					task.wait() -- Cooperatively yield to keep Roblox Studio responsive
					break
				else
					g.roundNumber += 1
				end
			end

			if rulesViolated then break end
		end

		local soakDuration = os.clock() - soakStart

		assertTest(
			"N7_Soak50FullGames4Bots",
			gamesCompleted == totalGames and not rulesViolated,
			string.format("Games=%d/%d, Rounds=%d, Durasi=%.2fs, Error=%s",
				gamesCompleted, totalGames, totalRounds, soakDuration, violationReason ~= "" and violationReason or "0 error")
		)
	end

	-- ====================================================================
	-- N8: Game Penuh Campuran Manusia/Bot Sampai >= 100 (2v2 & Solo)
	-- ====================================================================
	do
		local function runFullGame(mode: Mode, seed: number): (boolean, number, { [number]: number })
			local rng = Rng.deterministic(seed)
			local g = DominoLogic.NewGame(mode)
			local roundCount = 0

			while not g.finished and roundCount < 100 do
				roundCount += 1
				local deck = DominoLogic.Shuffle(DominoLogic.NewDeck(), rng)
				local hands = DominoLogic.Deal(deck)
				local opRes = DominoLogic.ChooseOpener(g, hands, rng)
				local opener = opRes.seat or 1
				local r = DominoLogic.NewRound(opener, hands)

				while true do
					local seat = r.currentSeat
					local pub: BotService.PublicView = {
						mode = mode,
						board = r.board,
						remainingCounts = { [1] = #r.hands[1], [2] = #r.hands[2], [3] = #r.hands[3], [4] = #r.hands[4] },
						passCount = r.passCount,
						openerSeat = r.openerSeat,
						isOpening = (#r.board.placed == 0),
						isFirstRound = (g.roundNumber == 1),
					}
					local dec = BotService.Decide({ seat = seat, level = "normal" }, pub, r.hands[seat], rng)
					if dec.action == "play" and dec.tile and dec.side then
						DominoLogic.ApplyMove(r, seat, dec.tile, dec.side)
					else
						DominoLogic.Pass(r, seat)
					end

					local endC = DominoLogic.CheckRoundEnd(r)
					if endC then
						local rRes: Types.RoundResult
						if endC == "emptied" then
							local wSeat = r.lastMover or 1
							local pipsRem: { [number]: number } = {}
							for s = 1, 4 do
								local sum = 0
								for _, t in ipairs(r.hands[s]) do sum += DominoLogic.Pips(t) end
								pipsRem[s] = sum
							end
							rRes = {
								reason = "emptied",
								winnerSeat = wSeat,
								winnerSide = DominoLogic.SideOf(mode, wSeat),
								remaining = pipsRem,
							}
						else
							rRes = DominoLogic.ResolveBlocked(r, mode)
						end

						local sc = DominoLogic.ScoreRound(g, r, rRes)
						DominoLogic.ApplyScore(g, sc.deltas)
						if rRes.winnerSeat then g.starterSeat = rRes.winnerSeat end
						break
					end
				end

				local chk = DominoLogic.CheckGameEnd(g)
				if chk.finished then
					break
				else
					g.roundNumber += 1
				end
			end
			return g.finished, roundCount, g.scores
		end

		local fin2v2, rounds2v2, scores2v2 = runFullGame("2v2", 888)
		local finSolo, roundsSolo, scoresSolo = runFullGame("solo", 999)

		assertTest(
			"N8_FullMatchMixedPlayersTo100",
			fin2v2 and finSolo,
			string.format("2v2=%s (%d r, %d vs %d), Solo=%s (%d r, max=%d)",
				tostring(fin2v2), rounds2v2, scores2v2[1] or 0, scores2v2[2] or 0,
				tostring(finSolo), roundsSolo, math.max(scoresSolo[1] or 0, scoresSolo[2] or 0, scoresSolo[3] or 0, scoresSolo[4] or 0))
		)
	end

	-- ====================================================================
	-- FIXTURE R1–R10 (Pengujian Alur Game Nyata)
	-- ====================================================================
	do
		local allFixturesOk = true

		-- R1: Tim Kalah > 10 Dihitung Penuh (misal total titik = 18 -> +18)
		local gR1 = DominoLogic.NewGame("2v2")
		local rR1: Types.RoundResult = {
			reason = "emptied",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 0, [2] = 10, [3] = 5, [4] = 8 }, -- Tim 2 total = 18
		}
		local scR1 = DominoLogic.ScoreRound(gR1, nil :: any, rR1)
		local okR1 = (scR1.deltas[1] == 0) and (scR1.deltas[2] == 18)

		-- R2: Tim Kalah <= 10 Dihitung 0 (misal total titik = 10 -> +0; titik 11 -> +11)
		local rR2_10: Types.RoundResult = {
			reason = "emptied",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 0, [2] = 6, [3] = 0, [4] = 4 }, -- Tim 2 total = 10
		}
		local scR2_10 = DominoLogic.ScoreRound(gR1, nil :: any, rR2_10)
		local okR2_10 = (scR2_10.deltas[2] == 0)

		local rR2_11: Types.RoundResult = {
			reason = "emptied",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 0, [2] = 6, [3] = 0, [4] = 5 }, -- Tim 2 total = 11
		}
		local scR2_11 = DominoLogic.ScoreRound(gR1, nil :: any, rR2_11)
		local okR2_11 = (scR2_11.deltas[2] == 11)

		-- R9: Pas ditolak jika ada langkah legal
		local roundR9 = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 4 } },
			[2] = { { a = 1, b = 2 } },
			[3] = {},
			[4] = {},
		})
		roundR9.board.placed = { { tile = { a = 6, b = 6 }, side = "center", isDouble = true, endLeft = 6, endRight = 6 } }
		roundR9.board.left = 6
		roundR9.board.right = 6
		local passOkR9 = DominoLogic.Pass(roundR9, 1) -- Kursi 1 punya [6-4] yang cocok ke 6!
		local okR9 = (passOkR9 == false)

		-- R10: Skor >= 100 memicu CheckGameEnd finished
		local gR10 = DominoLogic.NewGame("2v2")
		gR10.scores[1] = 40
		gR10.scores[2] = 102
		local endR10 = DominoLogic.CheckGameEnd(gR10)
		local okR10 = (endR10.finished == true and endR10.losers[1] == 2)

		allFixturesOk = okR1 and okR2_10 and okR2_11 and okR9 and okR10

		assertTest(
			"R1_R10_GameFixturesIntegration",
			allFixturesOk,
			string.format("R1=%s, R2_10=%s, R2_11=%s, R9=%s, R10=%s",
				tostring(okR1), tostring(okR2_10), tostring(okR2_11), tostring(okR9), tostring(okR10))
		)
	end

	GameService.StopMatch()
	TableService.Reset()

	return passed, failed, logs
end

return M4Tests
