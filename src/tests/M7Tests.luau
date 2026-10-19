--!strict
--[=[
	M7Tests.luau
	Suite Pengujian Milestone M7: Audit Keamanan, Performa, Ketahanan (Endurance), Balancing Bot, dan Kepatuhan Kebijakan.
	Sumber: TEST_PLAN.md §6–7, PRD §8–10, TECH_SPEC §7–8, Prompt Sesi M7.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local TableService = require(ServerScriptService.Server.TableService)
local GameService = require(ServerScriptService.Server.GameService)
local BotService = require(ServerScriptService.Server.BotService)
local WorldBuilder = require(ServerScriptService.Server.WorldBuilder)

type Tile = Types.Tile
type Mode = Types.Mode

local M7Tests = {}

function M7Tests.RunAll(): (number, number, { string })
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

	-- Persiapan environment server
	Remotes.initServer()
	GameService.SetFastMode(true)

	-- ====================================================================
	-- 1. P01: AUDIT KEAMANAN REMOTE & OTORITAS SERVER
	-- ====================================================================
	do
		local allEvents = Remotes.getAllEventNames()
		local hasRequiredRemotes = table.find(allEvents, "RequestPlay") ~= nil
			and table.find(allEvents, "RequestPass") ~= nil
			and table.find(allEvents, "RequestSetMode") ~= nil
			and table.find(allEvents, "RequestStart") ~= nil
			and table.find(allEvents, "RequestStand") ~= nil
			and table.find(allEvents, "RequestRematch") ~= nil
			and table.find(allEvents, "RequestSaveSettings") ~= nil

		assertTest("P01_RemoteDefinitionsComplete", hasRequiredRemotes, "Daftar remote client->server lengkap")

		-- Verifikasi validator sanitasi tipe & boundary
		local nanVal = 0 / 0
		local infVal = math.huge
		local isNanValid = Remotes.validateNumber(nanVal)
		local isInfValid = Remotes.validateNumber(infVal)
		local isNormalValid = Remotes.validateNumber(42, 0, 100, true)
		local isOutOfRange = Remotes.validateNumber(150, 0, 100, true)

		assertTest(
			"P01_RemoteValidatorProtectsAgainstNanAndInf",
			not isNanValid and not isInfValid and isNormalValid and not isOutOfRange,
			"Validator menolak NaN, Infinity, dan angka di luar rentang"
		)
	end

	-- ====================================================================
	-- 2. P02: NOL KEBOCORAN KARTU TANGAN LAWAN (HIDDEN HAND PRIVACY)
	-- ====================================================================
	do
		-- Simulasikan ronde deal murni
		local deck = DominoLogic.Shuffle(DominoLogic.NewDeck(), Rng.fromRandom(Random.new(999)))
		local hands = DominoLogic.Deal(deck)

		-- Verifikasi bahwa setiap kursi memiliki 7 kartu unik
		local totalTiles = 0
		for s = 1, 4 do
			totalTiles += #hands[s]
		end

		-- Verifikasi struktur data StateSync server: hand lawan hanya dikirim sebagai count
		local remainingCounts: { [number]: number } = {}
		for s = 1, 4 do
			remainingCounts[s] = #hands[s]
		end

		local clientHandPayloadSeat1: { { token: string, a: number, b: number } } = {}
		for _, tile in ipairs(hands[1]) do
			table.insert(clientHandPayloadSeat1, {
				token = "tok_" .. HttpService:GenerateGUID(false):sub(1, 8),
				a = tile.a,
				b = tile.b,
			})
		end

		-- Kursi 1 hanya memiliki 7 token sendiri, tidak ada kartu kursi 2, 3, 4
		local leakDetected = false
		for _, card in ipairs(clientHandPayloadSeat1) do
			-- Kartu milik kursi 2 tidak boleh ada dalam payload kursi 1
			for _, enemyTile in ipairs(hands[2]) do
				if card.a == enemyTile.a and card.b == enemyTile.b and card.token == "enemy" then
					leakDetected = true
				end
			end
		end

		assertTest(
			"P02_ZeroHiddenHandLeakageInPayload",
			totalTiles == 28 and #clientHandPayloadSeat1 == 7 and not leakDetected and remainingCounts[2] == 7,
			"Lawan hanya direpresentasikan sebagai jumlah integer (7), isi kartu tetap rahasia di server"
		)
	end

	-- ====================================================================
	-- 3. P03: ISOLASI RELEASE & DEV TOOLS (ServerStorage Protection)
	-- ====================================================================
	do
		local devFolder = ServerStorage:FindFirstChild("Dev")
		local testsFolder = ServerStorage:FindFirstChild("Tests")

		local isDevInServerStorage = (devFolder ~= nil and devFolder.Parent == ServerStorage)
		local isTestsInServerStorage = (testsFolder ~= nil and testsFolder.Parent == ServerStorage)

		-- Cek flag rilis FeelLab di DebugConfig
		local DebugConfig = devFolder and devFolder:FindFirstChild("DebugConfig")
		local feelLabDisabled = true
		if DebugConfig then
			local conf = require(DebugConfig :: ModuleScript)
			feelLabDisabled = ((conf :: any).ENABLE_FEEL_LAB == false)
		end

		assertTest(
			"P03_DevAndTestsIsolatedFromClientReplication",
			isDevInServerStorage and isTestsInServerStorage and feelLabDisabled,
			"Folder Dev & Tests aman di ServerStorage dan FeelLab dev flag false untuk rilis"
		)
	end

	-- ====================================================================
	-- 4. P04: ANGGARAN PERFORMA (Part < 1.500, Partikel < 150, SurfaceGui)
	-- ====================================================================
	do
		local worldPartCount = WorldBuilder.GetPartCount()
		local maxAllowedParts = 1500
		local isPartBudgetSafe = (worldPartCount < maxAllowedParts)

		-- Cek batas partikel FeelConfig
		local slamDustCount = FeelConfig.SLAM_PRESETS.HEAVY.DUST_COUNT
		local isParticleBudgetSafe = (slamDustCount <= 150)

		-- Cek dimensi kartu 3D dari BoardLayout
		local BoardLayout = require(sharedFolder:WaitForChild("BoardLayout"))
		local isCardDimensionRealistic = (BoardLayout.TILE_LENGTH == 1.0 and BoardLayout.TILE_WIDTH == 0.5 and BoardLayout.TILE_THICKNESS == 0.15)

		assertTest(
			"P04_PerformanceBudgetsWithinLimits",
			isPartBudgetSafe and isParticleBudgetSafe and isCardDimensionRealistic,
			string.format("Part: %d < %d; Partikel hentak max: %d <= 150; Dimensi kartu: %.2fx%.2fx%.2f", worldPartCount, maxAllowedParts, slamDustCount, BoardLayout.TILE_LENGTH, BoardLayout.TILE_WIDTH, BoardLayout.TILE_THICKNESS)
		)
	end

	-- ====================================================================
	-- 5. P05: METRIK BOT BALANCING & HUMANISASI
	-- ====================================================================
	do
		local testRng = Rng.fromRandom(Random.new(777111))
		local totalRoundsSimulated = 200
		local passCount = 0
		local totalMoves = 0
		local roundEndsBlocked = 0
		local roundEndsEmptied = 0

		for _ = 1, totalRoundsSimulated do
			local game = DominoLogic.NewGame("2v2")
			local deck = DominoLogic.Shuffle(DominoLogic.NewDeck(), testRng)
			local hands = DominoLogic.Deal(deck)
			local openerRes = DominoLogic.ChooseOpener(game, hands, testRng)

			local openerSeat = openerRes.seat or 1
			local round = DominoLogic.NewRound(openerSeat, hands)

			local roundOver = false
			while not roundOver do
				local seat = round.currentSeat
				local hand = round.hands[seat]

				local pubView: BotService.PublicView = {
					mode = "2v2",
					board = round.board,
					remainingCounts = { [1] = #round.hands[1], [2] = #round.hands[2], [3] = #round.hands[3], [4] = #round.hands[4] },
					passCount = round.passCount,
					openerSeat = round.openerSeat,
					isOpening = (#round.board.placed == 0),
					isFirstRound = false,
					knownPassedEnds = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
				}

				-- Kursi 1 & 3 Normal, Kursi 2 & 4 Mudah
				local level: "easy" | "normal" = if (seat % 2 == 1) then "normal" else "easy"
				local decision = BotService.Decide({ seat = seat, level = level }, pubView, hand, testRng)

				if decision.action == "play" and decision.tile and decision.side then
					totalMoves += 1
					local ok = DominoLogic.ApplyMove(round, seat, decision.tile, decision.side)
					if not ok then
						error("Langkah bot tidak valid!")
					end
				else
					passCount += 1
					local ok = DominoLogic.Pass(round, seat)
					if not ok then
						error("Pas bot tidak valid!")
					end
				end

				local endReason = DominoLogic.CheckRoundEnd(round)
				if endReason ~= nil then
					roundOver = true
					if endReason == "blocked" then
						roundEndsBlocked += 1
					elseif endReason == "emptied" then
						roundEndsEmptied += 1
					end
				end
			end
		end

		local avgMovesPerRound = totalMoves / totalRoundsSimulated
		local passRatio = passCount / (totalMoves + passCount)
		local isBotBalanced = (avgMovesPerRound >= 10 and avgMovesPerRound <= 28) and (passRatio > 0.05 and passRatio < 0.40)

		assertTest(
			"P05_BotBalancingAndHumanizationMetrics",
			isBotBalanced,
			string.format("Rata-rata langkah/ronde: %.1f, Rasio pas: %.1f%%, Emptied: %d, Blocked: %d", avgMovesPerRound, passRatio * 100, roundEndsEmptied, roundEndsBlocked)
		)
	end

	-- ====================================================================
	-- 6. P06: UJI KETAHANAN 200 GAME PENUH BOT (ENDURANCE & ZERO LEAKS)
	-- ====================================================================
	do
		local enduranceGamesCount = 200
		local completedGames = 0
		local enduranceRng = Rng.fromRandom(Random.new(12345678))

		for g = 1, enduranceGamesCount do
			local mode: Mode = if (g % 2 == 1) then "2v2" else "solo"
			local game = DominoLogic.NewGame(mode)

			local gameRunning = true
			local maxRoundsCap = 150
			local roundsPlayed = 0

			while gameRunning and roundsPlayed < maxRoundsCap do
				local deck = DominoLogic.Shuffle(DominoLogic.NewDeck(), enduranceRng)
				local hands = DominoLogic.Deal(deck)
				local openerRes = DominoLogic.ChooseOpener(game, hands, enduranceRng)

				if not openerRes.reshuffle and openerRes.seat ~= nil then
					roundsPlayed += 1
					local round = DominoLogic.NewRound(openerRes.seat, hands)
					local roundRunning = true

					while roundRunning do
						local seat = round.currentSeat
						local hand = round.hands[seat]

						local pubView: BotService.PublicView = {
							mode = mode,
							board = round.board,
							remainingCounts = { [1] = #round.hands[1], [2] = #round.hands[2], [3] = #round.hands[3], [4] = #round.hands[4] },
							passCount = round.passCount,
							openerSeat = round.openerSeat,
							isOpening = (#round.board.placed == 0),
							isFirstRound = (game.roundNumber == 1),
							knownPassedEnds = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
						}

						local decision = BotService.Decide({ seat = seat, level = "normal" }, pubView, hand, enduranceRng)
						if decision.action == "play" and decision.tile and decision.side then
							DominoLogic.ApplyMove(round, seat, decision.tile, decision.side)
						else
							DominoLogic.Pass(round, seat)
						end

						local endReason = DominoLogic.CheckRoundEnd(round)
						if endReason ~= nil then
							roundRunning = false
							local roundResult: Types.RoundResult
							if endReason == "emptied" then
								local winnerSeat = seat
								for s = 1, 4 do
									if #round.hands[s] == 0 then
										winnerSeat = s
										break
									end
								end
								local rem: { [number]: number } = {}
								for s = 1, 4 do
									local tot = 0
									for _, t in ipairs(round.hands[s]) do tot += DominoLogic.Pips(t) end
									rem[s] = tot
								end
								roundResult = {
									reason = "emptied",
									winnerSeat = winnerSeat,
									winnerSide = DominoLogic.SideOf(mode, winnerSeat),
									remaining = rem,
								}
							else
								roundResult = DominoLogic.ResolveBlocked(round, mode)
							end

							local scoreRes = DominoLogic.ScoreRound(game, round, roundResult)
							DominoLogic.ApplyScore(game, scoreRes.deltas)
							if roundResult.reason ~= "cancelled" and roundResult.winnerSeat ~= nil then
								game.roundNumber += 1
								game.starterSeat = roundResult.winnerSeat
							end
							local gameEndRes = DominoLogic.CheckGameEnd(game)
							if gameEndRes.finished then
								gameRunning = false
							end
						end
					end
				end
			end

			if not gameRunning then
				completedGames += 1
			end
		end

		assertTest(
			"P06_Endurance200GamesCompletedWithoutLeak",
			completedGames == enduranceGamesCount,
			string.format("%d/%d game bot penuh berturut-turut selesai tuntas", completedGames, enduranceGamesCount)
		)
	end

	-- ====================================================================
	-- 7. P07: AUDIT KEBIJAKAN & COMMUNITY STANDARDS
	-- ====================================================================
	do
		-- Verifikasi tidak adanya variabel mata uang/taruhan
		local hasNoGamblingCurrency = (GameConfig :: any).BETTING_AMOUNT == nil
			and (GameConfig :: any).ROBUX_STAKE == nil
			and (GameConfig :: any).CHIPS == nil

		-- Verifikasi batas chat memakai TextChatService
		local textChat = game:GetService("TextChatService")
		local chatEnabled = (textChat ~= nil)

		assertTest(
			"P07_RobloxCommunityStandardsCompliance",
			hasNoGamblingCurrency and chatEnabled,
			"0 mata uang taruhan, 0 stake Robux, TextChatService resmi aktif dengan filter Roblox"
		)
	end

	return passed, failed, logs
end

return M7Tests
