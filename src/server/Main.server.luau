--!strict
--[=[
	Main.server.luau
	Bootstrap server untuk Gaplek Pos Ronda (AGENTS.md §6).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local TableService = require(script.Parent:WaitForChild("TableService"))
local Logger = require(script.Parent:WaitForChild("Logger"))

local function bootstrap()
	Logger.info("Bootstrap", "Memulai inisialisasi server...")
	Remotes.initServer()
	Logger.info("Bootstrap", "Remotes berhasil diinisialisasi.")

	-- Membangun dunia pos ronda 3D (M2)
	local world = WorldBuilder.Build()
	local partCount = WorldBuilder.GetPartCount()
	Logger.info("Bootstrap", string.format("Pos Ronda berhasil dibangun (Total part: %d).", partCount))

	-- Inisialisasi layanan meja dan kursi (M3a)
	TableService.Init()

	-- Inisialisasi layanan game dan siklus pertandingan (M4)
	local GameService = require(script.Parent:WaitForChild("GameService"))
	GameService.Init()

	-- Inisialisasi layanan pengaturan pemain (M6)
	local SettingsService = require(script.Parent:WaitForChild("SettingsService"))
	SettingsService.Init()

	-- Dev Tool: Replikasi FeelLab jika flag aktif (M5)
	local ServerStorage = game:GetService("ServerStorage")
	local devFolder = ServerStorage:FindFirstChild("Dev")
	local DebugConfig = devFolder and devFolder:FindFirstChild("DebugConfig")
	if DebugConfig then
		local conf = require(DebugConfig :: ModuleScript)
		if (conf :: any).ENABLE_FEEL_LAB and devFolder:FindFirstChild("FeelLab") then
			local lab = devFolder.FeelLab:Clone()
			lab.Parent = ReplicatedStorage
			Logger.info("Bootstrap", "FeelLab berhasil direplikasi ke ReplicatedStorage.")
		end
	end

	print("[PosGaplek Server] boot ok")
end

bootstrap()
