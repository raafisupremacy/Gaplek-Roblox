--!strict
--[=[
	SettingsController.luau
	Pengelola pengaturan sisi client dan integrasi audio/kamera.
	Sumber: UI_UX_SPEC.md §4.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))

local SoundManager = require(script.Parent:WaitForChild("SoundManager"))

type PlayerSettings = Types.PlayerSettings

local SettingsController = {}

local currentSettings: PlayerSettings = {
	masterVolume = FeelConfig.USER_SETTINGS.MASTER_VOLUME,
	sfxVolume = FeelConfig.USER_SETTINGS.SFX_VOLUME,
	ambienceVolume = FeelConfig.USER_SETTINGS.AMBIENCE_VOLUME,
	uiVolume = FeelConfig.USER_SETTINGS.UI_VOLUME,
	reduceShake = FeelConfig.USER_SETTINGS.REDUCE_SHAKE,
	sensitivity = FeelConfig.USER_SETTINGS.SENSITIVITY,
	graphicsQuality = FeelConfig.USER_SETTINGS.GRAPHICS_QUALITY,
	hasSeenTutorial = FeelConfig.USER_SETTINGS.HAS_SEEN_TUTORIAL,
}

local changeListeners: { (PlayerSettings) -> () } = {}

--[=[
	Menerapkan pengaturan aktif ke subsistem (SoundManager, FeelConfig).
]=]
local function applySettings()
	-- Terapkan volume audio
	SoundManager.SetMasterVolume(currentSettings.masterVolume)
	SoundManager.SetGroupVolume("sfx", currentSettings.sfxVolume)
	SoundManager.SetGroupVolume("ambience", currentSettings.ambienceVolume)
	SoundManager.SetGroupVolume("ui", currentSettings.uiVolume)

	-- Terapkan ke FeelConfig
	FeelConfig.USER_SETTINGS.MASTER_VOLUME = currentSettings.masterVolume
	FeelConfig.USER_SETTINGS.SFX_VOLUME = currentSettings.sfxVolume
	FeelConfig.USER_SETTINGS.AMBIENCE_VOLUME = currentSettings.ambienceVolume
	FeelConfig.USER_SETTINGS.UI_VOLUME = currentSettings.uiVolume
	FeelConfig.USER_SETTINGS.REDUCE_SHAKE = currentSettings.reduceShake
	FeelConfig.USER_SETTINGS.SENSITIVITY = currentSettings.sensitivity
	FeelConfig.USER_SETTINGS.GRAPHICS_QUALITY = currentSettings.graphicsQuality
	FeelConfig.USER_SETTINGS.QUALITY_TIER = if currentSettings.graphicsQuality == "tinggi"
		then FeelConfig.QUALITY.HIGH
		elseif currentSettings.graphicsQuality == "rendah" then FeelConfig.QUALITY.LOW
		else FeelConfig.QUALITY.MEDIUM
	FeelConfig.USER_SETTINGS.HAS_SEEN_TUTORIAL = currentSettings.hasSeenTutorial

	for _, listener in ipairs(changeListeners) do
		task.spawn(listener, currentSettings)
	end
end

--[=[
	Mengambil salinan pengaturan saat ini.
]=]
function SettingsController.GetSettings(): PlayerSettings
	return {
		masterVolume = currentSettings.masterVolume,
		sfxVolume = currentSettings.sfxVolume,
		ambienceVolume = currentSettings.ambienceVolume,
		uiVolume = currentSettings.uiVolume,
		reduceShake = currentSettings.reduceShake,
		sensitivity = currentSettings.sensitivity,
		graphicsQuality = currentSettings.graphicsQuality,
		hasSeenTutorial = currentSettings.hasSeenTutorial,
	}
end

--[=[
	Mengubah satu nilai pengaturan dan menerapkannya.
]=]
function SettingsController.SetSetting(key: string, value: any)
	if (currentSettings :: any)[key] ~= nil then
		(currentSettings :: any)[key] = value
		applySettings()
	end
end

--[=[
	Menyimpan pengaturan ke server.
]=]
function SettingsController.Save()
	Remotes.getEvent("RequestSaveSettings"):FireServer(currentSettings)
end

--[=[
	Mendaftarkan callback ketika pengaturan berubah.
]=]
function SettingsController.OnChanged(callback: (PlayerSettings) -> ())
	table.insert(changeListeners, callback)
end

--[=[
	Inisialisasi SettingsController di klien.
]=]
function SettingsController.Init()
	Remotes.getEvent("SettingsLoaded").OnClientEvent:Connect(function(loaded: any)
		if typeof(loaded) == "table" then
			if typeof(loaded.masterVolume) == "number" then currentSettings.masterVolume = loaded.masterVolume end
			if typeof(loaded.sfxVolume) == "number" then currentSettings.sfxVolume = loaded.sfxVolume end
			if typeof(loaded.ambienceVolume) == "number" then currentSettings.ambienceVolume = loaded.ambienceVolume end
			if typeof(loaded.uiVolume) == "number" then currentSettings.uiVolume = loaded.uiVolume end
			if typeof(loaded.reduceShake) == "boolean" then currentSettings.reduceShake = loaded.reduceShake end
			if typeof(loaded.sensitivity) == "number" then currentSettings.sensitivity = loaded.sensitivity end
			if typeof(loaded.graphicsQuality) == "string" then currentSettings.graphicsQuality = loaded.graphicsQuality end
			if typeof(loaded.hasSeenTutorial) == "boolean" then currentSettings.hasSeenTutorial = loaded.hasSeenTutorial end
			applySettings()
		end
	end)

	-- Minta data pengaturan saat bergabung
	Remotes.getEvent("RequestGetSettings"):FireServer()
end

return SettingsController
