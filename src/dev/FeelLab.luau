--!strict
--[=[
	FeelLab.luau
	Panel dev interaktif untuk memicu, menguji, menyetel, dan mengekspor feel Grup A (GAME_FEEL.md).

	Fitur:
	- Flag ENABLED (hanya aktif saat dev / testing).
	- Pemicu aksi berulang: Kocok, Bagi, Hover, Pilih, Pasang Biasa, Hentak (3 preset), Ilegal, Pas.
	- Penyetelan parameter FeelConfig saat berjalan (live sliders/steppers).
	- Ekspor preset langsung ke konsol Studio agar mudah disalin ke FeelConfig.luau.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Types = require(sharedFolder:WaitForChild("Types"))

local localPlayer = Players.LocalPlayer

local FeelLab = {}

-- Flag status (aktifkan untuk pengujian visual/feel)
FeelLab.ENABLED = true

local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local isCollapsed = false

-- Referensi subsistem client
local TileAnimator: any = nil
local SoundManager: any = nil
local TileFactory: any = nil
local CameraController: any = nil
local UIController: any = nil
local EmoteController: any = nil

local function getClientModules()
	local clientScripts = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
	if not TileAnimator then
		TileAnimator = require(clientScripts:WaitForChild("TileAnimator"))
	end
	if not SoundManager then
		SoundManager = require(clientScripts:WaitForChild("SoundManager"))
	end
	if not TileFactory then
		TileFactory = require(clientScripts:WaitForChild("TileFactory"))
	end
	if not CameraController then
		CameraController = require(clientScripts:WaitForChild("CameraController"))
	end
	if not UIController then
		UIController = require(clientScripts:WaitForChild("UIController"))
	end
	if not EmoteController then
		EmoteController = require(clientScripts:WaitForChild("EmoteController"))
	end
end

-- Helper membuat tombol aksi
local function createActionButton(name: string, text: string, color: Color3, parent: Instance, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.Size = UDim2.new(1, -12, 0, 28)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.fromRGB(245, 245, 245)
	btn.Font = Enum.Font.SourceSansBold
	btn.TextSize = 13
	btn.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.Activated:Connect(onClick)
	btn.Parent = parent
	return btn
end

-- Helper membuat baris stepper nilai
local function createStepper(
	label: string,
	initialVal: number,
	step: number,
	minVal: number,
	maxVal: number,
	parent: Instance,
	onChange: (val: number) -> ()
): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -12, 0, 26)
	row.BackgroundTransparency = 1

	local lbl = Instance.new("TextLabel")
	lbl.Text = label
	lbl.Size = UDim2.new(0.5, 0, 1, 0)
	lbl.TextColor3 = Color3.fromRGB(220, 220, 225)
	lbl.Font = Enum.Font.SourceSans
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1
	lbl.Parent = row

	local currentVal = initialVal

	local valLbl = Instance.new("TextLabel")
	valLbl.Text = string.format("%.2f", currentVal)
	valLbl.Size = UDim2.new(0.2, 0, 1, 0)
	valLbl.Position = UDim2.new(0.5, 0, 0, 0)
	valLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
	valLbl.Font = Enum.Font.SourceSansBold
	valLbl.TextSize = 12
	valLbl.BackgroundTransparency = 1
	valLbl.Parent = row

	local btnMinus = Instance.new("TextButton")
	btnMinus.Text = "-"
	btnMinus.Size = UDim2.new(0, 22, 0, 22)
	btnMinus.Position = UDim2.new(0.72, 0, 0, 2)
	btnMinus.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
	btnMinus.TextColor3 = Color3.fromRGB(240, 240, 240)
	btnMinus.Font = Enum.Font.SourceSansBold
	btnMinus.Parent = row

	local btnPlus = Instance.new("TextButton")
	btnPlus.Text = "+"
	btnPlus.Size = UDim2.new(0, 22, 0, 22)
	btnPlus.Position = UDim2.new(0.86, 0, 0, 2)
	btnPlus.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
	btnPlus.TextColor3 = Color3.fromRGB(240, 240, 240)
	btnPlus.Font = Enum.Font.SourceSansBold
	btnPlus.Parent = row

	btnMinus.Activated:Connect(function()
		currentVal = math.clamp(currentVal - step, minVal, maxVal)
		valLbl.Text = string.format("%.2f", currentVal)
		onChange(currentVal)
	end)

	btnPlus.Activated:Connect(function()
		currentVal = math.clamp(currentVal + step, minVal, maxVal)
		valLbl.Text = string.format("%.2f", currentVal)
		onChange(currentVal)
	end)

	row.Parent = parent
	return row
end

-- Helper mencari dummy spot di meja
local function getTestSpotCFrame(): CFrame
	local posRonda = workspace:FindFirstChild("PosRonda")
	local tbl = posRonda and posRonda:FindFirstChild("Table")
	local boardCenter = tbl and tbl:FindFirstChild("BoardCenter") :: BasePart?
	if boardCenter then
		return boardCenter.CFrame * CFrame.new(0, 0.1, 0)
	end
	return CFrame.new(0, 4.25, 0)
end

--[=[
	Inisialisasi GUI FeelLab di PlayerGui.
]=]
function FeelLab.Init()
	if not FeelLab.ENABLED then return end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	if playerGui:FindFirstChild("FeelLabGui") then
		playerGui.FeelLabGui:Destroy()
	end

	getClientModules()

	local sg = Instance.new("ScreenGui")
	sg.Name = "FeelLabGui"
	sg.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Name = "MainFrame"
	frame.Size = UDim2.new(0, 260, 0, 480)
	frame.Position = UDim2.new(1, -270, 0.5, -240)
	frame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 150, 80)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	-- Header Title
	local header = Instance.new("TextLabel")
	header.Text = "FEEL LAB: GRUP A, B & C"
	header.Size = UDim2.new(1, -40, 0, 32)
	header.Position = UDim2.new(0, 10, 0, 2)
	header.TextColor3 = Color3.fromRGB(255, 215, 90)
	header.Font = Enum.Font.SourceSansBold
	header.TextSize = 15
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.BackgroundTransparency = 1
	header.Parent = frame

	-- Collapse button
	local btnCollapse = Instance.new("TextButton")
	btnCollapse.Text = "_"
	btnCollapse.Size = UDim2.new(0, 24, 0, 24)
	btnCollapse.Position = UDim2.new(1, -28, 0, 4)
	btnCollapse.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
	btnCollapse.TextColor3 = Color3.fromRGB(240, 240, 240)
	btnCollapse.Font = Enum.Font.SourceSansBold
	btnCollapse.Parent = frame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -38)
	scroll.Position = UDim2.new(0, 0, 0, 36)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 5
	scroll.CanvasSize = UDim2.new(0, 0, 0, 1850)
	scroll.Parent = frame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = scroll

	btnCollapse.Activated:Connect(function()
		isCollapsed = not isCollapsed
		scroll.Visible = not isCollapsed
		frame.Size = if isCollapsed then UDim2.new(0, 260, 0, 38) else UDim2.new(0, 260, 0, 480)
		btnCollapse.Text = if isCollapsed then "□" else "_"
	end)

	-- ================================================================
	-- TOMBOL-TOMBOL PEMICU AKSI GRUP A
	-- ================================================================

	local dummyTile: BasePart? = nil
	local function getOrMakeDummyTile(): BasePart
		if not dummyTile or not dummyTile.Parent then
			dummyTile = TileFactory.CreateTile(6, 6, false)
			dummyTile.Name = "FeelLab_DummyTile"
			dummyTile.CFrame = getTestSpotCFrame()
		end
		return dummyTile
	end

	-- 1. Hentak: Ringan
	createActionButton("BtnSlamLight", "HENTAK: RINGAN", Color3.fromRGB(60, 120, 70), scroll, function()
		local t = getOrMakeDummyTile()
		TileAnimator.AnimateSlam(t, getTestSpotCFrame(), "LIGHT")
	end)

	-- 2. Hentak: Sedang (Default Balak)
	createActionButton("BtnSlamMed", "HENTAK: SEDANG (DEFAULT)", Color3.fromRGB(160, 110, 40), scroll, function()
		local t = getOrMakeDummyTile()
		TileAnimator.AnimateSlam(t, getTestSpotCFrame(), "MEDIUM")
	end)

	-- 3. Hentak: Banting Meja (Klimaks)
	createActionButton("BtnSlamHeavy", "HENTAK: BANTING MEJA!", Color3.fromRGB(180, 50, 40), scroll, function()
		local t = getOrMakeDummyTile()
		TileAnimator.AnimateSlam(t, getTestSpotCFrame(), "HEAVY")
	end)

	-- 4. Pasang Biasa (Soft Place)
	createActionButton("BtnPlaceSoft", "PASANG BIASA (TOK)", Color3.fromRGB(50, 90, 140), scroll, function()
		local t = getOrMakeDummyTile()
		TileAnimator.AnimatePlaceNormal(t, getTestSpotCFrame())
	end)

	-- 5. Kocok Kartu (Shuffle)
	createActionButton("BtnShuffle", "KOCOK KARTU (1.5s)", Color3.fromRGB(80, 70, 110), scroll, function()
		local tiles = {}
		for i = 1, 12 do
			local t = TileFactory.CreateTile(i % 7, (i + 1) % 7, false)
			table.insert(tiles, t)
		end
		TileAnimator.AnimateShuffle(tiles, getTestSpotCFrame().Position, 1.5, function()
			for _, t in ipairs(tiles) do
				TileFactory.RecycleTile(t)
			end
		end)
	end)

	-- 6. Bagi Kartu (Deal)
	createActionButton("BtnDeal", "BAGI KARTU (SRET)", Color3.fromRGB(70, 100, 90), scroll, function()
		local t = getOrMakeDummyTile()
		local startPos = getTestSpotCFrame().Position + Vector3.new(0, 0.5, 0)
		local endCF = getTestSpotCFrame() * CFrame.new(0.8, 0, 0.8)
		TileAnimator.AnimateDeal(t, startPos, endCF)
	end)

	-- 7. Langkah Ilegal (Shake + Buzz)
	createActionButton("BtnIllegal", "LANGKAH ILEGAL (BUZZ)", Color3.fromRGB(150, 40, 40), scroll, function()
		local t = getOrMakeDummyTile()
		TileAnimator.AnimateIllegal(t, getTestSpotCFrame())
	end)

	-- 8. Pas (Ketuk Meja 2x)
	createActionButton("BtnKnock", "PAS (KETUK MEJA 2X)", Color3.fromRGB(90, 95, 105), scroll, function()
		TileAnimator.AnimateKnock(getTestSpotCFrame().Position)
	end)

	-- 9. Hover & Pilih Demo
	createActionButton("BtnHoverSelect", "HOVER & PILIH KARTU", Color3.fromRGB(120, 110, 50), scroll, function()
		local t = getOrMakeDummyTile()
		SoundManager.PlayHover()
		TileFactory.SetGlow(t, "hover")
		task.wait(0.25)
		SoundManager.PlaySelect()
		TileFactory.SetGlow(t, "selected")
		task.wait(0.5)
		TileFactory.SetGlow(t, "none")
	end)

	-- ================================================================
	-- PENYETELAN PARAMETER (LIVE STEPPERS)
	-- ================================================================

	local sectionLbl = Instance.new("TextLabel")
	sectionLbl.Text = "-- PENYETELAN PARAMETER --"
	sectionLbl.Size = UDim2.new(1, -12, 0, 20)
	sectionLbl.TextColor3 = Color3.fromRGB(180, 180, 190)
	sectionLbl.Font = Enum.Font.SourceSansBold
	sectionLbl.TextSize = 12
	sectionLbl.BackgroundTransparency = 1
	sectionLbl.Parent = scroll

	createStepper("Slam Lift (stud)", FeelConfig.SLAM_PRESETS.MEDIUM.LIFT, 0.1, 0.3, 2.0, scroll, function(v)
		FeelConfig.SLAM_PRESETS.MEDIUM.LIFT = v
		FeelConfig.SetOverride("SLAM_MEDIUM_LIFT", v)
	end)

	createStepper("Tilt Angle (deg)", FeelConfig.SLAM_PRESETS.MEDIUM.TILT_DEG, 5.0, 5.0, 60.0, scroll, function(v)
		FeelConfig.SLAM_PRESETS.MEDIUM.TILT_DEG = v
		FeelConfig.SetOverride("SLAM_MEDIUM_TILT", v)
	end)

	createStepper("Prepare Pause (s)", FeelConfig.SLAM_PRESETS.MEDIUM.PREPARE_PAUSE, 0.02, 0.02, 0.30, scroll, function(v)
		FeelConfig.SLAM_PRESETS.MEDIUM.PREPARE_PAUSE = v
		FeelConfig.SetOverride("SLAM_MEDIUM_PAUSE", v)
	end)

	createStepper("Swing Time (s)", FeelConfig.SLAM_PRESETS.MEDIUM.SWING_TIME, 0.02, 0.06, 0.40, scroll, function(v)
		FeelConfig.SLAM_PRESETS.MEDIUM.SWING_TIME = v
		FeelConfig.SetOverride("SLAM_MEDIUM_SWING", v)
	end)

	createStepper("FOV Punch (deg)", FeelConfig.SLAM_PRESETS.MEDIUM.FOV_PUNCH, 0.5, 0.0, 10.0, scroll, function(v)
		FeelConfig.SLAM_PRESETS.MEDIUM.FOV_PUNCH = v
		FeelConfig.SetOverride("SLAM_MEDIUM_FOV", v)
	end)

	createStepper("Camera Shake Amp", FeelConfig.SLAM_PRESETS.MEDIUM.SHAKE_AMP, 0.2, 0.0, 3.0, scroll, function(v)
		FeelConfig.SLAM_PRESETS.MEDIUM.SHAKE_AMP = v
		FeelConfig.SetOverride("SLAM_MEDIUM_SHAKE", v)
	end)

	createStepper("Dust Count", FeelConfig.SLAM_PRESETS.MEDIUM.DUST_COUNT, 5, 0, 60, scroll, function(v)
		FeelConfig.SLAM_PRESETS.MEDIUM.DUST_COUNT = v
		FeelConfig.SetOverride("SLAM_MEDIUM_DUST", v)
	end)

	-- ================================================================
	-- GRUP B: KAMERA & UI FEEL TRIGGERS + STEPPERS
	-- ================================================================

	local sectionGrpB = Instance.new("TextLabel")
	sectionGrpB.Text = "-- GRUP B: KAMERA & UI --"
	sectionGrpB.Size = UDim2.new(1, -12, 0, 22)
	sectionGrpB.TextColor3 = Color3.fromRGB(255, 215, 90)
	sectionGrpB.Font = Enum.Font.SourceSansBold
	sectionGrpB.TextSize = 13
	sectionGrpB.BackgroundTransparency = 1
	sectionGrpB.Parent = scroll

	local demoLeanActive = false
	createActionButton("BtnToggleLean", "CONDONG GILIRAN (TOGGLE)", Color3.fromRGB(60, 110, 150), scroll, function()
		demoLeanActive = not demoLeanActive
		CameraController.SetTurnLean(demoLeanActive)
	end)

	createActionButton("BtnShakeFov", "SHAKE + FOV PUNCH", Color3.fromRGB(165, 85, 45), scroll, function()
		CameraController.Shake(FeelConfig.SHAKE.AMPLITUDE, FeelConfig.CAMERA_FEEL.SHAKE_DEFAULT_DURATION)
		CameraController.PunchFOV(FeelConfig.FOV.PUNCH_DEGREES)
	end)

	local demoScoreVal = 24
	createActionButton("BtnScoreUp", "SKOR MENGHITUNG NAIK (+18)", Color3.fromRGB(50, 130, 80), scroll, function()
		local prev = demoScoreVal
		demoScoreVal += 18
		if UIController and UIController.TriggerScoreCountUp then
			UIController.TriggerScoreCountUp({ [1] = prev, [2] = 15 }, { [1] = demoScoreVal, [2] = 15 }, "2v2")
		end
	end)

	local notifySamples = {
		"Giliranmu!",
		"Bot Mas Joko pas (ketuk meja)",
		"Kocok ulang: tidak ada balak pembuka",
	}
	local notifyIdx = 0
	createActionButton("BtnNotify", "NOTIFIKASI SLIDE-IN (TES)", Color3.fromRGB(115, 80, 140), scroll, function()
		notifyIdx = (notifyIdx % #notifySamples) + 1
		if UIController and UIController.ShowNotification then
			UIController.ShowNotification(notifySamples[notifyIdx], FeelConfig.UI_FEEL.NOTIFY_HOLD_TIME)
		end
	end)

	local demoTurnSeat = 0
	createActionButton("BtnTurnInd", "INDIKATOR GILIRAN 3D + TING", Color3.fromRGB(140, 115, 40), scroll, function()
		demoTurnSeat = (demoTurnSeat % 4) + 1
		if UIController and UIController.UpdateTurnIndicator then
			UIController.UpdateTurnIndicator(demoTurnSeat, os.clock() + 15, true)
		end
	end)

	createActionButton("BtnTimeWarn", "PERINGATAN WAKTU 10s + KEDIP", Color3.fromRGB(175, 45, 45), scroll, function()
		if UIController and UIController.TriggerTimeWarning then
			UIController.TriggerTimeWarning(10)
		end
	end)

	createStepper("Breath Amp Y", FeelConfig.CAMERA_FEEL.BREATH_AMP_Y, 0.005, 0.0, 0.06, scroll, function(v)
		FeelConfig.CAMERA_FEEL.BREATH_AMP_Y = v
		FeelConfig.SetOverride("CAM_BREATH_AMP_Y", v)
	end)

	createStepper("Turn Lean (stud)", FeelConfig.CAMERA_FEEL.TURN_LEAN_FORWARD, 0.03, 0.0, 0.40, scroll, function(v)
		FeelConfig.CAMERA_FEEL.TURN_LEAN_FORWARD = v
		FeelConfig.SetOverride("CAM_TURN_LEAN_FORWARD", v)
	end)

	createStepper("Shake Dur (s)", FeelConfig.CAMERA_FEEL.SHAKE_DEFAULT_DURATION, 0.02, 0.15, 0.25, scroll, function(v)
		FeelConfig.CAMERA_FEEL.SHAKE_DEFAULT_DURATION = v
		FeelConfig.SHAKE.DURATION = v
		FeelConfig.SetOverride("CAM_SHAKE_DURATION", v)
	end)

	createStepper("Score Count (s)", FeelConfig.UI_FEEL.SCORE_COUNT_DURATION, 0.10, 0.20, 1.50, scroll, function(v)
		FeelConfig.UI_FEEL.SCORE_COUNT_DURATION = v
		FeelConfig.SetOverride("UI_SCORE_COUNT_DURATION", v)
	end)

	createStepper("Notify Hold (s)", FeelConfig.UI_FEEL.NOTIFY_HOLD_TIME, 0.20, 1.0, 5.0, scroll, function(v)
		FeelConfig.UI_FEEL.NOTIFY_HOLD_TIME = v
		FeelConfig.SetOverride("UI_NOTIFY_HOLD_TIME", v)
	end)

	-- ================================================================
	-- GRUP C: EMOTE, IDLE BERKALA, REAKSI GILIRAN LAMA, & REAKSI BOT
	-- ================================================================

	local sectionGrpC = Instance.new("TextLabel")
	sectionGrpC.Text = "-- GRUP C: EMOTE & KARAKTER --"
	sectionGrpC.Size = UDim2.new(1, -12, 0, 22)
	sectionGrpC.TextColor3 = Color3.fromRGB(255, 215, 90)
	sectionGrpC.Font = Enum.Font.SourceSansBold
	sectionGrpC.TextSize = 13
	sectionGrpC.BackgroundTransparency = 1
	sectionGrpC.Parent = scroll

	local demoEmoteIdx = 0
	createActionButton("BtnEmoteDemo", "DEMO 6 EMOTE (GELEMBUNG + GESTUR)", Color3.fromRGB(145, 75, 130), scroll, function()
		local order = FeelConfig.EMOTE.ORDER
		demoEmoteIdx = (demoEmoteIdx % #order) + 1
		local emoteId = order[demoEmoteIdx]
		if EmoteController and EmoteController.PlayEmoteForSeat then
			EmoteController.PlayEmoteForSeat(1, emoteId)
		end
	end)

	createActionButton("BtnIdleCoffee", "IDLE: SERUPUT KOPI + UAP", Color3.fromRGB(115, 75, 45), scroll, function()
		if EmoteController and EmoteController.TriggerIdleVariation then
			EmoteController.TriggerIdleVariation(1, "sip_coffee")
		end
	end)

	createActionButton("BtnIdleFan", "IDLE: KIPAS BADAN (3X)", Color3.fromRGB(55, 115, 115), scroll, function()
		if EmoteController and EmoteController.TriggerIdleVariation then
			EmoteController.TriggerIdleVariation(1, "fan_self")
		end
	end)

	createActionButton("BtnIdleScratch", "IDLE: GARUK KEPALA (2X)", Color3.fromRGB(95, 90, 60), scroll, function()
		if EmoteController and EmoteController.TriggerIdleVariation then
			EmoteController.TriggerIdleVariation(1, "scratch_head")
		end
	end)

	local lookTargetSeat = 0
	createActionButton("BtnLongTurnLook", "REAKSI GILIRAN LAMA (MENOLEH)", Color3.fromRGB(155, 95, 40), scroll, function()
		lookTargetSeat = (lookTargetSeat + 1) % 5 -- 1..4 lalu 0 (reset tengah meja)
		if EmoteController and EmoteController.TriggerLongTurnReaction then
			EmoteController.TriggerLongTurnReaction(if lookTargetSeat > 0 then lookTargetSeat else nil)
		end
	end)

	local botReactTypes = { "laugh", "yah", "clap", "taunt" }
	local botReactIdx = 0
	createActionButton("BtnBotReact", "REAKSI BOT KONTEKSTUAL", Color3.fromRGB(65, 125, 85), scroll, function()
		botReactIdx = (botReactIdx % #botReactTypes) + 1
		local seatToReact = ((botReactIdx % 3) + 2) -- Kursi 2, 3, atau 4
		if EmoteController and EmoteController.PlayEmoteForSeat then
			EmoteController.PlayEmoteForSeat(seatToReact, botReactTypes[botReactIdx])
		end
	end)

	createStepper("Idle Min (s)", FeelConfig.CHARACTER_FEEL.IDLE_MIN_INTERVAL, 1.0, 4.0, 25.0, scroll, function(v)
		FeelConfig.CHARACTER_FEEL.IDLE_MIN_INTERVAL = v
		FeelConfig.SetOverride("CHAR_IDLE_MIN_INTERVAL", v)
	end)

	createStepper("Sip Dur (s)", FeelConfig.CHARACTER_FEEL.SIP_COFFEE_DURATION, 0.1, 0.8, 3.0, scroll, function(v)
		FeelConfig.CHARACTER_FEEL.SIP_COFFEE_DURATION = v
		FeelConfig.SetOverride("CHAR_SIP_COFFEE_DURATION", v)
	end)

	createStepper("Long Turn (s)", FeelConfig.CHARACTER_FEEL.LONG_TURN_THRESHOLD, 1.0, 5.0, 20.0, scroll, function(v)
		FeelConfig.CHARACTER_FEEL.LONG_TURN_THRESHOLD = v
		FeelConfig.SetOverride("CHAR_LONG_TURN_THRESHOLD", v)
	end)

	createStepper("Head Look (deg)", FeelConfig.CHARACTER_FEEL.HEAD_LOOK_MAX_YAW_DEG, 3.0, 15.0, 65.0, scroll, function(v)
		FeelConfig.CHARACTER_FEEL.HEAD_LOOK_MAX_YAW_DEG = v
		FeelConfig.SetOverride("CHAR_HEAD_LOOK_MAX_YAW_DEG", v)
	end)

	-- ================================================================
	-- TOMBOL SIMPAN / EKSPOR PRESET KE KONSOL
	-- ================================================================

	createActionButton("BtnExport", "SIMPAN / EKSPOR PRESET", Color3.fromRGB(40, 130, 160), scroll, function()
		local p = FeelConfig.SLAM_PRESETS.MEDIUM
		local cf = FeelConfig.CAMERA_FEEL
		local uf = FeelConfig.UI_FEEL
		local chf = FeelConfig.CHARACTER_FEEL
		print("==================================================")
		print("-- [FEEL LAB EXPORT PRESET: GRUP A, B & C] --")
		print(string.format("LIFT = %.2f, TILT_DEG = %.1f, PREPARE_PAUSE = %.2f, SWING_TIME = %.2f,", p.LIFT, p.TILT_DEG, p.PREPARE_PAUSE, p.SWING_TIME))
		print(string.format("FOV_PUNCH = %.1f, SHAKE_AMP = %.2f, DUST_COUNT = %d,", p.FOV_PUNCH, p.SHAKE_AMP, p.DUST_COUNT))
		print(string.format("BREATH_AMP_Y = %.3f, TURN_LEAN_FORWARD = %.2f, SHAKE_DEFAULT_DURATION = %.2f,", cf.BREATH_AMP_Y, cf.TURN_LEAN_FORWARD, cf.SHAKE_DEFAULT_DURATION))
		print(string.format("SCORE_COUNT_DURATION = %.2f, NOTIFY_HOLD_TIME = %.2f,", uf.SCORE_COUNT_DURATION, uf.NOTIFY_HOLD_TIME))
		print(string.format("IDLE_MIN_INTERVAL = %.1f, SIP_COFFEE_DURATION = %.2f, LONG_TURN_THRESHOLD = %.1f, HEAD_LOOK_MAX_YAW_DEG = %.1f,", chf.IDLE_MIN_INTERVAL, chf.SIP_COFFEE_DURATION, chf.LONG_TURN_THRESHOLD, chf.HEAD_LOOK_MAX_YAW_DEG))
		print("==================================================")
	end)

	frame.Parent = sg
	sg.Parent = playerGui
	screenGui = sg
end

--[=[
	Membersihkan FeelLab dari layar.
]=]
function FeelLab.Destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return FeelLab
