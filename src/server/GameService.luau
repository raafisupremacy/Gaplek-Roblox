--!strict
--[=[
	GameService.luau
	Layanan inti server pengelola siklus pertandingan dan ronde permainan Gaplek multi-room (4 meja).
	Sumber: TECH_SPEC.md §3, §5, §6, §7; LOGIC_SPEC.md §4–7; BOT_SPEC.md §3–4.

	Tanggung Jawab:
	- Mengelola sesi pertandingan independen untuk masing-masing dari 4 meja pos ronda.
	- Menjalankan State Machine pertandingan per meja:
	  Idle -> Dealing -> OpenerCheck -(reshuffle)-> Dealing
	                    └(opener found)-> OpeningMove -> Playing
	  Playing -> (emptied | blocked) -> RoundEnd -> Scoring -> GameEnd | NextRound(Dealing)
	  RoundEnd(blocked + seri) -> Cancelled -> Dealing (pembuka sama)
	- Menggunakan DominoLogic murni apa adanya (nol duplikasi aturan).
	- Mengelola timer giliran (30s) + AutoPlay + AFK Strike handling per meja.
	- Mengatur pacing server menggunakan konstanta FeelConfig.
	- Menjamin keamanan informasi (token acak, 0 kebocoran kartu lawan).
	- Isolasi event jaringan: broadcast game hanya dikirimkan ke pemain yang duduk di meja bersangkutan.
	- Kompatibilitas 100% mundur untuk Table 1 dan seluruh test suite.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local BoardLayout = require(sharedFolder:WaitForChild("BoardLayout"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local Logger = require(script.Parent:WaitForChild("Logger"))
local BotService = require(script.Parent:WaitForChild("BotService"))

type Mode = Types.Mode
type Tile = Types.Tile
type Side = Types.Side
type Placed = Types.Placed
type Board = Types.Board
type RoundState = Types.RoundState
type GameState = Types.GameState
type RoundResult = Types.RoundResult
type GameResult = Types.GameResult
type RngInterface = Rng.RngInterface

export type ClientTilePayload = {
	token: string,
	a: number,
	b: number,
}

export type GameSession = {
	tableId: number,
	sessionId: number,
	currentGame: GameState?,
	currentRound: RoundState?,
	isMatchRunning: boolean,
	currentPhase: string, -- "idle" | "dealing" | "opener_check" | "playing" | "round_end" | "game_ended"
	seatTokens: { [number]: { [string]: Tile } },
	tileToToken: { [number]: { [string]: string } },
	knownPassedEnds: { [number]: { [number]: boolean } },
	afkStrikes: { [number]: number },
	botLastEmoteTime: { [number]: number },
	turnThread: thread?,
	turnDeadline: number,
}

local GameService = {}

local TABLE_COUNT = 4
local sessions: { [number]: GameSession } = {}

-- Inisialisasi struktur sesi game per meja
local function initSession(tableId: number): GameSession
	return {
		tableId = tableId,
		sessionId = 0,
		currentGame = nil,
		currentRound = nil,
		isMatchRunning = false,
		currentPhase = "idle",
		seatTokens = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
		tileToToken = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
		knownPassedEnds = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
		afkStrikes = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 },
		botLastEmoteTime = { [1] = -999, [2] = -999, [3] = -999, [4] = -999 },
		turnThread = nil,
		turnDeadline = 0,
	}
end

for t = 1, TABLE_COUNT do
	sessions[t] = initSession(t)
end

local function getSession(tableId: number?): GameSession
	local tid = tableId or 1
	if not sessions[tid] then
		sessions[tid] = initSession(tid)
	end
	return sessions[tid]
end

-- Generator keacakan server
local serverRng: RngInterface = Rng.fromRandom()

-- Flag Fast Mode untuk unit testing / soak testing (mempercepat jeda & bypass task.wait)
local fastMode = false

-- Forward declaration untuk TableService (di-require lazily untuk menghindari circular require)
local function getTableService()
	return require(script.Parent.TableService)
end

-- ====================================================================
-- BROADCAST HELPER ISOLASI MEJA
-- ====================================================================

--[=[
	Mengirimkan RemoteEvent HANYA ke pemain-pemain yang sedang duduk di meja bersangkutan.
]=]
local function broadcastToTable(tableId: number, remoteName: string, ...: any)
	local TableService = getTableService()
	local occupants = TableService.GetAllOccupants(tableId)
	local rem = Remotes.getEvent(remoteName)
	if not rem then return end

	for s = 1, GameConfig.TOTAL_SEATS do
		local occ = occupants[s]
		if occ then
			if typeof(occ) == "Instance" and occ:IsA("Player") then
				rem:FireClient(occ, ...)
			elseif type(occ) == "table" and type((occ :: any)._onRemoteEvent) == "function" then
				(occ :: any)._onRemoteEvent(remoteName, ...)
			end
		end
	end
end

--[=[
	Memicu emote untuk kursi bot di meja tertentu dengan menghormati FeelConfig.EMOTE.BOT_COOLDOWN.
]=]
function GameService.TriggerBotEmote(seat: number, emoteId: string, tableId: number?, nowTime: number?): boolean
	local tid = tableId or 1
	local session = getSession(tid)
	local TableService = getTableService()
	if not TableService.IsSeatBot(seat, tid) then
		return false
	end
	if not Remotes.validateWhitelist(emoteId, FeelConfig.EMOTE.ORDER) then
		return false
	end
	local now = nowTime or os.clock()
	local lastTime = session.botLastEmoteTime[seat] or -999
	if (now - lastTime) < FeelConfig.EMOTE.BOT_COOLDOWN then
		return false
	end
	session.botLastEmoteTime[seat] = now
	broadcastToTable(tid, "EmotePlayed", seat, emoteId)
	return true
end

-- ====================================================================
-- HELPER TOKENISASI KARTU & PAYLOAD AMAN (TECH_SPEC §5, §7)
-- ====================================================================

local function resetTokens(session: GameSession)
	for s = 1, GameConfig.TOTAL_SEATS do
		table.clear(session.seatTokens[s])
		table.clear(session.tileToToken[s])
	end
end

local function generateTokensForRound(session: GameSession, round: RoundState)
	resetTokens(session)
	for s = 1, GameConfig.TOTAL_SEATS do
		local hand = round.hands[s]
		for idx, tile in ipairs(hand) do
			local token = DominoLogic.GenerateTileToken(s, idx, serverRng)
			session.seatTokens[s][token] = { a = tile.a, b = tile.b }
			session.tileToToken[s][DominoLogic.TileKey(tile)] = token
		end
	end
end

local function getRemainingCounts(round: RoundState): { [number]: number }
	local counts: { [number]: number } = {}
	for s = 1, GameConfig.TOTAL_SEATS do
		counts[s] = if round.hands[s] then #round.hands[s] else 0
	end
	return counts
end

-- Mengambil hand khusus milik pemain lokal (hanya token + nilai kartu sendiri)
local function getClientPrivateHand(session: GameSession, seat: number): { ClientTilePayload }
	local list: { ClientTilePayload } = {}
	if not session.currentRound or not session.currentRound.hands[seat] then
		return list
	end

	for _, tile in ipairs(session.currentRound.hands[seat]) do
		local key = DominoLogic.TileKey(tile)
		local token = session.tileToToken[seat][key] or "token_unknown"
		table.insert(list, {
			token = token,
			a = tile.a,
			b = tile.b,
		})
	end
	return list
end

-- ====================================================================
-- SINKRONISASI STATE (StateSync)
-- ====================================================================

--[=[
	Mengirimkan StateSync ke satu pemain tertentu di meja tempatnya duduk.
	Menjamin isolasi meja: tidak pernah mengirim state meja A ke pemain di meja B.
]=]
function GameService.SendStateSync(player: Player, tableId: number?)
	local isRealPlayer = (typeof(player) == "Instance" and player:IsA("Player"))
	local isMockPlayer = (type(player) == "table" and type((player :: any)._onRemoteEvent) == "function")
	if not isRealPlayer and not isMockPlayer then
		return
	end

	local TableService = getTableService()
	local playerTable = TableService.GetPlayerTable(player)
	local seat = TableService.GetPlayerSeat(player)
	if not playerTable or not seat then
		return
	end
	if tableId ~= nil and tableId ~= playerTable then
		return
	end

	local tid = playerTable
	local session = getSession(tid)
	if TableService.GetOccupant(seat, tid) ~= player then
		return
	end

	local privateHand = getClientPrivateHand(session, seat)
	local remaining = if session.currentRound then getRemainingCounts(session.currentRound) else { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
	local boardPlaced = if session.currentRound then session.currentRound.board.placed else {}
	local leftEnd = if session.currentRound then session.currentRound.board.left else nil
	local rightEnd = if session.currentRound then session.currentRound.board.right else nil
	local currentSeat = if session.currentRound then session.currentRound.currentSeat else 0
	local passStreak = if session.currentRound then session.currentRound.passStreak else 0
	local scores = if session.currentGame then session.currentGame.scores else {}
	local mode = if session.currentGame then session.currentGame.mode else TableService.GetMode(tid)
	local isHost = (TableService.GetHost(tid) == player)

	if isRealPlayer then
		Remotes.getEvent("StateSync"):FireClient(
			player,
			seat,
			privateHand,
			remaining,
			boardPlaced,
			leftEnd,
			rightEnd,
			currentSeat,
			passStreak,
			scores,
			mode,
			session.currentPhase,
			isHost,
			session.turnDeadline
		)
	elseif isMockPlayer then
		(player :: any)._onRemoteEvent(
			"StateSync",
			seat,
			privateHand,
			remaining,
			boardPlaced,
			leftEnd,
			rightEnd,
			currentSeat,
			passStreak,
			scores,
			mode,
			session.currentPhase,
			isHost,
			session.turnDeadline
		)
	end
end

--[=[
	Mengirimkan StateSync bersih (kosong) ke pemain yang baru berdiri / meninggalkan meja.
]=]
function GameService.SendClearStateSync(player: Player)
	local isRealPlayer = (typeof(player) == "Instance" and player:IsA("Player"))
	local isMockPlayer = (type(player) == "table" and type((player :: any)._onRemoteEvent) == "function")
	local emptyCounts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
	if isRealPlayer then
		Remotes.getEvent("StateSync"):FireClient(
			player,
			0,
			{},
			emptyCounts,
			{},
			nil,
			nil,
			0,
			0,
			{},
			"2v2",
			"idle",
			false,
			0
		)
	elseif isMockPlayer then
		(player :: any)._onRemoteEvent(
			"StateSync",
			0,
			{},
			emptyCounts,
			{},
			nil,
			nil,
			0,
			0,
			{},
			"2v2",
			"idle",
			false,
			0
		)
	end
end

--[=[
	Mengirimkan StateSync ke seluruh pemain manusia di meja tertentu.
]=]
function GameService.SendStateSyncAll(tableId: number?)
	local tid = tableId or 1
	local TableService = getTableService()
	for s = 1, GameConfig.TOTAL_SEATS do
		local occupant = TableService.GetOccupant(s, tid)
		if occupant and not TableService.IsSeatBot(s, tid) then
			GameService.SendStateSync(occupant, tid)
		end
	end
end

-- ====================================================================
-- PACING & DELAY HELPER
-- ====================================================================

local function waitPacing(seconds: number)
	if fastMode then
		task.wait()
		return
	end
	task.wait(seconds)
end

-- ====================================================================
-- STATE MACHINE PERTANDINGAN (LOGIC_SPEC §4)
-- ====================================================================

local function stopTurnTimer(session: GameSession)
	local th = session.turnThread
	session.turnThread = nil
	if th and th ~= coroutine.running() then
		pcall(task.cancel, th)
	end
end

-- Forward declarations
local runTurnCycle: (session: GameSession) -> ()
local startNextRound: (session: GameSession) -> ()

--[=[
	Eksekusi AutoPlay jika pemain timeout (afk).
]=]
local function handleTimeout(session: GameSession, seat: number)
	if not session.isMatchRunning or not session.currentRound or session.currentRound.currentSeat ~= seat then
		return
	end

	local TableService = getTableService()
	local tid = session.tableId

	if not TableService.IsSeatBot(seat, tid) then
		session.afkStrikes[seat] = (session.afkStrikes[seat] or 0) + 1
		local occupant = TableService.GetOccupant(seat, tid)
		local playerName = if occupant then occupant.Name else ("Kursi " .. seat)
		Logger.warn("GameService", string.format("[Meja %d] Pemain %s AFK Strike %d/%d.",
			tid, playerName, session.afkStrikes[seat], GameConfig.AFK_STRIKES))

		if session.afkStrikes[seat] >= GameConfig.AFK_STRIKES then
			Logger.warn("GameService", string.format("[Meja %d] Pemain %s digantikan permanen oleh Bot karena AFK.", tid, playerName))
			TableService.ReplacePlayerWithBot(seat, "normal", tid)
		end
	end

	-- Jalankan bot otomatis untuk langkah AutoPlay
	local publicView = GameService.GetPublicView(tid)
	local decision = BotService.DecideMove(seat, session.currentRound.hands[seat], publicView, "normal", serverRng)

	if decision.action == "play" and decision.tile and decision.side then
		GameService.PlayMove(seat, decision.tile, decision.side, tid)
	else
		GameService.PassTurn(seat, tid)
	end
end

--[=[
	Menjalankan satu siklus giliran: memasang timer atau memanggil bot.
]=]
runTurnCycle = function(session: GameSession)
	if not session.isMatchRunning or not session.currentRound then
		return
	end

	stopTurnTimer(session)

	local currentSeat = session.currentRound.currentSeat
	local TableService = getTableService()
	local tid = session.tableId
	local isBot = TableService.IsSeatBot(currentSeat, tid)

	session.turnDeadline = os.time() + GameConfig.TURN_TIME

	-- Broadcast TurnStarted ke meja
	broadcastToTable(tid, "TurnStarted", currentSeat, session.turnDeadline)

	if isBot then
		session.turnThread = task.spawn(function()
			local profile = TableService.GetBotProfile(currentSeat, tid)
			local level = if profile then profile.level else "normal"

			if not fastMode then
				local delaySec = serverRng:NextNumber() * (GameConfig.BOT_THINK_MAX - GameConfig.BOT_THINK_MIN) + GameConfig.BOT_THINK_MIN
				task.wait(delaySec)
			end

			if not session.isMatchRunning or not session.currentRound or session.currentRound.currentSeat ~= currentSeat then
				return
			end

			local publicView = GameService.GetPublicView(tid)
			local decision = BotService.DecideMove(currentSeat, session.currentRound.hands[currentSeat], publicView, level, serverRng)

			if decision.action == "play" and decision.tile and decision.side then
				GameService.PlayMove(currentSeat, decision.tile, decision.side, tid)
			else
				GameService.PassTurn(currentSeat, tid)
			end
		end)
	else
		session.turnThread = task.spawn(function()
			if fastMode then
				handleTimeout(session, currentSeat)
				return
			end

			task.wait(GameConfig.TURN_TIME)
			handleTimeout(session, currentSeat)
		end)
	end
end

--[=[
	Memulai ronde berikutnya dalam pertandingan meja.
]=]
startNextRound = function(session: GameSession)
	if not session.currentGame then return end
	session.currentGame.roundNumber += 1

	local reshuffleCount = 0
	local hands: { [number]: { Tile } }
	local openerSeat: number

	-- Reset riwayat pas per ronde
	for s = 1, GameConfig.TOTAL_SEATS do
		session.knownPassedEnds[s] = {}
	end

	while true do
		local deck = DominoLogic.Shuffle(DominoLogic.NewDeck(), serverRng)
		hands = DominoLogic.Deal(deck)

		local openerResult = DominoLogic.ChooseOpener(session.currentGame, hands, serverRng)
		if not openerResult.reshuffle and openerResult.seat ~= nil then
			openerSeat = openerResult.seat
			break
		else
			reshuffleCount += 1
			Logger.info("GameService", string.format("[Meja %d] Reshuffle ronde %d ke-%d (Pembuka tanpa balak)", session.tableId, session.currentGame.roundNumber, reshuffleCount))
			if reshuffleCount > GameConfig.MAX_RESHUFFLE then
				error("MAX_RESHUFFLE terlampaui.")
			end
		end
	end

	-- Buat state ronde
	session.currentRound = DominoLogic.NewRound(openerSeat, hands)
	session.currentPhase = "playing"

	-- Generate token acak per ronde
	generateTokensForRound(session, session.currentRound)

	Logger.info("GameService", string.format("[Meja %d] Ronde %d dimulai. Opener: Kursi %d. Reshuffles: %d",
		session.tableId, session.currentGame.roundNumber, openerSeat, reshuffleCount))

	-- Broadcast event RoundStarted ke meja
	broadcastToTable(session.tableId, "RoundStarted", session.currentGame.roundNumber, openerSeat, reshuffleCount)

	-- Broadcast event DealStarted (jumlah kartu per kursi)
	broadcastToTable(session.tableId, "DealStarted", getRemainingCounts(session.currentRound))

	-- Kirim StateSync khusus hand masing-masing pemain di meja
	GameService.SendStateSyncAll(session.tableId)

	local mySessionId = session.sessionId

	-- Pacing pembagian kartu
	waitPacing(FeelConfig.DURATIONS.DEAL_INTERVAL * 7 + 0.3)

	if not session.isMatchRunning or session.sessionId ~= mySessionId then
		return
	end

	-- Mulai giliran pertama (pembuka)
	runTurnCycle(session)
end

--[=[
	Menangani akhir satu ronde: penghitungan skor, cek match selesai atau lanjut.
]=]
local function handleRoundEnd(session: GameSession, reason: "emptied" | "blocked")
	session.currentPhase = "round_end"
	stopTurnTimer(session)

	if not session.currentGame or not session.currentRound then return end

	local roundResult: RoundResult
	if reason == "emptied" then
		local winnerSeat = session.currentRound.lastMover or 1
		local winnerSide = DominoLogic.SideOf(session.currentGame.mode, winnerSeat)
		local remainingPips: { [number]: number } = {}
		for s = 1, GameConfig.TOTAL_SEATS do
			local sum = 0
			for _, t in ipairs(session.currentRound.hands[s]) do
				sum += DominoLogic.Pips(t)
			end
			remainingPips[s] = sum
		end

		roundResult = {
			reason = "emptied",
			winnerSeat = winnerSeat,
			winnerSide = winnerSide,
			remaining = remainingPips,
		}
	else
		-- Buntu (blocked)
		roundResult = DominoLogic.ResolveBlocked(session.currentRound, session.currentGame.mode)
	end

	-- Hitung perolehan poin skor ronde ini
	local scoreInfo = DominoLogic.ScoreRound(session.currentGame, session.currentRound, roundResult)
	DominoLogic.ApplyScore(session.currentGame, scoreInfo.deltas)

	-- Tentukan pemenang ronde berikutnya sebagai starterSeat
	if roundResult.winnerSeat then
		session.currentGame.starterSeat = roundResult.winnerSeat
	end

	-- Kumpulkan sisa kartu semua pemain (setelah ronde selesai, kartu terbuka dibuka)
	local revealedHands: { [number]: { Tile } } = {}
	for s = 1, GameConfig.TOTAL_SEATS do
		revealedHands[s] = session.currentRound.hands[s]
	end

	Logger.info("GameService", string.format("[Meja %d] Ronde %d usai (%s). Pemenang: Kursi %s (Pihak %s).",
		session.tableId, session.currentGame.roundNumber, reason, tostring(roundResult.winnerSeat), tostring(roundResult.winnerSide)))

	-- Broadcast RoundEnded ke pemain meja
	broadcastToTable(session.tableId, "RoundEnded",
		reason,
		roundResult.winnerSeat or 0,
		roundResult.winnerSide or 0,
		revealedHands,
		scoreInfo.deltas,
		session.currentGame.scores
	)

	-- Reaksi Kontekstual Bot saat akhir ronde (Grup C — BOT_SPEC §3, GAME_FEEL §4)
	if not fastMode and roundResult.winnerSide ~= nil then
		local TableService = getTableService()
		local tid = session.tableId
		for s = 1, GameConfig.TOTAL_SEATS do
			if TableService.IsSeatBot(s, tid) and serverRng:NextNumber() < FeelConfig.CHARACTER_FEEL.BOT_ROUND_END_REACT_CHANCE then
				local seatSide = DominoLogic.SideOf(session.currentGame.mode, s)
				local isWinner = (seatSide == roundResult.winnerSide)
				local reactEmote = if isWinner
					then (if serverRng:NextInteger(1, 2) == 1 then "clap" else "laugh")
					else (if serverRng:NextInteger(1, 2) == 1 then "sad" else "yah")
				GameService.TriggerBotEmote(s, reactEmote, tid)
			end
		end
	end

	-- Cek apakah game selesai (skor salah satu pihak mencapai >= 100)
	local gameResult = DominoLogic.CheckGameEnd(session.currentGame)
	if gameResult.finished then
		session.currentPhase = "game_ended"
		session.isMatchRunning = false
		local primaryLoser = gameResult.losers[1] or 1
		Logger.info("GameService", string.format("[Meja %d] Pertandingan Selesai! Pihak Kalah: %s (Skor: %d).",
			session.tableId, tostring(primaryLoser), session.currentGame.scores[primaryLoser] or 100))

		broadcastToTable(session.tableId, "GameEnded",
			gameResult.losers,
			gameResult.ranking,
			session.currentGame.scores
		)

		local TableService = getTableService()
		TableService.BroadcastRoomsUpdated()
	else
		-- Pacing sebelum ronde berikutnya
		task.delay(FeelConfig.DURATIONS.ROUND_END_DELAY or 4.0, function()
			if session.isMatchRunning then
				startNextRound(session)
			end
		end)
	end
end

-- ====================================================================
-- TINDAKAN PERMAINAN (PLAY MOVE & PASS)
-- ====================================================================

function GameService.PlayMove(seat: number, tile: Tile, side: Side, tableId: number?): (boolean, string?)
	local tid = tableId or 1
	local session = getSession(tid)

	if not session.isMatchRunning or not session.currentRound then
		return false, "MATCH_NOT_RUNNING"
	end

	-- DominoLogic.ApplyMove memvalidasi giliran, kepemilikan kartu, dan kecocokan board
	local ok, errReason = DominoLogic.ApplyMove(session.currentRound, seat, tile, side)
	if not ok then
		return false, errReason
	end

	-- Reset AFK strike pemain jika berhasil melangkah
	session.afkStrikes[seat] = 0

	-- Hentikan timer giliran
	stopTurnTimer(session)

	local boardPlaced = session.currentRound.board.placed
	local lastPlaced = boardPlaced[#boardPlaced]

	-- Hitung posisi CFrame relatif kartu di meja dari BoardLayout
	local layoutCFrames = BoardLayout.Calculate(boardPlaced)
	local placedRelCF = layoutCFrames[#layoutCFrames] or CFrame.new()

	local isDouble = (tile.a == tile.b)
	local remainingCount = #session.currentRound.hands[seat]

	-- Broadcast TilePlaced ke pemain meja
	broadcastToTable(tid, "TilePlaced",
		seat,
		tile.a,
		tile.b,
		side,
		session.currentRound.board.left,
		session.currentRound.board.right,
		placedRelCF,
		isDouble,
		remainingCount
	)

	-- Jika Bot memasang kartu balak dan bukan fastMode, beri peluang emote kontekstual
	local TableService = getTableService()
	if not fastMode and isDouble and TableService.IsSeatBot(seat, tid) then
		if serverRng:NextNumber() < FeelConfig.EMOTE.BOT_TRIGGER_CHANCE then
			local botEmote = if serverRng:NextInteger(1, 2) == 1 then "laugh" else "taunt"
			GameService.TriggerBotEmote(seat, botEmote, tid)
		end
	end

	-- Pacing animasi pemasangan/hentak kartu
	local waitDuration = if isDouble then FeelConfig.SLAM_TOTAL_TIME else (FeelConfig.DURATIONS.PLACE_NORMAL or 0.25)
	waitPacing(waitDuration)

	-- Periksa kondisi kemenangan atau ronde buntu
	local endCondition = DominoLogic.CheckRoundEnd(session.currentRound)
	if endCondition then
		handleRoundEnd(session, endCondition)
	else
		runTurnCycle(session)
	end

	return true, nil
end

function GameService.PassTurn(seat: number, tableId: number?): (boolean, string?)
	local tid = tableId or 1
	local session = getSession(tid)

	if not session.isMatchRunning or not session.currentRound then
		return false, "MATCH_NOT_RUNNING"
	end

	-- Catat riwayat angka terbuka saat pemain melakukan pas (BOT_SPEC §4) sebelum pass diaplikasikan
	if session.currentRound.board.left ~= nil then
		session.knownPassedEnds[seat][session.currentRound.board.left] = true
	end
	if session.currentRound.board.right ~= nil then
		session.knownPassedEnds[seat][session.currentRound.board.right] = true
	end

	local ok, errReason = DominoLogic.Pass(session.currentRound, seat)
	if not ok then
		return false, errReason
	end

	stopTurnTimer(session)
	session.afkStrikes[seat] = 0

	-- Broadcast PlayerPassed ke pemain meja
	broadcastToTable(tid, "PlayerPassed", seat, session.currentRound.passStreak)

	-- Jika Bot terpaksa pas dan bukan fastMode, beri peluang emote "yah" / "sad"
	local TableService = getTableService()
	if not fastMode then
		if TableService.IsSeatBot(seat, tid) then
			if serverRng:NextNumber() < FeelConfig.EMOTE.BOT_TRIGGER_CHANCE then
				local passEmote = if serverRng:NextInteger(1, 2) == 1 then "yah" else "sad"
				GameService.TriggerBotEmote(seat, passEmote, tid)
			end
		end

		-- Bot lawan menertawakan pemain/bot yang terpaksa pas (BOT_SPEC.md §3: "tertawa saat lawan pas")
		local mode = if session.currentGame then session.currentGame.mode else "2v2"
		local passerSide = DominoLogic.SideOf(mode, seat)
		for otherSeat = 1, GameConfig.TOTAL_SEATS do
			if otherSeat ~= seat and TableService.IsSeatBot(otherSeat, tid) then
				local otherSide = DominoLogic.SideOf(mode, otherSeat)
				if otherSide ~= passerSide and serverRng:NextNumber() < FeelConfig.CHARACTER_FEEL.BOT_OPPONENT_PASS_LAUGH_CHANCE then
					GameService.TriggerBotEmote(otherSeat, "laugh", tid)
					break
				end
			end
		end
	end

	waitPacing((FeelConfig.DURATIONS.KNOCK_PASS or 0.6) + 0.1)

	local endCondition = DominoLogic.CheckRoundEnd(session.currentRound)
	if endCondition then
		handleRoundEnd(session, endCondition)
	else
		runTurnCycle(session)
	end

	return true, nil
end

-- ====================================================================
-- KONTROL MATCH (START, STOP, REMATCH)
-- ====================================================================

function GameService.SetRng(customRng: RngInterface)
	serverRng = customRng
end

function GameService.StartMatch(mode: Mode, arg2: any?, arg3: any?): (boolean, string?)
	local tid = 1
	if type(arg2) == "number" then
		tid = arg2
		if arg3 and type(arg3) == "table" then
			serverRng = arg3
		end
	elseif type(arg2) == "table" then
		serverRng = arg2
		if type(arg3) == "number" then
			tid = arg3
		end
	elseif type(arg3) == "number" then
		tid = arg3
	end

	local session = getSession(tid)

	if session.isMatchRunning then
		return false, "MATCH_ALREADY_RUNNING"
	end

	local TableService = getTableService()
	-- Pastikan kursi kosong terisi oleh Bot
	TableService.FillEmptySeatsWithBots("normal", tid)

	session.sessionId += 1
	session.currentGame = DominoLogic.NewGame(mode)
	session.currentGame.roundNumber = 0 -- startNextRound akan menaikkannya ke 1 untuk ronde pertama
	session.isMatchRunning = true
	session.currentPhase = "dealing"

	for s = 1, GameConfig.TOTAL_SEATS do
		session.afkStrikes[s] = 0
	end

	Logger.info("GameService", string.format("[Meja %d] Match baru dimulai (Mode: %s).", tid, mode))
	TableService.BroadcastRoomsUpdated()

	task.spawn(function()
		startNextRound(session)
	end)

	return true, nil
end

function GameService.StopMatch(tableId: number?)
	local tid = tableId or 1
	local session = getSession(tid)

	stopTurnTimer(session)
	session.sessionId += 1
	session.isMatchRunning = false
	session.currentPhase = "idle"
	session.currentGame = nil
	session.currentRound = nil
	for s = 1, GameConfig.TOTAL_SEATS do
		session.botLastEmoteTime[s] = -999
	end
	resetTokens(session)
	Logger.info("GameService", string.format("[Meja %d] Match dihentikan.", tid))
end

--[=[
	Dipanggil saat kursi pemain yang sedang gilirannya diambil alih oleh Bot (berdiri/keluar).
]=]
function GameService.OnSeatReplacedByBot(tableId: number, seatIndex: number)
	local session = getSession(tableId)
	if session.isMatchRunning and session.currentRound and session.currentRound.currentSeat == seatIndex then
		runTurnCycle(session)
	end
end

-- ====================================================================
-- INISIALISASI & REMOTE EVENTS
-- ====================================================================

function GameService.Init()
	Remotes.initServer()

	-- 1. RequestPlay (Pemasangan kartu dari pemain)
	Remotes.getEvent("RequestPlay").OnServerEvent:Connect(function(player, tileToken, side)
		if not Remotes.checkRateLimit(player, "RequestPlay") then return end
		if not Remotes.validateString(tileToken, 3, 30) then return end
		if not Remotes.validateWhitelist(side, { "left", "right", "center" }) then return end

		local TableService = getTableService()
		local tid = TableService.GetPlayerTable(player) or 1
		local seat = TableService.GetPlayerSeat(player)
		local session = getSession(tid)
		if not seat or not session.currentRound then return end

		-- Validasi token milik kursi pemain
		local tile = session.seatTokens[seat][tileToken]
		if not tile then
			Remotes.getEvent("Rejected"):FireClient(player, "TILE_NOT_IN_HAND")
			return
		end

		local ok, err = GameService.PlayMove(seat, tile, side :: any, tid)
		if not ok and err then
			Remotes.getEvent("Rejected"):FireClient(player, err)
		end
	end)

	-- 2. RequestPass (Permintaan pas dari pemain)
	Remotes.getEvent("RequestPass").OnServerEvent:Connect(function(player)
		if not Remotes.checkRateLimit(player, "RequestPass") then return end

		local TableService = getTableService()
		local tid = TableService.GetPlayerTable(player) or 1
		local seat = TableService.GetPlayerSeat(player)
		local session = getSession(tid)
		if not seat or not session.currentRound then return end

		local ok, err = GameService.PassTurn(seat, tid)
		if not ok and err then
			Remotes.getEvent("Rejected"):FireClient(player, err)
		end
	end)

	-- 3. RequestEmote (Emote ekspresi dari pemain)
	Remotes.getEvent("RequestEmote").OnServerEvent:Connect(function(player, emoteId)
		if not Remotes.checkRateLimit(player, "RequestEmote") then return end
		if not Remotes.validateString(emoteId, 1, 20) then return end
		if not Remotes.validateWhitelist(emoteId, FeelConfig.EMOTE.ORDER) then return end

		local TableService = getTableService()
		local tid = TableService.GetPlayerTable(player)
		local seat = TableService.GetPlayerSeat(player)
		if not tid or not seat then return end

		-- Broadcast EmotePlayed hanya ke pemain di meja yang sama
		broadcastToTable(tid, "EmotePlayed", seat, emoteId)
	end)

	-- 4. Listener saat pemain disconnect / leave
	Players.PlayerRemoving:Connect(function(player)
		local TableService = getTableService()
		local tid = TableService.GetPlayerTable(player)
		local seat = TableService.GetPlayerSeat(player)
		if tid and seat then
			local session = getSession(tid)
			if session.isMatchRunning then
				Logger.info("GameService", string.format("[Meja %d] Pemain %s keluar saat match, digantikan Bot di Kursi %d.", tid, player.Name, seat))
				TableService.ReplacePlayerWithBot(seat, "normal", tid)

				if session.currentRound and session.currentRound.currentSeat == seat then
					runTurnCycle(session)
				end
			end
		end
	end)

	Logger.info("GameService", "GameService multi-room (4 meja) berhasil diinisialisasi.")
end

-- ====================================================================
-- TESTING & INSPECTION API
-- ====================================================================

function GameService.SetFastMode(enabled: boolean)
	fastMode = enabled
end

function GameService.GetState(tableId: number?): {
	isMatchRunning: boolean,
	currentPhase: string,
	currentGame: GameState?,
	currentRound: RoundState?,
	seatTokens: { [number]: { [string]: Tile } },
}
	local tid = tableId or 1
	local s = getSession(tid)
	return {
		isMatchRunning = s.isMatchRunning,
		currentPhase = s.currentPhase,
		currentGame = s.currentGame,
		currentRound = s.currentRound,
		seatTokens = s.seatTokens,
	}
end

function GameService.GetPublicView(tableId: number?): BotService.PublicView
	local tid = tableId or 1
	local s = getSession(tid)
	local mode = if s.currentGame then s.currentGame.mode else "2v2"
	local b = if s.currentRound then s.currentRound.board else DominoLogic.NewBoard()
	local counts = if s.currentRound then getRemainingCounts(s.currentRound) else { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
	local passC = if s.currentRound then s.currentRound.passCount else { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
	local op = if s.currentRound then s.currentRound.openerSeat else 1
	local isOp = if s.currentRound then (#s.currentRound.board.placed == 0) else true
	local isFirst = if s.currentGame then (s.currentGame.roundNumber == 1) else true

	return {
		mode = mode,
		board = b,
		remainingCounts = counts,
		passCount = passC,
		openerSeat = op,
		isOpening = isOp,
		isFirstRound = isFirst,
		knownPassedEnds = s.knownPassedEnds,
	}
end

return GameService
