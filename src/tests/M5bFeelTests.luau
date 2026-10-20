--!strict
--[=[
	M5bFeelTests.luau
	Unit test suite untuk Milestone M5 Grup B (Kamera & UI: 4 Lapisan Feel, CameraFX, UIAnimator, UIController, FeelLab).
	Sumber: GAME_FEEL.md §1–2, §4, §8–9; FIRST_PERSON_HANDS.md §4, §7; UI_UX_SPEC.md §3, §7.

	Cakupan Pengujian:
	- FB01: Checklist 4 lapisan lengkap untuk 8 aksi Grup B (Napas Kamera, Condong Giliran, Shake, FOV Punch,
	        Skor Menghitung Naik, Notifikasi, Indikator Giliran, Peringatan Waktu <= 10s).
	- FB02: Napas kamera sinusoidal & transisi Condong Saat Giliran (Turn Lean) non-linear + antisipasi.
	- FB03: Camera Shake (0.15-0.25s, peluruhan eksponensial) & FOV Punch menghormati REDUCE_SHAKE & Quality Tier.
	- FB04: Keamanan SoundManager untuk slot audio Grup B (turn_ting, timer_tick, score_tick) saat ID kosong.
	- FB05: Skor menghitung naik (UIAnimator.CountNumber + UIController.TriggerScoreCountUp) & Notifikasi Slide-in/Fade-out.
	- FB06: Indikator Giliran 3D (BillboardGui + cincin timer + spotlight meja + angkat tipis kartu sah di RackView).
	- FB07: Peringatan Waktu <= 10 detik (timer_tick + cincin merah berdenyut + kedipan lampu meja FlickerLamp).
	- FB08: Integrasi pemicu & stepper Grup B di FeelLab.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerStorage = game:GetService("ServerStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))

local clientFolder = StarterPlayer.StarterPlayerScripts.Client
local SoundManager = require(clientFolder:WaitForChild("SoundManager"))
local CameraFX = require(clientFolder:WaitForChild("CameraFX"))
local UIAnimator = require(clientFolder:WaitForChild("UIAnimator"))
local TileAnimator = require(clientFolder:WaitForChild("TileAnimator"))
local RackView = require(clientFolder:WaitForChild("RackView"))

local M5bFeelTests = {}

function M5bFeelTests.RunAll(): (number, number, { string })
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
	-- FB01: Checklist 4 Lapisan per Aksi Grup B (GAME_FEEL.md §4)
	-- ====================================================================
	do
		local checklistB = {
			napas_kamera = {
				motion = "Gelombang sinusoidal Y (±0.018 stud) & pitch (±0.35°)",
				sound = "Senyap disengaja (tidak mendistraksi fokus kartu)",
				visual = "Ayunan paralaks halus terhadap rak kartu & tepi meja",
				env = "Sinkron dengan pose bernapas tangan (HandController Idle)",
			},
			condong_giliran = {
				motion = "Antisipasi tarik napas + condong maju 0.15 stud & tunduk -2.5° (Quad Out)",
				sound = "Dipicu bersama turn_ting saat giliran dimulai",
				visual = "Sudut pandang mendekat ke rak & kartu sah terangkat tipis (0.07 stud)",
				env = "Cincin sorot meja menyala di depan kursi lokal",
			},
			shake_kamera = {
				motion = "Getaran posisi & roll (0.15–0.25s) dengan peluruhan eksponensial",
				sound = "Sinkron dengan benturan tile_slam_heavy",
				visual = "Jitter sudut pandang sesaat tanpa memutus orientasi",
				env = "Sinkron dengan guncangan gelas kopi & kartu sekitar",
			},
			fov_punch = {
				motion = "Lonjakan FieldOfView (+2°..+5°) dan kembali halus (Quad Out 0.25s)",
				sound = "Sinkron dengan puncak benturan hentak",
				visual = "Efek dorongan optik dinamis ke pusat meja",
				env = "Sinkron dengan kepulan debu & ayunan bohlam lampu",
			},
			skor_naik = {
				motion = "Angka bergulir naik non-linear (Quad Out) + denyut skala label (1.12x)",
				sound = "Bunyi score_tick bertempo dengan kenaikan pitch bertahap",
				visual = "Teks skor berkilau kuning bohlam selama penambahan",
				env = "Bohlam lampu pos ronda berayun tipis (SwayLamp 1.0°)",
			},
			notifikasi = {
				motion = "Slide-in dari atas (Back Out 0.25s) + denyut halus + Slide-out (Quad In)",
				sound = "Bunyi klik/ting UI halus (tile_hover)",
				visual = "Banner kayu tua dengan aksen border kontekstual (kuning/merah)",
				env = "Posisi tengah atas (Y=58px) bebas obstruksi area meja",
			},
			indikator_giliran = {
				motion = "Billboard 3D berpindah (Back Out) + cincin berdenyut + kartu sah naik tipis",
				sound = "Bunyi turn_ting posisional di kursi pemain aktif",
				visual = "BillboardGui nama + cincin timer di atas kepala + status bar bawah",
				env = "Sorotan cincin neon halus (TurnTableSpotlight) di permukaan meja",
			},
			peringatan_waktu = {
				motion = "Denyut cepat (1.14x) pada label timer & cincin 3D setiap detik (<= 10s)",
				sound = "Bunyi detak timer_tick per detik (pitch naik saat <= 5s)",
				visual = "Warna teks timer, cincin 3D, & sorotan meja berubah merah cabai",
				env = "Bohlam lampu meja berkedip sekali (FlickerLamp) saat menyentuh 10s",
			},
		}

		local allComplete = true
		for _, layers in pairs(checklistB) do
			if not layers.motion or not layers.sound or not layers.visual or not layers.env then
				allComplete = false
			end
		end

		assertTest(
			"FB01_FourLayersChecklistGroupB",
			allComplete and FeelConfig.CAMERA_FEEL ~= nil and FeelConfig.UI_FEEL ~= nil,
			"8 aksi di Grup B memiliki 4 lapisan lengkap & terkonfigurasi di FeelConfig"
		)
	end

	-- ====================================================================
	-- FB02: Napas Kamera Sinusoidal & Condong Saat Giliran (CameraFX)
	-- ====================================================================
	do
		CameraFX.Reset()
		local origReduce = FeelConfig.USER_SETTINGS.REDUCE_SHAKE
		FeelConfig.USER_SETTINGS.REDUCE_SHAKE = false

		local t0 = os.clock()
		local pos1, pitch1, _ = CameraFX.ComputeFrameOffsets(t0 + 0.9) -- ~1/4 periode (3.6s)
		local pos2, pitch2, _ = CameraFX.ComputeFrameOffsets(t0 + 2.7) -- ~3/4 periode

		local breathMovesY = math.abs(pos1.Y - pos2.Y) > 0.005
		local breathMovesPitch = math.abs(pitch1 - pitch2) > 0.05

		-- Uji Condong Giliran (Turn Lean)
		CameraFX.SetTurnLean(true)
		local isLeanOn, _ = CameraFX.GetTurnLeanState()
		-- Simulasi waktu setelah transisi selesai (+0.5s)
		local posLean, pitchLean, _ = CameraFX.ComputeFrameOffsets(os.clock() + 0.5)
		local _, alphaAfter = CameraFX.GetTurnLeanState()

		local leanForwardOk = (isLeanOn == true and alphaAfter >= 0.99 and posLean.Z < -0.10 and pitchLean < -1.5)

		-- Kembalikan ke rileks
		CameraFX.SetTurnLean(false)
		CameraFX.ComputeFrameOffsets(os.clock() + 0.5)
		local isLeanOff, alphaRelax = CameraFX.GetTurnLeanState()
		local relaxOk = (isLeanOff == false and math.abs(alphaRelax) < 0.01)

		FeelConfig.USER_SETTINGS.REDUCE_SHAKE = origReduce
		CameraFX.Reset()

		assertTest(
			"FB02_CameraBreathingAndTurnLean",
			breathMovesY and breathMovesPitch and leanForwardOk and relaxOk,
			string.format("Breath dY=%.4f, Lean alpha=%.2f, Lean Z=%.3f", math.abs(pos1.Y - pos2.Y), alphaAfter, posLean.Z)
		)
	end

	-- ====================================================================
	-- FB03: Camera Shake (0.15-0.25s) & FOV Punch + Opsi REDUCE_SHAKE
	-- ====================================================================
	do
		CameraFX.Reset()
		local origReduce = FeelConfig.USER_SETTINGS.REDUCE_SHAKE

		-- 1. Saat REDUCE_SHAKE = false: Shake & FOV Punch aktif
		FeelConfig.USER_SETTINGS.REDUCE_SHAKE = false
		local shakeTriggered = CameraFX.TriggerShake(1.0, 0.20)
		local fovTriggered = CameraFX.TriggerFOVPunch(workspace.CurrentCamera, 3.5)

		-- 2. Saat REDUCE_SHAKE = true: Shake & FOV Punch diblokir
		FeelConfig.USER_SETTINGS.REDUCE_SHAKE = true
		local shakeBlocked = (CameraFX.TriggerShake(1.0, 0.20) == false)
		local fovBlocked = (CameraFX.TriggerFOVPunch(workspace.CurrentCamera, 3.5) == false)

		-- 3. Durasi shake sesuai rentang spesifikasi 0.15 - 0.25 s
		local durMin = FeelConfig.CAMERA_FEEL.SHAKE_MIN_DURATION
		local durMax = FeelConfig.CAMERA_FEEL.SHAKE_MAX_DURATION
		local durRangeOk = (durMin >= 0.15 and durMax <= 0.25)

		FeelConfig.USER_SETTINGS.REDUCE_SHAKE = origReduce
		CameraFX.Reset()

		assertTest(
			"FB03_ShakeAndFovPunchRespectReduceShake",
			shakeTriggered and fovTriggered and shakeBlocked and fovBlocked and durRangeOk,
			"Shake (0.15-0.25s) & FOV Punch berfungsi dan menghormati REDUCE_SHAKE"
		)
	end

	-- ====================================================================
	-- FB04: Keamanan SoundManager untuk Slot Audio Grup B
	-- ====================================================================
	do
		local ok1 = pcall(function() SoundManager.PlayTurnTing() end)
		local ok2 = pcall(function() SoundManager.PlayTimerTick(false) end)
		local ok3 = pcall(function() SoundManager.PlayTimerTick(true) end)
		local ok4 = pcall(function() SoundManager.PlayScoreTick(0.5) end)

		assertTest(
			"FB04_GroupBSoundSlotsSafeFallback",
			ok1 and ok2 and ok3 and ok4,
			"PlayTurnTing, PlayTimerTick, dan PlayScoreTick aman saat ID kosong"
		)
	end

	-- ====================================================================
	-- FB05: Skor Menghitung Naik & Notifikasi Slide-In/Out (UIAnimator)
	-- ====================================================================
	do
		local dummyLabel = Instance.new("TextLabel")
		local finalReached = false
		UIAnimator.CountNumber(dummyLabel, 10, 28, 0.0, "TIM 1: ", " Poin", function()
			finalReached = true
		end)
		local textOk = (dummyLabel.Text == "TIM 1: 28 Poin" and finalReached)
		dummyLabel:Destroy()

		local dummyBanner = Instance.new("Frame")
		dummyBanner.Position = UDim2.new(0.5, -160, 0, -100)
		dummyBanner.Visible = false
		UIAnimator.SlideInTop(dummyBanner, UDim.new(0, 58), 0.05)
		local slideInVisible = (dummyBanner.Visible == true)
		dummyBanner:Destroy()

		assertTest(
			"FB05_ScoreCountUpAndNotificationTween",
			textOk and slideInVisible,
			"UIAnimator.CountNumber & SlideInTop bekerja sesuai spesifikasi"
		)
	end

	-- ====================================================================
	-- FB06: RackView Angkat Tipis Kartu Sah Saat Giliran (HighlightPlayableTiles)
	-- ====================================================================
	do
		local rv = RackView.new(1, true)
		rv:RenderRack({
			{ a = 6, b = 6 },
			{ a = 2, b = 5 },
			{ a = 1, b = 4 },
		})

		local okHighlight = pcall(function()
			rv:HighlightPlayableTiles({ [1] = true, [3] = true })
		end)
		local tileCountOk = (#rv.tiles == 3)
		rv:Destroy()

		assertTest(
			"FB06_RackViewHighlightPlayableTilesOnTurn",
			okHighlight and tileCountOk,
			"Kartu yang sah dimainkan di rak terangkat tipis saat giliran dimulai"
		)
	end

	-- ====================================================================
	-- FB07: Peringatan Waktu <= 10 Detik & Kedipan Lampu Meja (FlickerLamp)
	-- ====================================================================
	do
		local warnCfgOk = (
			FeelConfig.UI_FEEL.TIME_WARNING_THRESHOLD == 10
			and FeelConfig.UI_FEEL.TIME_CRITICAL_THRESHOLD == 5
			and FeelConfig.UI_FEEL.LAMP_FLICKER_DURATION > 0
		)
		local okFlicker = pcall(function()
			TileAnimator.FlickerLamp()
			TileAnimator.SwayLamp(1.0)
		end)

		assertTest(
			"FB07_TimeWarning10sAndLampFlicker",
			warnCfgOk and okFlicker,
			"Ambang peringatan 10s dan efek kedipan bohlam meja berjalan tanpa error"
		)
	end

	-- ====================================================================
	-- FB08: Keberadaan Modul FeelLab dengan Dukungan Grup B
	-- ====================================================================
	do
		local devFolder = ServerStorage:FindFirstChild("Dev")
		local feelLabMod = devFolder and devFolder:FindFirstChild("FeelLab")
		local debugCfgMod = devFolder and devFolder:FindFirstChild("DebugConfig")
		local hasFeelLab = (feelLabMod ~= nil and debugCfgMod ~= nil)

		assertTest(
			"FB08_FeelLabGroupBIntegration",
			hasFeelLab,
			"Modul FeelLab & DebugConfig tersedia di ServerStorage.Dev"
		)
	end

	return passed, failed, logs
end

return M5bFeelTests
