--!strict
--[=[
	TableService.luau
	Layanan server pengelola meja multi-room (4 meja), kursi, status duduk/berdiri, host, dan bot.
	Sumber: TECH_SPEC.md §3, §5; FIRST_PERSON_HANDS.md §2; PRD.md §6.

	Tanggung Jawab:
	- Menginisialisasi ProximityPrompt "Duduk" pada setiap kursi di 4 meja pos ronda.
	- Menetapkan kursi (1 kursi = 1 pemain/bot, tolak jika terisi).
	- Host tracking per meja (pemain pertama duduk otomatis host; berganti jika host pergi).
	- Pengaturan mode permainan (RequestSetMode) oleh host masing-masing meja.
	- Memulai match (RequestStart) & Rematch (RequestRematch) oleh host masing-masing meja.
	- Manajemen bot per meja: mengisi kursi kosong & menggantikan pemain disconnect/AFK.
	- Validasi avatar R15 dan penanganan RequestStand.
	- Manajemen multi-room: RequestGetRooms, RequestQuickPlay, RequestJoinTable, RoomsUpdated.
	- Kompatibilitas 100% mundur untuk Table 1 dan seluruh test suite sebelumnya.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local Logger = require(script.Parent:WaitForChild("Logger"))
local BotService = require(script.Parent:WaitForChild("BotService"))

type Mode = Types.Mode
type BotProfile = BotService.BotProfile

local TableService = {}

export type TableState = {
	id: number,
	name: string,
	occupants: { [number]: Player? },
	isBotSeat: { [number]: boolean },
	botProfiles: { [number]: BotProfile? },
	host: Player?,
	mode: Mode,
	connections: { [number]: { RBXScriptConnection } },
}

local TABLE_COUNT = 4
local TABLE_NAMES = {
	[1] = "Meja 1 (Pos Utama)",
	[2] = "Meja 2 (Bale Warkop)",
	[3] = "Meja 3 (Gazebo Bambu)",
	[4] = "Meja 4 (Pelataran Depan)",
}

-- Peta state per meja: [tableId] = TableState
local tables: { [number]: TableState } = {}

-- Peta balik pemain ke meja dan kursi:
local playerToTable: { [Player]: number } = {}
local playerToSeat: { [Player]: number } = {}

-- Nama tampilan bot
local BOT_NAMES = {
	[1] = "Bot Pak RT",
	[2] = "Bot Mas Joko",
	[3] = "Bot Kang Asep",
	[4] = "Bot Bang Udin",
}

-- Palet pakaian warga pos ronda untuk rig R15 bot
local BOT_SHIRT_COLORS = {
	[1] = Color3.fromRGB(95, 55, 38),  -- Pak RT: Batik coklat tua
	[2] = Color3.fromRGB(45, 85, 115), -- Mas Joko: Kemeja biru malam
	[3] = Color3.fromRGB(55, 95, 60),  -- Kang Asep: Kaos hijau lumut
	[4] = Color3.fromRGB(115, 48, 45), -- Bang Udin: Jaket merah marun
}
local BOT_PANTS_COLOR = Color3.fromRGB(35, 38, 45) -- Sarung / celana gelap
local BOT_SKIN_COLOR = Color3.fromRGB(215, 175, 140) -- Kulit sawo matang terang

-- Penyimpanan model rig R15 bot aktif: [tableId][seatIndex] = Model
local botRigs: { [number]: { [number]: Model? } } = {
	[1] = {},
	[2] = {},
	[3] = {},
	[4] = {},
}

-- Inisialisasi struktur state per meja
local function initTableState(id: number): TableState
	return {
		id = id,
		name = TABLE_NAMES[id] or ("Meja " .. id),
		occupants = { [1] = nil, [2] = nil, [3] = nil, [4] = nil },
		isBotSeat = { [1] = false, [2] = false, [3] = false, [4] = false },
		botProfiles = { [1] = nil, [2] = nil, [3] = nil, [4] = nil },
		host = nil,
		mode = "2v2",
		connections = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
	}
end

for t = 1, TABLE_COUNT do
	tables[t] = initTableState(t)
end

-- Forward declaration untuk GameService (lazy require menghindari circular dependency)
local function getGameService()
	return require(script.Parent.GameService)
end

-- Mengambil Model Meja dari PosRonda
local function getTableModel(tableId: number?): Model?
	local tid = tableId or 1
	local posRonda = workspace:FindFirstChild("PosRonda")
	if not posRonda then
		return nil
	end
	local modelName = if tid == 1 then "Table" else ("Table_" .. tid)
	return posRonda:FindFirstChild(modelName) :: Model?
end

-- Mengambil Part Seat berdasarkan indeks kursi (1..4) dan meja (1..4)
local function getSeatPart(seatIndex: number, tableId: number?): Seat?
	local tbl = getTableModel(tableId)
	if not tbl then
		return nil
	end
	return tbl:FindFirstChild("Seat" .. seatIndex) :: Seat?
end

--[=[
	Memeriksa apakah avatar pemain memenuhi syarat rig R15.
]=]
function TableService.ValidateR15(player: Player): (boolean, string?)
	local character = player.Character
	if not character then
		return false, "Karakter belum dimuat."
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, "Humanoid tidak ditemukan."
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return false, "Avatar Anda bertipe R6. Game ini memerlukan avatar R15 untuk animasi POV first-person."
	end

	return true, nil
end

-- ====================================================================
-- HOST & MODE MANAGEMENT
-- ====================================================================

function TableService.GetHost(tableId: number?): Player?
	local tid = tableId or 1
	local tbl = tables[tid]
	return if tbl then tbl.host else nil
end

function TableService.SetHost(player: Player?, tableId: number?)
	local tid = tableId or 1
	local tbl = tables[tid]
	if tbl then
		tbl.host = player
		Logger.info("TableService", string.format("[%s] Host saat ini: %s", tbl.name, if player then player.Name else "NIL"))
	end
end

function TableService.GetMode(tableId: number?): Mode
	local tid = tableId or 1
	local tbl = tables[tid]
	return if tbl then tbl.mode else "2v2"
end

function TableService.SetMode(mode: Mode, tableId: number?): (boolean, string?)
	local tid = tableId or 1
	local tbl = tables[tid]
	if not tbl then return false, "TABLE_NOT_FOUND" end

	local GameService = getGameService()
	local state = GameService.GetState(tid)
	if state.isMatchRunning then
		return false, "CANNOT_CHANGE_MODE_DURING_MATCH"
	end

	tbl.mode = mode
	Logger.info("TableService", string.format("[%s] Mode meja diubah menjadi: %s", tbl.name, mode))
	GameService.SendStateSyncAll(tid)
	TableService.BroadcastRoomsUpdated()
	return true, nil
end

-- Helper memilih host baru jika host lama berdiri / keluar
local function updateHostOnLeave(leftPlayer: Player, tableId: number)
	local tbl = tables[tableId]
	if not tbl then return end

	if tbl.host == leftPlayer then
		tbl.host = nil
		-- Cari pemain manusia lain yang sedang duduk di meja ini
		for s = 1, GameConfig.TOTAL_SEATS do
			local occupant = tbl.occupants[s]
			if occupant and not tbl.isBotSeat[s] and occupant ~= leftPlayer then
				tbl.host = occupant
				Logger.info("TableService", string.format("[%s] Host dialihkan ke pemain: %s", tbl.name, occupant.Name))
				break
			end
		end

		if not tbl.host then
			Logger.info("TableService", string.format("[%s] Tidak ada pemain manusia di meja. Host kosong.", tbl.name))
		end
	end
end

-- ====================================================================
-- BOT MANAGEMENT
-- ====================================================================

function TableService.IsSeatBot(seatIndex: number, tableId: number?): boolean
	local tid = tableId or 1
	local tbl = tables[tid]
	return if tbl then tbl.isBotSeat[seatIndex] == true else false
end

function TableService.GetBotProfile(seatIndex: number, tableId: number?): BotProfile?
	local tid = tableId or 1
	local tbl = tables[tid]
	return if tbl then tbl.botProfiles[seatIndex] else nil
end

-- Helper membuat atau menghapus karakter rig R15 untuk kursi Bot (BOT_SPEC.md §3)
local function destroyBotRig(tid: number, seatIndex: number)
	if botRigs[tid] and botRigs[tid][seatIndex] then
		local oldRig = botRigs[tid][seatIndex]
		botRigs[tid][seatIndex] = nil
		if oldRig and oldRig.Parent then
			oldRig:Destroy()
		end
	end
end

local function spawnBotRigAtSeat(tid: number, seatIndex: number, seatPart: Seat)
	destroyBotRig(tid, seatIndex)

	local ok, rig = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local skin = BOT_SKIN_COLOR
		local shirt = BOT_SHIRT_COLORS[seatIndex] or BOT_SHIRT_COLORS[1]
		desc.HeadColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.TorsoColor = shirt
		desc.LeftLegColor = BOT_PANTS_COLOR
		desc.RightLegColor = BOT_PANTS_COLOR
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)

	if not ok or not rig then
		return
	end

	rig.Name = string.format("BotRig_T%d_S%d", tid, seatIndex)
	rig:SetAttribute("IsBotRig", true)
	rig:SetAttribute("TableId", tid)
	rig:SetAttribute("SeatIndex", seatIndex)

	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = BOT_NAMES[seatIndex] or ("Bot " .. seatIndex)
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	-- Matikan CanCollide pada part tubuh bot agar tidak mengganggu fisika pemain
	for _, descPart in ipairs(rig:GetDescendants()) do
		if descPart:IsA("BasePart") then
			descPart.CanCollide = false
		end
	end

	local tblModel = getTableModel(tid)
	rig.Parent = tblModel or workspace
	local hrp = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = true
		rig:PivotTo(seatPart.CFrame * CFrame.new(0, 1.5, 0))
	end
	if hum then
		hum.Sit = true
	end

	if not botRigs[tid] then
		botRigs[tid] = {}
	end
	botRigs[tid][seatIndex] = rig
end

function TableService.GetBotRig(seatIndex: number, tableId: number?): Model?
	local tid = tableId or 1
	return if botRigs[tid] then botRigs[tid][seatIndex] else nil
end

function TableService.SetSeatBot(seatIndex: number, isBot: boolean, profile: BotProfile?, tableId: number?)
	local tid = tableId or 1
	local tbl = tables[tid]
	if not tbl then return end

	tbl.isBotSeat[seatIndex] = isBot
	tbl.botProfiles[seatIndex] = profile

	local seatPart = getSeatPart(seatIndex, tid)
	if seatPart then
		local prompt = seatPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = not isBot
		end
		if isBot then
			spawnBotRigAtSeat(tid, seatIndex, seatPart)
		else
			destroyBotRig(tid, seatIndex)
		end
	else
		if not isBot then
			destroyBotRig(tid, seatIndex)
		end
	end

	local botName = if isBot then (BOT_NAMES[seatIndex] or ("Bot " .. seatIndex)) else ""
	Remotes.getEvent("SeatChanged"):FireAllClients(seatIndex, if isBot then -seatIndex else 0, botName, isBot, if isBot then "bot_sit" else "bot_stand", tid)
	TableService.BroadcastRoomsUpdated()
end

--[=[
	Mengisi semua kursi yang kosong dengan bot sebelum match dimulai.
]=]
function TableService.FillEmptySeatsWithBots(defaultLevel: "easy" | "normal"?, tableId: number?)
	local tid = tableId or 1
	local tbl = tables[tid]
	if not tbl then return end

	local lvl = defaultLevel or "normal"
	for s = 1, GameConfig.TOTAL_SEATS do
		if tbl.occupants[s] == nil and not tbl.isBotSeat[s] then
			TableService.SetSeatBot(s, true, { seat = s, level = lvl }, tid)
			Logger.info("TableService", string.format("[%s] Kursi %d diisi oleh %s (Level: %s)", tbl.name, s, BOT_NAMES[s], lvl))
		end
	end
end

--[=[
	Menggantikan pemain manusia dengan bot saat disconnect/AFK di tengah permainan.
]=]
function TableService.ReplacePlayerWithBot(seatIndex: number, defaultLevel: "easy" | "normal"?, tableId: number?)
	local tid = tableId or 1
	local tbl = tables[tid]
	if not tbl then return end

	local lvl = defaultLevel or "normal"
	local oldPlayer = tbl.occupants[seatIndex]
	if oldPlayer then
		playerToSeat[oldPlayer] = nil
		playerToTable[oldPlayer] = nil
		tbl.occupants[seatIndex] = nil
		updateHostOnLeave(oldPlayer, tid)
	end

	TableService.SetSeatBot(seatIndex, true, { seat = seatIndex, level = lvl }, tid)
	Logger.info("TableService", string.format("[%s] Kursi %d diambil alih oleh %s", tbl.name, seatIndex, BOT_NAMES[seatIndex]))
end

-- ====================================================================
-- DUDUK / BERDIRI PEMAIN
-- ====================================================================

--[=[
	Menangani permintaan pemain untuk menduduki kursi tertentu di meja tertentu.
]=]
function TableService.SitPlayer(player: Player, seatIndex: number, tableId: number?): (boolean, string?)
	local tid = tableId or 1
	local tbl = tables[tid]
	if not tbl then
		return false, "Nomor meja tidak valid."
	end

	if seatIndex < 1 or seatIndex > GameConfig.TOTAL_SEATS then
		return false, "Nomor kursi tidak valid."
	end

	if tbl.occupants[seatIndex] ~= nil or tbl.isBotSeat[seatIndex] then
		return false, "Kursi ini sudah terisi."
	end

	if playerToSeat[player] ~= nil then
		return false, "Anda sudah duduk di kursi lain."
	end

	local isR15, r15Err = TableService.ValidateR15(player)
	if not isR15 then
		if typeof(player) == "Instance" and player:IsA("Player") then
			Remotes.getEvent("Rejected"):FireClient(player, "NOT_R15_AVATAR")
		end
		Logger.warn("TableService", string.format("Pemain %s ditolak duduk: %s", player.Name, tostring(r15Err)))
		return false, r15Err
	end

	local character = player.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local seatPart = getSeatPart(seatIndex, tid)
	if not seatPart then
		return false, "Part kursi tidak ditemukan."
	end

	-- Catat kepemilikan kursi dan meja
	tbl.occupants[seatIndex] = player
	playerToTable[player] = tid
	playerToSeat[player] = seatIndex
	tbl.isBotSeat[seatIndex] = false
	tbl.botProfiles[seatIndex] = nil

	-- Pemain pertama duduk otomatis menjadi Host meja tersebut
	if tbl.host == nil then
		TableService.SetHost(player, tid)
	end

	-- Nonaktifkan prompt kursi ini
	local prompt = seatPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	local isRealPlayer = (typeof(player) == "Instance" and player:IsA("Player"))
	if isRealPlayer then
		seatPart:Sit(humanoid)
	else
		humanoid.Sit = true
	end

	Logger.info("TableService", string.format("Pemain %s (%d) duduk di [%s] Kursi %d.", player.Name, player.UserId, tbl.name, seatIndex))

	-- Broadcast SeatChanged ke semua client dengan info tableId
	Remotes.getEvent("SeatChanged"):FireAllClients(seatIndex, player.UserId, player.Name, false, "sit", tid)

	-- Kirim StateSync ke pemain yang baru duduk
	local GameService = getGameService()
	GameService.SendStateSync(player, tid)

	TableService.BroadcastRoomsUpdated()
	return true, nil
end

--[=[
	Menangani permintaan pemain untuk berdiri dari kursi.
]=]
function TableService.StandPlayer(player: Player): (boolean, string?)
	local tid = playerToTable[player]
	local seatIndex = playerToSeat[player]
	if not tid or not seatIndex then
		return false, "Pemain tidak sedang duduk di kursi manapun."
	end

	local tbl = tables[tid]
	local GameService = getGameService()
	local state = GameService.GetState(tid)

	-- Bersihkan state client pemain yang berdiri agar tidak menyisakan state meja lama
	Remotes.getEvent("SeatChanged"):FireAllClients(seatIndex, player.UserId, player.Name, false, "stand", tid)
	GameService.SendClearStateSync(player)

	-- Jika match sedang berlangsung, ganti dengan bot agar permainan tidak macet
	if state.isMatchRunning then
		TableService.ReplacePlayerWithBot(seatIndex, "normal", tid)
		GameService.OnSeatReplacedByBot(tid, seatIndex)
	else
		if tbl then
			tbl.occupants[seatIndex] = nil
		end
		playerToTable[player] = nil
		playerToSeat[player] = nil
		updateHostOnLeave(player, tid)

		local seatPart = getSeatPart(seatIndex, tid)
		if seatPart then
			local prompt = seatPart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = true
			end
		end
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local seatPart = getSeatPart(seatIndex, tid)
		if hrp and seatPart then
			-- Pindahkan karakter sedikit ke belakang kursi agar berdiri bebas
			hrp.CFrame = seatPart.CFrame * CFrame.new(0, 0.5, 2.5)
		end
	end

	Logger.info("TableService", string.format("Pemain %s (%d) berdiri dari [Meja %d] Kursi %d.", player.Name, player.UserId, tid, seatIndex))
	TableService.BroadcastRoomsUpdated()
	return true, nil
end

function TableService.GetOccupant(seatIndex: number, tableId: number?): Player?
	local tid = tableId or 1
	local tbl = tables[tid]
	return if tbl then tbl.occupants[seatIndex] else nil
end

function TableService.GetPlayerSeat(player: Player): number?
	return playerToSeat[player]
end

function TableService.GetPlayerTable(player: Player): number?
	return playerToTable[player]
end

function TableService.GetAllOccupants(tableId: number?): { [number]: Player? }
	local tid = tableId or 1
	local tbl = tables[tid]
	return if tbl then tbl.occupants else {}
end

-- ====================================================================
-- MULTI-ROOM / ROOM BROWSER & QUICK PLAY
-- ====================================================================

function TableService.GetRoomsData(): { any }
	local GameService = getGameService()
	local list = {}
	for t = 1, TABLE_COUNT do
		local tbl = tables[t]
		local humanCount = 0
		local botCount = 0
		local seatInfos = {}

		for s = 1, GameConfig.TOTAL_SEATS do
			local occ = tbl.occupants[s]
			local isBot = tbl.isBotSeat[s]
			if occ then
				humanCount += 1
			end
			if isBot then
				botCount += 1
			end
			table.insert(seatInfos, {
				seat = s,
				isOccupied = (occ ~= nil or isBot),
				isBot = isBot,
				name = if occ then occ.Name else (if isBot then (BOT_NAMES[s] or "Bot") else "Kosong"),
			})
		end

		local gs = GameService.GetState(t)
		local statusText = if gs.isMatchRunning then "Sedang Bermain"
			elseif (humanCount + botCount) > 0 then "Menunggu Pemain"
			else "Kosong"

		table.insert(list, {
			id = t,
			name = tbl.name,
			mode = tbl.mode,
			hostName = if tbl.host then tbl.host.Name else "-",
			playerCount = humanCount,
			botCount = botCount,
			totalSeated = humanCount + botCount,
			status = statusText,
			seats = seatInfos,
		})
	end
	return list
end

function TableService.BroadcastRoomsUpdated()
	local data = TableService.GetRoomsData()
	local rem = Remotes.getEvent("RoomsUpdated")
	if rem then
		rem:FireAllClients(data)
	end
end

--[=[
	Mencari kursi kosong secara otomatis di meja mana pun (Quick Play).
]=]
function TableService.QuickPlay(player: Player): (boolean, string?)
	-- 1. Cari meja yang sudah memiliki pemain namun belum penuh
	for t = 1, TABLE_COUNT do
		local tbl = tables[t]
		local GameService = getGameService()
		local gs = GameService.GetState(t)
		if not gs.isMatchRunning then
			local count = 0
			for s = 1, GameConfig.TOTAL_SEATS do
				if tbl.occupants[s] ~= nil or tbl.isBotSeat[s] then
					count += 1
				end
			end
			if count > 0 and count < GameConfig.TOTAL_SEATS then
				for s = 1, GameConfig.TOTAL_SEATS do
					if tbl.occupants[s] == nil and not tbl.isBotSeat[s] then
						return TableService.SitPlayer(player, s, t)
					end
				end
			end
		end
	end

	-- 2. Jika tidak ada yang sedang menunggu, cari meja kosong pertama
	for t = 1, TABLE_COUNT do
		local tbl = tables[t]
		local GameService = getGameService()
		local gs = GameService.GetState(t)
		if not gs.isMatchRunning then
			for s = 1, GameConfig.TOTAL_SEATS do
				if tbl.occupants[s] == nil and not tbl.isBotSeat[s] then
					return TableService.SitPlayer(player, s, t)
				end
			end
		end
	end

	return false, "Semua kursi di semua meja saat ini terisi penuh!"
end

--[=[
	Bergabung ke meja tertentu melalui Table Browser.
]=]
function TableService.JoinTable(player: Player, tableId: number?, preferredSeat: number?): (boolean, string?)
	local tid = if type(tableId) == "number" then math.clamp(tableId, 1, TABLE_COUNT) else 1
	local tbl = tables[tid]
	if not tbl then return false, "Meja tidak valid." end

	if preferredSeat and preferredSeat >= 1 and preferredSeat <= GameConfig.TOTAL_SEATS then
		if tbl.occupants[preferredSeat] == nil and not tbl.isBotSeat[preferredSeat] then
			return TableService.SitPlayer(player, preferredSeat, tid)
		end
	end

	-- Cari kursi kosong pertama di meja ini
	for s = 1, GameConfig.TOTAL_SEATS do
		if tbl.occupants[s] == nil and not tbl.isBotSeat[s] then
			return TableService.SitPlayer(player, s, tid)
		end
	end

	return false, "Meja ini sudah penuh!"
end

-- ====================================================================
-- INISIALISASI
-- ====================================================================

function TableService.Reset()
	for t = 1, TABLE_COUNT do
		local tbl = tables[t]
		if tbl then
			for s = 1, GameConfig.TOTAL_SEATS do
				destroyBotRig(t, s)
				tbl.occupants[s] = nil
				tbl.isBotSeat[s] = false
				tbl.botProfiles[s] = nil
			end
			tbl.host = nil
			tbl.mode = "2v2"
		end
	end
	table.clear(playerToTable)
	table.clear(playerToSeat)
end

function TableService.Init()
	TableService.Reset()
	Remotes.initServer()

	-- Inisialisasi prompt pada seluruh kursi di 4 meja
	for tid = 1, TABLE_COUNT do
		local tblModel = getTableModel(tid)
		local tblState = tables[tid]
		if tblModel and tblState then
			for seatIndex = 1, GameConfig.TOTAL_SEATS do
				local seatPart = tblModel:FindFirstChild("Seat" .. seatIndex) :: Seat?
				if seatPart then
					for _, conn in ipairs(tblState.connections[seatIndex]) do
						conn:Disconnect()
					end
					tblState.connections[seatIndex] = {}

					local oldPrompt = seatPart:FindFirstChildOfClass("ProximityPrompt")
					if oldPrompt then
						oldPrompt:Destroy()
					end

					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = "SitPrompt"
					prompt.ActionText = "Duduk"
					prompt.ObjectText = string.format("%s - Kursi %d", tblState.name, seatIndex)
					prompt.HoldDuration = 0.2
					prompt.MaxActivationDistance = 6.0
					prompt.RequiresLineOfSight = false
					prompt.KeyboardKeyCode = Enum.KeyCode.E
					prompt.UIOffset = Vector2.new(0, 15)
					prompt.Parent = seatPart

					local triggerConn = prompt.Triggered:Connect(function(player)
						TableService.SitPlayer(player, seatIndex, tid)
					end)
					table.insert(tblState.connections[seatIndex], triggerConn)

					local occupantConn = seatPart:GetPropertyChangedSignal("Occupant"):Connect(function()
						if seatPart.Occupant == nil then
							local currentOccupant = tblState.occupants[seatIndex]
							-- Hanya picu StandPlayer untuk Player Roblox nyata yang melompat dari kursi физических
							if currentOccupant and typeof(currentOccupant) == "Instance" and currentOccupant:IsA("Player") then
								TableService.StandPlayer(currentOccupant)
							end
						end
					end)
					table.insert(tblState.connections[seatIndex], occupantConn)
				end
			end
		else
			Logger.warn("TableService", string.format("Model Meja %d belum tersedia di Workspace!", tid))
		end
	end

	-- 1. RequestStand
	Remotes.getEvent("RequestStand").OnServerEvent:Connect(function(player)
		TableService.StandPlayer(player)
	end)

	-- 2. RequestSetMode
	Remotes.getEvent("RequestSetMode").OnServerEvent:Connect(function(player, mode)
		if not Remotes.checkRateLimit(player, "RequestSetMode") then return end
		local tid = playerToTable[player] or 1
		local tblState = tables[tid]
		if not tblState or player ~= tblState.host then
			Remotes.getEvent("Rejected"):FireClient(player, "NOT_HOST")
			return
		end
		if mode ~= "2v2" and mode ~= "solo" then return end

		TableService.SetMode(mode, tid)
	end)

	-- 3. RequestStart
	Remotes.getEvent("RequestStart").OnServerEvent:Connect(function(player)
		if not Remotes.checkRateLimit(player, "RequestStart") then return end
		local tid = playerToTable[player] or 1
		local tblState = tables[tid]
		if not tblState or player ~= tblState.host then
			Remotes.getEvent("Rejected"):FireClient(player, "NOT_HOST")
			return
		end

		local GameService = getGameService()
		local ok, err = GameService.StartMatch(tblState.mode, tid)
		if not ok and err then
			Remotes.getEvent("Rejected"):FireClient(player, err)
		end
	end)

	-- 4. RequestRematch
	Remotes.getEvent("RequestRematch").OnServerEvent:Connect(function(player)
		if not Remotes.checkRateLimit(player, "RequestRematch") then return end
		local tid = playerToTable[player] or 1
		local tblState = tables[tid]
		if not tblState or player ~= tblState.host then
			Remotes.getEvent("Rejected"):FireClient(player, "NOT_HOST")
			return
		end

		local GameService = getGameService()
		local state = GameService.GetState(tid)
		if state.currentPhase == "game_ended" or state.currentPhase == "idle" then
			GameService.StartMatch(tblState.mode, tid)
		end
	end)

	-- 5. RequestGetRooms
	Remotes.getEvent("RequestGetRooms").OnServerEvent:Connect(function(player)
		if not Remotes.checkRateLimit(player, "RequestGetRooms") then return end
		Remotes.getEvent("RoomsUpdated"):FireClient(player, TableService.GetRoomsData())
	end)

	-- 6. RequestQuickPlay
	Remotes.getEvent("RequestQuickPlay").OnServerEvent:Connect(function(player)
		if not Remotes.checkRateLimit(player, "RequestQuickPlay") then return end
		local ok, err = TableService.QuickPlay(player)
		if not ok and err then
			Remotes.getEvent("Rejected"):FireClient(player, err)
		end
	end)

	-- 7. RequestJoinTable
	Remotes.getEvent("RequestJoinTable").OnServerEvent:Connect(function(player, tableId, seatIndex)
		if not Remotes.checkRateLimit(player, "RequestJoinTable") then return end
		local tid = if type(tableId) == "number" then tableId else 1
		local prefSeat = if type(seatIndex) == "number" then seatIndex else nil
		local ok, err = TableService.JoinTable(player, tid, prefSeat)
		if not ok and err then
			Remotes.getEvent("Rejected"):FireClient(player, err)
		end
	end)

	-- 8. Players.PlayerRemoving
	Players.PlayerRemoving:Connect(function(player)
		if playerToSeat[player] then
			TableService.StandPlayer(player)
		end
	end)

	Logger.info("TableService", "TableService multi-table (4 meja) berhasil diinisialisasi.")
end

--[=[
	Mereset seluruh status kursi meja untuk pengujian atau pembersihan.
]=]
function TableService.ResetForTesting()
	local GameService = getGameService()
	for tid = 1, TABLE_COUNT do
		GameService.StopMatch(tid)
		local tbl = tables[tid]
		if tbl then
			for s = 1, GameConfig.TOTAL_SEATS do
				destroyBotRig(tid, s)
				local occ = tbl.occupants[s]
				if occ and typeof(occ) == "table" and (occ :: any).Character then
					local hum = (occ :: any).Character:FindFirstChildOfClass("Humanoid")
					if hum then hum.Sit = false end
				end
				tbl.occupants[s] = nil
				tbl.isBotSeat[s] = false
				tbl.botProfiles[s] = nil
				local seatPart = getSeatPart(s, tid)
				if seatPart then
					local prompt = seatPart:FindFirstChildOfClass("ProximityPrompt")
					if prompt then
						prompt.Enabled = true
					end
				end
			end
			tbl.host = nil
			tbl.mode = "2v2"
		end
	end
	table.clear(playerToTable)
	table.clear(playerToSeat)
end

return TableService
