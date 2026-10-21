--!strict
--[=[
	SettingsService.luau
	Pengelola penyimpanan pengaturan pemain menggunakan DataStoreService dengan fallback aman.
	Sumber: UI_UX_SPEC.md §4, TECH_SPEC.md §5, §7.
]=]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local Logger = require(script.Parent:WaitForChild("Logger"))

type PlayerSettings = Types.PlayerSettings

local SettingsService = {}

local DATASTORE_NAME = "PosGaplek_PlayerSettings_v1"
local SAVE_COOLDOWN_SECONDS = 2.0

-- In-memory cache: [userId] = PlayerSettings
local settingsCache: { [number]: PlayerSettings } = {}
local lastSaveTimes: { [number]: number } = {}

local dataStore: GlobalDataStore? = nil

-- Lazy initialize DataStore dengan pcall
local function getDataStore(): GlobalDataStore?
	if dataStore then return dataStore end
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok and ds then
		dataStore = ds
		return ds
	else
		Logger.warn("SettingsService", "DataStoreService tidak dapat diakses (Studio mode atau API mati). Menggunakan in-memory fallback.")
		return nil
	end
end

--[=[
	Mengembalikan tabel pengaturan default yang aman berdasarkan FeelConfig.
]=]
function SettingsService.GetDefaultSettings(): PlayerSettings
	local cfg = FeelConfig.USER_SETTINGS
	return {
		masterVolume = cfg.MASTER_VOLUME,
		sfxVolume = cfg.SFX_VOLUME,
		ambienceVolume = cfg.AMBIENCE_VOLUME,
		uiVolume = cfg.UI_VOLUME,
		reduceShake = cfg.REDUCE_SHAKE,
		sensitivity = cfg.SENSITIVITY,
		graphicsQuality = cfg.GRAPHICS_QUALITY,
		hasSeenTutorial = cfg.HAS_SEEN_TUTORIAL,
	}
end

--[=[
	Memvalidasi dan menormalkan input pengaturan dari klien.
]=]
local function sanitizeSettings(raw: any): PlayerSettings
	local defaults = SettingsService.GetDefaultSettings()
	if typeof(raw) ~= "table" then
		return defaults
	end

	local master = if typeof(raw.masterVolume) == "number" then math.clamp(raw.masterVolume, 0, 1) else defaults.masterVolume
	local sfx = if typeof(raw.sfxVolume) == "number" then math.clamp(raw.sfxVolume, 0, 1) else defaults.sfxVolume
	local ambience = if typeof(raw.ambienceVolume) == "number" then math.clamp(raw.ambienceVolume, 0, 1) else defaults.ambienceVolume
	local ui = if typeof(raw.uiVolume) == "number" then math.clamp(raw.uiVolume, 0, 1) else defaults.uiVolume
	local reduceShake = if typeof(raw.reduceShake) == "boolean" then raw.reduceShake else defaults.reduceShake
	local sensitivity = if typeof(raw.sensitivity) == "number" then math.clamp(raw.sensitivity, 0.2, 3.0) else defaults.sensitivity
	local graphicsQuality = if raw.graphicsQuality == "rendah" or raw.graphicsQuality == "sedang" or raw.graphicsQuality == "tinggi"
		then raw.graphicsQuality
		else defaults.graphicsQuality
	local hasSeenTutorial = if typeof(raw.hasSeenTutorial) == "boolean" then raw.hasSeenTutorial else defaults.hasSeenTutorial

	return {
		masterVolume = master,
		sfxVolume = sfx,
		ambienceVolume = ambience,
		uiVolume = ui,
		reduceShake = reduceShake,
		sensitivity = sensitivity,
		graphicsQuality = graphicsQuality,
		hasSeenTutorial = hasSeenTutorial,
	}
end

--[=[
	Mengambil pengaturan pemain (dari cache atau DataStore).
]=]
function SettingsService.GetSettings(player: Player): PlayerSettings
	local userId = player.UserId
	if settingsCache[userId] then
		return settingsCache[userId]
	end

	local ds = getDataStore()
	if ds then
		local ok, savedData = pcall(function()
			return ds:GetAsync(tostring(userId))
		end)
		if ok and savedData then
			local sanitized = sanitizeSettings(savedData)
			settingsCache[userId] = sanitized
			return sanitized
		end
	end

	-- Fallback ke default
	local defaultSettings = SettingsService.GetDefaultSettings()
	settingsCache[userId] = defaultSettings
	return defaultSettings
end

--[=[
	Menyimpan pengaturan pemain ke memory cache dan DataStore.
]=]
function SettingsService.SaveSettings(player: Player, newSettings: any): (boolean, string?)
	local userId = player.UserId
	local now = os.clock()

	-- Cooldown proteksi spam DataStore
	local lastSave = lastSaveTimes[userId] or 0
	if (now - lastSave) < SAVE_COOLDOWN_SECONDS then
		return false, "RATE_LIMITED"
	end
	lastSaveTimes[userId] = now

	local sanitized = sanitizeSettings(newSettings)
	settingsCache[userId] = sanitized

	local ds = getDataStore()
	if ds then
		task.spawn(function()
			pcall(function()
				ds:SetAsync(tostring(userId), sanitized)
			end)
		end)
	end

	Logger.info("SettingsService", string.format("Pengaturan disimpan untuk %s (%d).", player.Name, userId))
	return true, nil
end

--[=[
	Inisialisasi listener remote di server.
]=]
function SettingsService.Init()
	Remotes.initServer()

	Remotes.getEvent("RequestGetSettings").OnServerEvent:Connect(function(player)
		local settings = SettingsService.GetSettings(player)
		Remotes.getEvent("SettingsLoaded"):FireClient(player, settings)
	end)

	Remotes.getEvent("RequestSaveSettings").OnServerEvent:Connect(function(player, payload)
		local ok, err = SettingsService.SaveSettings(player, payload)
		Remotes.getEvent("SettingsSaved"):FireClient(player, ok)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		settingsCache[userId] = nil
		lastSaveTimes[userId] = nil
	end)

	Logger.info("SettingsService", "SettingsService berhasil diinisialisasi.")
end

--[=[
	Membersihkan cache untuk kebutuhan pengujian unit otomatis.
]=]
function SettingsService.ResetForTesting(userId: number?)
	if userId then
		settingsCache[userId] = nil
		lastSaveTimes[userId] = nil
	else
		table.clear(settingsCache)
		table.clear(lastSaveTimes)
	end
end

return SettingsService
