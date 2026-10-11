--!strict
--[=[
	Remotes.luau
	Modul tunggal untuk inisialisasi, akses, validasi input, dan rate limiting RemoteEvent.
	Sumber: TECH_SPEC.md §5, §7.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

local REMOTES_FOLDER_NAME = "Remotes"

local CLIENT_TO_SERVER_EVENTS = {
	"RequestPlay",
	"RequestPass",
	"RequestEmote",
	"RequestSetMode",
	"RequestStart",
	"RequestStand",
	"RequestRematch",
	"RequestGetSettings",
	"RequestSaveSettings",
	"RequestGetRooms",
	"RequestQuickPlay",
	"RequestJoinTable",
}

local SERVER_TO_CLIENT_EVENTS = {
	"StateSync",
	"RoundStarted",
	"DealStarted",
	"TurnStarted",
	"TilePlaced",
	"PlayerPassed",
	"RoundEnded",
	"GameEnded",
	"EmotePlayed",
	"SeatChanged",
	"Rejected",
	"SettingsLoaded",
	"SettingsSaved",
	"RoomsUpdated",
}

local Remotes = {}

-- Cache lokal referensi RemoteEvent
local cachedEvents: { [string]: RemoteEvent } = {}

-- Rate limiter storage: [userId][remoteName] = timestamp
local lastCallTimestamps: { [number]: { [string]: number } } = {}

-- Pembersihan memori saat pemain meninggalkan server
if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(player)
		lastCallTimestamps[player.UserId] = nil
	end)
end

-- Ambil semua nama event yang terdaftar
function Remotes.getAllEventNames(): { string }
	local list: { string } = {}
	for _, name in ipairs(CLIENT_TO_SERVER_EVENTS) do
		table.insert(list, name)
	end
	for _, name in ipairs(SERVER_TO_CLIENT_EVENTS) do
		table.insert(list, name)
	end
	return list
end

--[=[
	Inisialisasi semua RemoteEvent di Server.
	Idempotent: Tidak membuat duplikat jika dipanggil berulang kali.
]=]
function Remotes.initServer(): ()
	if not RunService:IsServer() then
		warn("[Remotes] Remotes.initServer() hanya boleh dipanggil dari Server.")
		return
	end

	local folder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = REMOTES_FOLDER_NAME
		newFolder.Parent = ReplicatedStorage
		folder = newFolder
	end

	Remotes.Server = {}
	Remotes.Client = {}

	for _, eventName in ipairs(Remotes.getAllEventNames()) do
		local existing = folder:FindFirstChild(eventName)
		local ev: RemoteEvent
		if not existing then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = eventName
			remoteEvent.Parent = folder
			ev = remoteEvent
		else
			ev = existing :: RemoteEvent
		end
		cachedEvents[eventName] = ev
		Remotes.Server[eventName] = ev
		Remotes.Client[eventName] = ev
	end
end

-- Kompatibilitas alias untuk bootstrap server
function Remotes.init(): ()
	Remotes.initServer()
end

--[=[
	Mengambil referensi RemoteEvent berdasarkan nama (Client dan Server).
	Di Client, menunggu folder dan instance tereplikasi secara aman.
]=]
function Remotes.getEvent(eventName: string): RemoteEvent
	local cached = cachedEvents[eventName]
	if cached and cached.Parent ~= nil then
		return cached
	end

	local folder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not folder then
		if RunService:IsClient() then
			folder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME, 10)
		end
	end

	if not folder then
		error(string.format("[Remotes] Folder '%s' tidak ditemukan di ReplicatedStorage.", REMOTES_FOLDER_NAME))
	end

	local event = folder:FindFirstChild(eventName)
	if not event and RunService:IsClient() then
		event = folder:WaitForChild(eventName, 10)
	end

	if not event or not event:IsA("RemoteEvent") then
		error(string.format("[Remotes] RemoteEvent '%s' tidak ditemukan.", eventName))
	end

	cachedEvents[eventName] = event :: RemoteEvent
	return event :: RemoteEvent
end

-- ====================================================================
-- VALIDATOR & RATE LIMITER (Server Security Utilities - TECH_SPEC §7)
-- ====================================================================

--[=[
	Pemeriksaan rate limit per pemain per remote.
	Mengembalikan true jika diizinkan, false jika melebihi batas frekuensi (rate limited).
]=]
function Remotes.checkRateLimit(player: Player, remoteName: string): boolean
	local limit = GameConfig.RATE_LIMITS[remoteName] or 0.1
	local now = os.clock()
	local userId = player.UserId

	local userRecords = lastCallTimestamps[userId]
	if not userRecords then
		userRecords = {}
		lastCallTimestamps[userId] = userRecords
	end

	local lastTime = userRecords[remoteName]
	if lastTime and (now - lastTime) < limit then
		return false
	end

	userRecords[remoteName] = now
	return true
end

-- Reset rate limit (berguna untuk keperluan unit testing)
function Remotes._resetRateLimitForTesting(userId: number): ()
	lastCallTimestamps[userId] = nil
end

--[=[
	Validasi tipe data nilai.
]=]
function Remotes.validateType(val: any, expectedType: string): boolean
	return typeof(val) == expectedType
end

--[=[
	Validasi nilai terhadap daftar whitelist.
]=]
function Remotes.validateWhitelist(val: any, allowedValues: { any }): boolean
	for _, allowed in ipairs(allowedValues) do
		if val == allowed then
			return true
		end
	end
	return false
end

--[=[
	Validasi string dengan batas panjang opsional (min & max).
]=]
function Remotes.validateString(val: any, minLen: number?, maxLen: number?): boolean
	if typeof(val) ~= "string" then
		return false
	end
	local len = #val
	if minLen and len < minLen then
		return false
	end
	if maxLen and len > maxLen then
		return false
	end
	return true
end

--[=[
	Validasi angka dengan rentang nilai opsional (min & max) dan opsi bilangan bulat.
]=]
function Remotes.validateNumber(val: any, minVal: number?, maxVal: number?, integerOnly: boolean?): boolean
	if typeof(val) ~= "number" then
		return false
	end
	-- Cegah NaN dan Infinity
	if val ~= val or val == math.huge or val == -math.huge then
		return false
	end
	if integerOnly and math.floor(val) ~= val then
		return false
	end
	if minVal and val < minVal then
		return false
	end
	if maxVal and val > maxVal then
		return false
	end
	return true
end

return Remotes

