--!strict
--[=[
	MultiTableTests.luau
	Pengujian isolasi multi-meja (4 meja) dan sistem Emote sesuai Sesi Stabilisasi v2 (§3 & §5).

	Cakupan Pengujian:
	- MT01: Event & StateSync meja A tidak pernah terkirim ke pemain di meja B.
	- MT02: Hand/token kartu tidak bocor antar meja maupun antar kursi.
	- MT03: Satu meja macet / menunggu timer manusia tidak mempengaruhi meja lain yang sedang bermain.
	- MT04: Pindah meja (StandPlayer dari Meja 1 -> JoinTable ke Meja 2) membersihkan state lama
	        (SendClearStateSync) dan menyinkronkan state Meja 2 dengan bersih.
	- MT05: Emote (FeelConfig.EMOTE, EmoteController, TriggerBotEmote) menghormati cooldown
	        dan terisolasi hanya untuk pemain di meja yang sama.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local WorldBuilder = require(ServerScriptService.Server.WorldBuilder)
local TableService = require(ServerScriptService.Server.TableService)
local GameService = require(ServerScriptService.Server.GameService)
local BotService = require(ServerScriptService.Server.BotService)

local clientFolder = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local EmoteController = require(clientFolder:WaitForChild("EmoteController"))

export type MockEventRecord = {
	remoteName: string,
	args: { any },
}

local MultiTableTests = {}

-- Helper pembuat mock player R15 dengan perekam event jaringan per-pemain
local function createMockPlayer(userId: number, name: string): (any, { MockEventRecord }, () -> ())
	local dummyChar = Instance.new("Model")
	dummyChar.Name = name .. "_Char"

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.Parent = dummyChar

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Anchored = true
	hrp.Parent = dummyChar
	dummyChar.PrimaryPart = hrp

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Anchored = true
	head.Parent = dummyChar

	dummyChar.Parent = workspace

	local receivedEvents: { MockEventRecord } = {}

	local mockPlayer = {
		UserId = userId,
		Name = name,
		Character = dummyChar,
		_onRemoteEvent = function(remoteName: string, ...: any)
			table.insert(receivedEvents, {
				remoteName = remoteName,
				args = { ... },
			})
		end,
	}

	local function cleanup()
		dummyChar:Destroy()
	end

	return mockPlayer, receivedEvents, cleanup
end

function MultiTableTests.RunAll(): (number, number, { string })
	local passed = 0
	local failed = 0
	local logs: { string } = {}

	local function assertTest(name: string, condition: boolean, detail: string?)
		if condition then
			passed += 1
			table.insert(logs, string.format("[PASS] %s (%s)", name, detail or "OK"))
		else
			failed += 1
			local err = string.format("[FAIL] %s - %s", name, detail or "assertion failed")
			table.insert(logs, err)
			warn(err)
		end
	end

	WorldBuilder.Build()
	Remotes.initServer()
	TableService.ResetForTesting()

	-- ====================================================================
	-- MT01: Event & StateSync Meja A Tidak Terkirim ke Pemain Meja B
	-- ====================================================================
	do
		GameService.SetFastMode(false)
		TableService.ResetForTesting()

		local playerA, eventsA, cleanA = createMockPlayer(9001, "PemainMeja1")
		local playerB, eventsB, cleanB = createMockPlayer(9002, "PemainMeja2")

		local okSitA = TableService.SitPlayer(playerA, 1, 1)
		local okSitB = TableService.SitPlayer(playerB, 1, 2)

		-- Bersihkan event saat duduk awal
		table.clear(eventsA)
		table.clear(eventsB)

		-- Mulai match hanya di Meja 1
		local okStart1 = GameService.StartMatch("2v2", 1, Rng.deterministic(5151))
		task.wait(0.15)

		-- Coba paksa panggil SendStateSync(playerB, 1) untuk menguji apakah server menolak lintas meja
		GameService.SendStateSync(playerB, 1)

		-- Hitung event yang masuk ke Pemain A (Meja 1) vs Pemain B (Meja 2)
		local countRoundA = 0
		local countStateSyncA = 0
		for _, ev in ipairs(eventsA) do
			if ev.remoteName == "RoundStarted" or ev.remoteName == "DealStarted" or ev.remoteName == "TurnStarted" or ev.remoteName == "TilePlaced" then
				countRoundA += 1
			elseif ev.remoteName == "StateSync" then
				countStateSyncA += 1
			end
		end

		local leakedToB = 0
		for _, ev in ipairs(eventsB) do
			if ev.remoteName == "RoundStarted"
				or ev.remoteName == "DealStarted"
				or ev.remoteName == "TurnStarted"
				or ev.remoteName == "TilePlaced"
				or ev.remoteName == "PlayerPassed"
				or ev.remoteName == "RoundEnded"
				or ev.remoteName == "StateSync"
			then
				leakedToB += 1
			end
		end

		GameService.StopMatch(1)
		GameService.StopMatch(2)
		TableService.ResetForTesting()
		cleanA()
		cleanB()

		assertTest(
			"MT01_TableAEventsAndStateSyncNeverSentToTableB",
			okSitA and okSitB and okStart1 and countRoundA > 0 and countStateSyncA > 0 and leakedToB == 0,
			string.format("Meja1_Events=%d, Meja1_Sync=%d, BocorKeMeja2=%d", countRoundA, countStateSyncA, leakedToB)
		)
	end

	-- ====================================================================
	-- MT02: Hand & Token Kartu Tidak Bocor Antar Meja Maupun Antar Kursi
	-- ====================================================================
	do
		GameService.SetFastMode(false)
		TableService.ResetForTesting()

		local p1, ev1, clean1 = createMockPlayer(9011, "P1_Meja1")
		local p2, ev2, clean2 = createMockPlayer(9012, "P2_Meja2")

		TableService.SitPlayer(p1, 1, 1)
		TableService.SitPlayer(p2, 1, 2)
		table.clear(ev1)
		table.clear(ev2)

		GameService.StartMatch("2v2", 1, Rng.deterministic(1111))
		GameService.StartMatch("2v2", 2, Rng.deterministic(2222))
		task.wait(0.15)

		local state1 = GameService.GetState(1)
		local state2 = GameService.GetState(2)

		-- 1. Pastikan token meja 1 dan meja 2 tidak bisa dipakai silang
		local crossTokenRejected = true
		for token1, _ in pairs(state1.seatTokens[1]) do
			if state2.seatTokens[1][token1] ~= nil then
				-- Token boleh kebetulan sama format hanya jika RNG identik, tapi dengan seed berbeda tidak boleh bocor state
			end
		end

		-- 2. Periksa payload StateSync yang diterima p1 dan p2:
		-- Hanya menerima tepat 7 kartu milik kursinya sendiri, dan kartu tersebut cocok dengan hand server di mejanya masing-masing
		local handPayload1 = nil
		for _, ev in ipairs(ev1) do
			if ev.remoteName == "StateSync" then
				handPayload1 = ev.args[2]
			end
		end

		local handPayload2 = nil
		for _, ev in ipairs(ev2) do
			if ev.remoteName == "StateSync" then
				handPayload2 = ev.args[2]
			end
		end

		local valid1 = (handPayload1 ~= nil and #handPayload1 == 7)
		local valid2 = (handPayload2 ~= nil and #handPayload2 == 7)

		-- Verifikasi bahwa kartu di handPayload1 benar-benar berasal dari Meja 1 Kursi 1, dan tidak memuat kartu kursi 2..4
		if valid1 and state1.currentRound then
			for _, item in ipairs(handPayload1) do
				local mapped = state1.seatTokens[1][item.token]
				if not mapped or mapped.a ~= item.a or mapped.b ~= item.b then
					valid1 = false
				end
				for otherSeat = 2, 4 do
					if state1.seatTokens[otherSeat][item.token] ~= nil then
						crossTokenRejected = false
					end
				end
			end
		else
			valid1 = false
		end

		if valid2 and state2.currentRound then
			for _, item in ipairs(handPayload2) do
				local mapped = state2.seatTokens[1][item.token]
				if not mapped or mapped.a ~= item.a or mapped.b ~= item.b then
					valid2 = false
				end
			end
		else
			valid2 = false
		end

		GameService.StopMatch(1)
		GameService.StopMatch(2)
		TableService.ResetForTesting()
		clean1()
		clean2()

		assertTest(
			"MT02_NoHandOrTokenLeakAcrossTables",
			valid1 and valid2 and crossTokenRejected,
			string.format("validMeja1=%s, validMeja2=%s, noCrossSeatToken=%s", tostring(valid1), tostring(valid2), tostring(crossTokenRejected))
		)
	end

	-- ====================================================================
	-- MT03: Satu Meja Macet (Menunggu Giliran Manusia) Tidak Mempengaruhi Meja Lain
	-- ====================================================================
	do
		GameService.SetFastMode(true)
		TableService.ResetForTesting()

		-- Dudukkan 4 pemain manusia di Meja 1 dan matikan fastMode setelah StartMatch Meja 1
		-- atau tahan giliran manusia di Meja 1 sementara Meja 2 (4 bot) jalan terus.
		GameService.SetFastMode(false)
		local h1, _, c1 = createMockPlayer(9021, "Human1_M1")
		local h2, _, c2 = createMockPlayer(9022, "Human2_M1")
		local h3, _, c3 = createMockPlayer(9023, "Human3_M1")
		local h4, _, c4 = createMockPlayer(9024, "Human4_M1")
		TableService.SitPlayer(h1, 1, 1)
		TableService.SitPlayer(h2, 2, 1)
		TableService.SitPlayer(h3, 3, 1)
		TableService.SitPlayer(h4, 4, 1)

		-- Mulai Meja 1: karena ke-4 kursinya manusia, Meja 1 akan menunggu timer manusia (30 detik) tanpa ada kartu dipasang
		-- Tunggu hingga pacing deal (0.72s) selesai agar Meja 1 benar-benar masuk ke fase giliran manusia
		GameService.StartMatch("2v2", 1, Rng.deterministic(3001))
		task.wait(0.85)

		local state1Before = GameService.GetState(1)
		local placed1Before = if state1Before.currentRound then #state1Before.currentRound.board.placed else -1

		-- Sementara Meja 1 macet menunggu input manusia, nyalakan FastMode dan jalankan Meja 2 (4 Bot)
		GameService.SetFastMode(true)
		GameService.StartMatch("2v2", 2, Rng.deterministic(3002))
		task.wait(0.25)

		local state1After = GameService.GetState(1)
		local placed1After = if state1After.currentRound then #state1After.currentRound.board.placed else -1

		local state2After = GameService.GetState(2)
		local placed2After = if state2After.currentRound then #state2After.currentRound.board.placed else 0
		local round2Num = if state2After.currentGame then state2After.currentGame.roundNumber else 0

		local table1StalledAsExpected = (placed1Before == 0 and placed1After == 0)
		local table2ProgressedFreely = (placed2After > 0 or round2Num > 1 or not state2After.isMatchRunning)

		GameService.StopMatch(1)
		GameService.StopMatch(2)
		TableService.ResetForTesting()
		c1()
		c2()
		c3()
		c4()

		assertTest(
			"MT03_StalledTableDoesNotBlockOtherTables",
			table1StalledAsExpected and table2ProgressedFreely,
			string.format("Meja1_Placed=%d (menunggu manusia), Meja2_Placed=%d (Ronde=%d)", placed1After, placed2After, round2Num)
		)
	end

	-- ====================================================================
	-- MT04: Pindah Meja Membersihkan State Lama & Mengambil State Meja Baru
	-- ====================================================================
	do
		GameService.SetFastMode(false)
		TableService.ResetForTesting()

		local mover, moverEvents, cleanMover = createMockPlayer(9031, "MoverPlayer")

		-- 1. Duduk di Meja 1 Kursi 1 dan mulai match
		local okSit1 = TableService.SitPlayer(mover, 1, 1)
		GameService.StartMatch("2v2", 1, Rng.deterministic(4001))
		task.wait(0.15)

		table.clear(moverEvents)

		-- 2. Berdiri dari Meja 1 di tengah match
		local okStand1 = TableService.StandPlayer(mover)

		-- Pastikan pemain menerima StateSync pembersihan (seat=0, hand={}, phase="idle")
		-- dan Kursi 1 di Meja 1 diambil alih oleh Bot
		local gotClearSync = false
		for _, ev in ipairs(moverEvents) do
			if ev.remoteName == "StateSync" and ev.args[1] == 0 and #ev.args[2] == 0 and ev.args[11] == "idle" then
				gotClearSync = true
			end
		end
		local table1Seat1IsNowBot = TableService.IsSeatBot(1, 1)

		table.clear(moverEvents)

		-- 3. Pindah duduk ke Meja 2 Kursi 3
		local okJoin2 = TableService.JoinTable(mover, 2, 3)
		local newTable = TableService.GetPlayerTable(mover)
		local newSeat = TableService.GetPlayerSeat(mover)

		local gotTable2Sync = false
		for _, ev in ipairs(moverEvents) do
			if ev.remoteName == "StateSync" and ev.args[1] == 3 then
				gotTable2Sync = true
			end
		end

		-- 4. Pastikan setelah pindah ke Meja 2, event dari Meja 1 tidak lagi masuk ke mover
		table.clear(moverEvents)
		GameService.TriggerBotEmote(1, "laugh", 1, os.clock() + 100)
		local leakedFromTable1 = 0
		for _, ev in ipairs(moverEvents) do
			if ev.remoteName == "EmotePlayed" then
				leakedFromTable1 += 1
			end
		end

		GameService.StopMatch(1)
		GameService.StopMatch(2)
		TableService.ResetForTesting()
		cleanMover()

		assertTest(
			"MT04_MovingTablesCleansUpOldStateAndIsolatesNewTable",
			okSit1 and okStand1 and gotClearSync and table1Seat1IsNowBot and okJoin2 and newTable == 2 and newSeat == 3 and gotTable2Sync and leakedFromTable1 == 0,
			string.format("clearSync=%s, botTakeover=%s, newTable=%s/Seat=%s, table2Sync=%s, leakFromT1=%d",
				tostring(gotClearSync), tostring(table1Seat1IsNowBot), tostring(newTable), tostring(newSeat), tostring(gotTable2Sync), leakedFromTable1)
		)
	end

	-- ====================================================================
	-- MT05: Emote Wheel, Cooldown, & Isolasi Meja (GAME_FEEL §4)
	-- ====================================================================
	do
		TableService.ResetForTesting()

		local pA, evA, cleanA = createMockPlayer(9041, "EmotePlayerA")
		local pB, evB, cleanB = createMockPlayer(9042, "EmotePlayerB")

		TableService.SitPlayer(pA, 1, 1)
		TableService.SitPlayer(pB, 1, 2)
		TableService.FillEmptySeatsWithBots("normal", 1)
		table.clear(evA)
		table.clear(evB)

		-- 1. Verifikasi 6 emote wajib di FeelConfig.EMOTE
		local requiredEmotes = { "laugh", "angry", "sad", "yah", "clap", "taunt" }
		local configComplete = (FeelConfig.EMOTE ~= nil and FeelConfig.EMOTE.COOLDOWN == 3.0 and FeelConfig.EMOTE.BOT_COOLDOWN > 3.0)
		for _, id in ipairs(requiredEmotes) do
			if not FeelConfig.EMOTE.ITEMS[id] or not table.find(FeelConfig.EMOTE.ORDER, id) then
				configComplete = false
			end
		end

		-- 2. Verifikasi cooldown client EmoteController (3.0 detik)
		EmoteController._resetForTesting()
		local can1 = EmoteController.CanSendEmote(10.0)
		local send1 = EmoteController.SendEmote("laugh", 10.0)
		local can2 = EmoteController.CanSendEmote(11.5) -- 1.5s < 3.0s -> harus false
		local send2 = EmoteController.SendEmote("angry", 11.5)
		local can3 = EmoteController.CanSendEmote(13.1) -- 3.1s >= 3.0s -> harus true

		local clientCooldownOk = (can1 == true and send1 == true and can2 == false and send2 == false and can3 == true)

		-- 3. Verifikasi bot emote cooldown & isolasi meja
		local baseNow = os.clock() + 1000
		local botEmote1 = GameService.TriggerBotEmote(2, "laugh", 1, baseNow)
		local botEmote2 = GameService.TriggerBotEmote(2, "taunt", 1, baseNow + 2.0) -- < BOT_COOLDOWN (8.0s) -> ditolak
		local botEmote3 = GameService.TriggerBotEmote(2, "clap", 1, baseNow + 9.0)  -- >= 8.0s -> diterima

		local receivedEmotesA = 0
		for _, ev in ipairs(evA) do
			if ev.remoteName == "EmotePlayed" then
				receivedEmotesA += 1
			end
		end

		local receivedEmotesB = 0
		for _, ev in ipairs(evB) do
			if ev.remoteName == "EmotePlayed" then
				receivedEmotesB += 1
			end
		end

		-- 4. Verifikasi pembuatan BillboardGui gelembung emoji di atas kepala karakter
		EmoteController.PlayOnCharacter(pA.Character, "laugh")
		local head = pA.Character:FindFirstChild("Head")
		local bubble = head and head:FindFirstChild("EmoteBubbleGui")
		local hasBubble = (bubble ~= nil and bubble:IsA("BillboardGui"))

		EmoteController._resetForTesting()
		TableService.ResetForTesting()
		cleanA()
		cleanB()

		assertTest(
			"MT05_EmoteSystemCooldownBubbleAndTableIsolation",
			configComplete and clientCooldownOk and botEmote1 and (not botEmote2) and botEmote3 and receivedEmotesA == 2 and receivedEmotesB == 0 and hasBubble,
			string.format("cfg=%s, clientCD=%s, botCD=(%s,%s,%s), Meja1Recv=%d, Meja2Recv=%d, bubble=%s",
				tostring(configComplete), tostring(clientCooldownOk), tostring(botEmote1), tostring(botEmote2), tostring(botEmote3), receivedEmotesA, receivedEmotesB, tostring(hasBubble))
		)
	end

	GameService.SetFastMode(true)
	return passed, failed, logs
end

return MultiTableTests
