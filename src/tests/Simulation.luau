--!strict
--[=[
	Simulation.luau
	Simulasi massal logika domino (TEST_PLAN.md §2).
	
	Menjalankan 10.000+ ronde per mode (2v2 dan solo):
	- Memverifikasi invarian integritas data (28 kartu unik, skor monoton naik).
	- Fuzzing ribuan input ilegal acak untuk membuktikan state tidak berubah saat ditolak.
	- Pengumpulan data statistik: frekuensi 6-6, laju reshuffle ronde >= 2 vs teori (0.29%),
	  evaluasi peluang balak pemenang (tidak memihak), winrate AI, dan waktu komputasi.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")

local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local Types = require(sharedFolder:WaitForChild("Types"))
local Rng = require(sharedFolder:WaitForChild("Rng"))
local BotService = require(game:GetService("ServerScriptService").Server.BotService)

export type Mode = Types.Mode
export type Tile = Types.Tile
export type RoundState = Types.RoundState
export type GameState = Types.GameState
export type BotProfile = BotService.BotProfile

local Simulation = {}

-- Fungsi utilitas untuk serialisasi state sederhana (memverifikasi invariansi fuzzing)
local function serializeRoundState(round: RoundState): string
	local parts: { string } = {}
	table.insert(parts, string.format("turn:%d|streak:%d|phase:%s", round.currentSeat, round.passStreak, round.phase))
	table.insert(parts, string.format("boardLeft:%s|boardRight:%s|boardPlaced:%d", tostring(round.board.left), tostring(round.board.right), #round.board.placed))
	for seat = 1, 4 do
		local handStr: { string } = {}
		for _, t in ipairs(round.hands[seat]) do
			table.insert(handStr, DominoLogic.TileKey(t))
		end
		table.sort(handStr)
		table.insert(parts, string.format("s%d:%s|pass:%d", seat, table.concat(handStr, ","), round.passCount[seat] or 0))
	end
	return table.concat(parts, "###")
end

--[=[
	Menjalankan simulasi penuh satu mode.
]=]
function Simulation.runSimulation(
	mode: Mode,
	targetRounds: number,
	initialSeed: number,
	yieldInterval: number
): { [string]: any }
	local rng = Rng.deterministic(initialSeed)
	local startTime = os.clock()

	-- Konfigurasi Bot:
	-- Pada 2v2: Tim 1 (Kursi 1 & 3: Normal), Tim 2 (Kursi 2 & 4: Easy)
	-- Pada Solo: Kursi 1 & 2 Normal, Kursi 3 & 4 Easy
	local botProfiles: { [number]: BotProfile } = {
		[1] = { seat = 1, level = "normal" },
		[2] = { seat = 2, level = "easy" },
		[3] = { seat = 3, level = if mode == "2v2" then "normal" else "easy" },
		[4] = { seat = 4, level = "easy" },
	}

	-- Metrik & Statistik
	local completedRounds = 0
	local totalGames = 0
	local roundsInCurrentGame = 0
	local blockedCount = 0
	local emptiedCount = 0
	local cancelledCount = 0
	local reshuffleAttempts = 0
	local totalDealsEvaluated = 0

	-- Statistik Reshuffle Ronde >= 2 vs Teori
	local round2DealsEvaluated = 0
	local round2ReshuffleCount = 0

	-- Statistik 6-6 round 1
	local sixSixHolderCount = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
	local round1Count = 0

	-- Statistik Balak Pemenang vs Rata-rata
	local previousWinnerSeat: number? = nil
	local previousWinnerHasDoubleCount = 0
	local previousWinnerCheckRounds = 0
	local anyPlayerHasDoubleCount = 0
	local anyPlayerCheckCount = 0

	-- Distribusi Skor
	local finalLosingScores: { number } = {}
	local roundDeltasRecord: { number } = {}

	-- Invarian & Fuzzing
	local invariantsViolated = false
	local invariantViolationReason = ""
	local fuzzAttempts = 0
	local fuzzStateViolations = 0

	-- Metrik Performa Bot
	local botDecisionsCount = 0
	local botComputeTimeTotal = 0
	local winsPerSeat = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
	local winsPerSide = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }

	-- Inisialisasi game pertama
	local currentGame = DominoLogic.NewGame(mode)

	while completedRounds < targetRounds do
		roundsInCurrentGame += 1
		local isFirstRound = (currentGame.roundNumber == 1)
		if isFirstRound then
			round1Count += 1
		end

		-- 1. Kocok dan Bagi Kartu (Deal & Opener Resolution)
		local currentHands: { [number]: { Tile } }
		local openerSeat: number
		local reshuffleInThisRound = 0

		while true do
			totalDealsEvaluated += 1
			local deck = DominoLogic.Shuffle(DominoLogic.NewDeck(), rng)
			currentHands = DominoLogic.Deal(deck)

			-- Catat statistik 6-6 pada ronde 1
			if isFirstRound and reshuffleInThisRound == 0 then
				for seat = 1, 4 do
					for _, tile in ipairs(currentHands[seat]) do
						if tile.a == 6 and tile.b == 6 then
							sixSixHolderCount[seat] += 1
							break
						end
					end
				end
			end

			-- Catat statistik balak pada pemenang sebelumnya (ronde >= 2)
			if not isFirstRound and previousWinnerSeat ~= nil and reshuffleInThisRound == 0 then
				previousWinnerCheckRounds += 1
				local winnerHadDouble = false
				for _, t in ipairs(currentHands[previousWinnerSeat]) do
					if DominoLogic.IsDouble(t) then
						winnerHadDouble = true
						break
					end
				end
				if winnerHadDouble then
					previousWinnerHasDoubleCount += 1
				end

				-- Periksa rata-rata semua pemain
				for s = 1, 4 do
					anyPlayerCheckCount += 1
					local pHasDouble = false
					for _, t in ipairs(currentHands[s]) do
						if DominoLogic.IsDouble(t) then
							pHasDouble = true
							break
						end
					end
					if pHasDouble then
						anyPlayerHasDoubleCount += 1
					end
				end
			end

			if not isFirstRound then
				round2DealsEvaluated += 1
			end

			local openerCheck = DominoLogic.ChooseOpener(currentGame, currentHands, rng)
			if not openerCheck.reshuffle and openerCheck.seat ~= nil then
				openerSeat = openerCheck.seat
				break
			else
				reshuffleAttempts += 1
				reshuffleInThisRound += 1
				if not isFirstRound then
					round2ReshuffleCount += 1
				end
				if reshuffleInThisRound > GameConfig.MAX_RESHUFFLE then
					invariantsViolated = true
					invariantViolationReason = "MAX_RESHUFFLE exceeded!"
					break
				end
			end
		end

		if invariantsViolated then break end

		-- 2. Mulai Ronde
		local round = DominoLogic.NewRound(openerSeat, currentHands)
		local knownPassedEnds: { [number]: { [number]: boolean } } = {
			[1] = {}, [2] = {}, [3] = {}, [4] = {}
		}

		-- Mainkan ronde sampai selesai
		local roundFinishedReason: ("emptied" | "blocked" | "cancelled" | nil) = nil

		while roundFinishedReason == nil do
			local seat = round.currentSeat
			local profile = botProfiles[seat]
			local hand = round.hands[seat]

			-- Invarian: Kartu di meja + semua tangan harus tepat 28 kartu unik
			local totalTilesCount = #round.board.placed
			local seenTileKeys: { [string]: boolean } = {}
			for _, p in ipairs(round.board.placed) do
				local k = DominoLogic.TileKey(p.tile)
				if seenTileKeys[k] then
					invariantsViolated = true
					invariantViolationReason = "Duplicate tile on board: " .. k
				end
				seenTileKeys[k] = true
			end
			for s = 1, 4 do
				totalTilesCount += #round.hands[s]
				for _, t in ipairs(round.hands[s]) do
					local k = DominoLogic.TileKey(t)
					if seenTileKeys[k] then
						invariantsViolated = true
						invariantViolationReason = "Duplicate tile in hands: " .. k
					end
					seenTileKeys[k] = true
				end
			end
			if totalTilesCount ~= 28 then
				invariantsViolated = true
				invariantViolationReason = "Tile count invariant failed: " .. tostring(totalTilesCount)
			end

			-- Fuzzing input ilegal acak (verifikasi state tidak berubah sama sekali saat ditolak)
			if rng:NextInteger(1, 15) == 1 and fuzzAttempts < 2500 then
				fuzzAttempts += 1
				local stateBefore = serializeRoundState(round)

				-- Uji 1: Kursi salah (giliran bukan miliknya)
				local wrongSeat = (seat % 4) + 1
				local fOk1 = DominoLogic.ApplyMove(round, wrongSeat, { a = 9, b = 9 }, "left")

				-- Uji 2: Kartu tidak ada di tangan
				local fOk2 = DominoLogic.ApplyMove(round, seat, { a = 9, b = 9 }, "left")

				-- Uji 3: Sisi salah (center pada board yang sudah terisi)
				local fOk3 = false
				if #round.board.placed > 0 and #hand > 0 then
					fOk3 = DominoLogic.ApplyMove(round, seat, hand[1], "center")
				end

				-- Uji 4: Pas ilegal saat memiliki langkah legal
				local fOk4 = false
				local playable = DominoLogic.GetPlayableMoves(hand, round.board)
				if #playable > 0 then
					fOk4 = DominoLogic.Pass(round, seat)
				end

				local stateAfter = serializeRoundState(round)
				if fOk1 or fOk2 or fOk3 or fOk4 or (stateBefore ~= stateAfter) then
					fuzzStateViolations += 1
				end
			end

			-- Keputusan Bot
			local publicView: BotService.PublicView = {
				mode = mode,
				board = round.board,
				remainingCounts = {
					[1] = #round.hands[1],
					[2] = #round.hands[2],
					[3] = #round.hands[3],
					[4] = #round.hands[4],
				},
				passCount = round.passCount,
				openerSeat = round.openerSeat,
				isOpening = (#round.board.placed == 0),
				isFirstRound = (currentGame.roundNumber == 1),
				knownPassedEnds = knownPassedEnds,
			}

			local t0 = os.clock()
			local decision = BotService.Decide(profile, publicView, hand, rng)
			local dt = os.clock() - t0
			botDecisionsCount += 1
			botComputeTimeTotal += dt

			if decision.action == "play" and decision.tile and decision.side then
				local ok, err = DominoLogic.ApplyMove(round, seat, decision.tile, decision.side)
				if not ok then
					invariantsViolated = true
					invariantViolationReason = string.format("Bot produced illegal move: %s by seat %d", tostring(err), seat)
					break
				end
			elseif decision.action == "pass" then
				-- Catat ujung board yang tidak bisa dimainkan oleh pemain ini
				if round.board.left ~= nil then
					knownPassedEnds[seat][round.board.left] = true
				end
				if round.board.right ~= nil then
					knownPassedEnds[seat][round.board.right] = true
				end

				local ok, err = DominoLogic.Pass(round, seat)
				if not ok then
					invariantsViolated = true
					invariantViolationReason = string.format("Bot produced illegal pass: %s by seat %d", tostring(err), seat)
					break
				end
			end

			-- Cek apakah ronde selesai
			roundFinishedReason = DominoLogic.CheckRoundEnd(round)
		end

		if invariantsViolated then break end

		-- 3. Penyelesaian Ronde
		local roundResult: Types.RoundResult
		if roundFinishedReason == "emptied" then
			emptiedCount += 1
			local winnerSeat = round.lastMover :: number
			local remainingPips: { [number]: number } = {}
			for s = 1, 4 do
				local p = 0
				for _, t in ipairs(round.hands[s]) do p += DominoLogic.Pips(t) end
				remainingPips[s] = p
			end
			roundResult = {
				reason = "emptied",
				winnerSeat = winnerSeat,
				winnerSide = DominoLogic.SideOf(mode, winnerSeat),
				remaining = remainingPips,
			}
		elseif roundFinishedReason == "blocked" then
			blockedCount += 1
			roundResult = DominoLogic.ResolveBlocked(round, mode)
			if roundResult.reason == "cancelled" then
				cancelledCount += 1
			end
		else
			error("Unrecognized round finish reason")
		end

		-- Hitung Skor Ronde
		local scoreData = DominoLogic.ScoreRound(currentGame, round, roundResult)
		local prevScores: { [number]: number } = {}
		for k, v in pairs(currentGame.scores) do prevScores[k] = v end

		for _, delta in pairs(scoreData.deltas) do
			if delta > 0 then
				table.insert(roundDeltasRecord, delta)
			end
		end

		DominoLogic.ApplyScore(currentGame, scoreData.deltas)

		-- Invarian: Skor tidak pernah menurun
		for k, v in pairs(currentGame.scores) do
			if v < (prevScores[k] or 0) then
				invariantsViolated = true
				invariantViolationReason = "Score decreased!"
			end
		end

		-- Update status pemenang ronde untuk pembuka ronde berikutnya
		if roundResult.winnerSeat ~= nil then
			previousWinnerSeat = roundResult.winnerSeat
			currentGame.starterSeat = roundResult.winnerSeat
			winsPerSeat[roundResult.winnerSeat] += 1
			if roundResult.winnerSide ~= nil then
				winsPerSide[roundResult.winnerSide] += 1
			end
		end

		-- Cek Akhir Game
		local gameEnd = DominoLogic.CheckGameEnd(currentGame)
		if gameEnd.finished then
			totalGames += 1
			for _, loserSide in ipairs(gameEnd.losers) do
				table.insert(finalLosingScores, currentGame.scores[loserSide])
			end
			roundsInCurrentGame = 0
			-- Mulai game baru
			currentGame = DominoLogic.NewGame(mode)
			previousWinnerSeat = nil
		else
			currentGame.roundNumber += 1
		end

		completedRounds += 1

		-- Beri task.wait() berkala di Studio agar tidak memblokir thread
		if completedRounds % yieldInterval == 0 then
			task.wait()
		end
	end

	local elapsed = os.clock() - startTime

	-- Hitung Metrik Statistik
	local avgRoundsPerGame = if totalGames > 0 then (completedRounds / totalGames) else completedRounds
	local pctBlocked = (blockedCount / completedRounds) * 100
	local pctEmptied = (emptiedCount / completedRounds) * 100
	local pctCancelled = (cancelledCount / completedRounds) * 100
	local pctReshuffleRound2 = if round2DealsEvaluated > 0 then (round2ReshuffleCount / round2DealsEvaluated) * 100 else 0

	local sixSixDistribution = {
		seat1Pct = (sixSixHolderCount[1] / math.max(1, round1Count)) * 100,
		seat2Pct = (sixSixHolderCount[2] / math.max(1, round1Count)) * 100,
		seat3Pct = (sixSixHolderCount[3] / math.max(1, round1Count)) * 100,
		seat4Pct = (sixSixHolderCount[4] / math.max(1, round1Count)) * 100,
	}

	local winnerDoublePct = if previousWinnerCheckRounds > 0 then (previousWinnerHasDoubleCount / previousWinnerCheckRounds) * 100 else 0
	local avgPlayerDoublePct = if anyPlayerCheckCount > 0 then (anyPlayerHasDoubleCount / anyPlayerCheckCount) * 100 else 0

	local avgBotComputeMs = if botDecisionsCount > 0 then (botComputeTimeTotal / botDecisionsCount) * 1000 else 0

	local sumDelta = 0
	for _, d in ipairs(roundDeltasRecord) do sumDelta += d end
	local avgDelta = if #roundDeltasRecord > 0 then (sumDelta / #roundDeltasRecord) else 0

	local sumLosingScore = 0
	for _, s in ipairs(finalLosingScores) do sumLosingScore += s end
	local avgLosingScore = if #finalLosingScores > 0 then (sumLosingScore / #finalLosingScores) else 0

	return {
		mode = mode,
		seed = initialSeed,
		completedRounds = completedRounds,
		totalGames = totalGames,
		elapsedSeconds = elapsed,
		avgRoundsPerGame = avgRoundsPerGame,
		pctBlocked = pctBlocked,
		pctEmptied = pctEmptied,
		pctCancelled = pctCancelled,
		pctReshuffleRound2 = pctReshuffleRound2,
		theoreticalReshufflePct = 0.2899,
		sixSixDistribution = sixSixDistribution,
		winnerDoublePct = winnerDoublePct,
		avgPlayerDoublePct = avgPlayerDoublePct,
		doubleHoldingDiff = math.abs(winnerDoublePct - avgPlayerDoublePct),
		avgRoundDelta = avgDelta,
		avgLosingScore = avgLosingScore,
		invariantsPassed = not invariantsViolated and (fuzzStateViolations == 0),
		invariantViolationReason = invariantViolationReason,
		fuzzAttempts = fuzzAttempts,
		fuzzStateViolations = fuzzStateViolations,
		botDecisionsCount = botDecisionsCount,
		avgBotComputeMs = avgBotComputeMs,
		winsPerSeat = winsPerSeat,
		winsPerSide = winsPerSide,
	}
end

return Simulation
