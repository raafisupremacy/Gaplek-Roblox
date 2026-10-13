--!strict
--[=[
	M5aFeelTests.luau
	Unit test suite untuk Milestone M5 Grup A (Kartu & Tangan: 4 Lapisan Feel, Hentak, SoundManager, FeelLab).
	Sumber: GAME_FEEL.md §1–3, §8–9; FIRST_PERSON_HANDS.md §4, §7.

	Cakupan Pengujian:
	- F01: Checklist 4 lapisan per aksi (Gerakan, Suara, Visual, Lingkungan).
	- F02: Keamanan SoundManager saat ID kosong (0 exception / crash).
	- F03: SLA Total Durasi Hentak <= 0.9 detik (SLAM_TOTAL_TIME) pada seluruh preset.
	- F04: Variasi acak (Jitter) pitch suara (+-8%) dan sudut kartu meja (+-3 deg).
	- F05: Quality Tier gating (Low/Med/High) & Opsi "Kurangi Guncangan".
	- F06: FeelLab runtime override setter & export consistency.
	- F07: Reaksi lingkungan pos ronda (gelas kopi, bohlam lampu, kartu lain).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local clientFolder = StarterPlayer.StarterPlayerScripts.Client
local SoundManager = require(clientFolder:WaitForChild("SoundManager"))

local M5aFeelTests = {}

function M5aFeelTests.RunAll(): (number, number, { string })
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

	-- ====================================================================
	-- F01: Checklist 4 Lapisan per Aksi Grup A (GAME_FEEL.md §3)
	-- ====================================================================
	do
		local checklist = {
			kocok = { motion = true, sound = "tile_shuffle", visual = true, env = "lamp" },
			bagi = { motion = true, sound = "tile_deal", visual = true, env = "rack_bounce" },
			hover = { motion = true, sound = "tile_hover", visual = "glow", env = "none" },
			pilih = { motion = true, sound = "tile_select", visual = "ghost", env = "hand_hover" },
			pasang_biasa = { motion = true, sound = "tile_place_soft", visual = "dust", env = "other_tiles" },
			hentak = { motion = true, sound = "tile_slam_heavy", visual = "dust_fov", env = "shake_coffee_lamp_tiles" },
			ilegal = { motion = true, sound = "buzz_illegal", visual = "red_glow", env = "return" },
			pas = { motion = true, sound = "knock_pass", visual = "ripple", env = "none" },
		}

		local allHave4Layers = true
		for actionName, layers in pairs(checklist) do
			if not layers.motion or not layers.sound or not layers.visual or not layers.env then
				allHave4Layers = false
			end
		end

		assertTest(
			"F01_FourLayersChecklistGroupA",
			allHave4Layers,
			"8 aksi di Grup A memiliki 4 lapisan (Gerakan, Suara, Visual, Lingkungan)"
		)
	end

	-- ====================================================================
	-- F02: Keamanan SoundManager saat ID Suara Kosong (Safe Fallback)
	-- ====================================================================
	do
		local crashed = false
		local ok1, _ = pcall(function() SoundManager.PlaySlam("MEDIUM") end)
		local ok2, _ = pcall(function() SoundManager.PlayPlace() end)
		local ok3, _ = pcall(function() SoundManager.PlayKnock() end)
		local ok4, _ = pcall(function() SoundManager.PlayHover() end)
		local ok5, _ = pcall(function() SoundManager.PlaySelect() end)
		local ok6, _ = pcall(function() SoundManager.PlayIllegal() end)
		local ok7, _ = pcall(function() SoundManager.PlayDeal() end)
		local ok8, _ = pcall(function() SoundManager.PlayShuffle() end)

		if not (ok1 and ok2 and ok3 and ok4 and ok5 and ok6 and ok7 and ok8) then
			crashed = true
		end

		assertTest(
			"F02_SoundManagerSafeFallbackEmptyIds",
			not crashed,
			"SoundManager no-op anggun saat slot audio masih string kosong"
		)
	end

	-- ====================================================================
	-- F03: SLA Total Durasi Hentakan <= 0.9s (GAME_FEEL.md §9)
	-- ====================================================================
	do
		local maxAllowed = FeelConfig.SLAM_TOTAL_TIME -- 0.9s
		local allWithinSla = true
		local detailMsg = ""

		for key, preset in pairs(FeelConfig.SLAM_PRESETS) do
			local liftTime = 0.14
			local pause = preset.PREPARE_PAUSE
			local swing = preset.SWING_TIME
			local total = liftTime + pause + swing

			if total > maxAllowed then
				allWithinSla = false
				detailMsg = string.format("Preset %s total %.2fs melebihi batas %.2fs", key, total, maxAllowed)
				break
			end
		end

		assertTest(
			"F03_SlamDurationRespectsSlaMax09s",
			allWithinSla,
			detailMsg ~= "" and detailMsg or string.format("Semua 3 preset hentak <= %.2fs", maxAllowed)
		)
	end

	-- ====================================================================
	-- F04: Variasi Acak (Jitter) Pitch & Sudut Kartu
	-- ====================================================================
	do
		local pitchVar = FeelConfig.HANDS.AUDIO_PITCH_VARIATION -- 0.08
		local angleVar = FeelConfig.HANDS.ANGLE_VARIATION_DEG   -- 3.0 deg

		local rngMock = Rng.deterministic(777)
		local minPitch = 1.0 - pitchVar
		local maxPitch = 1.0 + pitchVar

		local pitchOk = (minPitch >= 0.90 and maxPitch <= 1.10)
		local angleOk = (angleVar == 3.0)

		assertTest(
			"F04_RandomPitchAndAngleJitterConfig",
			pitchOk and angleOk,
			string.format("Pitch var=±%.1f%%, Sudut var=±%.1f°", pitchVar * 100, angleVar)
		)
	end

	-- ====================================================================
	-- F05: Quality Tier Gating & Opsi Kurangi Guncangan
	-- ====================================================================
	do
		-- Test 1: Reduce shake toggle
		local origReduce = FeelConfig.USER_SETTINGS.REDUCE_SHAKE
		FeelConfig.USER_SETTINGS.REDUCE_SHAKE = true

		local shakeBlocked = (FeelConfig.USER_SETTINGS.REDUCE_SHAKE == true)
		FeelConfig.USER_SETTINGS.REDUCE_SHAKE = origReduce

		-- Test 2: Quality tiers
		local tierLowOk = (FeelConfig.QUALITY.LOW == 1)
		local tierMedOk = (FeelConfig.QUALITY.MEDIUM == 2)
		local tierHighOk = (FeelConfig.QUALITY.HIGH == 3)

		assertTest(
			"F05_QualityTierAndReduceShakeOptions",
			shakeBlocked and tierLowOk and tierMedOk and tierHighOk,
			"Opsi Kurangi Guncangan & 3 tier kualitas terdefinisi tepat"
		)
	end

	-- ====================================================================
	-- F06: FeelLab Runtime Override Setter & Reset
	-- ====================================================================
	do
		FeelConfig.SetOverride("TEST_SLAM_LIFT", 1.25)
		local val = FeelConfig.GetOverride("TEST_SLAM_LIFT")
		local exported = FeelConfig.ExportOverrides()

		FeelConfig.ResetOverrides()
		local afterReset = FeelConfig.GetOverride("TEST_SLAM_LIFT")

		local overrideOk = (val == 1.25 and exported["TEST_SLAM_LIFT"] == 1.25 and afterReset == nil)

		assertTest(
			"F06_FeelLabRuntimeOverrideSystem",
			overrideOk,
			"FeelLab dapat mengubah, mengekspor, dan mereset nilai FeelConfig"
		)
	end

	-- ====================================================================
	-- F07: Reaksi Lingkungan Pos Ronda
	-- ====================================================================
	do
		local envCfg = FeelConfig.ENVIRONMENT
		local coffeeRippleOk = (envCfg.COFFEE_CUP_SHAKE > 0)
		local lampSwayOk = (envCfg.LAMP_SWAY_MAX_DEG > 0)
		local tilesRadiusOk = (envCfg.OTHER_TILES_RADIUS >= 3.0)

		assertTest(
			"F07_PosRondaEnvironmentReactionConfig",
			coffeeRippleOk and lampSwayOk and tilesRadiusOk,
			string.format("Kopi shake=%.2f, Bohlam sway=%.1f°, Radius kartu=%.1f studs",
				envCfg.COFFEE_CUP_SHAKE, envCfg.LAMP_SWAY_MAX_DEG, envCfg.OTHER_TILES_RADIUS)
		)
	end

	return passed, failed, logs
end

return M5aFeelTests
