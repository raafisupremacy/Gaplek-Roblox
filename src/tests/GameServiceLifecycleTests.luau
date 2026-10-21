--!strict
--[=[
	GameServiceLifecycleTests.luau
	Suite tes integrasi siklus hidup nyata GameService & verifikasi Batch 1 Blocker Runtime.

	Cakupan pengujian:
	- T01: Siklus nyata Ronde 1 ke Ronde 2 via GameService (tanpa crash CheckGameOver/CheckGameEnd, roundNumber = 1).
	- T02: Ronde 1 hanya boleh dibuka oleh [6-6] (manusia, bot, timeout); ronde >= 2 boleh balak apa saja.
	- T03: Full match 2v2 hingga Game Over (skor >= 100) melalui GameService.
	- T04: Full match Solo hingga Game Over (skor >= 100) melalui GameService.
	- T05: Aturan pembuka ketat: ronde 1 tolak [5-5] ("FIRST_ROUND_MUST_BE_6_6"), ronde >= 2 terima [5-5].
	- T06: Fixture GAME_RULES R1–R10 terintegrasi lewat DominoLogic & GameService.
	- T07: Pencegahan duplikasi listener remote pada GameService.Init().
	- T08: Verifikasi props meja (GelasKopi, Bohlam, Uap, Goyangan) di Meja 1..4 bebas dari zona kartu/rak.
	- T09: Pengukuran memori heap TileFactory selama 20 ronde (bebas GC churn).
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local Types = require(sharedFolder:WaitForChild("Types"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local TablePropsHelper = require(sharedFolder:WaitForChild("TablePropsHelper"))
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))

local serverFolder = ServerScriptService:WaitForChild("Server")
local GameService = require(serverFolder:WaitForChild("GameService"))
local TableService = require(serverFolder:WaitForChild("TableService"))

local GameServiceLifecycleTests = {}

function GameServiceLifecycleTests.RunAll(): (boolean, number, number, { string })
	local logs: { string } = {}
	local passedCount = 0
	local failedCount = 0

	local function assertTest(name: string, condition: boolean, errorMsg: string?)
		if condition then
			passedCount += 1
			table.insert(logs, string.format("[PASS] %s", name))
		else
			failedCount += 1
			local detail = errorMsg or "Assertion failed"
			table.insert(logs, string.format("[FAIL] %s: %s", name, detail))
		end
	end

	-- Inisialisasi Service dan aktifkan fastMode agar bot bergerak instan dalam testing
	Remotes.initServer()
	TableService.Init()
	GameService.Init()
	GameService.SetFastMode(true)
	for tid = 1, 4 do
		GameService.StopMatch(tid)
	end
	TableService.ResetForTesting()

	-- ====================================================================
	-- T01: Verifikasi Siklus Ronde 1 Menuju Ronde 2 Melalui GameService
	-- ====================================================================
	do
		local tid = 2
		GameService.StopMatch(tid)
		TableService.ResetForTesting()

		local startOk, startErr = GameService.StartMatch("2v2", tid)
		assertTest("T01_StartMatchAccepted", startOk == true, startErr)

		local state = GameService.GetState(tid)
		local initialRoundNum = if state.currentGame then state.currentGame.roundNumber else -1
		assertTest("T01_FirstRoundIsRoundNumberOne", initialRoundNum == 1, string.format("Ronde awal adalah %d (seharusnya 1)", initialRoundNum))

		local startTime = os.clock()
		local round1Ended = false
		local round2Started = false

		while (os.clock() - startTime) < 8.0 do
			task.wait(0.05)
			local s = GameService.GetState(tid)
			if s.currentGame then
				if s.currentPhase == "round_end" then
					round1Ended = true
				end
				if s.currentGame.roundNumber >= 2 and s.isMatchRunning then
					round1Ended = true
					round2Started = true
					break
				end
			end
		end

		assertTest(
			"T01_Round1CompletesAndTransitionsToRound2",
			round1Ended and round2Started,
			string.format("Transisi gagal: round1Ended=%s, round2Started=%s (Waktu: %.2f s)", tostring(round1Ended), tostring(round2Started), os.clock() - startTime)
		)

		GameService.StopMatch(tid)
	end

	-- ====================================================================
	-- T02: Verifikasi Ronde 1 Hanya Boleh Dibuka Oleh [6-6]
	-- ====================================================================
	do
		local tid = 3
		GameService.StopMatch(tid)
		TableService.ResetForTesting()

		local startOk = GameService.StartMatch("2v2", tid)
		local s = GameService.GetState(tid)
		local openerTileStr = ""
		local waitStart = os.clock()

		while (os.clock() - waitStart) < 4.0 do
			task.wait(0.05)
			s = GameService.GetState(tid)
			if s.currentRound and #s.currentRound.board.placed > 0 then
				local firstCard = s.currentRound.board.placed[1].tile
				openerTileStr = string.format("%d-%d", firstCard.a, firstCard.b)
				break
			end
		end

		assertTest(
			"T02_Round1OpenedWithDoubleSixOnly",
			openerTileStr == "6-6",
			string.format("Pembuka ronde 1 adalah [%s] (Wajib [6-6] sesuai GAME_RULES.md §4)", openerTileStr)
		)

		GameService.StopMatch(tid)
	end

	-- ====================================================================
	-- T03: Full Match Hingga Game Over Melalui GameService (Mode 2v2)
	-- ====================================================================
	do
		local tid = 4
		GameService.StopMatch(tid)
		TableService.ResetForTesting()

		local startOk = GameService.StartMatch("2v2", tid)
		local matchStartTime = os.clock()
		local matchFinished = false
		local s = GameService.GetState(tid)

		while (os.clock() - matchStartTime) < 28.0 do
			task.wait(0.05)
			s = GameService.GetState(tid)
			if s.currentPhase == "game_ended" or (s.currentGame and s.currentGame.finished) then
				matchFinished = true
				break
			end
		end

		local maxScore = 0
		if s.currentGame then
			for _, sc in pairs(s.currentGame.scores) do
				if sc > maxScore then maxScore = sc end
			end
		end

		assertTest(
			"T03_FullMatch2v2CompletesToGameOver",
			matchFinished and maxScore >= GameConfig.TARGET_SCORE,
			string.format("Match 2v2 tidak selesai tuntas: finished=%s, maxScore=%d/100 (Waktu: %.2f s)", tostring(matchFinished), maxScore, os.clock() - matchStartTime)
		)

		GameService.StopMatch(tid)
	end

	-- ====================================================================
	-- T04: Full Match Hingga Game Over Melalui GameService (Mode Solo)
	-- ====================================================================
	do
		local tid = 4
		GameService.StopMatch(tid)
		TableService.ResetForTesting()

		local startOk = GameService.StartMatch("solo", tid)
		local matchStartTime = os.clock()
		local matchFinished = false
		local s = GameService.GetState(tid)

		while (os.clock() - matchStartTime) < 70.0 do
			task.wait(0.05)
			s = GameService.GetState(tid)
			if s.currentPhase == "game_ended" or (s.currentGame and s.currentGame.finished) then
				matchFinished = true
				break
			end
		end

		local maxScore = 0
		if s.currentGame then
			for _, sc in pairs(s.currentGame.scores) do
				if sc > maxScore then maxScore = sc end
			end
		end

		assertTest(
			"T04_FullMatchSoloCompletesToGameOver",
			matchFinished and maxScore >= GameConfig.TARGET_SCORE,
			string.format("Match Solo tidak selesai tuntas: finished=%s, maxScore=%d/100 (Waktu: %.2f s)", tostring(matchFinished), maxScore, os.clock() - matchStartTime)
		)

		GameService.StopMatch(tid)
	end

	-- ====================================================================
	-- T05: Aturan Pembuka Ketat (Ronde 1 Tolak [5-5], Ronde 2 Terima [5-5])
	-- ====================================================================
	do
		local r1 = DominoLogic.NewRound(1, {
			[1] = { { a = 5, b = 5 }, { a = 6, b = 6 } },
			[2] = {}, [3] = {}, [4] = {},
		})
		-- Pada Ronde 1 (isFirstRound = true), mencoba membuka dengan [5-5] HARUS ditolak
		local okR1Bad, errR1Bad = DominoLogic.ApplyMove(r1, 1, { a = 5, b = 5 }, "center", true)
		local okR1Good, _ = DominoLogic.ApplyMove(r1, 1, { a = 6, b = 6 }, "center", true)

		-- Pada Ronde 2 (isFirstRound = false), membuka dengan [5-5] HARUS diterima
		local r2 = DominoLogic.NewRound(1, {
			[1] = { { a = 5, b = 5 } },
			[2] = {}, [3] = {}, [4] = {},
		})
		local okR2Good, _ = DominoLogic.ApplyMove(r2, 1, { a = 5, b = 5 }, "center", false)

		assertTest(
			"T05_OpeningMovesStrictRules",
			(okR1Bad == false and errR1Bad == "FIRST_ROUND_MUST_BE_6_6" and okR1Good == true and okR2Good == true),
			string.format("Aturan pembuka gagal: okR1Bad=%s, err=%s, okR1Good=%s, okR2Good=%s", tostring(okR1Bad), tostring(errR1Bad), tostring(okR1Good), tostring(okR2Good))
		)
	end

	-- ====================================================================
	-- T06: Fixture GAME_RULES R1–R10 Terintegrasi
	-- ====================================================================
	do
		local allR_Ok = true

		-- R1: Tim kalah > 10 dihitung penuh (misal total = 18 -> +18)
		local gR1 = DominoLogic.NewGame("2v2")
		local resR1: Types.RoundResult = {
			reason = "emptied",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 0, [2] = 10, [3] = 4, [4] = 8 },
		}
		local scR1 = DominoLogic.ScoreRound(gR1, nil :: any, resR1)
		local okR1 = (scR1.deltas[1] == 0 and scR1.deltas[2] == 18)

		-- R2: Tim kalah <= 10 dihitung 0 (+0); total 11 dihitung penuh (+11)
		local resR2_10: Types.RoundResult = {
			reason = "emptied",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 0, [2] = 6, [3] = 0, [4] = 4 },
		}
		local scR2_10 = DominoLogic.ScoreRound(gR1, nil :: any, resR2_10)
		local okR2_10 = (scR2_10.deltas[2] == 0)

		local resR2_11: Types.RoundResult = {
			reason = "emptied",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 0, [2] = 6, [3] = 0, [4] = 5 },
		}
		local scR2_11 = DominoLogic.ScoreRound(gR1, nil :: any, resR2_11)
		local okR2_11 = (scR2_11.deltas[2] == 11)

		-- R3: Solo buntu (3, 5, 12, 9) -> Kursi 1 menang, kursi 2 (+0), kursi 3 (+12), kursi 4 (+0)
		local gR3 = DominoLogic.NewGame("solo")
		local resR3: Types.RoundResult = {
			reason = "blocked",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 3, [2] = 5, [3] = 12, [4] = 9 },
		}
		local scR3 = DominoLogic.ScoreRound(gR3, nil :: any, resR3)
		local okR3 = (scR3.deltas[1] == 0 and scR3.deltas[2] == 0 and scR3.deltas[3] == 12 and scR3.deltas[4] == 0)

		-- R4: 2v2 buntu (3, 5, 9, 20) -> Kursi 1 menang, Tim 2 total 25 -> +25, k3 diabaikan
		local gR4 = DominoLogic.NewGame("2v2")
		local resR4: Types.RoundResult = {
			reason = "blocked",
			winnerSeat = 1,
			winnerSide = 1,
			remaining = { [1] = 3, [2] = 5, [3] = 9, [4] = 20 },
		}
		local scR4 = DominoLogic.ScoreRound(gR4, nil :: any, resR4)
		local okR4 = (scR4.deltas[1] == 0 and scR4.deltas[2] == 25)

		-- R5: Buntu A punya 3, B punya 5 -> A menang
		local rR5 = DominoLogic.NewRound(1, {
			[1] = { { a = 2, b = 1 } },
			[2] = { { a = 2, b = 3 } },
			[3] = { { a = 6, b = 6 } },
			[4] = { { a = 5, b = 5 } },
		})
		local resR5 = DominoLogic.ResolveBlocked(rR5, "solo")
		local okR5 = (resR5.winnerSeat == 1)

		-- R6: Buntu seri beda tim (k1=4, k2=4), pas k1=1, k2=2 -> k1 menang
		local rR6 = DominoLogic.NewRound(1, {
			[1] = { { a = 2, b = 2 } },
			[2] = { { a = 1, b = 3 } },
			[3] = { { a = 5, b = 5 } },
			[4] = { { a = 6, b = 6 } },
		})
		rR6.passCount[1] = 1
		rR6.passCount[2] = 2
		local resR6 = DominoLogic.ResolveBlocked(rR6, "2v2")
		local okR6 = (resR6.winnerSeat == 1 and resR6.winnerSide == 1)

		-- R7: Buntu seri satu tim (k1=4, k3=4) -> tim 1 menang
		local rR7 = DominoLogic.NewRound(1, {
			[1] = { { a = 2, b = 2 } },
			[2] = { { a = 6, b = 5 } },
			[3] = { { a = 1, b = 3 } },
			[4] = { { a = 6, b = 6 } },
		})
		local resR7 = DominoLogic.ResolveBlocked(rR7, "2v2")
		local okR7 = (resR7.winnerSide == 1 and resR7.winnerSeat == 1)

		-- R8: Opener ronde >= 2 (pemenang k3 tanpa balak, k4 punya [5-5] -> k4 pembuka)
		local gR8 = DominoLogic.NewGame("2v2")
		gR8.roundNumber = 2
		gR8.starterSeat = 3
		local handsR8 = {
			[1] = { { a = 1, b = 2 } },
			[2] = { { a = 2, b = 3 } },
			[3] = { { a = 1, b = 4 } }, -- k3 tidak punya balak
			[4] = { { a = 5, b = 5 }, { a = 2, b = 3 } }, -- k4 punya balak 5-5
		}
		local opR8 = DominoLogic.ChooseOpener(gR8, handsR8)
		local okR8 = (opR8.seat == 4 and opR8.reshuffle == false)

		-- R9: Pas ilegal ditolak jika ada kartu yang cocok
		local rR9 = DominoLogic.NewRound(1, {
			[1] = { { a = 6, b = 4 } },
			[2] = {}, [3] = {}, [4] = {},
		})
		rR9.board.placed = { { tile = { a = 6, b = 6 }, side = "center", isDouble = true, endLeft = 6, endRight = 6 } }
		rR9.board.left = 6
		rR9.board.right = 6
		local passOkR9 = DominoLogic.Pass(rR9, 1)
		local okR9 = (passOkR9 == false)

		-- R10: Skor >= 100 memicu CheckGameEnd
		local gR10 = DominoLogic.NewGame("2v2")
		gR10.scores[1] = 50
		gR10.scores[2] = 104
		local endR10 = DominoLogic.CheckGameEnd(gR10)
		local okR10 = (endR10.finished == true and endR10.losers[1] == 2)

		allR_Ok = okR1 and okR2_10 and okR2_11 and okR3 and okR4 and okR5 and okR6 and okR7 and okR8 and okR9 and okR10

		assertTest(
			"T06_FixturesR1_R10_Integration",
			allR_Ok,
			string.format("R1=%s, R2=%s/%s, R3=%s, R4=%s, R5=%s, R6=%s, R7=%s, R8=%s, R9=%s, R10=%s",
				tostring(okR1), tostring(okR2_10), tostring(okR2_11), tostring(okR3), tostring(okR4),
				tostring(okR5), tostring(okR6), tostring(okR7), tostring(okR8), tostring(okR9), tostring(okR10))
		)
	end

	-- ====================================================================
	-- T07: Pencegahan Duplikasi Listener Remote pada GameService.Init()
	-- ====================================================================
	do
		GameService.Init()
		GameService.Init()
		GameService.Init()

		local count = GameService.GetConnectionCount()
		assertTest(
			"T07_RemoteListenersNoLeakOnReInit",
			count == 4,
			string.format("Jumlah listener remote adalah %d (seharusnya tepat 4, tanpa kebocoran)", count)
		)
	end

	-- ====================================================================
	-- T08: Verifikasi Props Meja & Reaksi Lingkungan (Meja 1..4)
	-- ====================================================================
	do
		local allTablesOk = true
		for tid = 1, 4 do
			local tblModel = TablePropsHelper.GetTableModel(tid)
			local cup = TablePropsHelper.GetCoffeeCup(tid)
			local bulb = TablePropsHelper.GetBulb(tid)

			if not tblModel or not cup or not bulb then
				allTablesOk = false
				break
			end

			-- Verifikasi partikel uap pada kopi
			local steam = cup:FindFirstChild("SteamParticle", true)
			if not steam or not steam:IsA("ParticleEmitter") then
				allTablesOk = false
				break
			end

			-- Verifikasi posisi cangkir tidak berada di zona kartu tengah (jarak > 1.8 stud dari pusat)
			local center = tblModel:GetPivot().Position
			local cupDist = (Vector3.new(cup.Position.X, 0, cup.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
			if cupDist < 1.8 then
				allTablesOk = false
				break
			end
		end

		assertTest(
			"T08_TablePropsAndBulbVerification",
			allTablesOk,
			"Objek GelasKopi, Uap, atau Bohlam tidak ditemukan lengkap di Meja 1..4 atau berada di zona kartu"
		)
	end

	-- ====================================================================
	-- T09: Pengukuran Memori Heap TileFactory Selama 20 Ronde
	-- ====================================================================
	do
		local StarterPlayer = game:GetService("StarterPlayer")
		local clientScripts = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
		local TileFactory = require(clientScripts:WaitForChild("TileFactory"))

		local memBefore = gcinfo()

		-- Simulasikan pembuatan dan daur ulang 28 kartu sebanyak 20 ronde
		for round = 1, 20 do
			local roundTiles = {}
			for idx = 1, 28 do
				local a = (idx % 7)
				local b = ((idx * 3) % 7)
				local t = TileFactory.CreateTile(a, b, true)
				table.insert(roundTiles, t)
			end
			for _, t in ipairs(roundTiles) do
				TileFactory.RecycleTile(t)
			end
		end

		local memAfter = gcinfo()
		local memDiffKb = memAfter - memBefore

		-- Pertumbuhan heap harus sangat kecil (< 500 KB setelah 20 ronde daur ulang pool)
		assertTest(
			"T09_TileFactoryMemoryPoolStability",
			memDiffKb < 500,
			string.format("Pertumbuhan memori heap terlalu besar: %d KB (seharusnya < 500 KB)", memDiffKb)
		)
	end

	-- ====================================================================
	-- T10: Verifikasi Logika Pass Pemain (ClientState.CanPass)
	-- ====================================================================
	do
		local StarterPlayer = game:GetService("StarterPlayer")
		local clientScripts = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
		local csClone = clientScripts:WaitForChild("ClientState"):Clone()
		csClone.Parent = clientScripts
		local ClientState = require(csClone)

		-- Kasus 1: Bukan giliran pemain -> canPass harus false
		ClientState.mySeat = 1
		ClientState.currentTurn = 2
		ClientState.myHand = { { token = "t1", tile = { a = 1, b = 2 } } }
		ClientState.boardPlaced = { { tile = { a = 6, b = 6 }, side = "center", isDouble = true, endLeft = 6, endRight = 6 } }
		ClientState.leftEnd = 6
		ClientState.rightEnd = 6
		ClientState.UpdateCanPass()
		assertTest("T10_CannotPassWhenNotMyTurn", ClientState.canPass == false, "canPass harus false saat bukan giliran")

		-- Kasus 2: Giliran sendiri tapi ada kartu cocok -> canPass harus false
		ClientState.currentTurn = 1
		ClientState.myHand = { { token = "t1", tile = { a = 6, b = 3 } }, { token = "t2", tile = { a = 1, b = 2 } } }
		ClientState.UpdateCanPass()
		assertTest("T10_CannotPassWhenHasMatchingTile", ClientState.canPass == false, "canPass harus false saat ada kartu cocok [6-3]")

		-- Kasus 3: Giliran sendiri dan TIDAK ADA kartu cocok -> canPass WAJIB TRUE
		ClientState.leftEnd = 6
		ClientState.rightEnd = 4
		ClientState.myHand = { { token = "t1", tile = { a = 1, b = 2 } }, { token = "t2", tile = { a = 3, b = 5 } } }
		ClientState.UpdateCanPass()
		assertTest("T10_CanPassWhenNoMatchingTiles", ClientState.canPass == true, "canPass harus true saat tidak ada kartu cocok")
		csClone:Destroy()
	end

	-- Matikan fastMode setelah tes selesai
	GameService.SetFastMode(false)
	TableService.ResetForTesting()

	return (failedCount == 0), passedCount, failedCount, logs
end

return GameServiceLifecycleTests
